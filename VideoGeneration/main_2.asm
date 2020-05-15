/*
 * main_2.asm
 *
 *  Created: 11-05-2020 20:12:33
 *   Author: Sondre
 */ 

.cseg
rjmp start

.include "tn817def.inc"

; Define VGA timing parameters
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
.EQU CLK_DIV = 2
.EQU PIXEL_DIV = 4

; Tileset parameters
.EQU TILE_WIDTH = 8
.EQU TILE_HEIGHT = 12
.EQU TILEDATA_WIDTH = 27
.EQU TILEDATA_HEIGHT = 15

.EQU SCANLINE_BUFFER_TILES = 26


; Fixed register allocations
.DEF r_zero = r3
.DEF r_tile_y = r24
.DEF r_y = r25
.DEF r_frame = r6

; Main entry point
.cseg
start:
	; Setup to use external clock, with no prescaler
	ldi r16, CPU_CCP_IOREG_gc
	out CPU_CCP, r16
	ldi r16, CLKCTRL_CLKSEL_EXTCLK_gc
	sts CLKCTRL_MCLKCTRLA, r16
	ldi r16, CPU_CCP_IOREG_gc
	out CPU_CCP, r16
	ldi r16, 0
	sts CLKCTRL_MCLKCTRLB, r16
	
	; Setup TCA in split mode, to generate:
	;  - HBLANK mask on WO0, passed into CCL
	;  - HSYNC pulse on TCA0.WO5 (PA5)

	ldi r16, TCA_SPLIT_SPLITM_bm
	sts TCA0_SPLIT_CTRLD, r16

	; Setup HSYNC
	ldi r16, (H_FULL / CLK_DIV / 4) - 1
	sts TCA0_SPLIT_HPER, r16
	ldi r16, (H_SYNC / CLK_DIV / 4)
	sts TCA0_SPLIT_HCMP2, r16
	ldi r16, 0
	sts TCA0_SPLIT_HCNT, r16

	; Setup HBLANK
	ldi r16, (H_FULL / CLK_DIV / 4) - 1
	sts TCA0_SPLIT_LPER, r16
	ldi r16, (H_VISIBLE / CLK_DIV / 4)
	sts TCA0_SPLIT_LCMP0, r16
	ldi r16, ((H_VISIBLE + H_BACK) / CLK_DIV / 4)
	sts TCA0_SPLIT_LCNT, r16

	ldi r16, TCA_SPLIT_HCMP2EN_bm | TCA_SPLIT_LCMP0EN_bm
	sts TCA0_SPLIT_CTRLB, r16

	; HSYNC pin on PA5
	sbi VPORTA_DIR, 5
	ldi r16, PORT_INVEN_bm
	sts PORTA_PIN5CTRL, r16

	; Setup USART0 to serialize the pixel data, to be passed to the CCL
	ldi r16, USART_MSPI_CMODE_MSPI_gc
	sts USART0_CTRLC, r16
	ldi r16, (1 << 6)
	sts USART0_BAUD, r16

	; Setup CCL to compute AND(TCA0.WO0, USART0.TXD, LUT0.IN2)
	ldi r16, CCL_INSEL1_USART0_gc | CCL_INSEL0_TCA0_gc
	sts CCL_LUT0CTRLB, r16
	ldi r16, CCL_INSEL2_IO_gc
	sts CCL_LUT0CTRLC, r16
	ldi r16, 0b10000000
	sts CCL_TRUTH0, r16
	ldi r16, CCL_ENABLE_bm | CCL_OUTEN_bm
	sts CCL_LUT0CTRLA, r16
	ldi r16, CCL_ENABLE_bm
	sts CCL_CTRLA, r16
	
	; Mask pin on PA1 (fully software controlled) to disable pixel output
	; during VBLANK
	sbi VPORTA_DIR, 1
	cbi VPORTA_OUT, 1

	; Pixel pin on LUT0.OUT* (PB4)
	ldi r16, PORTMUX_LUT0_bm
	sts PORTMUX_CTRLA, r16
	sbi VPORTB_DIR, 4
	cbi VPORTA_OUT, 4

	; VSYNC pin on PA4 (fully software controlled)
	sbi VPORTA_DIR, 4
	sbi VPORTA_OUT, 4

	
	; ====================
	; State Initialization
	; ====================
	; Always-zero register
	clr r_zero
	; Setup registers to control the generation
	ldi XH, high(scanline_bufferA)
	ldi XL, low(scanline_bufferA)
	ldi YH, high(scanline_bufferB)
	ldi YL, low(scanline_bufferB)
	; Register keeping track of the currently drawing line, in pixels
	clr r_y
	; Register keeping track of the current tile y-index, and position in that
	; tile. High nibble is tile index, low nibble is index in that tile
	clr r_tile_y
	; Initialize scroll_x
	ldi r16, 2
	sts scroll_x, r16
	; Initialize scroll_y
	ldi r16, 0
	sts scroll_y, r16
	; Initialize tiledata
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
		cpi r17, TILEDATA_WIDTH * TILEDATA_HEIGHT / 2
		brne load_level_loop
	; Register for counting frames. Useful for test animations and such
	clr r6


	; Enable USART0 and TCA0
	; Make sure the prescaler of TCA is synchronized with the baud-rate
	; generator of USART0. Note that the baudrate generator is running even if
	; no transmission is in progress.
	ldi r16, USART_TXEN_bm
	sts USART0_CTRLB, r16
	ldi r16, TCA_SPLIT_CLKSEL_DIV4_gc | TCA_SPLIT_ENABLE_bm
	sts TCA0_SPLIT_CTRLA, r16

; Loop across four scanlines
visible_scanline4x:
	; ===================
	; Begin scanline 4k+0
	; ===================
	
	
	; Make sure we only enable the output once we render row 1 (meaning row 0
	; has been rendered, and should be streamed out).
	cpi r_y, 1
	breq enable_output
		rjmp enable_output_done
	enable_output:
		sbi VPORTA_OUT, 1
	enable_output_done:

	; Wait until HBLANK is done
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop

	; This block takes between 11 and 25 cycles, depending on the value in
	; scroll_x.
	lds r16, scroll_x
	lsl r16
	andi r16, 0xF ; Ensure no infinite loop occurs if scroll_x > 7
	ldi ZL, low(timingjmpA_14)
	ldi ZH, high(timingjmpA_14)
	add ZL, r16
	adc ZH, r_zero
	ijmp
	timingjmpA_14: nop nop
	timingjmpA_12: nop nop
	timingjmpA_10: nop nop
	timingjmpA_8: nop nop
	timingjmpA_6: nop nop
	timingjmpA_4: nop nop
	timingjmpA_2: nop nop
	timingjmpA_0:

	; Start streaming out the output-buffer, while rendering to the
	; renderbuffer
	ld r2, X+
	sts USART0_TXDATAL, r2 ; Output byte 0

	; Render tiles of current line to the renderbuffer. Y holds a pointer to
	; the current render-buffer.
	; Since both the X and Y registers are occupied as pointers to the display-
	; and renderbuffers respectivly, we must use the Z register for both the
	; tiledata, and the tileset.
	; We dont need to load scroll_y, since r_tile_y contains all the
	; information we need
	mov r16, r_tile_y
	swap r16
	andi r16, 0x0F
	ldi r17, TILEDATA_WIDTH
	; Multiply tile y-index with width to get index of first tile in row
	mul r16, r17
	; Load scroll_x, and add the top 5 bits to the tile index. Keep result in
	; r18 in order to wrap the rendering if it goes beyond the right side of
	; the array.
	lds r18, scroll_x
	lsr r18
	lsr r18
	lsr r18
	
	ld r2, X+
	sts USART0_TXDATAL, r2 ; Output byte 1

	add r0, r18
	adc r1, r_zero
	; Load tiledata pointer into Z, and offset to the correct starting tile
	ldi ZL, low(tiledata)
	ldi ZH, high(tiledata)
	add ZL, r0
	adc ZH, r1
	; Set r19 to the y-index within the tile
	mov r19, r_tile_y
	andi r19, 0x0F


	rcall render_tile_while_streaming ; Render byte 0. Output bytes 2,3,4
	rcall render_tile_while_streaming ; Render byte 1. Output bytes 5,6,7
	rcall render_tile_while_streaming ; Render byte 2. Output bytes 8,9,10
	rcall render_tile_while_streaming ; Render byte 3. Output bytes 11,12,13
	rcall render_tile_while_streaming ; Render byte 4. Output bytes 14,15,16
	rcall render_tile_while_streaming ; Render byte 5. Output bytes 17,18,19
	rcall render_tile_while_streaming ; Render byte 6. Output bytes 20,21,22
	rcall render_tile_while_streaming ; Render byte 7. Output bytes 23,24,25

	; Rewind to start of output buffer
	subi XL, SCANLINE_BUFFER_TILES

	rcall render_tile ; Render byte 8
	rcall render_tile ; Render byte 9

	nop nop nop nop nop nop nop nop nop nop
	nop nop nop 


	; ===================
	; Begin scanline 4k+1
	; ===================

	; Wait until HBLANK is done
	rcall render_tile ; Render byte 10
	nop nop nop nop nop nop nop nop

	; Start rendering and streaming data
	rcall render_tile_while_streaming ; Render byte 11. Output bytes 0,1,2
	rcall render_tile_while_streaming ; Render byte 12. Output bytes 3,4,5
	rcall render_tile_while_streaming ; Render byte 13. Output bytes 6,7,8
	rcall render_tile_while_streaming ; Render byte 14. Output bytes 9,10,11
	rcall render_tile_while_streaming ; Render byte 15. Output bytes 12,13,14
	rcall render_tile_while_streaming ; Render byte 16. Output bytes 15,16,17
	rcall render_tile_while_streaming ; Render byte 17. Output bytes 18,19,20
	rcall render_tile_while_streaming ; Render byte 18. Output bytes 21,22,23

	; Output bytes 24 and 25 without rendering
	nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2

	; Rewind to start of output buffer
	subi XL, SCANLINE_BUFFER_TILES
	
	rcall render_tile ; Render byte 19
	rcall render_tile ; Render byte 20
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop

	; ===================
	; Begin scanline 4k+2
	; ===================

	; Wait until HBLANK is done
	rcall render_tile ; Render byte 21
	nop nop nop nop nop nop nop nop 
	
	rcall render_tile_while_streaming ; Render byte 22. Output bytes 0,1,2
	rcall render_tile_while_streaming ; Render byte 23. Output bytes 3,4,5
	rcall render_tile_while_streaming ; Render byte 24. Output bytes 6,7,8
	rcall render_tile_while_streaming ; Render byte 25. Output bytes 9,10,11
	; Rendering finished, rewind to start of renderbuffer
	sbiw Y, SCANLINE_BUFFER_TILES
	
	nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2

	nop nop

	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	
	
	; ===================
	; Begin scanline 4k+3
	; ===================

	; Wait until HBLANK is done
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	
	nop
	; Rewind to start of output buffer
	subi XL, SCANLINE_BUFFER_TILES

	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r2, X+
	sts USART0_TXDATAL, r2

	nop
	
	; Rewind to start of output buffer
	subi XL, SCANLINE_BUFFER_TILES
	


	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop

	

	; Compensation for the scroll-delay at the top
	; This block takes between 11 and 25 cycles, depending on the value in
	; scroll_x.
	lds r16, scroll_x
	lsl r16
	andi r16, 0xF ; Ensure no infinite loop occurs if scroll_x > 7
	ldi ZL, low(timingjmpB_0)
	ldi ZH, high(timingjmpB_0)
	sub ZL, r16
	sbc ZH, r_zero
	ijmp
	timingjmpB_14: nop nop
	timingjmpB_12: nop nop
	timingjmpB_10: nop nop
	timingjmpB_8: nop nop
	timingjmpB_6: nop nop
	timingjmpB_4: nop nop
	timingjmpB_2: nop nop
	timingjmpB_0:


	; Swap buffers
	eor YL, XL
	eor XL, YL
	eor YL, XL
	eor YH, XH
	eor XH, YH
	eor YH, XH

	nop nop nop
	nop nop nop nop nop nop nop nop
	nop nop
	
	; Advance r_tile_y. Add one to the low nibble, if the incremented value
	; equals TILE_HEIGHT, clear it, and increment the high nibble. There is no
	; need to handle the high nibble wrapping, as this is reset during VBLANK.
	inc r_tile_y
	ldi r16, 0x10-TILE_HEIGHT
	add r_tile_y, r16
	brhs r_tile_y_wrap			 ; Branch on carry from low to high nibble
		sub r_tile_y, r16
		rjmp r_tile_y_wrap_done
	r_tile_y_wrap:
		nop nop
	r_tile_y_wrap_done:


	; Advance line counter, and jump to either the next visible line, or into
	; vblank.
	inc r_y
	cpi r_y, (V_VISIBLE / PIXEL_DIV + 1)
	breq vblank

	rjmp visible_scanline4x


; This section lasts for exactly 24 lines, plus the initial NOP at the
; beginning. The VBLANK interval is really 28 lines, but the final four lines
; is spent runing the visible_scanline4x loop without streaming out any data,
; so that row 0 can be rendered to the buffer.
;   24 lines = 24*1056/2 = 12672 cycles
vblank:
	nop ; 1-cycle delay to synchronize with where the visible_scanline4x starts

	; Disable pixel output
	cbi VPORTA_OUT, 1

	; Wait until start of line
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop

	; Delay for 1 line minus 1 cycle (527 cycles)
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop

	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop

	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop	nop nop nop nop

	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop nop	nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop nop nop nop nop
	
	nop nop nop nop nop nop nop nop	nop nop nop nop nop	nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop	nop nop nop nop

	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop
	

	; Lower vsync-pulse
	cbi VPORTA_OUT, 4
	
	; Delay for 4 lines minus 1 cycles (4 * 528 - 1 cycles)
	clr r16
	loop1: inc r16 inc r16 brne loop1 ; 512 cycles
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop

	clr r16
	loop2: inc r16 inc r16 brne loop2 ; 512 cycles
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop

	clr r16
	loop3: inc r16 inc r16 brne loop3 ; 512 cycles
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop

	clr r16
	loop4: inc r16 inc r16 brne loop4 ; 512 cycles
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop

	
	; Raise vsync-pulse
	sbi VPORTA_OUT, 4


	; Delay for 19 lines minus the back porch of the last line (approx)
	
	; 18 lines
	ldi r17, 18
	loop6:
		clr r16
		loop5: inc r16 inc r16 brne loop5 ; 512 cycles
		nop nop nop nop nop nop nop nop nop nop nop
		dec r17
		brne loop6

	; Incomplete 21st line (528-44=484 cycles)
	ldi r16, 0x80
	loop7: inc r16 inc r16 brne loop7 ; 256 cycles

	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop	nop nop nop nop

	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop nop	nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop	nop nop nop nop
	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop nop nop nop nop

	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop


	; Test scrolling functionality
	inc r_frame
	ldi r16, 5
	cp r_frame, r16
	breq scroll_12Hz
		nop nop nop nop nop nop nop nop nop nop
		rjmp scroll_12Hz_done
	scroll_12Hz:
		clr r_frame
		lds r16, scroll_x
		inc r16

		cpi r16, (TILE_WIDTH * TILEDATA_WIDTH)
		breq scroll_12Hz_wrap
			rjmp scroll_12Hz_wrap_done	
		scroll_12Hz_wrap:
			clr r16
		scroll_12Hz_wrap_done:

		sts scroll_x, r16
	scroll_12Hz_done:

	nop nop

	; Reset to line 0, set the A to be output, and the B buffer as the
	; rendertarget, then jump back to the rendering-loop
	clr r_y
	clr r_tile_y ;TODO here is to load in scroll_y, instead of clearing
	
	ldi XH, high(scanline_bufferA)
	ldi XL, low(scanline_bufferA)
	ldi YH, high(scanline_bufferB)
	ldi YL, low(scanline_bufferB)

	rjmp visible_scanline4x


; Subroutine which renders 1 byte, while outputting three to the USART
render_tile_while_streaming:
	; Subroutine call takes 2 cycles
	
	ld r16, Z+ ; Load tile
	
	ld r2, X+
	sts USART0_TXDATAL, r2

	movw r5:r4, Z
	; Compute address in tileset
	ldi r17, TILE_HEIGHT
	mul r16, r17
	add r0, r19
	adc r1, r_zero
	ldi ZL, low(tileset_data << 1)
	ldi ZH, high(tileset_data << 1)
	add ZL, r0
	adc ZH, r1
	nop nop
	
	ld r2, X+
	sts USART0_TXDATAL, r2

	lpm r16, Z ; Load row from tileset
	st Y+, r16 ; Write row to render-buffer
	movw Z, r5:r4
	
	; Increment x-index and wrap if we've reached the right side of tiledata
	inc r18
	cpi r18, TILEDATA_WIDTH
	breq wrap_index_x
		nop nop
		rjmp wrap_index_x_done
	wrap_index_x:
		clr r18
		sbiw Z, TILEDATA_WIDTH
	wrap_index_x_done:
	
	ld r2, X+
	sts USART0_TXDATAL, r2

	nop nop nop nop
	; Return jump takes 4 cycles
	ret

; Subroutine to render 1 byte while no streaming is needed
; Takes 30 cycles, including call and return
render_tile:
	; Subroutine call takes 2 cycles
	ld r16, Z+ ; Load tile

	; Compute address in tileset
	movw r5:r4, Z
	ldi r17, TILE_HEIGHT
	mul r16, r17
	add r0, r19
	adc r1, r_zero
	ldi ZL, low(tileset_data << 1)
	ldi ZH, high(tileset_data << 1)
	add ZL, r0
	adc ZH, r1

	; Render byte
	lpm r16, Z ; Load row from tileset
	st Y+, r16 ; Write row to render-buffer
	movw Z, r5:r4
	
	; Increment x-index and wrap if we've reached the right side of tiledata
	inc r18
	cpi r18, TILEDATA_WIDTH
	breq wrap_index_x2
		nop nop
		rjmp wrap_index_x2_done
	wrap_index_x2:
		clr r18
		sbiw Z, TILEDATA_WIDTH
	wrap_index_x2_done:
	
	; Return jump takes 4 cycles
	ret

.include "default_leveldata.asm"
.include "tileset.asm"

; Tiledata array in RAM
.dseg
.org 0x3E00
scanline_bufferA: .byte SCANLINE_BUFFER_TILES
scanline_bufferB: .byte SCANLINE_BUFFER_TILES
tiledata: .byte (TILEDATA_WIDTH * TILEDATA_HEIGHT)
window_tiles: .byte (H_VISIBLE / PIXEL_DIV / TILE_WIDTH)
sprite_0: .byte 10
sprite_1: .byte 10
sprite_2: .byte 4
scroll_x: .byte 1
scroll_y: .byte 1
window_y: .byte 1