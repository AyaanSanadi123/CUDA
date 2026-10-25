#include "cpu_worker.h"
#include "types.h"

void cpu_worker_scalar(void* arg) {
    struct ThreadArgs* args = (struct ThreadArgs*)arg;
    
    // Use size_t here so it doesn't overflow!
    for (size_t i = args->start_idx; i < args->end_idx; i++) {
        args->c[i] = args->a[i] + args->b[i];
    }
}