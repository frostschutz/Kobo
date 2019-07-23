#include <poll.h>
#include <linux/input.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

int main(int argc, char *argv[]) {
    struct pollfd *fds = malloc((argc-1)*sizeof(struct pollfd));
    struct input_event *events = malloc(32*sizeof(struct input_event));
    int h, i;
    for(i=1,h=0; i < argc; i++,h++) {
        fds[h].fd = open(argv[i], O_RDONLY);
        fds[h].events = POLLIN;
    }
    int ret = poll(fds, h, -1);
    if(ret<=0) {
        exit(1);
    }
    for(i=1,h=0; i < argc; i++,h++) {
        if(fds[h].revents & POLLIN) {
            usleep(50000);
            h = read(fds[h].fd, events, 32*sizeof(struct input_event)) / sizeof(struct input_event);
            for(i=0; i<h; i++) {
                printf("%ld %ld %d %d %d\n", events[i].time.tv_sec, events[i].time.tv_usec, events[i].type, events[i].code, events[i].value);
            }
            exit(0);
        }
    }
    exit(2);
}


