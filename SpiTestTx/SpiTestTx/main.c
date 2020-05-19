/*
 * SpiTestTx.c
 *
 * Created: 18-05-2020 15:28:05
 * Author : Sondre
 */ 

#include <avr/io.h>

#define F_CPU (20000000ULL / 6)
#include <util/delay.h>


int main(void)
{
	PORTMUX.CTRLB = PORTMUX_SPI0_ALTERNATE_gc;
	PORTC.DIRSET = (1 << 0) | (1 << 2) | (1 << 3); // Set MOSI, SCK, and ~SS as outputs
	PORTC.OUTSET = (1 << 3);
	
	SPI0.CTRLB = SPI_BUFWR_bm | SPI_SSD_bm | SPI_MODE_0_gc;
	
	SPI0.CTRLA = SPI_MASTER_bm | SPI_PRESC_DIV16_gc | SPI_ENABLE_bm;
	
    while (1) 
    {
	    PORTC.OUTCLR = (1 << 3);
		SPI0.DATA = 0xCA;
		_delay_us(50);
		SPI0.DATA = 0xFE;
		_delay_us(50);
		SPI0.DATA = 0xBA;
		_delay_us(50);
		PORTC.OUTSET = (1 << 3);
		_delay_ms(100);
    }
}

