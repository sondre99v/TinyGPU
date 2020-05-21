/*
 * SpiTestTx.c
 *
 * Created: 18-05-2020 15:28:05
 * Author : Sondre
 */ 

#include <avr/io.h>
#include <avr/interrupt.h>

#define F_CPU 20000000ULL
#include <util/delay.h>

#define TILEDATA_OFFSET 0

int main(void)
{
	CCP = CCP_IOREG_gc;
	CLKCTRL.MCLKCTRLB = !CLKCTRL_PEN_bm;
	
	PORTMUX.CTRLB = PORTMUX_SPI0_ALTERNATE_gc;
	PORTC.DIRSET = PIN0_bm | PIN2_bm | PIN3_bm; // Set MOSI, SCK, and ~SS as outputs
	PORTC.OUTSET = PIN3_bm;
	
	PORTB.DIRCLR = PIN3_bm; // Read HSYNC on PB3
	PORTB.PIN3CTRL = PORT_ISC_RISING_gc;
	
	SPI0.CTRLB = SPI_BUFWR_bm | SPI_SSD_bm | SPI_MODE_0_gc;
	
	SPI0.CTRLA = SPI_MASTER_bm | SPI_PRESC_DIV16_gc | SPI_ENABLE_bm;
	
	sei();
	
    while (1) 
    {
    }
}

uint8_t i = 0;
ISR(PORTB_PORT_vect)
{
	
	PORTC.OUTCLR = (1 << 3);
	SPI0.DATA = i;
	_delay_us(7);
	SPI0.DATA = 0;
	_delay_us(7);
	SPI0.DATA = i;
	_delay_us(7);
	PORTC.OUTSET = (1 << 3);
	
	i++;
	
	PORTB.INTFLAGS = PIN3_bm;
}