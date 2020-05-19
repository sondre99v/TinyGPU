import sys
from PIL import Image

filename = sys.argv[1]

image = Image.open(filename)
pixels = image.load()

print("Converting %sx%s image..."%(image.width, image.height))

tiles_x = image.width // 8
tiles_y = image.height // 12

outfile = open(filename + ".asm", "w")
outfile.write('.db ')

for ty in range(tiles_y):
    for tx in range(tiles_x):
        for row in range(12):
            b = ''.join([str(pixels[8*tx+i, 12*ty+row]) for i in range(8)])
            outfile.write('0x' + "{:02X}".format(int(b, 2)) + ', ')
        outfile.write('\n    ')

outfile.close()