#include "lodepng.h"
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
    if(argc != 2)
    {
        printf("usage: %s file.png | pickel showpic\n", argv[0]);
        return 1;
    }

    int x, y;
    const char* filename = argv[1];
    unsigned char* image;
    unsigned char fb[1088*3072*2];
    unsigned width, height;

    lodepng_decode24_file(&image, &width, &height, filename);

    if(width == 1080 && height == 1440)
    {
        for(x=1440; x--; )
        {
            for(y=1080; y--;)
            {
                // I hate RGB565
                fb[2*((1079-y)*1440+x)+1] = (image[3*(x*1080+y)+0]>>3)<<3 | (image[3*(x*1080+y)+1]>>5);
                fb[2*((1079-y)*1440+x)+0] = (image[3*(x*1080+y)+1]>>2)<<5 | (image[3*(x*1080+y)+2]>>3);
                // mathematically challenged >_<
            }
        }
    }

    free(image);

    write(1, fb, 1088*3072*2);

    return 0;
}
