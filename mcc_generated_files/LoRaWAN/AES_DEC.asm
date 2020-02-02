;*********************************************************************
;*
;* AES decryption module
;*
;*********************************************************************
;* FileName: AES_DEC.asm
;* Dependencies:
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
;* David Flowers	06/08/04	initial revision
;********************************************************************/
#define NO_EXTERN
#include AESdef.inc

#ifdef DECODE
#ifndef ENCODE
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
#else
	EXTERN	block
	EXTERN	key
	EXTERN	_aux
	EXTERN	_aux1
	EXTERN	_aux2
	EXTERN	_aux3
	EXTERN	_temp0	
	EXTERN	_temp1
	EXTERN	_temp2
	EXTERN	_temp3	
	EXTERN	_d0		
	EXTERN	_d1	
	EXTERN	_d2	
	EXTERN	_rcon
	EXTERN	_roundCount
#endif
AES_DEC_CODE	CODE
#include p18cxxx.inc

#ifndef ENCODE
#include tables.inc
#else
	EXTERN S_table
	EXTERN Si_Table
	EXTERN x1
	EXTERN x2
	EXTERN x3
#endif

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
; Function: void AESDecrypt(BYTE* key, BYTE* block)
;
; PreCondition:
;
; Input: key[16] key array, block[16] data array
;
; Output: none
;
; Side Effects: block has been decrypted and key should 
;				be at original encrypt key
;
; Stack Requirements: 3 level deep
;
; Overview: block has been decrypted and key should be at original encyrpt key
;***************************************************************************
	GLOBAL AESDecrypt
AESDecrypt:
	mMOVLF	0x36,_rcon
	call	_key_addition

	;** first iteration of the loop without mix_column **
	rcall	_substitution_Si
	rcall	_dec_shift_row
	rcall	_dec_key_schedule
	call	_key_addition

	mMOVLF	D'9',_roundCount

decryptLoop
	rcall	_inv_mix_column
	rcall	_substitution_Si
	rcall	_dec_shift_row
	rcall	_dec_key_schedule
	call	_key_addition

	decfsz	_roundCount,f
	goto	decryptLoop

	return
#ifdef FOR_C
	GLOBAL	decrypt
#endif

;***************************************************************************
; Function: void _inv_mix_column(BYTE* block)
;
; PreCondition:
;
; Input: block[16] data array
;
; Output: none
;
; Side Effects: block columns mixed
;
; Stack Requirements: 1 level deep
;
; Overview: block's columns are mixed
;***************************************************************************
_inv_mix_column:
; col 1
	;define shorthands:
	; x3[a]=xtime(xtime(xtime(a)))
	; b[0]=block[0]

	;temp3 = x3[b[0]]^x3[b[1]]^x3[b[2]]^x3[b[3]]
	mPOINT	x3
	movf	block+0,w
	mTBLRD_PLUS_W
	movff	TABLAT,_temp3
	mPOINT	x3
	movf	block+1,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp3,f
	mPOINT	x3
	movf	block+2,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp3,f
	mPOINT	x3
	movf	block+3,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp3,f

	;temp3 ^= b[0]^b[1]^b[2]^b[3]
	movf	block+0,w
	xorwf	_temp3,f
	movf	block+1,w
	xorwf	_temp3,f
	movf	block+2,w
	xorwf	_temp3,f
	movf	block+3,w
	xorwf	_temp3,f

	;temp0=temp1=temp2=temp3
	movff	_temp3,_temp2
	movff	_temp3,_temp1
	movff	_temp3,_temp0

	;temp0^=x2[b[0]];
	;temp2^=x2[b[0]];
	mPOINT	x2
	movf	block+0,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp2,f

	;temp1^=x2[b[1]];
	;temp3^=x2[b[1]];
	mPOINT	x2
	movf	block+1,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp1,f
	xorwf	_temp3,f

	;temp0^=x2[b[2]];
	;temp2^=x2[b[2]];
	mPOINT	x2
	movf	block+2,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp2,f

	;temp1^=x2[b[3]];
	;temp3^=x2[b[3]];
	mPOINT	x2
	movf	block+3,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp1,f
	xorwf	_temp3,f

	;temp0^=x1[b[0]];
	;temp3^=x1[b[0]];
	mPOINT	x1
	movf	block+0,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp3,f

	;temp0^=x1[b[1]];
	;temp1^=x1[b[1]];
	mPOINT	x1
	movf	block+1,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp1,f

	;temp1^=x1[b[2]];
	;temp2^=x1[b[2]];
	mPOINT	x1
	movf	block+2,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp1,f
	xorwf	_temp2,f

	;temp2^=x1[b[3]];
	;temp3^=x1[b[3]];
	mPOINT	x1
	movf	block+3,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp2,f
	xorwf	_temp3,f

	;temp0^=b[0];
	;temp1^=b[1];
	;temp2^=b[2];
	;temp3^=b[3];
	movf	_temp0,w
	xorwf	block+0,f
	movf	_temp1,w
	xorwf	block+1,f
	movf	_temp2,w
	xorwf	block+2,f
	movf	_temp3,w
	xorwf	block+3,f

; col 2
	mPOINT	x3
	movf	block+4,w
	mTBLRD_PLUS_W
	movff	TABLAT,_temp3
	mPOINT	x3
	movf	block+5,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp3,f
	mPOINT	x3
	movf	block+6,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp3,f
	mPOINT	x3
	movf	block+7,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp3,f

	movf	block+4,w
	xorwf	_temp3,f
	movf	block+5,w
	xorwf	_temp3,f
	movf	block+6,w
	xorwf	_temp3,f
	movf	block+7,w
	xorwf	_temp3,f

	movff	_temp3,_temp2
	movff	_temp3,_temp1
	movff	_temp3,_temp0

	mPOINT	x2
	movf	block+4,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp2,f

	mPOINT	x2
	movf	block+5,w
	mTBLRD_PLUS_W
	movf TABLAT,w
	xorwf	_temp1,f
	xorwf	_temp3,f

	mPOINT	x2
	movf	block+6,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp2,f

	mPOINT	x2
	movf	block+7,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp1,f
	xorwf	_temp3,f

	mPOINT	x1
	movf	block+4,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp3,f

	mPOINT	x1
	movf	block+5,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp1,f

	mPOINT	x1
	movf	block+6,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp1,f
	xorwf	_temp2,f

	mPOINT	x1
	movf	block+7,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp2,f
	xorwf	_temp3,f

	movf	_temp0,w
	xorwf	block+4,f
	movf	_temp1,w
	xorwf	block+5,f
	movf	_temp2,w
	xorwf	block+6,f
	movf	_temp3,w
	xorwf	block+7,f

; col 3
	mPOINT	x3
	movf	block+8,w
	mTBLRD_PLUS_W
	movff	TABLAT,_temp3
	mPOINT	x3
	movf	block+9,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp3,f
	mPOINT	x3
	movf	block+d'10',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp3,f
	mPOINT	x3
	movf	block+d'11',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp3,f

	movf	block+8,w
	xorwf	_temp3,f
	movf	block+9,w
	xorwf	_temp3,f
	movf	block+d'10',w
	xorwf	_temp3,f
	movf	block+d'11',w
	xorwf	_temp3,f

	movff	_temp3,_temp2
	movff	_temp3,_temp1
	movff	_temp3,_temp0

	mPOINT	x2
	movf	block+8,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp2,f

	mPOINT	x2
	movf	block+9,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp1,f
	xorwf	_temp3,f

	mPOINT	x2
	movf	block+d'10',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp2,f

	mPOINT	x2
	movf	block+d'11',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp1,f
	xorwf	_temp3,f

	mPOINT	x1
	movf	block+8,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp3,f

	mPOINT	x1
	movf	block+9,w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp1,f

	mPOINT	x1
	movf	block+d'10',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp1,f
	xorwf	_temp2,f

	mPOINT	x1
	movf	block+d'11',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp2,f
	xorwf	_temp3,f

	movf	_temp0,w
	xorwf	block+8,f
	movf	_temp1,w
	xorwf	block+9,f
	movf	_temp2,w
	xorwf	block+d'10',f
	movf	_temp3,w
	xorwf	block+d'11',f

; col 4
	mPOINT	x3
	movf	block+d'12',w
	mTBLRD_PLUS_W
	movff	TABLAT,_temp3
	mPOINT	x3
	movf	block+d'13',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp3,f
	mPOINT	x3
	movf	block+d'14',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp3,f
	mPOINT	x3
	movf	block+d'15',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp3,f

	movf	block+d'12',w
	xorwf	_temp3,f
	movf	block+d'13',w
	xorwf	_temp3,f

	movf	block+d'14',w
	xorwf	_temp3,f
	movf	block+d'15',w
	xorwf	_temp3,f

	movff	_temp3,_temp2
	movff	_temp3,_temp1
	movff	_temp3,_temp0

	mPOINT	x2
	movf	block+d'12',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp2,f

	mPOINT	x2
	movf	block+d'13',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp1,f
	xorwf	_temp3,f

	mPOINT	x2
	movf	block+d'14',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp2,f

	mPOINT	x2
	movf	block+d'15',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp1,f
	xorwf	_temp3,f

	mPOINT	x1
	movf	block+d'12',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp3,f

	mPOINT	x1
	movf	block+d'13',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp0,f
	xorwf	_temp1,f

	mPOINT	x1
	movf	block+d'14',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp1,f
	xorwf	_temp2,f

	mPOINT	x1
	movf	block+d'15',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	_temp2,f
	xorwf	_temp3,f

	movf	_temp0,w
	xorwf	block+d'12',f
	movf	_temp1,w
	xorwf	block+d'13',f
	movf	_temp2,w
	xorwf	block+d'14',f
	movf	_temp3,w
	xorwf	block+d'15',f
	return

;***************************************************************************
; Function: void _dec_shift_row(BYTE* block)
;
; PreCondition:
;
; Input: block[16] data array
;
; Output: none
;
; Side Effects: block's values are shifted
;
; Stack Requirements: 1 level deep
;
; Overview: block's values are shifted
;***************************************************************************
_dec_shift_row:
; Rotates right row 1 one position

	movf	block+0x1,w
	movwf	_aux
	movf	block+0xD,w		;
	movwf	block+0x1
	movf	block+0x9,w		;
	movwf	block+0xD
	movf	block+0x5,w		;
	movwf	block+0x9
	movf	_aux,w
	movwf	block+0x5		;


; Rotates right row 2 two positions from position block+0x0A
	
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

; Rotates right row 3 three positions from block+0xB


	movf	block+0xF,w
	movwf	_aux
	movf	block+0x3,w
	movwf	block+0xF
	movf	block+0x7,w
	movwf	block+0x3
	movf	block+0xB,w
	movwf	block+0x7
	movf	_aux,w
	movwf	block+0xB
	return


;***************************************************************************
; Function: void _dec_key_schedule(BYTE* key)
;
; PreCondition:
;
; Input: key[16] key array
;
; Output: none
;
; Side Effects: key values updated
;
; Stack Requirements: 1 level deep
;
; Overview: key values updated with newest decrypt key
;***************************************************************************
_dec_key_schedule:
	;/* column 4 */
	;key[12]^=key[8];
	movf	key+8,w
	xorwf	key+d'12',f

	;key[13]^=key[9];
	movf	key+9,w
	xorwf	key+d'13',f

	;key[14]^=key[10];
	movf	key+d'10',w
	xorwf	key+d'14',f

	;key[15]^=key[11];
	movf	key+d'11',w
	xorwf	key+d'15',f
	
	;/* column 3 */
	;key[8]^=key[4];
	movf	key+4,w
	xorwf	key+8,f

	;key[9]^=key[5];
	movf	key+5,w
	xorwf	key+9,f

	;key[10]^=key[6];
	movf	key+6,w
	xorwf	key+d'10',f

	;key[11]^=key[7];
	movf	key+7,w
	xorwf	key+d'11',f

	;/* column 2 */
	;key[4]^=key[0];
	movf	key+0,w
	xorwf	key+4,f

	;key[5]^=key[1];
	movf	key+1,w
	xorwf	key+5,f

	;key[6]^=key[2];
	movf	key+2,w
	xorwf	key+6,f

	;key[7]^=key[3];
	movf	key+3,w
	xorwf	key+7,f

	;/* column 1 */
	;key[0]^=STable[key[13]];
	mPOINT	S_table
	movf	key+d'13',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	key+0,f

	;key[1]^=STable[key[14]];
	mPOINT	S_table
	movf	key+d'14',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	key+1,f

	;key[2]^=STable[key[15]];
	mPOINT	S_table
	movf	key+d'15',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	key+2,f

	;key[3]^=STable[key[12]];
	mPOINT	S_table
	movf	key+d'12',w
	mTBLRD_PLUS_W
	movf	TABLAT,w
	xorwf	key+3,f

	;key[0]^=_rcon;
	movf	_rcon,w
	xorwf	key+0,f

	;if(_rcon &0x01)
	andlw	0x01
	bz	_rcon_rotate
	mMOVLF	0x80,_rcon
	return
_rcon_rotate
	bcf		STATUS,C
	rrcf	_rcon,f
	return

;***************************************************************************
; Function: void _substitution_Si(BYTE* block)
;
; PreCondition:
;
; Input: block[16] data array
;
; Output: none
;
; Side Effects: block's values are substituted with block[i]=SiTable[block[i]]
;
; Stack Requirements: 1 level deep
;
; Overview: block's values are substituted with block[i]=SiTable[block[i]]
;***************************************************************************
_substitution_Si: 			; implements the inverse substitution

	mPOINT	Si_Table
	movf	block+0,w
	mTBLRD_PLUS_W
	movff	TABLAT,block+0

	mPOINT	Si_Table
	movf	block+1,w
	mTBLRD_PLUS_W
	movff	TABLAT,block+1

	mPOINT	Si_Table
	movf	block+2,w
	mTBLRD_PLUS_W
	movff	TABLAT,block+2

	mPOINT	Si_Table
	movf	block+3,w
	mTBLRD_PLUS_W
	movff	TABLAT,block+3

	mPOINT	Si_Table
	movf	block+4,w
	mTBLRD_PLUS_W
	movff	TABLAT,block+4

	mPOINT	Si_Table
	movf	block+5,w
	mTBLRD_PLUS_W
	movff	TABLAT,block+5

	mPOINT	Si_Table
	movf	block+6,w
	mTBLRD_PLUS_W
	movff	TABLAT,block+6

	mPOINT	Si_Table
	movf	block+7,w
	mTBLRD_PLUS_W
	movff	TABLAT,block+7

	mPOINT	Si_Table
	movf	block+8,w
	mTBLRD_PLUS_W
	movff	TABLAT,block+8

	mPOINT	Si_Table
	movf	block+9,w
	mTBLRD_PLUS_W
	movff	TABLAT,block+9

	mPOINT	Si_Table
	movf	block+d'10',w
	mTBLRD_PLUS_W
	movff	TABLAT,block+d'10'

	mPOINT	Si_Table
	movf	block+d'11',w
	mTBLRD_PLUS_W
	movff	TABLAT,block+d'11'

	mPOINT	Si_Table
	movf	block+d'12',w
	mTBLRD_PLUS_W
	movff	TABLAT,block+d'12'

	mPOINT	Si_Table
	movf	block+d'13',w
	mTBLRD_PLUS_W
	movff	TABLAT,block+d'13'

	mPOINT	Si_Table
	movf	block+d'14',w
	mTBLRD_PLUS_W
	movff	TABLAT,block+d'14'

	mPOINT	Si_Table
	movf	block+d'15',w
	mTBLRD_PLUS_W
	movff	TABLAT,block+d'15'

	return

#ifdef CALCKEY
;***************************************************************************
; Function: void AESCalcDecryptKey(BYTE* key)
;
; PreCondition:
;
; Input: key[16] key array
;
; Output: none
;
; Side Effects: key values changed
;
; Stack Requirements: 3 level deep
;
; Overview: key valued changed from initial encrypt key to final decrypt key
;			to start the decrypt process if the decrypt key is not known
;***************************************************************************
	GLOBAL AESCalcDecryptKey
AESCalcDecryptKey:
	;/* reconstruct key */
	mMOVLF	d'10',_roundCount
	mMOVLF	0x01,_rcon
setDecryptKeyLoop
	call	_enc_key_schedule;
	decfsz	_roundCount,f
	bra		setDecryptKeyLoop
	return

#endif


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
#ifndef ENCODE
_enc_key_schedule:
	call	_calc_s_table_based_values
	movf	_rcon,w				; key[0] ^= _rcon
	xorwf	key,f
	bcf		STATUS,C
	rlcf	_rcon,f				; _rcon = xtime(_rcon)
	btfss	STATUS,C
	goto	complete_round
	movlw	0x1B
	movwf	_rcon
complete_round
	movf	key+0x0,w		; This is equivalent to the 
	xorwf	key+0x4,f		; XOR of each column with the
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
	movf	key+0xD,w		; key[0x0] ^= s_box[key[0xD]]
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
	movf	key+0xE,w		; key[0x1] ^= s_box[key[0xE]]	
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
	movf	key+0xF,w		; key[0x2] ^= s_box[key[0xF]]	
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
	movf	key+0xC,w		; key[0x3] ^= s_box[key[0xC]]	
	addwf	TBLPTRL,f
	clrf	WREG
	addwfc	TBLPTRH,f
	tblrd*
	movf	TABLAT,w
	xorwf	key+0x3,f
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
#else
	EXTERN _key_addition
	EXTERN _enc_key_schedule
#endif

#endif
	end
;************* end of decrypt **********;
