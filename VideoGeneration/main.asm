;
; VideoGeneration.asm
;
; Created: 10-05-2020 12:09:00
; Author : Sondre
;

.cseg
rjmp start

.include "tn817def.inc"

; Define VGA timing parameters
.EQU CLK_DIV = 2
.EQU H_VISIBLE = 800
.EQU H_FRONT = 40
.EQU H_SYNC = 128
.EQU H_BACK = 88
.EQU H_FULL = 1056
.EQU V_VISIBLE = 600
.EQU V_FRONT = 1
.EQU V_SYNC = 4
.EQU V_BACK = 23
.EQU V_FULL = 628

; CCP unlock macro
.macro CCP_UNLOCK_IO
	ldi r16, CPU_CCP_IOREG_gc
	out CPU_CCP, r16
.endmacro

; Main entry point
.cseg
start:
	; CLK_PER = 20 MHz (16/20 fuse set to 20)
	CCP_UNLOCK_IO
	ldi r16, 0
	sts CLKCTRL_MCLKCTRLB, r16
	
	; HSYNC on PB0, generated by TCA
	sbi VPORTB_DIR, 0
	
	; Configure TCA
	ldi r16, low(H_FULL / CLK_DIV - 1)
	sts TCA0_SINGLE_PER, r16
	ldi r16, high(H_FULL / CLK_DIV - 1)
	sts (TCA0_SINGLE_PER+1), r16
	
	ldi r16, low((H_BACK + H_VISIBLE + H_FRONT) / CLK_DIV - 1)
	sts TCA0_SINGLE_CMP0, r16
	ldi r16, high((H_BACK + H_VISIBLE + H_FRONT) / CLK_DIV - 1)
	sts (TCA0_SINGLE_CMP0+1), r16

	ldi r16, TCA_SINGLE_CMP0EN_bm | TCA_SINGLE_WGMODE_SINGLESLOPE_gc
	sts TCA0_SINGLE_CTRLB, r16

	ldi r16, TCA_SINGLE_OVF_bm
	sts TCA0_SINGLE_INTCTRL, r16

	; Start TCA just before wraparound
	.equ LOOP_HEADSTART = 6
	ldi r16, low(H_BACK / CLK_DIV - LOOP_HEADSTART + 1)
	sts TCA0_SINGLE_CNT, r16
	ldi r16, high(H_BACK / CLK_DIV - LOOP_HEADSTART + 1)
	sts (TCA0_SINGLE_CNT+1), r16


	; VSYNC on PC0, generated in software
	sbi VPORTC_DIR, 0
	sbi VPORTC_OUT, 0

	; Setup 16 bit register Z to count scanlines
	clr ZL
	clr ZH

	
	; Pixel data output on PA5, generated by USART0 filtered through CCL,LUT0
	sbi VPORTA_DIR, 5
	cbi VPORTA_OUT, 5

	; Use PA1 as gate output to disable USART,TXD during blanking intervals
	sbi VPORTA_DIR, 3
	cbi VPORTA_OUT, 3

	; Configure USART0
	ldi r16, USART_TXEN_bm
	sts USART0_CTRLB, r16
	ldi r16, USART_MSPI_CMODE_MSPI_gc
	sts USART0_CTRLC, r16
	ldi r16, (1 << 6)
	sts USART0_BAUD, r16

	; Configure CCL
	ldi r16, CCL_INSEL1_USART0_gc | CCL_INSEL0_MASK_gc
	sts CCL_LUT0CTRLB, r16
	ldi r16, CCL_INSEL2_IO_gc
	sts CCL_LUT0CTRLC, r16
	ldi r16, 0b01000000
	sts CCL_TRUTH0, r16
	ldi r16, CCL_ENABLE_bm | CCL_OUTEN_bm
	sts CCL_LUT0CTRLA, r16
	ldi r16, CCL_ENABLE_bm
	sts CCL_CTRLA, r16


	; Enable TCA to start video signal
	ldi r16, TCA_SINGLE_ENABLE_bm
	sts TCA0_SINGLE_CTRLA, r16

; This loop should be synchronous with TCA, so it must run exactly H_FULL/CLK_DIV (1056/2=528) clock cycles
;	TCA0.CNT is H_BACK/CLK_DIV-LOOP_HEADSTART at the top of this loop
scanline_loop:
	; >>> TCA0.CNT = 39

	; Setup before image interval
	sbrs r5, 0
		; Line is in the visible portion
		rjmp setup_visible_line
	sbrc r5, 1
		; Line is in the vertical sync pulse
		rjmp setup_sync_line
	
	; Setup_blank_line
		nop nop nop nop nop
		sbi VPORTC_OUT, 0 ; Set sync pulse high
		rjmp blank_pixel_line
	
	setup_sync_line:
		nop nop nop nop
		cbi VPORTC_OUT, 0 ; Set sync pulse low
		rjmp blank_pixel_line

	setup_visible_line:
		ldi r16, 0x40 ; Output byte 0
		sts USART0_TXDATAL, r16 ; Data transmission starts 3 clock cycles later
		nop nop nop
		; Enable pixel data output at the same time as USART starts transmitting
		sbi VPORTA_OUT, 3
		rjmp pixel_phase

; >>> TCA0.CNT = 51
	pixel_phase:
	nop nop nop nop nop nop nop nop
	
	ldi r16, 0x7E ; Output byte 1
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x81 ; Output byte 2
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x7E ; Output byte 3
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x81 ; Output byte 4
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x7E ; Output byte 5
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x81 ; Output byte 6
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x00 ; Output byte 7
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0xFF ; Output byte 8
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x00 ; Output byte 9
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0xFF ; Output byte 10
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x00 ; Output byte 11
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0xFF ; Output byte 12
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x00 ; Output byte 13
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0xFF ; Output byte 14
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x00 ; Output byte 15
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0xFF ; Output byte 16
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x00 ; Output byte 17
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0xFF ; Output byte 18
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x00 ; Output byte 19
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0xFF ; Output byte 20
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x00 ; Output byte 21
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0xFF ; Output byte 22
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0x00 ; Output byte 23
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	ldi r16, 0xFF ; Output byte 24
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	; Turn off pixel data after cycle 400 of hline
	cbi VPORTA_OUT, 3
; >>> TCA0.CNT = 445
	rjmp horizontal_blanking_interval
	
; >>> TCA0.CNT = 51
	blank_pixel_line:
	; Start of image interval
	; 397 cycle delay (40 pr. line)
	                        nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	
	; Turn off pixel data after cycle 400 of hline
	cbi VPORTA_OUT, 3
	rjmp horizontal_blanking_interval

; >>> TCA0.CNT = 447
	horizontal_blanking_interval:
	; Start of blanking interval
	; 101 cycle delay (32 pr. line)
	    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop

; >>> TCA0.CNT = 19
	; Increment and wrap line counter, and set r5 to 0, 1, 2 or 3 depending on
	; which vertical phase we are in (visible, front, sync, or back)
	; Makes sure the timing is the same in all paths through the code
	adiw ZH:ZL, 1
	
	; First, check top byte. If this is not 0x02, we are in the visible phase
	cpi ZH, 0x02
	brne z_phase_visible
	
	cpi ZL, low(V_VISIBLE)
	breq z_phase_front
	
	cpi ZL, low(V_VISIBLE+V_FRONT)
	breq z_phase_sync
	
	cpi ZL, low(V_VISIBLE+V_FRONT+V_SYNC)
	breq z_phase_back
	
	cpi ZL, low(V_FULL)
	breq z_phase_wrap

	nop nop nop nop
	rjmp z_phase_done

	; Handle each phase separatly
	z_phase_visible:
		; No changes here, so just wait the right amount of time
		nop nop nop nop nop nop nop nop nop nop nop
	rjmp z_phase_done
	
	z_phase_front:
		; Start of front porch
		inc r5
		nop nop nop nop nop nop nop nop
	rjmp z_phase_done
	
	z_phase_sync:
		; Start of sync pulse
		inc r5
		inc r5
		nop nop nop nop nop
	rjmp z_phase_done
	
	z_phase_back:
		; Start of back porch
		dec r5
		dec r5
		nop nop nop
	rjmp z_phase_done
	
	z_phase_wrap:
		clr r5
		clr ZH
		clr ZL
	rjmp z_phase_done


	z_phase_done: ; 16 cycles after adiw ZH:ZL, 1

; >>> TCA0.CNT = 37
    rjmp scanline_loop ; Jump back takes 2 cycles


