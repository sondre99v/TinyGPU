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
.EQU TILEDATA_HEIGHT = 14

.EQU SCANLINE_BUFFER_TILES = 26


; Fixed register allocations
.DEF r_prodL = r0
.DEF r_prodH = r1
.DEF r_stream_tmp = r2
.DEF r_zero = r3
.DEF r_tmp16L = r4
.DEF r_tmp16H = r5
.DEF r_scroll_x = r23
.DEF r_tile_y = r24
.DEF r_y = r25

; Buffers and settings in RAM
; Important that the tiledata array is larger than 256 bytes, so that only
; 8-bit address calculation is required for the other buffers.
.dseg
.org 0x3E00
tiledata: .byte (TILEDATA_WIDTH * TILEDATA_HEIGHT)
scroll_x: .byte 1
scroll_y: .byte 1
window_y: .byte 1
sprite_0: .byte 4
sprite_1: .byte 4
sprite_3: .byte 4
sprite_4: .byte 4
sprite_5: .byte 4
sprite_6: .byte 4
sprite_7: .byte 4
sprite_8: .byte 4
sprite_9: .byte 4
sprite_10: .byte 4
sprite_11: .byte 4
sprite_12: .byte 4
sprite_13: .byte 4
reserved0: .byte 1
reserved1: .byte 1
scanline_bufferA: .byte SCANLINE_BUFFER_TILES
scanline_bufferB: .byte SCANLINE_BUFFER_TILES
window_tiles: .byte (H_VISIBLE / PIXEL_DIV / TILE_WIDTH)
.EQU SPR_COL = 0
.EQU SPR_MASK = 1
.EQU SPR_POSX = 2
.EQU SPR_POSY = 3

; Macro for delaying exact number of cycles, in increments of 10.
; Disturbs r16
.MACRO delay_decacycles
	ldi r16, @0
	delay_loop_1:
		nop nop nop nop nop nop nop
		dec r16
		brne delay_loop_1
.ENDMACRO

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
	ldi r16, USART_MSPI_CMODE_MSPI_gc | USART_UDORD_bm
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

	; VSYNC pin on PA4 (fully software controlled)
	sbi VPORTA_DIR, 4
	sbi VPORTA_OUT, 4

	
	; Setup SPI for receiving commands
	ldi r16, PORTMUX_SPI0_ALTERNATE_gc
	sts PORTMUX_CTRLB, r16
	sbi VPORTC_DIR, 1 ; MISO as output
	ldi r16, SPI_BUFEN_bm | SPI_BUFWR_bm | SPI_SSD_bm | SPI_MODE_0_gc
	sts SPI0_CTRLB, r16
	ldi r16, SPI_PRESC_DIV16_gc | SPI_ENABLE_bm
	;sts SPI0_CTRLA, r16


	; ====================
	; State Initialization
	; ====================
	; Always-zero register
	clr r_zero
	; Register keeping track of the currently drawing line, in pixels
	clr r_y
	; Register keeping track of the current tile y-index, and position in that
	; tile. High nibble is tile index, low nibble is index in that tile
	clr r_tile_y
	; Initialize scroll_x
	ldi r_scroll_x, 0
	sts scroll_x, r_scroll_x
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
	; Setup registers to control the generation
	ldi XH, high(scanline_bufferA)
	ldi XL, low(scanline_bufferA)
	ldi YH, high(scanline_bufferB)
	ldi YL, low(scanline_bufferB)
	; Register for counting frames. Useful for test animations and such
	clr r6
	; Initialize spriteslot 0
	ldi r16, 'P' sts (sprite_0 + SPR_COL), r16
	ldi r16, 'P' sts (sprite_0 + SPR_MASK), r16
	ldi r16, 68   sts (sprite_0 + SPR_POSX), r16
	ldi r16, 57   sts (sprite_0 + SPR_POSY), r16



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
	; Make sure we only enable the output once we render row 1 (meaning row 0
	; has been rendered, and should be streamed out).
	cpi r_y, 1
	breq enable_output
		rjmp enable_output_done
	enable_output:
		sbi VPORTA_OUT, 1
	enable_output_done:

	; This block takes between 9 and 23 cycles, depending on the value in
	; scroll_x.
	mov r16, r_scroll_x
	andi r16, 0x7 ; Ensure no infinite loop occurs if scroll_x > 7
	lsl r16
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

	nop nop nop nop nop

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
	mov r18, r_scroll_x
	lsr r18
	lsr r18
	lsr r18

	; ===============================
	; Begin streaming scanline 4k + 0
	; ===============================
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	; USART starts first pixel exactly 4 cycles after the end of this write
	

	; Load tiledata pointer into Z, and offset to the correct starting tile
	ldi ZL, low(tiledata)
	ldi ZH, high(tiledata)
	add ZL, r0
	adc ZH, r1
	add ZL, r18
	adc ZH, r_zero
	; Set r19 to the y-index within the tile
	mov r19, r_tile_y
	andi r19, 0x0F
	
	; Setup r21:r20 for tile-rendering
	ldi r20, low(tileset_data << 1)
	ldi r21, high(tileset_data << 1)
	add r20, r19
	adc r21, r_zero
	
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp

	nop nop nop nop nop nop nop nop nop nop
	nop


	; Use r22 as loop counter
	; Only 12 loops are needed to output all the bytes to the USART, but in
	; order to render the remaining tiles for the next row, we allow this loop
	; to run 13 times (the final 13 tiles for the next row are rendered during
	; the next scanline).
	; The USART output will be masked by the CCL, so it doesn't matter that it
	; is two bytes of garbage to transmit.
	ldi r22, 13
	render_while_streaming_loop:
	
		ld r_stream_tmp, X+
		sts USART0_TXDATAL, r_stream_tmp

		ld r16, Z+ ; Load tile
		movw r5:r4, Z
		; Compute address in tileset
		ldi r17, TILE_HEIGHT
		mul r16, r17
		movw Z, r21:r20
		add ZL, r0
		adc ZH, r1

		lpm r16, Z ; Load row from tileset
	
		ld r_stream_tmp, X+
		sts USART0_TXDATAL, r_stream_tmp

		st Y+, r16 ; Write row to render-buffer
		movw Z, r5:r4
	
		; Increment x-index and wrap if we've reached the right side of tiledata
		inc r18
		cpi r18, TILEDATA_WIDTH
		breq wrap_index_xA
			nop
			rjmp wrap_index_x_doneA
		wrap_index_xA:
			sbiw Z, TILEDATA_WIDTH
		wrap_index_x_doneA:
		
		nop

		dec r22
		brne render_while_streaming_loop

	; Rewind to start of output buffer
	; The renderloop above overruns the output buffer by two bytes, so we need
	; to reset the pointer accordingly.
	subi XL, (SCANLINE_BUFFER_TILES + 2)
	

	; Read SPI communication
	lds r16, SPI0_INTFLAGS
	sbrs r16, SPI_RXCIE_bp
		rjmp spi_comm_delay_0
	; Read command
		lds ZL, SPI0_DATA  ; Low byte of address
		lds ZH, SPI0_DATA  ; High byte of address
		andi ZH, 0x01
		ldi r16, high(INTERNAL_SRAM_START)
		add ZH, r16
		lds r16, SPI0_DATA ; Data
		st Z, r16
		rjmp spi_comm_done_0
	spi_comm_delay_0:
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop
	spi_comm_done_0:
	ser r16
	sts SPI0_INTFLAGS, r16
	

	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop
	
	; ===============================
	; Begin streaming scanline 4k + 1
	; ===============================

	; Use r22 as loop counter
	ldi r22, 13
	render_while_streaming_loop2:
	
		ld r_stream_tmp, X+
		sts USART0_TXDATAL, r_stream_tmp

		ld r16, Z+ ; Load tile
		movw r5:r4, Z
		; Compute address in tileset
		ldi r17, TILE_HEIGHT
		mul r16, r17
		movw Z, r21:r20
		add ZL, r0
		adc ZH, r1

		lpm r16, Z ; Load row from tileset
	
		ld r_stream_tmp, X+
		sts USART0_TXDATAL, r_stream_tmp

		st Y+, r16 ; Write row to render-buffer
		movw Z, r5:r4
	
		; Increment x-index and wrap if we've reached the right side of tiledata
		inc r18
		cpi r18, TILEDATA_WIDTH
		breq wrap_index_xB
			nop
			rjmp wrap_index_x_doneB
		wrap_index_xB:
			sbiw Z, TILEDATA_WIDTH
		wrap_index_x_doneB:
		
		nop

		dec r22
		brne render_while_streaming_loop2

	; Rendering finished, rewind to start of srenderbuffer
	sbiw Y, SCANLINE_BUFFER_TILES

	; Rewind to start of output buffer
	subi XL, SCANLINE_BUFFER_TILES
	

	; Wait for sync-pulse before reading SPI
	nop nop nop nop nop nop nop nop nop nop
	nop

	
	; Read SPI communication
	lds r16, SPI0_INTFLAGS
	sbrs r16, SPI_RXCIE_bp
		rjmp spi_comm_delay_1
	; Read command
		lds ZL, SPI0_DATA  ; Low byte of address
		lds ZH, SPI0_DATA  ; High byte of address
		andi ZH, 0x01
		ldi r16, high(INTERNAL_SRAM_START)
		add ZH, r16
		lds r16, SPI0_DATA ; Data
		st Z, r16
		rjmp spi_comm_done_1
	spi_comm_delay_1:
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop
	spi_comm_done_1:
	ser r16
	sts SPI0_INTFLAGS, r16
	
	
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop
	
	
	; ===============================
	; Begin streaming scanline 4k + 2
	; ===============================
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	
	; Rewind to start of output buffer
	subi XL, SCANLINE_BUFFER_TILES
	
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop
	
	; Read SPI communication
	lds r16, SPI0_INTFLAGS
	sbrs r16, SPI_RXCIE_bp
		rjmp spi_comm_delay_2
	; Read command
		lds ZL, SPI0_DATA  ; Low byte of address
		lds ZH, SPI0_DATA  ; High byte of address
		andi ZH, 0x01
		ldi r16, high(INTERNAL_SRAM_START)
		add ZH, r16
		lds r16, SPI0_DATA ; Data
		st Z, r16
		rjmp spi_comm_done_2
	spi_comm_delay_2:
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop
	spi_comm_done_2:
	ser r16
	sts SPI0_INTFLAGS, r16
	
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop
	

	; ===============================
	; Begin streaming scanline 4k + 4
	; ===============================
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp
	nop nop nop nop nop nop nop nop nop nop
	nop nop
	ld r_stream_tmp, X+
	sts USART0_TXDATAL, r_stream_tmp

	
	; Rewind to start of output buffer
	subi XL, SCANLINE_BUFFER_TILES
	

	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop nop nop
	nop nop nop
	

	; Read SPI communication
	lds r16, SPI0_INTFLAGS
	sbrs r16, SPI_RXCIE_bp
		rjmp spi_comm_delay_3
	; Read command
		lds ZL, SPI0_DATA  ; Low byte of address
		lds ZH, SPI0_DATA  ; High byte of address
		andi ZH, 0x01
		ldi r16, high(INTERNAL_SRAM_START)
		add ZH, r16
		lds r16, SPI0_DATA ; Data
		st Z, r16
		rjmp spi_comm_done_3
	spi_comm_delay_3:
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop
	spi_comm_done_3:
	ser r16
	sts SPI0_INTFLAGS, r16

	nop nop nop nop nop nop nop

	; Compensation for the scroll-delay at the top
	; This block takes between 9 and 23 cycles, depending on the value in
	; scroll_x.
	mov r16, r_scroll_x
	andi r16, 0x7 ; Ensure no infinite loop occurs if scroll_x > 7
	lsl r16
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
	; Disable pixel output
	cbi VPORTA_OUT, 1

	; Wait 470 cycles until first HSYNC pulse
	delay_decacycles 47
	
	
	; Read SPI communication
	lds r16, SPI0_INTFLAGS
	sbrs r16, SPI_RXCIE_bp
		rjmp spi_comm_delay_V0
	; Read command
		lds ZL, SPI0_DATA  ; Low byte of address
		lds ZH, SPI0_DATA  ; High byte of address
		andi ZH, 0x01
		ldi r16, high(INTERNAL_SRAM_START)
		add ZH, r16
		lds r16, SPI0_DATA ; Data
		st Z, r16
		rjmp spi_comm_done_V0
	spi_comm_delay_V0:
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop
	spi_comm_done_V0:
	ser r16
	sts SPI0_INTFLAGS, r16

	; Wait 84 cycles until the end of the back porch
	delay_decacycles 8
	nop nop nop nop
	
	; Lower vsync-pulse
	cbi VPORTA_OUT, 4

	; Wait 420 cycles until the second HSYNC pulse
	delay_decacycles 42
	
	; Read SPI communication
	lds r16, SPI0_INTFLAGS
	sbrs r16, SPI_RXCIE_bp
		rjmp spi_comm_delay_V1
	; Read command
		lds ZL, SPI0_DATA  ; Low byte of address
		lds ZH, SPI0_DATA  ; High byte of address
		andi ZH, 0x01
		ldi r16, high(INTERNAL_SRAM_START)
		add ZH, r16
		lds r16, SPI0_DATA ; Data
		st Z, r16
		rjmp spi_comm_done_V1
	spi_comm_delay_V1:
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop
	spi_comm_done_V1:
	ser r16
	sts SPI0_INTFLAGS, r16
	
	; Wait 505 cycles until the third HSYNC pulse
	delay_decacycles 50
	nop nop nop nop nop
	
	; Read SPI communication
	lds r16, SPI0_INTFLAGS
	sbrs r16, SPI_RXCIE_bp
		rjmp spi_comm_delay_V2
	; Read command
		lds ZL, SPI0_DATA  ; Low byte of address
		lds ZH, SPI0_DATA  ; High byte of address
		andi ZH, 0x01
		ldi r16, high(INTERNAL_SRAM_START)
		add ZH, r16
		lds r16, SPI0_DATA ; Data
		st Z, r16
		rjmp spi_comm_done_V2
	spi_comm_delay_V2:
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop
	spi_comm_done_V2:
	ser r16
	sts SPI0_INTFLAGS, r16
	
	; Wait 505 cycles until the fourth HSYNC pulse
	delay_decacycles 50
	nop nop nop nop nop
	
	; Read SPI communication
	lds r16, SPI0_INTFLAGS
	sbrs r16, SPI_RXCIE_bp
		rjmp spi_comm_delay_V3
	; Read command
		lds ZL, SPI0_DATA  ; Low byte of address
		lds ZH, SPI0_DATA  ; High byte of address
		andi ZH, 0x01
		ldi r16, high(INTERNAL_SRAM_START)
		add ZH, r16
		lds r16, SPI0_DATA ; Data
		st Z, r16
		rjmp spi_comm_done_V3
	spi_comm_delay_V3:
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop
	spi_comm_done_V3:
	ser r16
	sts SPI0_INTFLAGS, r16
	
	; Wait 505 cycles until the fifth HSYNC pulse
	delay_decacycles 50
	nop nop nop nop nop
	
	; Read SPI communication
	lds r16, SPI0_INTFLAGS
	sbrs r16, SPI_RXCIE_bp
		rjmp spi_comm_delay_V4
	; Read command
		lds ZL, SPI0_DATA  ; Low byte of address
		lds ZH, SPI0_DATA  ; High byte of address
		andi ZH, 0x01
		ldi r16, high(INTERNAL_SRAM_START)
		add ZH, r16
		lds r16, SPI0_DATA ; Data
		st Z, r16
		rjmp spi_comm_done_V4
	spi_comm_delay_V4:
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop
	spi_comm_done_V4:
	ser r16
	sts SPI0_INTFLAGS, r16
	
	; Wait 84 cycles until the end of the back porch
	delay_decacycles 8
	nop nop nop nop
	
	; Raise vsync-pulse
	sbi VPORTA_OUT, 4

	; 18 lines
	ldi r17, 18
	loop6:
		; Delay through "visible" portion
		delay_decacycles 39
		nop nop nop nop nop nop nop nop nop

		; Delay through front porch
		delay_decacycles 2

		; Read SPI communication
		lds r16, SPI0_INTFLAGS
		sbrs r16, SPI_RXCIE_bp
			rjmp spi_comm_delay_V5
		; Read command
			lds ZL, SPI0_DATA  ; Low byte of address
			lds ZH, SPI0_DATA  ; High byte of address
			andi ZH, 0x01
			ldi r16, high(INTERNAL_SRAM_START)
			add ZH, r16
			lds r16, SPI0_DATA ; Data
			st Z, r16
			rjmp spi_comm_done_V5
		spi_comm_delay_V5:
			nop nop nop nop nop nop nop nop nop nop
			nop nop nop nop
		spi_comm_done_V5:
		ser r16
		sts SPI0_INTFLAGS, r16
		
		; Delay through rest of HSYNC + back porch (41 + 44 - 4(for jump))
		delay_decacycles 8
		nop nop
		
		dec r17
		breq loop6_exit
		rjmp loop6
	loop6_exit:
	

	; Incomplete 21st line (528-44=484 cycles)
	ldi r16, 0x80
	loop7: inc r16 inc r16 brne loop7 ; 256 cycles

	delay_decacycles 18
	nop nop nop nop nop nop
	
	; Update r_scroll_x from memory in case it has been changed
	; Also, maybe test scrolling functionality
	lds r_scroll_x, scroll_x
	nop ;inc r_scroll_x
	cpi r_scroll_x, 216
	breq wrap_x
		rjmp wrap_done
	wrap_x:
		clr r_scroll_x
	wrap_done:
	sts scroll_x, r_scroll_x


	nop nop nop nop nop nop nop nop nop nop
	nop nop nop nop nop nop nop nop

	; Reset to line 0, set the A to be output, and the B buffer as the
	; rendertarget, then jump back to the rendering-loop
	clr r_y
	clr r_tile_y ;TODO here is to load in scroll_y, instead of clearing
	
	nop;ldi XH, high(scanline_bufferA)
	nop;ldi XL, low(scanline_bufferA)
	nop;ldi YH, high(scanline_bufferB)
	nop;ldi YL, low(scanline_bufferB)

	rjmp visible_scanline4x

powers_of_2_table: .db 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80

.include "default_leveldata.asm"
.include "tileset.asm"

/*
; Render sprite 0

	; Compute y in sprite
	ldi r17, TILE_HEIGHT
	lds r16, (sprite_0 + SPR_POSY)
	sub r16, r_y
	neg r16
	
	; Check y-limits
	brmi sprite_dont_render
	cp r16, r17
	brge sprite_dont_render_2
		rjmp sprite_start_render
	sprite_dont_render:
		nop nop
	sprite_dont_render_2:
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop nop nop nop nop nop nop
		nop nop nop nop nop nop nop nop nop
		rjmp sprite_render_done
	sprite_start_render:
	
	; Get sprite data
	ldi ZL, low(tileset_data << 1)
	ldi ZH, high(tileset_data << 1)
	add ZL, r16
	adc ZH, r_zero
	lds r16, (sprite_0 + SPR_COL)
	mul r16, r17
	add ZL, r0
	adc ZH, r1
	lpm r18, Z
	sub ZL, r0
	sbc ZH, r1
	lds r16, (sprite_0 + SPR_MASK)
	mul r16, r17
	add ZL, r0
	adc ZH, r1
	lpm r20, Z
	
	; Set- and clr- values
	mov r16, r18
	and r18, r20
	com r16
	and r20, r16
	
	; Split up x_pos
	lds r16, (sprite_0 + SPR_POSX)
	mov r17, r_scroll_x
	andi r17, 0x07
	add r16, r17
	mov r17, r16
	lsr r17
	lsr r17
	lsr r17
	andi r16, 0x07
	
	; Shift to x_pos
	ldi ZL, low(powers_of_2_table << 1)
	ldi ZH, high(powers_of_2_table << 1)
	add ZL, r16
	adc ZH, r_zero
	lpm r21, Z
	mul r18, r21
	movw r19:r18, r1:r0
	mul r20, r21
	movw r21:r20, r1:r0

	; Modify the renderbuffer
	add YL, r17
	adc YH, r_zero
	ld r14, Y+
	cpi r17, (SCANLINE_BUFFER_TILES - 1)
	brge sprite_wrap_A
		nop
		rjmp sprite_wrap_A_done
	sprite_wrap_A:
		sbiw Y, SCANLINE_BUFFER_TILES
	sprite_wrap_A_done:
	ld r15, Y+
	or r14, r18
	or r15, r19
	com r20
	com r21
	and r14, r20
	and r15, r21
	st -Y, r15
	cpi r17, (SCANLINE_BUFFER_TILES - 1)
	brge sprite_wrap_B
		nop
		rjmp sprite_wrap_B_done
	sprite_wrap_B:
		adiw Y, SCANLINE_BUFFER_TILES
	sprite_wrap_B_done:
	st -Y, r14
	sub YL, r17
	sbc YH, r_zero
	sprite_render_done:
*/