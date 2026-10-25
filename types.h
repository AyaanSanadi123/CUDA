// types.h
#ifndef TYPES_H
#define TYPES_H
#include <stddef.h> // Required for size_t
struct ThreadArgs {
    const float* a;
    const float* b;
    float* c;
    
    // The specific chunk of the array this thread is responsible for
    size_t start_idx;
    size_t end_idx;
};

#endif // TYPES_H