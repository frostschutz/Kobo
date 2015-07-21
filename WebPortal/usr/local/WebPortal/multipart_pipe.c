/*
 *
 *  Handling a multipart/form-data stream in shell was unbelievably sloooooow.
 *  And I couldn't think of a way to make it faster without using a C utility.
 *  Powered by: https://github.com/iafonov/multipart-parser-c
 *
 *  This program receives the multipart/form-data stream [from busybox-httpd],
 *  and prints out headers which can be easily parsed in shell.
 *  The binary data itself goes into a named pipe / fifo.
 *
 */

#include "multipart_parser.h"
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#define BLOCKSIZE 65536

int fifo;
char fifoname[1000];
char template[1000];

// These are not the standard callbacks, but buffered variants, see below.

void header_field(size_t len, const char* buf)
{
    if(fifo)
    {
        close(fifo);
        fifo = 0;
        unlink(fifoname);
    }

    if(len)
    {
        printf("FIELD %.*s\n", len, buf);
    }
}

void header_value(size_t len, const char* buf)
{
    if(len)
    {
        printf("VALUE %.*s\n", len, buf);
    }
}

void part_data(size_t len, const char* buf)
{
    ssize_t n;

    if(!fifo)
    {
        strcpy(fifoname, template);
        mktemp(fifoname);
        mkfifo(fifoname, 0666);
    }

    printf("DATA %s\n", fifoname);

    if(!fifo)
    {
        fifo = open(fifoname, O_WRONLY);
    }

    n = write(fifo, buf, len);

    if(n < len)
    {
        fprintf(stderr, "Warning: short write (%d of %d bytes)\n", n, len);
    }
}

// The multipart-parser has a few oddities. It calls data with 1 or even 0 bytes.
// It might call us with half a header field, if it happened on a block boundary.
// Fixing the parser didn't seem straightforward, so hack around it here for now.

int limbo_s=0;
size_t limbo_len=0;
char limbo[BLOCKSIZE];

void limbo_pop()
{
    switch(limbo_s)
    {
        case 1:
            header_field(limbo_len, limbo);
            break;
        case 2:
            header_value(limbo_len, limbo);
            break;
        case 3:
            part_data(limbo_len, limbo);
            break;
    }

    limbo_len = 0;
}

void limbo_push(int s, const char *at, size_t length)
{
    if(limbo_len > 0 &&
       (s != limbo_s || limbo_len+length>BLOCKSIZE))
    {
        limbo_pop();
    }

    memcpy(limbo+limbo_len, at, length);
    limbo_len+=length;
    limbo_s = s;
}

int limbo_field(multipart_parser* p, const char *at, size_t length)
{
    limbo_push(1, at, length);
    return 0;
}

int limbo_value(multipart_parser* p, const char *at, size_t length)
{
    limbo_push(2, at, length);
    return 0;
}

int limbo_data(multipart_parser* p, const char *at, size_t length)
{
    limbo_push(3, at, length);
    return 0;
}

int limbo_body_end(multipart_parser* p)
{
    limbo_pop();
    return 0;
}

int main(int argc, char *argv[])
{
    if(argc != 3)
    {
        fprintf(stderr, "Usage: %s --<boundary> <fifo>XXXXXX\n", argv[0]);
        exit(1);
    }

    strcpy(template, argv[2]);

    // line buffering so shell can parse us properly
    setvbuf(stdout, NULL, _IOLBF, 0);
    // ignore sigpipe errors to handle incomplete reads
    signal(SIGPIPE, SIG_IGN);

    multipart_parser_settings callbacks = {
        // the parser gives us small and cut-up data, buffer it in limbo
        .on_header_field=limbo_field,
        .on_header_value=limbo_value,
        .on_part_data=limbo_data,
        .on_body_end=limbo_body_end
    };

    multipart_parser *parser = multipart_parser_init(argv[1], &callbacks);

    char buf[BLOCKSIZE];
    size_t len;

    while( (len=read(0, buf, BLOCKSIZE)) > 0 )
    {
        multipart_parser_execute(parser, buf, len);
    }

    if(fifo)
    {
        close(fifo);
        fifo = 0;
        unlink(fifoname);
    }

    return 0;
}

/* --- End of file. --- */
