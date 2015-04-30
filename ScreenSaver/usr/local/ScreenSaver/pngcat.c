#include "lodepng.h"
#include <stdio.h>
#include <stdlib.h>

#define FB_MAX 6684672

int main(int argc, char *argv[])
{
    char * product = getenv("PRODUCT");
    int xres, yres, size;
    int x, y, xmax, ymax;
    const char* filename = argv[1];
    unsigned char* image;
    unsigned char fb[FB_MAX];
    for(x=FB_MAX; x--; ) fb[x] = ~0; // white
    unsigned width, height;

    // setup
    if(argc != 2 || !product)
    {
        printf("usage: PRODUCT=dahlia %s file.png | pickel showpic\n", argv[0]);
        return 1;
    }

    if(!strcmp(product, "dahlia") || !strcmp(product, "dragon"))
    {
        xres=1080;
        yres=1440;
        size=6684672;
    }

    else if(!strcmp(product, "kraken") || !strcmp(product, "phoenix"))
    {
        xres=768;
        yres=1024;
        size=3145728;
    }

    else if(!strcmp(product, "trilogy") || !strcmp(product, "pixie") || !strcmp(product, "pica"))
    {
        xres=600;
        yres=800;
        size=2179072;
    }

    else
    {
        printf("unknown PRODUCT value");
        return 1;
    }

    // read file
    lodepng_decode24_file(&image, &width, &height, filename);

    // convert to raw
    xmax = width;
    ymax = height;

    if(xmax > xres)
    {
        xmax = xres;
    }

    if(ymax > yres)
    {
        ymax = yres;
    }

    for(x=ymax; x--; ) // x=y due to rotation
    {
        for(y=xmax; y--;) // y=x due to rotation
        {
            // I hate RGB565
            fb[2*((xres-1-y)*yres+x)+1] = (image[3*(x*width+y)+0]>>3)<<3 | (image[3*(x*width+y)+1]>>5);
            fb[2*((xres-1-y)*yres+x)+0] = (image[3*(x*width+y)+1]>>2)<<5 | (image[3*(x*width+y)+2]>>3);
            // mathematically challenged >_<
        }
    }

    free(image);

    write(1, fb, size);

    return 0;
}
