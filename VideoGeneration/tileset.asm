/*
 * tileset.asm
 *
 *  Created: 10-05-2020 23:05:59
 *   Author: Sondre
 */ 

.cseg
.org (PROGMEM_START + PROGMEM_SIZE - TILE_HEIGHT * 128) >> 1
tileset_data:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, \
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, \
    0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, \
    0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, \
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
    0x24, 0x49, 0x92, 0x24, 0x49, 0x92, 0x24, 0x49, 0x92, 0x24, 0x49, 0x92, \
    0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, \
    0xB6, 0xDB, 0x6D, 0xB6, 0xDB, 0x6D, 0xB6, 0xDB, 0x6D, 0xB6, 0xDB, 0x6D, \
    0x00, 0x00, 0x80, 0xC2, 0x66, 0x3C, 0xFE, 0xFE, 0x9E, 0x6E, 0x90, 0x60, \
    0x00, 0x00, 0xFF, 0x01, 0x01, 0x01, 0xFF, 0xCF, 0xFF, 0xFF, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x01, 0x02, 0x04, 0x7F, 0x7F, 0x79, 0x76, 0x09, 0x06, \
    0x00, 0x18, 0x3C, 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x00, \
    0x00, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x3C, 0x18, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x18, 0x30, 0x7F, 0x30, 0x18, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x0C, 0x06, 0x7F, 0x06, 0x0C, 0x00, 0x00, 0x00, 0x00, \
    0x46, 0x4A, 0x46, 0xFF, 0x55, 0xAA, 0x00, 0x00, 0xFF, 0x4A, 0x46, 0x4A, \
    0x00, 0x00, 0x00, 0xF4, 0x5E, 0xAA, 0x0A, 0x0E, 0xF4, 0x00, 0x00, 0x00, \
    0x46, 0x4A, 0x46, 0x4A, 0x46, 0x4A, 0x3C, 0x66, 0x3C, 0x00, 0x00, 0x00, \
    0x46, 0x4A, 0x46, 0x8A, 0x06, 0xAA, 0x06, 0x0E, 0xFC, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x2F, 0x75, 0x5A, 0x50, 0x70, 0x2F, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0xFF, 0x55, 0xAA, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, \
    0x46, 0x4A, 0x46, 0x4B, 0x45, 0x42, 0x40, 0x60, 0x3F, 0x00, 0x00, 0x00, \
    0x46, 0x4A, 0x46, 0x8B, 0x05, 0xA2, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x3C, 0x66, 0x3C, 0x46, 0x4A, 0x46, 0x4A, 0x46, 0x4A, \
    0x00, 0x00, 0x00, 0xFC, 0x56, 0xAA, 0x06, 0x0A, 0xC6, 0x4A, 0x46, 0x4A, \
    0x46, 0x4A, 0x46, 0x4A, 0x46, 0x4A, 0x46, 0x4A, 0x46, 0x4A, 0x46, 0x4A, \
    0x46, 0x4A, 0x46, 0x8A, 0x06, 0xAA, 0x06, 0x0A, 0xC6, 0x4A, 0x46, 0x4A, \
    0x00, 0x00, 0x00, 0x3F, 0x55, 0x6A, 0x40, 0x48, 0x41, 0x4A, 0x46, 0x4A, \
    0x00, 0x00, 0x00, 0xFF, 0x55, 0xAA, 0x00, 0x08, 0xC1, 0x4A, 0x46, 0x4A, \
    0x46, 0x4A, 0x46, 0x4B, 0x45, 0x42, 0x40, 0x48, 0x41, 0x4A, 0x46, 0x4A, \
    0x46, 0x4A, 0x46, 0x8B, 0x05, 0xA2, 0x00, 0x08, 0xC1, 0x4A, 0x46, 0x4A, \
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x0C, 0x1E, 0x1E, 0x1E, 0x0C, 0x0C, 0x00, 0x0C, 0x0C, 0x00, 0x00, \
    0x00, 0x66, 0x66, 0x66, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x36, 0x36, 0x7F, 0x36, 0x36, 0x36, 0x7F, 0x36, 0x36, 0x00, 0x00, \
    0x0C, 0x0C, 0x3E, 0x03, 0x03, 0x1E, 0x30, 0x30, 0x1F, 0x0C, 0x0C, 0x00, \
    0x00, 0x00, 0x00, 0x23, 0x33, 0x18, 0x0C, 0x06, 0x33, 0x31, 0x00, 0x00, \
    0x00, 0x0E, 0x1B, 0x1B, 0x0E, 0x5F, 0x7B, 0x33, 0x3B, 0x6E, 0x00, 0x00, \
    0x00, 0x0C, 0x0C, 0x0C, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x30, 0x18, 0x0C, 0x06, 0x06, 0x06, 0x0C, 0x18, 0x30, 0x00, 0x00, \
    0x00, 0x06, 0x0C, 0x18, 0x30, 0x30, 0x30, 0x18, 0x0C, 0x06, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x66, 0x3C, 0xFF, 0x3C, 0x66, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x18, 0x18, 0x7E, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1C, 0x1C, 0x06, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x00, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1C, 0x1C, 0x00, 0x00, \
    0x00, 0x00, 0x40, 0x60, 0x30, 0x18, 0x0C, 0x06, 0x03, 0x01, 0x00, 0x00, \
    0x00, 0x3E, 0x63, 0x73, 0x7B, 0x6B, 0x6F, 0x67, 0x63, 0x3E, 0x00, 0x00, \
    0x00, 0x08, 0x0C, 0x0F, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x3F, 0x00, 0x00, \
    0x00, 0x1E, 0x33, 0x33, 0x30, 0x18, 0x0C, 0x06, 0x33, 0x3F, 0x00, 0x00, \
    0x00, 0x1E, 0x33, 0x30, 0x30, 0x1C, 0x30, 0x30, 0x33, 0x1E, 0x00, 0x00, \
    0x00, 0x30, 0x38, 0x3C, 0x36, 0x33, 0x7F, 0x30, 0x30, 0x78, 0x00, 0x00, \
    0x00, 0x3F, 0x03, 0x03, 0x03, 0x1F, 0x30, 0x30, 0x33, 0x1E, 0x00, 0x00, \
    0x00, 0x1C, 0x06, 0x03, 0x03, 0x1F, 0x33, 0x33, 0x33, 0x1E, 0x00, 0x00, \
    0x00, 0x7F, 0x63, 0x63, 0x60, 0x30, 0x18, 0x0C, 0x0C, 0x0C, 0x00, 0x00, \
    0x00, 0x1E, 0x33, 0x33, 0x37, 0x1E, 0x3B, 0x33, 0x33, 0x1E, 0x00, 0x00, \
    0x00, 0x1E, 0x33, 0x33, 0x33, 0x3E, 0x18, 0x18, 0x0C, 0x0E, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x1C, 0x1C, 0x00, 0x00, 0x1C, 0x1C, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x1C, 0x1C, 0x00, 0x00, 0x1C, 0x1C, 0x18, 0x0C, 0x00, \
    0x00, 0x30, 0x18, 0x0C, 0x06, 0x03, 0x06, 0x0C, 0x18, 0x30, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x7E, 0x00, 0x7E, 0x00, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x30, 0x18, 0x0C, 0x06, 0x00, 0x00, \
    0x00, 0x1E, 0x33, 0x30, 0x18, 0x0C, 0x0C, 0x00, 0x0C, 0x0C, 0x00, 0x00, \
    0x00, 0x3E, 0x63, 0x63, 0x7B, 0x7B, 0x7B, 0x03, 0x03, 0x3E, 0x00, 0x00, \
    0x00, 0x0C, 0x1E, 0x33, 0x33, 0x33, 0x3F, 0x33, 0x33, 0x33, 0x00, 0x00, \
    0x00, 0x3F, 0x66, 0x66, 0x66, 0x3E, 0x66, 0x66, 0x66, 0x3F, 0x00, 0x00, \
    0x00, 0x3C, 0x66, 0x63, 0x03, 0x03, 0x03, 0x63, 0x66, 0x3C, 0x00, 0x00, \
    0x00, 0x1F, 0x36, 0x66, 0x66, 0x66, 0x66, 0x66, 0x36, 0x1F, 0x00, 0x00, \
    0x00, 0x7F, 0x46, 0x06, 0x26, 0x3E, 0x26, 0x06, 0x46, 0x7F, 0x00, 0x00, \
    0x00, 0x7F, 0x66, 0x46, 0x26, 0x3E, 0x26, 0x06, 0x06, 0x0F, 0x00, 0x00, \
    0x00, 0x3C, 0x66, 0x63, 0x03, 0x03, 0x73, 0x63, 0x66, 0x7C, 0x00, 0x00, \
    0x00, 0x33, 0x33, 0x33, 0x33, 0x3F, 0x33, 0x33, 0x33, 0x33, 0x00, 0x00, \
    0x00, 0x1E, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x1E, 0x00, 0x00, \
    0x00, 0x78, 0x30, 0x30, 0x30, 0x30, 0x33, 0x33, 0x33, 0x1E, 0x00, 0x00, \
    0x00, 0x67, 0x66, 0x36, 0x36, 0x1E, 0x36, 0x36, 0x66, 0x67, 0x00, 0x00, \
    0x00, 0x0F, 0x06, 0x06, 0x06, 0x06, 0x46, 0x66, 0x66, 0x7F, 0x00, 0x00, \
    0x00, 0x63, 0x77, 0x7F, 0x7F, 0x6B, 0x63, 0x63, 0x63, 0x63, 0x00, 0x00, \
    0x00, 0x63, 0x63, 0x67, 0x6F, 0x7F, 0x7B, 0x73, 0x63, 0x63, 0x00, 0x00, \
    0x00, 0x1C, 0x36, 0x63, 0x63, 0x63, 0x63, 0x63, 0x36, 0x1C, 0x00, 0x00, \
    0x00, 0x3F, 0x66, 0x66, 0x66, 0x3E, 0x06, 0x06, 0x06, 0x0F, 0x00, 0x00, \
    0x00, 0x1C, 0x36, 0x63, 0x63, 0x63, 0x73, 0x7B, 0x3E, 0x30, 0x78, 0x00, \
    0x00, 0x3F, 0x66, 0x66, 0x66, 0x3E, 0x36, 0x66, 0x66, 0x67, 0x00, 0x00, \
    0x00, 0x1E, 0x33, 0x33, 0x03, 0x0E, 0x18, 0x33, 0x33, 0x1E, 0x00, 0x00, \
    0x00, 0x3F, 0x2D, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x1E, 0x00, 0x00, \
    0x00, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x1E, 0x00, 0x00, \
    0x00, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x1E, 0x0C, 0x00, 0x00, \
    0x00, 0x63, 0x63, 0x63, 0x63, 0x6B, 0x6B, 0x36, 0x36, 0x36, 0x00, 0x00, \
    0x00, 0x33, 0x33, 0x33, 0x1E, 0x0C, 0x1E, 0x33, 0x33, 0x33, 0x00, 0x00, \
    0x00, 0x33, 0x33, 0x33, 0x33, 0x1E, 0x0C, 0x0C, 0x0C, 0x1E, 0x00, 0x00, \
    0x00, 0x7F, 0x73, 0x19, 0x18, 0x0C, 0x06, 0x46, 0x63, 0x7F, 0x00, 0x00, \
    0x00, 0x3C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x3C, 0x00, 0x00, \
    0x00, 0x00, 0x01, 0x03, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x40, 0x00, 0x00, \
    0x00, 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x00, \
    0x08, 0x1C, 0x36, 0x63, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, \
    0x0C, 0x0C, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x1E, 0x30, 0x3E, 0x33, 0x33, 0x6E, 0x00, 0x00, \
    0x00, 0x07, 0x06, 0x06, 0x3E, 0x66, 0x66, 0x66, 0x66, 0x3B, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x1E, 0x33, 0x03, 0x03, 0x33, 0x1E, 0x00, 0x00, \
    0x00, 0x38, 0x30, 0x30, 0x3E, 0x33, 0x33, 0x33, 0x33, 0x6E, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x1E, 0x33, 0x3F, 0x03, 0x33, 0x1E, 0x00, 0x00, \
    0x00, 0x1C, 0x36, 0x06, 0x06, 0x1F, 0x06, 0x06, 0x06, 0x0F, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x6E, 0x33, 0x33, 0x33, 0x3E, 0x30, 0x33, 0x1E, \
    0x00, 0x07, 0x06, 0x06, 0x36, 0x6E, 0x66, 0x66, 0x66, 0x67, 0x00, 0x00, \
    0x00, 0x18, 0x18, 0x00, 0x1E, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00, 0x00, \
    0x00, 0x30, 0x30, 0x00, 0x3C, 0x30, 0x30, 0x30, 0x30, 0x33, 0x33, 0x1E, \
    0x00, 0x07, 0x06, 0x06, 0x66, 0x36, 0x1E, 0x36, 0x66, 0x67, 0x00, 0x00, \
    0x00, 0x1E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x3F, 0x6B, 0x6B, 0x6B, 0x6B, 0x63, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x1F, 0x33, 0x33, 0x33, 0x33, 0x33, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x1E, 0x33, 0x33, 0x33, 0x33, 0x1E, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x3B, 0x66, 0x66, 0x66, 0x66, 0x3E, 0x06, 0x0F, \
    0x00, 0x00, 0x00, 0x00, 0x6E, 0x33, 0x33, 0x33, 0x33, 0x3E, 0x30, 0x78, \
    0x00, 0x00, 0x00, 0x00, 0x37, 0x76, 0x6E, 0x06, 0x06, 0x0F, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x1E, 0x33, 0x06, 0x18, 0x33, 0x1E, 0x00, 0x00, \
    0x00, 0x00, 0x04, 0x06, 0x3F, 0x06, 0x06, 0x06, 0x36, 0x1C, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x33, 0x33, 0x33, 0x33, 0x33, 0x6E, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x33, 0x33, 0x33, 0x33, 0x1E, 0x0C, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x63, 0x63, 0x6B, 0x6B, 0x36, 0x36, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x63, 0x36, 0x1C, 0x1C, 0x36, 0x63, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x30, 0x18, 0x0F, \
    0x00, 0x00, 0x00, 0x00, 0x3F, 0x31, 0x18, 0x06, 0x23, 0x3F, 0x00, 0x00, \
    0x00, 0x38, 0x0C, 0x0C, 0x06, 0x03, 0x06, 0x0C, 0x0C, 0x38, 0x00, 0x00, \
    0x00, 0x18, 0x18, 0x18, 0x18, 0x00, 0x18, 0x18, 0x18, 0x18, 0x00, 0x00, \
    0x00, 0x07, 0x0C, 0x0C, 0x18, 0x30, 0x18, 0x0C, 0x0C, 0x07, 0x00, 0x00, \
    0x00, 0xCE, 0x5B, 0x73, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x08, 0x1C, 0x36, 0x63, 0x63, 0x7F, 0x00, 0x00, 0x00