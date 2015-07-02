/*
 * gcc -Wall -O2 -s \
 *     -DLODEPNG_NO_COMPILE_ENCODER -DLODEPNG_NO_COMPILE_ERROR_TEXT \
 *     lodepng.c pngshow.c -o pngshow
 *
 */

#include "lodepng.h"
#include "mxcfb.h"
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
    int fb0 = open("/dev/fb0", O_RDWR);
    char *fb0map;
    struct fb_var_screeninfo screen = {0};
    unsigned int screensize, rotate;

    if(fb0 < 0)
    {
        perror("open");
        exit(1);
    }

    if(ioctl(fb0, FBIOGET_VSCREENINFO, &screen) < 0)
    {
        perror("screen info");
        exit(2);
    }

    // 180° rotation hack
    // FIXME: remember result for subsequent calls to avoid race condition
    rotate = screen.rotate;
    screen.rotate ^= 0x2;
    ioctl(fb0, FBIOPUT_VSCREENINFO, &screen);
    if(rotate != screen.rotate)
    {
        screen.rotate = rotate;
        ioctl(fb0, FBIOPUT_VSCREENINFO, &screen);
        screen.rotate ^= 0x2;
    }

    screensize = screen.xres_virtual * screen.yres_virtual * 2;

    fb0map = (char*)mmap(0, screensize, PROT_READ | PROT_WRITE, MAP_SHARED, fb0, 0);

    if((int)fb0map < 0)
    {
        perror("mmap");
        exit(3);
    }

    // START PNG

    const char* filename = argv[1];
    unsigned char* image;
    unsigned int width, height, x, y, xmax, ymax, xres, yres, line;

    if(lodepng_decode24_file(&image, &width, &height, filename) != 0)
    {
        perror("lodepng");
        exit(10);
    }

    if(screen.rotate % 2)
    {
        xres = screen.xres;
        yres = screen.yres;
    }

    else
    {
        xres = screen.yres;
        yres = screen.xres;
    }

    xmax = width;
    ymax = height;
    line = screen.xres_virtual;

    if(xmax > xres)
    {
        xmax = xres;
    }

    if(ymax > yres)
    {
        ymax = yres;
    }

    memset(fb0map, ~0, screensize); // white

    // image[0] is the top left corner, image[0..width*3] the top row

    switch(screen.rotate)
    {
        case 1:
            // fb0map[0] is the top left corner, fb0map[0..xres_virtual*2] the top row
            for(x=xmax; x--;)
            {
                for(y=ymax; y--;)
                {
                    fb0map[2*(y*line+x)+1] = (image[3*(y*width+x)+0]>>3)<<3 | (image[3*(y*width+x)+1]>>5);
                    fb0map[2*(y*line+x)+0] = (image[3*(y*width+x)+1]>>2)<<5 | (image[3*(y*width+x)+2]>>3);
                }
            }

            break;
        case 3:
            // fb0map[0] is the bottom right corner, fb0map[0..xres_virtual*2] the bottom row
            for(x=xmax; x--;)
            {
                for(y=ymax; y--;)
                {
                    fb0map[2*((yres-y-1)*line+(xres-x-1))+1] = (image[3*(y*width+x)+0]>>3)<<3 | (image[3*(y*width+x)+1]>>5);
                    fb0map[2*((yres-y-1)*line+(xres-x-1))+0] = (image[3*(y*width+x)+1]>>2)<<5 | (image[3*(y*width+x)+2]>>3);
                }
            }

            break;
        case 2:
            // fb0map[0] is the top right corner, fb0map[0..xres_virtual*2] the right column
            for(x=xmax; x--;)
            {
                for(y=ymax; y--;)
                {
                    fb0map[2*((xres-x-1)*line+y)+1] = (image[3*(y*width+x)+0]>>3)<<3 | (image[3*(y*width+x)+1]>>5);
                    fb0map[2*((xres-x-1)*line+y)+0] = (image[3*(y*width+x)+1]>>2)<<5 | (image[3*(y*width+x)+2]>>3);
                }
            }
            break;
        case 0:
            // fb0map[0] is the bottom left corner, fb0map[0..xres_virtual*2] the left column
            for(x=xmax; x--;)
            {
                for(y=ymax; y--;)
                {
                    fb0map[2*(x*line+(yres-y-1))+1] = (image[3*(y*width+x)+0]>>3)<<3 | (image[3*(y*width+x)+1]>>5);
                    fb0map[2*(x*line+(yres-y-1))+0] = (image[3*(y*width+x)+1]>>2)<<5 | (image[3*(y*width+x)+2]>>3);
                }
            }
            break;
    }

    // END PNG

    struct mxcfb_update_data update = {
        .temp=TEMP_USE_AMBIENT,
        .update_marker=getpid(),
        .update_mode=UPDATE_MODE_FULL,
        .update_region.height=screen.yres,
        .update_region.width=screen.xres,
        .waveform_mode=WAVEFORM_MODE_AUTO,
    };

    if(ioctl(fb0, MXCFB_SEND_UPDATE, &update) < 0)
    {
        perror("update");
        exit(4);
    }

    if(update.update_marker != 0 && ioctl(fb0, MXCFB_WAIT_FOR_UPDATE_COMPLETE, &update.update_marker) < 0)
    {
        perror("wait for update");
        exit(5);
    }

    exit(0);
}
