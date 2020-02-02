/**
  Generated Main Source File

  Company:
    Microchip Technology Inc.

  File Name:
    main.c

  Summary:
    This is the main file generated using PIC10 / PIC12 / PIC16 / PIC18 MCUs

  Description:
    This header file provides implementations for driver APIs for all modules selected in the GUI.
    Generation Information :
        Product Revision  :  PIC10 / PIC12 / PIC16 / PIC18 MCUs - 1.65
        Device            :  PIC18LF46K22
        Driver Version    :  2.00
*/

/*
    (c) 2016 Microchip Technology Inc. and its subsidiaries. You may use this
    software and any derivatives exclusively with Microchip products.

    THIS SOFTWARE IS SUPPLIED BY MICROCHIP "AS IS". NO WARRANTIES, WHETHER
    EXPRESS, IMPLIED OR STATUTORY, APPLY TO THIS SOFTWARE, INCLUDING ANY IMPLIED
    WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY, AND FITNESS FOR A
    PARTICULAR PURPOSE, OR ITS INTERACTION WITH MICROCHIP PRODUCTS, COMBINATION
    WITH ANY OTHER PRODUCTS, OR USE IN ANY APPLICATION.

    IN NO EVENT WILL MICROCHIP BE LIABLE FOR ANY INDIRECT, SPECIAL, PUNITIVE,
    INCIDENTAL OR CONSEQUENTIAL LOSS, DAMAGE, COST OR EXPENSE OF ANY KIND
    WHATSOEVER RELATED TO THE SOFTWARE, HOWEVER CAUSED, EVEN IF MICROCHIP HAS
    BEEN ADVISED OF THE POSSIBILITY OR THE DAMAGES ARE FORESEEABLE. TO THE
    FULLEST EXTENT ALLOWED BY LAW, MICROCHIP'S TOTAL LIABILITY ON ALL CLAIMS IN
    ANY WAY RELATED TO THIS SOFTWARE WILL NOT EXCEED THE AMOUNT OF FEES, IF ANY,
    THAT YOU HAVE PAID DIRECTLY TO MICROCHIP FOR THIS SOFTWARE.

    MICROCHIP PROVIDES THIS SOFTWARE CONDITIONALLY UPON YOUR ACCEPTANCE OF THESE
    TERMS.
*/

#include "mcc_generated_files/mcc.h"


//LORA DANE Z DOKUMENTACJI 
uint8_t nwkSKey[16] = {0x2B, 0x7E, 0x15, 0x16, 0x28, 0xAE, 0xD2, 0xA6, 0xAB,
0xF7, 0x15, 0x88, 0x09, 0xCF, 0x4F, 0x3C};
uint8_t appSKey[16] = {0x3C, 0x8F, 0x26, 0x27, 0x39, 0xBF, 0xE3, 0xB7, 0xBC,
0x08, 0x26, 0x99, 0x1A, 0xD0, 0x50, 0x4D};
// adres urz?dzenia 
uint32_t devAddr = 0x1100000F;
// tryb debugu
#define DEBUG 1 
// minimalny poziom naladowania baterii
#define BAT_MIN 10

int bat_level ; 
int ac_conncect ;
int LoRa_IR_RX_Counter = 0;
int LoRa_CASE_OPENED_Counter = 0;
int ir_status_Counter = 0;
int i = 0; 

char LoRa_Data;

void RxData(uint8_t* pData, uint8_t dataLength, OpStatus_t status)
{}
void RxJoinResponse(bool status)
{}



// TODO: funkcja musi zosta? zmieniona na transmisj? danych
int ir_status(void) { 
    // swiecimy diod? IR
    LoRa_IR_TX_SetHigh();
    // sprawdzamy czy jest stan wysoki na odiorniku IR
    if(LoRa_IR_RX_PORT == 1) { return 1; } else { return 0; } 
    // gasimy diode IR 
    LoRa_IR_TX_SetLow();
}

void chargin(void) {
    
    // jez?li bateria na?adowana. 
    // TODO: eksperymenatlnie sprawdzi? poziom na?adowania baterii 
    if(bat_level >= 1000){ LoRa_FULL_CHARGED_SetHigh(); } 
    // stan po na?adowaniu baterii 
    else { 
        LoRa_FULL_CHARGED_SetLow();
       // sleep();
    }   
}

void alarm(void) {
    
}

// TODO: napisa? funkcje spania na 
void sleep(void) {
    
}

void debug(void) {   
   printf("\n\r ADRESS: "+ devAddr); 
   printf("\n\r BAT LVL: "+ ADCC_GetSingleConversion(LoRa_BAT_LEVEL));
   printf("\n\r BAT MEASURE: "+ LoRa_BAT_MEASURE_PORT);
   printf("\n\r FULL CHARGED: "+ LoRa_FULL_CHARGED_LAT);
   printf("\n\r CONNECTED STATUS: "+ ADCC_GetSingleConversion(LoRa_CONNECTED));
   printf("\n\r IR RX STATUS: "+ LoRa_IR_RX_PORT);
   printf("\n\r IR TX STATUS: "+ LoRa_IR_TX_LAT);
   printf("\n\r CASE OPENED STATUS: "+ LoRa_CASE_OPENED_PORT);
} 


void main(void)
{
    // Initialize the device
    SYSTEM_Initialize();
     
    // Enable the Global Interrupts
    //INTERRUPT_GlobalInterruptEnable();

    // Disable the Global Interrupts
    //INTERRUPT_GlobalInterruptDisable();

    // Enable the Peripheral Interrupts
    //INTERRUPT_PeripheralInterruptEnable();

    // Disable the Peripheral Interrupts
    //INTERRUPT_PeripheralInterruptDisable();
    
    LORAWAN_Init(RxData, RxJoinResponse);
    LORAWAN_SetNetworkSessionKey(nwkSKey);
    LORAWAN_SetApplicationSessionKey(appSKey);
    LORAWAN_SetDeviceAddress(devAddr);
    
    LORAWAN_Join(ABP);
    
    // kod autorski 
    LoRa_IR_RX_SetDigitalInput();
    LoRa_FULL_CHARGED_SetDigitalInput();
    LoRa_CONNECTED_SetDigitalInput();
    
    printf("SafeLocker ver 2.0 \n\r");

    while (1)
    {
        LORAWAN_Mainloop();
        i++;
       // od 0 do 1023 ADC 
       ac_conncect = ADCC_GetSingleConversion(LoRa_CONNECTED);
       bat_level  = ADCC_GetSingleConversion(LoRa_BAT_LEVEL);
       
       // spr czy uk?ada ?adowania nie zosta? podl?czony 
      if(ac_conncect == 0) {
       // spr czy bateria nie jest rozladowania  
       if(bat_level > BAT_MIN) { 
          if(ir_status == 0) { LoRa_IR_RX_Counter++; ir_status_Counter=1; }
          if(ir_status == 1 && ir_status_Counter == 1) { ir_status_Counter = 0;  }
          if(LoRa_CASE_OPENED_PORT != 0) { LoRa_CASE_OPENED_Counter++; }
          
           LoRa_Data = i;
           LoRa_Data += '|';
           LoRa_Data += devAddr;
           LoRa_Data += '|';
           LoRa_Data +=bat_level;
           LoRa_Data += '|';   
           LoRa_Data += ir_status;
           LoRa_Data += '|';
           LoRa_Data += LoRa_IR_RX_Counter;
           LoRa_Data += '|';
           LoRa_Data += LoRa_CASE_OPENED_PORT;
           
           // wysylanie przez lore 
           LORAWAN_Send(UNCNF, 2,LoRa_Data, 4);
           
        // tryb wyczerpanej baterii    
        } else { 
          sleep();   
        }
      
      // tryb ?adowania  
      } else {
          LoRa_IR_RX_Counter = 0;
          LoRa_CASE_OPENED_Counter = 0;
          chargin();
       }
       
       if(DEBUG == 1) { debug(); } 
    
        
    }
      //reset licznika 
  if (i == 10000) i = 0;
}


