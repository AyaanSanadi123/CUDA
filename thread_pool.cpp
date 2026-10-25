#include "thread_pool.h"
#include <thread>
#include <vector>
#include <stdlib.h>
#include <stdio.h>

void launch_thread_pool(const float* a, const float* b, float* c, 
                        int N, int num_threads, 
                        void (*worker_func)(void*)) 
{
    // The C++ way to handle a dynamic array of OS thread handles
    std::vector<std::thread> threads;
    
    // We still malloc the application payload so each thread gets isolated memory
    struct ThreadArgs* args = (struct ThreadArgs*)malloc(num_threads * sizeof(struct ThreadArgs));

    if (args == NULL) {
        fprintf(stderr, "Failed to allocate memory for args.\n");
        exit(EXIT_FAILURE);
    }

    int chunk_size = N / num_threads;

    // Dispatch threads
    for (int i = 0; i < num_threads; i++) {
        args[i].a = a;
        args[i].b = b;
        args[i].c = c;
        args[i].start_idx = i * chunk_size;
        
        if (i == num_threads - 1) {
            args[i].end_idx = N;
        } else {
            args[i].end_idx = (i + 1) * chunk_size;
        }

        // Spawn the thread. C++ elegantly accepts the function and its argument directly.
        threads.push_back(std::thread(worker_func, (void*)&args[i]));
    }

    // Barrier: Wait for all threads to complete their chunks
    for (int i = 0; i < num_threads; i++) {
        threads[i].join();
    }

    // Clean up
    free(args);
}