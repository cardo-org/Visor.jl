#define _GNU_SOURCE
#define __USE_GNU

#include <julia.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <semaphore.h>

JL_DLLEXPORT extern int jl_load_repl(int, char **);

// See:
// https://github.com/JuliaLang/julia/blob/master/test/embedding/embedding.c

// julia <= 1.6
// JULIA_DEFINE_FAST_TLS() // only define this once, in an executable (not in a shared library) if you want fast code.

// julia >= 1.7
JULIA_DEFINE_FAST_TLS

uint8_t signal_num = 0;

sem_t mutex;

static void handle_signal(int signo)
{
    signal_num = signo;
    sem_post(&mutex);
}

int setsignal(int signo)
{
    signal_num = signo;
}

int wait_for_sig()
{
    sem_wait(&mutex);
    return signal_num;
}

int filo_exit()
{
    signal_num = 0;
    sem_post(&mutex);
}

int enable_handler()
{
    if (signal(SIGINT, handle_signal) == SIG_ERR)
    {
        fputs("error setting SIGINT signal handler.\n", stderr);
        return EXIT_FAILURE;
    }
}

int init_signal_handler()
{
    sigset_t set;
    int sig;
    sem_init(&mutex, 0, 1);
    sem_wait(&mutex);

    return enable_handler();
}

int main(int argc, char *argv[])
{
    return jl_load_repl(argc, argv);
}