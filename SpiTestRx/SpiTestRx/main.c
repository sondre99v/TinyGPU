/*
 * SpiTestRx.c
 *
 * Created: 18-05-2020 15:28:35
 * Author : Sondre
 */ 

#include <avr/io.h>

#define F_CPU (20000000ULL / 6)
#include <util/delay.h>

int main(void)
{
	PORTMUX.CTRLB = PORTMUX_SPI0_ALTERNATE_gc;
	PORTC.DIRSET = (1 << 1); // Set MISO as output
	
	SPI0.CTRLB = SPI_BUFEN_bm | SPI_BUFWR_bm | SPI_SSD_bm | SPI_MODE_0_gc;
	
	SPI0.CTRLA = SPI_PRESC_DIV16_gc | SPI_ENABLE_bm;
	
	volatile uint8_t buffer[64] = {0};
	volatile int index = 0;
	
    while (1) 
    {
		if (SPI0.INTFLAGS & SPI_RXCIE_bm) {
			_delay_ms(50);
			buffer[index++] = SPI0.DATA;
			buffer[index++] = SPI0.DATA;
			buffer[index++] = SPI0.DATA;
			asm volatile("nop");
		}
    }
}

