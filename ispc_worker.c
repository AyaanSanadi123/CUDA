#include "ispc_worker.h"
#include "types.h"
#include <stddef.h>

// In pure C, we just include the generated ISPC header directly
#include "vector_add_ispc.h"

void ispc_worker(void* arg) {
    struct ThreadArgs* args = (struct ThreadArgs*)arg;

    // 1. Calculate using size_t to prevent overflow
    size_t count = args->end_idx - args->start_idx;
    
    // 2. Remove 'ispc::' namespace (pure C syntax)
    // 3. Cast count to (int) for the ISPC signature
    vector_add_ispc(args->a + args->start_idx, 
                    args->b + args->start_idx, 
                    args->c + args->start_idx, 
                    (int)count);
}