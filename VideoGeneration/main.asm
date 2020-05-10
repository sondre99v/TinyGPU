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

; Main entry point
.cseg
start:
	; CLK_PER = 20 MHz (16/20 fuse set to 20)
	ldi r16, CPU_CCP_IOREG_gc
	out CPU_CCP, r16
	ldi r16, 0
	sts CLKCTRL_MCLKCTRLB, r16
	
	; HSYNC on PB0, generated by TCA
	sbi VPORTB_DIR, 0
	cbi VPORTB_OUT, 0
	
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
	ldi r16, low(H_FULL / CLK_DIV - 1)
	sts TCA0_SINGLE_CNT, r16
	ldi r16, high(H_FULL / CLK_DIV - 1)
	sts (TCA0_SINGLE_CNT+1), r16

	; VSYNC on PC0, generated in software
	sbi VPORTC_DIR, 0
	sbi VPORTC_OUT, 0

	; Setup 16 bit register Y to count scanlines
	clr YL
	clr YH

	
	; Pixel data output on PA5, generated by USART0 filtered through CCL,LUT0
	sbi VPORTA_DIR, 5
	cbi VPORTA_OUT, 5

	; Use PA1 as gate output to disable USART,TXD during blanking intervals
	sbi VPORTA_DIR, 3
	cbi VPORTA_OUT, 3

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

	; Configure USART0
	; Note! USART clock starts counting when the USART is enabled, meaning it could
	; get out of phase if odd number of clock cycles occur between this enable and the TCA enable
	ldi r16, USART_MSPI_CMODE_MSPI_gc
	sts USART0_CTRLC, r16
	ldi r16, (1 << 6)
	sts USART0_BAUD, r16
	ldi r16, USART_TXEN_bm
	sts USART0_CTRLB, r16
	nop

	; Enable TCA to start video signal
	ldi r16, TCA_SINGLE_ENABLE_bm
	sts TCA0_SINGLE_CTRLA, r16
	nop ; TCA0 wraps to 0x0000
	nop ; TCA0 counts to 0x0001
	nop ; TCA0 counts to 0x0002, as sync line goes high

; This loop should be synchronous with TCA, so it must run exactly H_FULL/CLK_DIV (1056/2=528) clock cycles
;	TCA0.CNT is H_BACK/CLK_DIV-LOOP_HEADSTART at the top of this loop
scanline_loop:
	; Delay to close to the end of the back porch
	nop nop nop nop nop nop nop nop nop nop													  ; 2-11
	nop nop nop nop nop nop nop nop nop nop													  ; 12-21
	nop nop nop nop nop nop nop nop nop nop													  ; 22-31
	nop nop																					  ; 32-33

	; Setup before image interval
	sbrs r5, 0																				  ; 34
		; Line is in the visible portion
		rjmp setup_visible_line																  ; 35-36
	sbrc r5, 1																				  ; 36
		; Line is in the vertical sync pulse
		rjmp setup_sync_line																  ; 37-38
	
	; Setup_blank_line
		nop nop nop nop nop nop nop															  ; 38-44
		sbi VPORTC_OUT, 0 ; Set sync pulse high												  ; 45
		rjmp blank_pixel_line																  ; 46-47
	
	setup_sync_line:
		nop nop nop nop nop nop																  ; 39-44
		cbi VPORTC_OUT, 0 ; Set sync pulse low												  ; 45
		rjmp blank_pixel_line																  ; 46-47


	setup_visible_line:
	lpm r16, Z+ 																			  ; 37-39
	sts USART0_TXDATAL, r16 ; Output byte 0													  ; 40-41
	nop nop nop ; Wait for transmission to start											  ; 42-44

	; Enable pixel data output at the same time as USART starts transmitting
	sbi VPORTA_OUT, 3
	nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 1
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 2
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 3
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 4
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 5
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 6
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 7
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 8
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 9
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 10
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 11
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 12
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 13
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 14
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 15
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 16
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 17
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 18
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 19
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 20
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 21
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 22
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 23
	nop nop nop nop nop nop nop nop nop nop nop
	
	lpm r16, Z+
	sts USART0_TXDATAL, r16 ; Output byte 24
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop	nop nop nop nop					  ; 427-444
	
	; Turn off pixel data
	cbi VPORTA_OUT, 3																		  ; 445
	rjmp horizontal_blanking_interval
	

	blank_pixel_line:
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 48-67
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 68-87
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 88-107
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 108-127
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 128-147
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 148-167
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 168-187
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 188-207
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 208-227
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 228-247
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 248-267
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 268-287
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 288-307
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 308-327
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 328-347
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 348-367
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 368-387
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 388-407
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 408-427
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop	nop nop					  ; 428-445
	
	
	rjmp horizontal_blanking_interval														  ; 446-447

	horizontal_blanking_interval:
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop					  ; 448-465 (front porch)
	
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 466-485
	nop nop nop nop nop nop nop nop nop nop 												  ; 486-495

	

	; Increment and wrap line counter, and set r5 to 0, 1, 2 or 3 depending on
	; which vertical phase we are in (visible, front, sync, or back)
	adiw YH:YL, 1																			  ; 496-497

	; First, check top byte. If this is not 0x02, we are in the visible phase
	cpi YH, 0x02
	brne y_phase_visible

	cpi YL, low(V_VISIBLE)
	breq y_phase_front

	cpi YL, low(V_VISIBLE+V_FRONT)
	breq y_phase_sync

	cpi YL, low(V_VISIBLE+V_FRONT+V_SYNC)
	breq y_phase_back

	cpi YL, low(V_FULL)
	breq y_phase_wrap

	nop nop nop nop
	rjmp y_phase_done

	; Handle each phase separatly
	y_phase_visible:
		; No changes here, so just wait the right amount of time
		nop nop nop nop nop nop nop nop nop nop nop
	rjmp y_phase_done

	y_phase_front:
		; Start of front porch
		inc r5
		nop nop nop nop nop nop nop nop
	rjmp y_phase_done

	y_phase_sync:
		; Start of sync pulse
		inc r5
		inc r5
		nop nop nop nop nop
	rjmp y_phase_done

	y_phase_back:
		; Start of back porch
		dec r5
		dec r5
		nop nop nop
	rjmp y_phase_done

	y_phase_wrap:
		clr r5
		clr YH
		clr YL
	rjmp y_phase_done


	y_phase_done: ; 16 cycles after adiw YH:YL, 1


	; Calculate image index
	mov r16, YL
	mov r17, YH
	lsr r17
	ror r16
	lsr r17
	ror r16
	
	ldi r17, 25
	mul r16, r17

	movw ZH:ZL, r1:r0
	ldi r16, low(image_data << 1)
	add ZL, r16
	ldi r16, high(image_data << 1)
	adc ZH, r16																				  ; 527


    rjmp scanline_loop ; Jump back takes 2 cycles											  ; 0-1


.include "image_data.asm"
