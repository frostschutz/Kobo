/*

 touchgrab helper to grab the touchscreen exclusively

*/


#include <linux/input.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    int touchscreen = open("/dev/input/event1", O_RDONLY | O_NONBLOCK);
    fd_set readfds;
    struct timeval timeout = {5, 0}, t;
    char buffer[4096];

    // grab
    if(ioctl(touchscreen, EVIOCGRAB, 1) == -1) {
        perror("failed touchscreen grab");
        exit(1);
    }

    // unbuffered
    setvbuf(stdout, NULL, _IONBF, 0);
    // nonblocking
    fcntl(STDOUT_FILENO, F_SETFL, fcntl(STDOUT_FILENO, F_GETFL) | O_NONBLOCK);

    // print our pid so we can be killed
    fprintf(stdout, "%d\n", getpid());

    // read touchscreen, write STDOUT_FILENO (or discard if blocked)
    while(1) {
        FD_ZERO(&readfds);
        FD_SET(touchscreen, &readfds);
        t = timeout;

        // wait for touch
        if(select(FD_SETSIZE, &readfds, NULL, NULL, &t) < 0) {
            perror("Failed select");
            exit(1);
        }

        if(FD_ISSET(touchscreen, &readfds)) {
            ssize_t n = read(touchscreen, buffer, 4096);

            if(n > 0) {
                write(STDOUT_FILENO, buffer, n);
            }

            else if(n < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
                // bail out
                break;
            }

            else {
                // otherwise discard
            }
        }
    }

    // release
    if(ioctl(touchscreen, EVIOCGRAB, 0) == -1) {
        perror("Failed EVIOCGRAB release");
        exit(1);
    }
    exit(0);
}

