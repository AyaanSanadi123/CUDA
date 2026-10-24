// types.h
#ifndef TYPES_H
#define TYPES_H

struct ThreadArgs {
    const float* a;
    const float* b;
    float* c;
    
    // The specific chunk of the array this thread is responsible for
    int start_idx;
    int end_idx;
};

#endif // TYPES_H