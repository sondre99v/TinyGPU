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
.EQU TILE_ARRAY_WIDTH = 27
.EQU TILE_ARRAY_HEIGHT = 15

.EQU SCANLINE_BUFFER_TILES = 26

; Main entry point
.cseg
start:
	; CLK_PER = 20 MHz (16/20 fuse set to 20)
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
	
	; Mask pin on PA3 (fully software controlled) to disable pixel output
	; during VBLANK
	sbi VPORTA_DIR, 3
	cbi VPORTA_OUT, 3

	; Pixel pin on LUT0.OUT* (PB4)
	ldi r16, PORTMUX_LUT0_bm
	sts PORTMUX_CTRLA, r16
	sbi VPORTB_DIR, 4
	cbi VPORTA_OUT, 4

	; VSYNC pin on PA4 (fully software controlled)
	sbi VPORTA_DIR, 4
	sbi VPORTA_OUT, 4


	; Setup registers to control the generation
	ldi XH, high(scanline_bufferA)
	ldi XL, low(scanline_bufferA)
	; Register keeping track of the currently drawing line, in pixels
	.DEF r_y = r25
	clr r_y


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
	
	
	; Check if this is a really visible line, or if it is "line -1"
	cpi r_y, 1
	breq enable_output
		rjmp enable_output_done
	enable_output:
		sbi VPORTA_OUT, 3
	enable_output_done:

	; Wait until HBLANK is done
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop

	ldi XH, high(scanline_bufferA)
	ldi XL, low(scanline_bufferA)
	
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16


	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	
	
	; ===================
	; Begin scanline 4k+1
	; ===================

	; Wait until HBLANK is done
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop

	ldi XH, high(scanline_bufferA)
	ldi XL, low(scanline_bufferA)

	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16

	ldi XH, high(scanline_bufferA)
	ldi XL, low(scanline_bufferA)

	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	
	
	; ===================
	; Begin scanline 4k+2
	; ===================

	; Wait until HBLANK is done
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop

	ldi XH, high(scanline_bufferA)
	ldi XL, low(scanline_bufferA)

	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16

	ldi XH, high(scanline_bufferA)
	ldi XL, low(scanline_bufferA)

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

	ldi XH, high(scanline_bufferA)
	ldi XL, low(scanline_bufferA)

	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16
	nop nop nop nop nop nop nop
	nop nop nop nop nop
	ld r16, X+
	sts USART0_TXDATAL, r16

	ldi XH, high(scanline_bufferA)
	ldi XL, low(scanline_bufferA)


	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop

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
	cbi VPORTA_OUT, 3 ; Ignore for now

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
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop

	nop nop nop nop nop nop nop nop	nop nop nop nop nop nop nop nop nop	nop nop

	; Reset to line 0, and jump back to the rendering-loop
	clr r_y
	rjmp visible_scanline4x
	
;.include "tileset.asm"
;.include "default_leveldata.asm"

; Tiledata array in RAM
.dseg
.org 0x3E00
scanline_bufferA: .byte SCANLINE_BUFFER_TILES
scanline_bufferB: .byte SCANLINE_BUFFER_TILES
tiledata: .byte (TILE_ARRAY_WIDTH * TILE_ARRAY_HEIGHT)
window_tiles: .byte (H_VISIBLE / PIXEL_DIV / TILE_WIDTH)
sprite_0: .byte 10
sprite_1: .byte 10
sprite_2: .byte 4
scroll_x: .byte 1
scroll_y: .byte 1
window_y: .byte 1