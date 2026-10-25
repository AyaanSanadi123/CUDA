#include "cpu_worker.h"
#include "types.h"
#include <stddef.h>

void cpu_worker_scalar(void* arg) {
    // 1. Cast the generic raw memory address back into a ThreadArgs pointer
    struct ThreadArgs* args = (struct ThreadArgs*)arg;

    // 2. Run the naive, 1-element-per-clock-cycle addition
    for (int i = args->start_idx; i < args->end_idx; i++) {
        args->c[i] = args->a[i] + args->b[i];
    }

    // 3. POSIX requires returning a void* pointer. 
    // We write directly to the array, so we return a null pointer.
   
}