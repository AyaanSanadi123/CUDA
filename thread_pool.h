#ifndef THREAD_POOL_H
#define THREAD_POOL_H
#include <pthread.h>

typedef struct task{
    void(function*)(void*);
    void* arg;
    task_t next;

}  task_t;


#endif