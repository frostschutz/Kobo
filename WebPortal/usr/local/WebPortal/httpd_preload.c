/*
 * gcc -Wall -O2 -s \
 *     -fPIC -shared -ldl \
 *     httpd_preload.c -o httpd_preload.so
 *
 */

#define _GNU_SOURCE

#include <sys/types.h>
#include <sys/socket.h>
#include <dlfcn.h>
#include <unistd.h>
#include <stdlib.h>

int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen)
{
    int n;
    int (*c_accept)(int, struct sockaddr*, socklen_t*);
    c_accept=dlsym(RTLD_NEXT, "accept");
    char * path = getcwd(NULL, 0);

    // change cwd to rootfs to unblock /mnt/onboard
    if(chdir("/usr/local/WebPortal") != 0)
    {
        exit(1);
    }

    // wait for connection
    n = c_accept(sockfd, addr, addrlen);

    // change back to /mnt/onboard to serve this request
    while(chdir(path) != 0)
    {
        if(chdir("/mnt/onboard/.kobo") == 0)
        {
            // fatal: webportal path went awol
            exit(1);
        }

        sleep(2);
    }

    free(path);
    return n;
}
