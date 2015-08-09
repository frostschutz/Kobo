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
    chdir("/");
    n = c_accept(sockfd, addr, addrlen);
    chdir(path);
    free(path);
    return n;
}
