/*
 * clock_gen.asm
 *
 *  Created: 15-05-2020 17:06:49
 *   Author: Sondre
 */ 
 
.include "tn817def.inc"

start:
	ldi r16, CPU_CCP_IOREG_gc
	out CPU_CCP, r16
	ldi r16, 0
	sts CLKCTRL_MCLKCTRLB, r16

	ldi r16, CPU_CCP_IOREG_gc
	out CPU_CCP, r16
	ldi r16, CLKCTRL_CLKOUT_bm
	sts CLKCTRL_MCLKCTRLA, r16

	loop:
		rjmp loop