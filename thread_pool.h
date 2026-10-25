// thread_pool.h
#ifndef THREAD_POOL_H
#define THREAD_POOL_H
#include <pthread.h>


typedef struct task {
    void(*function)(void*);
    void* arg;
    task_t* next;

} task_t;

void pool_init(int num_threads); // initialise the pool with n threads 
void pool_submit(void(*function)(void*),void*arg); // push a task into the queue and wakeup a thread 
void pool_wait(); // block the main thread until all the threads are idle and queue is empty -> make shift barrier 
void pool_shutdown(); // destroy the bool 
#endif // THREAD_POOL_H