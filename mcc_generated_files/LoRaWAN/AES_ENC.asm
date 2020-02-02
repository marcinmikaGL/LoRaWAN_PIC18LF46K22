;*********************************************************************
;*
;* AES encryption module
;*
;*********************************************************************
;* FileName: AES_ENC.inc
;* Dependencies: AES_VARS.inc, AES_MAC.inc
;* Processor: PIC18FXXX/18CXXX
;* Assembler: MPASMWIN 02.70.02 or higher
;* Linker: MPLINK 2.33.00 or higher
;* Company: Microchip Technology, Inc.
;*
;* Software License Agreement
;*
;* The software supplied herewith by Microchip Technology Incorporated
;* (the “Company”) for its PICmicro® Microcontroller is intended and
;* supplied to you, the Company’s customer, for use solely and
;* exclusively on Microchip PICmicro Microcontroller products. The
;* software is owned by the Company and/or its supplier, and is
;* protected under applicable copyright laws. All rights are reserved.
;* Any use in violation of the foregoing restrictions may subject the
;* user to criminal sanctions under applicable laws, as well as to
;* civil liability for the breach of the terms and conditions of this
;* license.
;*
;* Microchip Technology Inc. (“Microchip”) licenses this software to 
;* you solely for use with Microchip products.  The software is owned 
;* by Microchip and is protected under applicable copyright laws.  
;* All rights reserved.
;*
;* You may not export or re-export Software, technical data, direct 
;* products thereof or any other items which would violate any applicable
;* export control laws and regulations including, but not limited to, 
;* those of the United States or United Kingdom.  You agree that it is
;* your responsibility to obtain copies of and to familiarize yourself
;* fully with these laws and regulations to avoid violation.
;*
;* SOFTWARE IS PROVIDED “AS IS.”  MICROCHIP EXPRESSLY DISCLAIM ANY 
;* WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT 
;* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
;* PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL MICROCHIP
;* BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES,
;* LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF PROCUREMENT
;* OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS BY THIRD PARTIES
;* (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF), ANY CLAIMS FOR 
;* INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS. 
;*
;*
;*
;* ANY SPECIAL DESCRIPTION THAT MIGHT BE USEFUL FOR THIS FILE.
;*
;* Author Date Comment
;*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;* Author Name 		Date		Comment
;* David Flowers	06/07/04	initial revision
;* David Flowers    01/05/06    error corrected in key scheduler
;********************************************************************/

#define NO_EXTERN
#include AESdef.inc
#ifdef ENCODE

AES_VARS	UDATA
block		RES	16	;block:16
	GLOBAL	block
key			RES	16	;key:16
	GLOBAL	key
_aux		RES	1	;_aux
_aux1		RES	1	;_aux1'
_aux2		RES	1	;_aux2
_aux3		RES	1	;_aux3
_temp0		RES	1	;_temp0
_temp1		RES	1	;_temp1
_temp2		RES	1	;_temp2
_temp3		RES	1	;_temp3
_d0			RES	1	;_d0
_d1			RES	1	;_d1
_d2			RES	1	;_d2
_rcon		RES	1	;_rcon
_roundCount	RES	1	;_roundCount

	GLOBAL _aux
	GLOBAL _aux1	
	GLOBAL _aux2	
	GLOBAL _aux3	
	GLOBAL _temp0	
	GLOBAL _temp1	
	GLOBAL _temp2	
	GLOBAL _temp3	
	GLOBAL _d0		
	GLOBAL _d1		
	GLOBAL _d2		
	GLOBAL _rcon	
	GLOBAL _roundCount	

AES_ENC_CODE	CODE

#include p18cxxx.inc
#include tables.inc

#ifndef mMOVLF
mMOVLF  macro  literal,dest
        movlw  literal
        movwf  dest
        endm
#endif

#ifndef mPOINT
mPOINT  macro  stringname
        mMOVLF  high stringname, TBLPTRH
        mMOVLF  low stringname, TBLPTRL
        endm
#endif

#ifndef mTBLRD_PLUS_W
mTBLRD_PLUS_W macro
		addwf	TBLPTRL,f
		clrf	WREG
		addwfc	TBLPTRH,f
		tblrd*
		endm
#endif

#ifndef _mXTIME
_mXTIME macro  var
		movlw	0x1B
		bcf	STATUS,C
		rlcf	var,f
		btfsc	STATUS,C
		xorwf	var,f
		endm
#endif

#ifndef _mXTIME2
;XTIME2 can follow an XTIME and reduce cycle time by 1 cycle
; by eliminating the movlw 0x1B
_mXTIME2  macro  var
		bcf	STATUS,C
		rlcf	var,f
		btfsc	STATUS,C
		xorwf	var,f
		endm
#endif


;***************************************************************************
; Function: void AESEncrypt(BYTE* key, BYTE* block)
;
; PreCondition: key and block variables loaded with key and data to encrypt
;
; Input: key[16] encryption key
;	block[16] data to encrypt
;
; Output: none
;
; Side Effects: block is encrypted and key has changed to the decrypt key
;				called subroutines may use the table pointer
;
; Stack Requirements: 3 level deep
;
; Overview: block is encrypted and key has changed to the decrypt key
;***************************************************************************

	GLOBAL AESEncrypt
AESEncrypt:
	mMOVLF	D'1',_rcon				;initialize round variables
	mMOVLF	D'10',_roundCount
	rcall	_key_addition		;initial key addition

encryptLoop
	rcall	_substitution_S		;s table substitution
	rcall	_enc_shift_row		;encoding row shift
	decfsz	_roundCount,w		;skip mix column if its the last round
	rcall	_mix_column
	rcall	_enc_key_schedule	;get next key
	rcall	_key_addition		;key addition with the new key
	decfsz	_roundCount,f		;decriment the round counter and exit if 0
	goto	encryptLoop			;if not zero then repeat the loop
	return

;***************************************************************************
; Function: void key_addition(BYTE* key, BYTE* block)
;
; PreCondition: 
;
; Input: key[16] encryption key
;	block[16] data to encrypt
;
; Output: none
;
; Side Effects: block is xored with the key
;
; Stack Requirements: 1 level deep
;
; Overview: block is xored with the key
;***************************************************************************
#ifdef CALCKEY
	GLOBAL _key_addition
#endif
_key_addition:
	movf	key+0x0,w			; block[0] ^= key[0]; 
	xorwf	block+0x0,f

	movf	key+0x1,w			; block[1] ^= key[1]; 
	xorwf	block+0x1,f

	movf	key+0x2,w			; block[2] ^= key[2]; 
	xorwf	block+0x2,f

	movf	key+0x3,w			; block[3] ^= key[3]; 
	xorwf	block+0x3,f

	movf	key+0x4,w			; block[4] ^= key[4]; 
	xorwf	block+0x4,f

	movf	key+0x5,w			; block[5] ^= key[5]; 
	xorwf	block+0x5,f

	movf	key+0x6,w			; block[6] ^= key[6]; 
	xorwf	block+0x6,f

	movf	key+0x7,w			; block[7] ^= key[7]; 
	xorwf	block+0x7,f

	movf	key+0x8,w			; block[8] ^= key[8]; 
	xorwf	block+0x8,f

	movf	key+0x9,w			; block[9] ^= key[9]; 
	xorwf	block+0x9,f

	movf	key+0x0A,w			; block[10] ^= key[10]; 
	xorwf	block+0x0A,f

	movf	key+0x0B,w			; block[11] ^= key[11]; 
	xorwf	block+0x0B,f

	movf	key+0x0C,w			; block[12] ^= key[12]; 
	xorwf	block+0x0C,f

	movf	key+0x0D,w			; block[13] ^= key[13]; 
	xorwf	block+0x0D,f

	movf	key+0x0E,w			; block[14] ^= key[14]; 
	xorwf	block+0x0E,f

	movf	key+0x0F,w			; block[15] ^= key[15]; 
	xorwf	block+0x0F,f
	return

;***************************************************************************
; Function: void enc_key_schedule(BYTE* key, BYTE _rcon)
;
; PreCondition:
;
; Input: key[16] encryption key
;	_rcon - round variable
;
; Output: none
;
; Side Effects: the next encryption round key is calculated
;
; Stack Requirements: 2 level deep
;
; Overview: key is updated with the next encryption round key
;***************************************************************************
#ifdef CALCKEY
	GLOBAL _enc_key_schedule
#endif
_enc_key_schedule:
	call	_calc_s_table_based_values
	movf	_rcon,w				; key[0] ^= _rcon
	xorwf	key,f
	bcf		STATUS,C
	rlcf	_rcon,f				; _rcon = xtime(_rcon)
	btfss	STATUS,C
	goto	complete_round
	movlw	0x1B
	xorwf	_rcon
complete_round
	movf	key+0x0,w			; This is equivalent to the 
	xorwf	key+0x4,f			; XOR of each column with the
								; previous one
	movf	key+0x1,w
	xorwf	key+0x5,f
								; first column1 ^= column0
	movf	key+0x2,w
	xorwf	key+0x6,f

	movf	key+0x3,w
	xorwf	key+0x7,f
								; column2 ^= column1
	movf	key+0x4,w
	xorwf	key+0x8,f

	movf	key+0x5,w
	xorwf	key+0x9,f

	movf	key+0x6,w
	xorwf	key+0xA,f

	movf	key+0x7,w
	xorwf	key+0xB,f
								; column3 ^= column2
	movf	key+0x8,w
	xorwf	key+0xC,f

	movf	key+0x9,w
	xorwf	key+0xD,f

	movf	key+0xA,w
	xorwf	key+0xE,f

	movf	key+0xB,w
	xorwf	key+0xF,f
	return

;***************************************************************************
; Function: void calc_s_table_based_valeus(BYTE* key)
;
; PreCondition: 
;
; Input: key[16] encryption key
;
; Output: none
;
; Side Effects: key is updated with s table lookup of old data
;
; Stack Requirements: 1 level deep
;
; Overview: key is updated with s table lookup of old data
;***************************************************************************
_calc_s_table_based_values:

	movf	key+0xD,w			
	btfss	STATUS,Z
	goto	put_S_table_0xD
	movlw	D'99'
	xorwf	key+0x0,f
	goto	read_key_0xE

put_S_table_0xD
	mPOINT	S_table
	movf	key+0xD,w			; key[0x0] ^= s_box[key[0xD]]
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
	xorwf	key+0x0,f

read_key_0xE

	movf	key+0xE,w			
	btfss	STATUS,Z
	goto	put_S_table_0xE
	movlw	D'99'
	xorwf	key+0x1,f
	goto	read_key_0xF

put_S_table_0xE
	mPOINT	S_table
	movf	key+0xE,w			; key[0x1] ^= s_box[key[0xE]]	
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
	xorwf	key+0x1,f

read_key_0xF

	movf	key+0xF,w			
	btfss	STATUS,Z
	goto	put_S_table_0xF
	movlw	D'99'
	xorwf	key+0x2,f
	goto	read_key_0xC

put_S_table_0xF
	mPOINT	S_table
	movf	key+0xF,w			; key[0x2] ^= s_box[key[0xF]]	
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
	xorwf	key+0x2,f

read_key_0xC

	movf	key+0xC,w			
	btfss	STATUS,Z
	goto	put_S_table_0xC
	movlw	D'99'
	xorwf	key+0x3,f
	return				;

put_S_table_0xC
	mPOINT	S_table
	movf	key+0xC,w			; key[0x3] ^= s_box[key[0xC]]	
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
	xorwf	key+0x3,f
	return

;***************************************************************************
; Function: void _enc_shift_row(BYTE* block)
;
; PreCondition:
;
; Input: block[16] data to encrypt
;
; Output: none
;
; Side Effects: block's rows are shifted
;
; Stack Requirements: 1 level deep
;
; Overview: block's rows are shifted
;***************************************************************************
_enc_shift_row:

; Rotates left row 1 one position

	movf	block+0x1,w
	movwf	_aux
	movf	block+0x5,w	
	movwf	block+0x1
	movf	block+0x9,w	
	movwf	block+0x5
	movf	block+0xD,w	
	movwf	block+0x9
	movf	_aux,w
	movwf	block+0xD

; Rotates left row 2 two positions from position block+0x0A
	
	movf	block+0x2,w
	movwf	_aux
	movf	block+0x6,w
	movwf	_aux1
	
	movf	block+0xA,w
	movwf	block+0x2
	movf	block+0xE,w
	movwf	block+0x6

	movf	_aux,w
	movwf	block+0xA
	movf	_aux1,w
	movwf	block+0xE

; Rotates left row 3 three positions from block+0xB


	movf	block+0xF,w
	movwf	_aux
	movf	block+0xB,w
	movwf	block+0xF
	movf	block+0x7,w
	movwf	block+0xB
	movf	block+0x3,w
	movwf	block+0x7
	movf	_aux,w
	movwf	block+0x3
	return	

;***************************************************************************
; Function: void _mix_column(BYTE* block)
;
; PreCondition:
;
; Input: block[16] data array
;
; Output: none
;
; Side Effects: block's columns are mixed according to the specification
;
; Stack Requirements: 1 level deep
;
; Overview: block's rows are mixed according to the specification
;***************************************************************************
_mix_column:
; begins with the mix of column 0

	movf	block+0x0,w		
	xorwf	block+0x1,w
	movwf	_aux1			; _aux1 = block+0x0 ^ block+0x1 
	xorwf	block+0x2,w
	xorwf	block+0x3,w
	movwf	_aux			; _aux = block+0x0 ^ block+0x1 ^ block+0x2 ^ block+0x3
	
	movf	block+0x1,w		; _aux2 = block+0x1 ^ block+0x2 
	xorwf	block+0x2,w
	movwf	_aux2

	movf	block+0x2,w		; _aux3 = block+0x2 ^ block+0x3 
	xorwf	block+0x3,w
	movwf	_aux3

	_mXTIME   _aux1
	_mXTIME2  _aux2
	_mXTIME2  _aux3

	movf	_aux,w			; block+0x0 ^= _aux ^ _aux1
	xorwf	_aux1,w
	xorwf	block+0x0,f

	movf	_aux,w			; block+0x1 ^= _aux ^ _aux2
	xorwf	_aux2,w
	xorwf	block+0x1,f

	movf	_aux,w			; block+0x2 ^= _aux ^ _aux3
	xorwf	_aux3,w
	xorwf	block+0x2,f

	movf	block+0x0,w		; block+0x3 = block+0x1 ^ block+0x2 ^ block+0x2 ^ _aux
	xorwf	block+0x1,w
	xorwf	block+0x2,w
	xorwf	_aux,w
	movwf	block+0x3


; mix of column 1

	movf	block+0x4,w
	xorwf	block+0x5,w
	movwf	_aux1			;
	xorwf	block+0x6,w
	xorwf	block+0x7,w
	movwf	_aux
	
	movf	block+0x5,w
	xorwf	block+0x6,w
	movwf	_aux2

	movf	block+0x6,w
	xorwf	block+0x7,w
	movwf	_aux3

	_mXTIME   _aux1
	_mXTIME2  _aux2
	_mXTIME2  _aux3

	movf	_aux,w
	xorwf	_aux1,w
	xorwf	block+0x4,f

	movf	_aux,w
	xorwf	_aux2,w
	xorwf	block+0x5,f

	movf	_aux,w
	xorwf	_aux3,w
	xorwf	block+0x6,f

	movf	block+0x4,w
	xorwf	block+0x5,w
	xorwf	block+0x6,w
	xorwf	_aux,w
	movwf	block+0x7

; mix of column 2

	movf	block+0x8,w
	xorwf	block+0x9,w
	movwf	_aux1			; 
	xorwf	block+0xA,w
	xorwf	block+0xB,w
	movwf	_aux
	
	movf	block+0x9,w
	xorwf	block+0xA,w
	movwf	_aux2

	movf	block+0xA,w
	xorwf	block+0xB,w
	movwf	_aux3

	_mXTIME   _aux1
	_mXTIME2  _aux2
	_mXTIME2  _aux3

	movf	_aux,w
	xorwf	_aux1,w
	xorwf	block+0x8,f

	movf	_aux,w
	xorwf	_aux2,w
	xorwf	block+0x9,f

	movf	_aux,w
	xorwf	_aux3,w
	xorwf	block+0xA,f

	movf	block+0x8,w
	xorwf	block+0x9,w
	xorwf	block+0xA,w
	xorwf	_aux,w
	movwf	block+0xB


; mix of column 3

	movf	block+0xC,w
	xorwf	block+0xD,w
	movwf	_aux1			;
	xorwf	block+0xE,w
	xorwf	block+0xF,w
	movwf	_aux
	
	movf	block+0xD,w
	xorwf	block+0xE,w
	movwf	_aux2

	movf	block+0xE,w
	xorwf	block+0xF,w
	movwf	_aux3

	_mXTIME   _aux1
	_mXTIME2  _aux2
	_mXTIME2  _aux3

	movf	_aux,w
	xorwf	_aux1,w
	xorwf	block+0xC,f

	movf	_aux,w
	xorwf	_aux2,w
	xorwf	block+0xD,f

	movf	_aux,w
	xorwf	_aux3,w
	xorwf	block+0xE,f

	movf	block+0xC,w
	xorwf	block+0xD,w
	xorwf	block+0xE,w
	xorwf	_aux,w
	movwf	block+0xF
	return



;***************************************************************************
; Function: void _substitution_S(BYTE* block)
;
; PreCondition:
;
; Input: block[16] data array
;
; Output: none
;
; Side Effects: block's values are substituted with block[i]=STable[block[i]]
;
; Stack Requirements: 1 level deep
;
; Overview: block's values are substituted with block[i]=STable[block[i]]
;***************************************************************************
_substitution_S:				; implements the direct substitution
put_s_table_b0
	movlw	D'99'				; if (block[i]==0) --> block[i]=99D 
	movf	block+0x0,f
	btfsc	STATUS,Z
	goto	put_b0
	mPOINT	S_table				; else block[i]=STable[block[i];
	movf	block+0x0,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_b0
	movwf	block+0x0

put_s_table_b1
	movlw	D'99'				; same as above
	movf	block+0x1,f
	btfsc	STATUS,Z
	goto	put_b1
	mPOINT	S_table
	movf	block+0x1,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_b1
	movwf	block+0x1

put_s_table_b2
	movlw	D'99'				;  "
	movf	block+0x2,f
	btfsc	STATUS,Z
	goto	put_b2
	mPOINT	S_table
	movf	block+0x2,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_b2
	movwf	block+0x2

put_s_table_b3
	movlw	D'99'				; "
	movf	block+0x3,f
	btfsc	STATUS,Z
	goto	put_b3
	mPOINT	S_table
	movf	block+0x3,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_b3
	movwf	block+0x3

put_s_table_b4
	movlw	D'99'			; 
	movf	block+0x4,f
	btfsc	STATUS,Z
	goto	put_b4
	mPOINT	S_table
	movf	block+0x4,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_b4
	movwf	block+0x4

put_s_table_b5
	movlw	D'99'			; 
	movf	block+0x5,f
	btfsc	STATUS,Z
	goto	put_b5
	mPOINT	S_table
	movf	block+0x5,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w 
put_b5
	movwf	block+0x5

put_s_table_b6
	movlw	D'99'			; 
	movf	block+0x6,f
	btfsc	STATUS,Z
	goto	put_b6
	mPOINT	S_table
	movf	block+0x6,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_b6
	movwf	block+0x6

put_s_table_b7
	movlw	D'99'			; 
	movf	block+0x7,f
	btfsc	STATUS,Z
	goto	put_b7
	mPOINT	S_table
	movf	block+0x7,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_b7
	movwf	block+0x7

put_s_table_b8
	movlw	D'99'			; 
	movf	block+0x8,f
	btfsc	STATUS,Z
	goto	put_b8
	mPOINT	S_table
	movf	block+0x8,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_b8
	movwf	block+0x8

put_s_table_b9
	movlw	D'99'			; 
	movf	block+0x9,f
	btfsc	STATUS,Z
	goto	put_b9
	mPOINT	S_table
	movf	block+0x9,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_b9
	movwf	block+0x9

put_s_table_bA
	movlw	D'99'			; 
	movf	block+0xA,f
	btfsc	STATUS,Z
	goto	put_bA
	mPOINT	S_table
	movf	block+0xA,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_bA
	movwf	block+0xA

put_s_table_bB
	movlw	D'99'			; 
	movf	block+0xB,f
	btfsc	STATUS,Z
	goto	put_bB
	mPOINT	S_table
	movf	block+0xB,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_bB
	movwf	block+0xB

put_s_table_bC
	movlw	D'99'			; 
	movf	block+0xC,f
	btfsc	STATUS,Z
	goto	put_bC
	mPOINT	S_table
	movf	block+0xC,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_bC
	movwf	block+0xC

put_s_table_bD
	movlw	D'99'			; 
	movf	block+0xD,f
	btfsc	STATUS,Z
	goto	put_bD
	mPOINT	S_table
	movf	block+0xD,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_bD
	movwf	block+0xD

put_s_table_bE
	movlw	D'99'			; 
	movf	block+0xE,f
	btfsc	STATUS,Z
	goto	put_bE
	mPOINT	S_table
	movf	block+0xE,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_bE
	movwf	block+0xE

put_s_table_bF
	movlw	D'99'			; 
	movf	block+0xF,f
	btfsc	STATUS,Z
	goto	put_bF
	mPOINT	S_table
	movf	block+0xF,w
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
put_bF
	movwf	block+0xF
	return

#endif

	end
