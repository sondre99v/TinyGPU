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

.def r_y = r6 ; Inter-tile y-index
.def r_ty = r8 ; Tile y-index
.def r_x = r7

; Main entry point
.cseg
start:
	; CLK_PER = 20 MHz (16/20 fuse set to 20)
	ldi r16, CPU_CCP_IOREG_gc
	out CPU_CCP, r16
	ldi r16, 0
	sts CLKCTRL_MCLKCTRLB, r16

	; HSYNC on PB0, generated by software
	sbi VPORTB_DIR, 0
	sbi VPORTB_OUT, 0
	
	sbi VPORTB_DIR, 4
	ldi r16, PORTMUX_TCA01_bm
	sts PORTMUX_CTRLC, r16

	; Configure TCA
	ldi r16, low(H_FULL / CLK_DIV - 1)
	sts TCA0_SINGLE_PER, r16
	ldi r16, high(H_FULL / CLK_DIV - 1)
	sts (TCA0_SINGLE_PER+1), r16
	
	ldi r16, low(H_VISIBLE / CLK_DIV)
	sts TCA0_SINGLE_CMP1, r16
	ldi r16, high(H_VISIBLE / CLK_DIV)
	sts (TCA0_SINGLE_CMP1+1), r16

	ldi r16, TCA_SINGLE_CMP1EN_bm | TCA_SINGLE_WGMODE_SINGLESLOPE_gc
	sts TCA0_SINGLE_CTRLB, r16

	; Start TCA just before wraparound
	ldi r16, low((H_FULL-H_BACK) / CLK_DIV)
	sts TCA0_SINGLE_CNT, r16
	ldi r16, high((H_FULL-H_BACK) / CLK_DIV)
	sts (TCA0_SINGLE_CNT+1), r16

	; VSYNC on PC0, generated in software
	sbi VPORTC_DIR, 0
	sbi VPORTC_OUT, 0

	
	; Pixel data output on PA5, generated by USART0 filtered through CCL,LUT0
	sbi VPORTA_DIR, 5
	cbi VPORTA_OUT, 5

	; Use PA1 as gate output to disable USART,TXD during blanking intervals
	sbi VPORTA_DIR, 3
	cbi VPORTA_OUT, 3

	; Use PA0 as gate to disable USART, USART,TXD during VBLANK
	sbi VPORTA_DIR, 0
	sbi VPORTA_OUT, 0

	; Configure CCL
	ldi r16, CCL_INSEL1_USART0_gc | CCL_INSEL0_IO_gc
	sts CCL_LUT0CTRLB, r16
	ldi r16, CCL_INSEL2_IO_gc
	sts CCL_LUT0CTRLC, r16
	ldi r16, 0b10000000
	sts CCL_TRUTH0, r16
	ldi r16, CCL_ENABLE_bm | CCL_OUTEN_bm
	sts CCL_LUT0CTRLA, r16
	ldi r16, CCL_ENABLE_bm
	sts CCL_CTRLA, r16

	; Configure USART0
	ldi r16, USART_MSPI_CMODE_MSPI_gc
	sts USART0_CTRLC, r16
	ldi r16, (1 << 6)
	sts USART0_BAUD, r16


	; Setup 16 bit register Y to count scanlines
	clr YL
	clr YH
	
	; Setup registers for tile-decoding
	clr r_y
	clr r_ty
	clr r_x

	; Load default level into tiledata
	ldi XL, low(tiledata)
	ldi XH, high(tiledata)
	ldi ZL, low(default_leveldata << 1)
	ldi ZH, high(default_leveldata << 1)
	clr r17
	load_level_loop:
		lpm r16, Z+
		st X+, r16
		lpm r16, Z+
		st X+, r16
		inc r17
		cpi r17, 224
		brne load_level_loop


	; Enable TCA and USART to start video signal
	; Note! USART clock starts counting when the USART is enabled, meaning it could
	; get out of phase if odd number of clock cycles occur between this enable and the TCA enable
	ldi r16, USART_TXEN_bm
	ldi r17, TCA_SINGLE_ENABLE_bm
	sts USART0_CTRLB, r16
	sts TCA0_SINGLE_CTRLA, r17
	nop ; TCA0 wraps to 0x0000
	nop ; TCA0 counts to 0x0001
	nop ; TCA0 counts to 0x0002, as mask line goes high

; This loop should be synchronous with TCA, so it must run exactly H_FULL/CLK_DIV (1056/2=528) clock cycles
scanline_loop:
	; Starting at TCA.CNT = 2
	
	ldi r19, 12
	clr r20
	clr r_x

	; Lookup first tile index
	ldi XH, high(tiledata)
	ldi XL, low(tiledata)

	ldi r16, 28
	mul r16, r_ty

	add XL, r0
	adc XH, r1

	nop
	nop
	nop
	nop
	nop
	nop

	ld r16, X+
	mul r16, r19
	
	; Set Z to base of tileset
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)

	; Add index to correct tile
	add ZL, r0
	adc ZH, r1

	; Add index to row in tile
	add ZL, r_y
	adc ZH, r20
	
	; Load correct byte
	lpm r17, Z

	nop
	nop
	nop
	

	; Setup line
	sbrs r5, 0																				  ; 34
		; Line is in the visible portion
		rjmp setup_visible_line																  ; 35-36
	sbrc r5, 1																				  ; 36
		; Line is in the vertical sync pulse
		rjmp setup_sync_line																  ; 37-38
	
	nop nop nop nop nop nop nop																  ; 38-44
	sbi VPORTC_OUT, 0 ; Set sync pulse high													  ; 45
	rjmp blank_pixel_line																	  ; 46-47
	
	setup_sync_line:
		nop nop nop nop nop nop																  ; 39-44
		cbi VPORTC_OUT, 0 ; Set sync pulse low												  ; 45
		rjmp blank_pixel_line																  ; 46-47


	setup_visible_line:
	
	; Start preparing next byte
	ld r16, X+																	              ; 37-38

	; Disable VSYNC mask
	sbi VPORTA_OUT, 0																		  ; 39

	sts USART0_TXDATAL, r17 ; Output byte 0													  ; 40-41
	
	mul r16, r19
	ldi ZH, high(tileset_data << 1)

	; Enable pixel data output at the same time as USART starts transmitting
	sbi VPORTA_OUT, 3

	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop nop nop

	sts USART0_TXDATAL, r16 ; Output byte 1

	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 2
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 3
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 4
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 5
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 6
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 7
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 8
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 9
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 10
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 11
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 12
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 13
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 14
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 15
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 16
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 17
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 18
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 19
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 20
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 21
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 22
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
	sts USART0_TXDATAL, r16 ; Output byte 23
	
	; Load next byte
	ld r16, X+
	mul r16, r19
	ldi ZH, high(tileset_data << 1)
	ldi ZL, low(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	add ZL, r_y
	adc ZH, r20
	lpm r16, Z
	nop
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
	            nop nop nop nop nop nop nop nop nop nop nop nop nop nop						  ; 448-464 (front porch)
	cbi VPORTB_OUT, 0																		  ; 465

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop			  ; 466-485
	nop nop nop nop nop nop nop 															  ; 486-492

	

	; Increment and wrap line counter, and set r5 to 0, 1, 2 or 3 depending on
	; which vertical phase we are in (visible, front, sync, or back)
	adiw YH:YL, 1																			  ; 493-494

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

	nop nop nop nop nop nop
	rjmp y_phase_done

	; Handle each phase separatly
	y_phase_visible:
		; No changes here, so just wait the right amount of time
		nop nop nop nop nop nop nop nop nop nop nop nop nop
	rjmp y_phase_done

	y_phase_front:
		; Start of front porch
		inc r5
		cbi VPORTA_OUT, 0
		nop nop nop nop nop nop nop nop nop
	rjmp y_phase_done

	y_phase_sync:
		; Start of sync pulse
		inc r5
		inc r5
		nop nop nop nop nop nop nop
	rjmp y_phase_done

	y_phase_back:
		; Start of back porch
		dec r5
		dec r5
		nop nop nop nop nop
	rjmp y_phase_done

	y_phase_wrap:
		clr r5
		clr YH
		clr YL
		clr r_ty
		clr r_y
	rjmp y_phase_done


	y_phase_done: ; 16 cycles after adiw YH:YL, 1


	; Increment r_y if line is multiple of 4
	sbrc YL, 0
	rjmp dont_inc_r_y_A
	sbrc YL, 1
	rjmp dont_inc_r_y_B
		; Increment r_y and r_ty
		inc r_y
		ldi r16, 12
		cp r_y, r16
		breq ry_wrap
		nop nop nop
		rjmp inc_ry_done
		ry_wrap:
		clr r_y
		inc r_ty
		rjmp inc_ry_done

	dont_inc_r_y_A:
		nop nop
	dont_inc_r_y_B:
		nop nop nop nop nop nop nop nop

	inc_ry_done:


	nop
	nop
	nop
	nop
	sbi VPORTB_OUT, 0																		  ; 527


    rjmp scanline_loop ; Jump back takes 2 cycles											  ; 0-1


.include "tileset.asm"
.include "default_leveldata.asm"

.dseg
.org 0x3E00
tiledata:
.byte 28*16
