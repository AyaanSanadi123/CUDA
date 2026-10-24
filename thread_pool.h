// thread_pool.h
#ifndef THREAD_POOL_H
#define THREAD_POOL_H

#include "types.h"

#ifdef __cplusplus
extern "C" {
#endif

// Spawns pthreads, divides the array N into chunks, and executes worker_func
void launch_thread_pool(const float* a, const float* b, float* c, 
                        int N, int num_threads, 
                        void* (*worker_func)(void*));

#ifdef __cplusplus
}
#endif

#endif // THREAD_POOL_H