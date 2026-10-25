#include "ispc_worker.h"
#include "types.h"
#include <stddef.h>

// In pure C, we just include the generated ISPC header directly
#include "vector_add_ispc.h"

void ispc_worker(void* arg) {
    struct ThreadArgs* args = (struct ThreadArgs*)arg;

    int count = args->end_idx - args->start_idx;
    
    // Shift the memory pointers ahead by start_idx 
   ispc :: vector_add_ispc(args->a + args->start_idx, 
                    args->b + args->start_idx, 
                    args->c + args->start_idx, 
                    count);

   
}