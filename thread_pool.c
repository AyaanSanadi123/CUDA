#include <pthread.h>
#include <stdlib.h>
#include <stdio.h>
#include "thread_pool.h"


void launch_thread_pool(const float* a, const float* b, float* c, 
                        int N, int num_threads, 
                        void* (*worker_func)(void*))

{

    pthread_t* threads = (pthread_t*)malloc(num_threads * sizeof(pthread_t)); // this points to the address of each thread 
    struct ThreadArgs* args = (struct ThreadArgs*)malloc(num_threads * sizeof(struct ThreadArgs)); // this points to the address of each task a thread must do
    if (threads == NULL || args == NULL) {
        fprintf(stderr, "Failed to allocate memory for threads.\n");
        exit(EXIT_FAILURE);
    }

    int chunk_size = N / num_threads;

    // Dispatch threads
    for (int i = 0; i < num_threads; i++) {
        args[i].a = a;
        args[i].b = b;
        args[i].c = c;
        args[i].start_idx = i * chunk_size;
        
        // The last thread picks up any uneven remaining elements
        if (i == num_threads - 1) {
            args[i].end_idx = N;
        } else {
            args[i].end_idx = (i + 1) * chunk_size;
        }
        if (pthread_create(&threads[i], NULL, worker_func, (void*)&args[i]) != 0) {
            fprintf(stderr, "Failed to create thread %d\n", i);
            exit(EXIT_FAILURE);
        }
    }
    // barrier, wait for all threads to finish their work 
    for (int i = 0; i < num_threads; i++) {
        if (pthread_join(threads[i], NULL) != 0) {
            fprintf(stderr, "Failed to join thread %d\n", i);
            exit(EXIT_FAILURE);
        }
    }

    // Clean up
    free(threads);
    free(args);
}


                            
                        