/*
 * SpiTestTx.c
 *
 * Created: 18-05-2020 15:28:05
 * Author : Sondre
 */ 

#include <avr/io.h>

#define F_CPU 20000000ULL
#include <util/delay.h>

#define TILEDATA_OFFSET 0
#define SCROLLX_OFFSET (TILEDATA_OFFSET+27*14+26+26+25)
#define SCROLLY_OFFSET (SCROLLX_OFFSET+1)
#define SPRITE0_OFFSET (SCROLLY_OFFSET+4)

int main(void)
{
	CCP = CCP_IOREG_gc;
	CLKCTRL.MCLKCTRLB = !CLKCTRL_PEN_bm;
	
	PORTMUX.CTRLB = PORTMUX_SPI0_ALTERNATE_gc;
	PORTC.DIRSET = PIN0_bm | PIN2_bm | PIN3_bm; // Set MOSI, SCK, and ~SS as outputs
	PORTC.OUTSET = PIN3_bm;
	
	PORTB.DIRCLR = PIN3_bm; // Read HSYNC on PB3
	
	SPI0.CTRLB = SPI_BUFWR_bm | SPI_SSD_bm | SPI_MODE_0_gc;
	
	SPI0.CTRLA = SPI_MASTER_bm | SPI_PRESC_DIV16_gc | SPI_ENABLE_bm;
	
	uint8_t i = 0;
	uint8_t wave = 45;
	
    while (1) 
    {
	    while (!(PORTB.IN & PIN3_bm)) { } // Wait for end of HSYNC PULSE
		
	    PORTC.OUTCLR = (1 << 3);
		SPI0.DATA = (SPRITE0_OFFSET + 2) & 0xFF;
		_delay_us(7);
		SPI0.DATA = 0x01;
		_delay_us(7);
		SPI0.DATA = i;
		_delay_us(7);
		PORTC.OUTSET = (1 << 3);
		_delay_us(80);
		
		i++;
		(i == 208) ? (i = 0) : i;
		wave = 45 + 25*sin(6.28 * i / 104);
		
		while (PORTB.IN & PIN3_bm) { } // Wait for next HSYNC PULSE
		PORTC.OUTCLR = (1 << 3);
		SPI0.DATA = (SPRITE0_OFFSET + 3) & 0xFF;
		_delay_us(7);
		SPI0.DATA = 0x01;
		_delay_us(7);
		SPI0.DATA = wave;
		_delay_us(7);
		PORTC.OUTSET = (1 << 3);
		_delay_ms(10);
		
    }
}

