;
; DA_Test.asm
;
; Created: 29-06-2020 18:18:36
; Author : Sondre
;

.include "AVR128DA64def.inc"

; Macro for delaying exact number of cycles, in increments of 10.
; Disturbs r16
.MACRO delay_decacycles
	ldi r16, @0
	delay_loop_1:
		nop nop nop nop nop nop nop
		dec r16
		brne delay_loop_1
.ENDMACRO

; Set clock to 20MHz
ldi r16, CPU_CCP_IOREG_gc
ldi r17, CLKCTRL_FREQSEL_20M_gc
sts CPU_CCP, r16
sts CLKCTRL_OSCHFCTRLA, r17

; Enable CLKOUT on PA7 (pin 5)
;sbi VPORTA_DIR, 7
;ldi r16, CPU_CCP_IOREG_gc
;ldi r17, CLKCTRL_CLKOUT_bm
;sts CPU_CCP, r16
;sts CLKCTRL_MCLKCTRLA, r17

; Configure USART0, 1, 2, and 3
ldi r16, USART_MSPI_CMODE_MSPI_gc | USART_UDORD_bm
sts USART0_CTRLC, r16
sts USART1_CTRLC, r16
sts USART2_CTRLC, r16
sts USART3_CTRLC, r16
ldi r16, (1 << 6)
sts USART0_BAUDL, r16
sts USART1_BAUDL, r16
sts USART2_BAUDL, r16
sts USART3_BAUDL, r16
sbi VPORTA_DIR, 0 ; USART0,TxD (pin 62)
sbi VPORTA_DIR, 2 ; USART0,XCK (pin 64)
sbi VPORTC_DIR, 0 ; USART1,TxD (pin 16)
sbi VPORTF_DIR, 0 ; USART2,TxD (pin 44)
sbi VPORTF_DIR, 2 ; USART2,XCK (pin 46)
sbi VPORTB_DIR, 0 ; USART3,TxD (pin 8)

; Configure CCL, LUT0
; LUT0,OUT = USART0,XCK ? USART1,TxD : USART0,TxD
ldi r16, CCL_INSEL0_USART0_gc | CCL_INSEL1_USART1_gc
sts CCL_LUT0CTRLB, r16
ldi r16, CCL_INSEL2_IN2_gc
sts CCL_LUT0CTRLC, r16
ldi r16, 0b11001010
sts CCL_TRUTH0, r16
ldi r16, CCL_ENABLE_bm | CCL_OUTEN_bm | CCL_FILTSEL_SYNCH_gc
sts CCL_LUT0CTRLA, r16
sbi VPORTA_DIR, 3 ; LUT0,OUT (pin 1)

; Configure CCL, LUT3
; USART3,TXD at PB0 (pin 8) linked externally to LUT3,IN1 at PF1 (pin 45)
; LUT3,OUT = USART1,XCK ? USART3,TxD : USART2,TxD
ldi r16, CCL_INSEL0_IN0_gc | CCL_INSEL1_IN1_gc
sts CCL_LUT3CTRLB, r16
ldi r16, CCL_INSEL2_IN2_gc
sts CCL_LUT3CTRLC, r16
ldi r16, 0b11001010
sts CCL_TRUTH3, r16
ldi r16, CCL_ENABLE_bm | CCL_OUTEN_bm | CCL_FILTSEL_SYNCH_gc
sts CCL_LUT3CTRLA, r16
sbi VPORTF_DIR, 3 ; LUT3,OUT (pin 47)

; Enable CCL
ldi r16, CCL_ENABLE_bm
sts CCL_CTRLA, r16

; Enable USARTs
; Enable writes are two cycles apart, resulting in synchronized prescalers
ldi r16, USART_TXEN_bm
sts USART0_CTRLB, r16
sts USART1_CTRLB, r16
sts USART2_CTRLB, r16
sts USART3_CTRLB, r16


; Send dummy data to synchronize the USARTs
ldi r16, 0x42
; Start USART0
sts USART0_TXDATAL, r16
; Schedule the next dummy byte for USART0
sts USART0_TXDATAL, r16
nop nop nop nop nop nop nop nop nop nop
nop nop

; Start USART1 simultaniously with the next byte from USART0
sts USART1_TXDATAL, r16
; Schedule the next dummy byte for USARTs 0 and 1
sts USART0_TXDATAL, r16
sts USART1_TXDATAL, r16
nop nop nop nop nop nop nop nop nop nop

; Start USART2 simultaniously with the next byte from USARTs 0 and 1
sts USART2_TXDATAL, r16
; Schedule the next dummy bytes for USARTs 0, 1, and 2
sts USART0_TXDATAL, r16
sts USART1_TXDATAL, r16
sts USART2_TXDATAL, r16
nop nop nop nop nop nop nop nop

; Start USART3 simultaniously with the next byte from USARTs 0, 1, and 2
sts USART3_TXDATAL, r16

start:
	ldi r16, 0xE2
	sts USART0_TXDATAL, r16
	sts USART2_TXDATAL, r16

	ldi r16, 0xF8
	sts USART1_TXDATAL, r16
	sts USART3_TXDATAL, r16

	nop nop nop nop

    rjmp start
