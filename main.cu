#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <cuda_runtime.h>

extern "C" {
    #include "thread_pool.h"
    #include "cpu_worker.h"
    #include "ispc_worker.h"
}

double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

__global__ void vector_add_kernel(const float* a, const float* b, float* c, size_t N) {
    size_t i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < N) {
        c[i] = a[i] + b[i];
    }
}

void vector_add_baseline(const float* a, const float* b, float* c, size_t N) {
    for (size_t i = 0; i < N; i++) {
        c[i] = a[i] + b[i];
    }
}

void verify_results(const float* c, size_t N, float expected, const char* engine_name) {
    for (size_t i = 0; i < N; i++) {
        if (c[i] != expected) {
            printf("[%s] FAILED at index %zu! Expected %f, got %f\n", engine_name, i, expected, c[i]);
            return;
        }
    }
    printf("[%s] Results verified successfully.\n", engine_name);
}

int main() {
    int num_threads = 8; 

    // ==========================================
    // WARM-UP: INITIALIZE PERSISTENT POSIX POOL
    // ==========================================
    // Threads are created exactly ONCE for the entire program
    pool_init(num_threads);
    
    // Array of sizes to benchmark
    size_t test_sizes[] = {50, 5000, 500000, 50000000, 500000000ULL};
    int num_tests = sizeof(test_sizes) / sizeof(test_sizes[0]);

    for (int t = 0; t < num_tests; t++) {
        size_t N = test_sizes[t];
        size_t bytes = N * sizeof(float);

        printf("\n=======================================================\n");
        printf("Benchmarking Vector Addition (N = %zu)\n", N);
        printf("=======================================================\n");

        // --- ALLOCATE HOST MEMORY ---
        float *h_a = (float*)malloc(bytes);
        float *h_b = (float*)malloc(bytes);
        float *h_c = (float*)malloc(bytes);

        for (size_t i = 0; i < N; i++) {
            h_a[i] = 1.0f;
            h_b[i] = 2.0f;
        }

        // Configure task chunks for this specific N
        struct ThreadArgs args[8];
        size_t chunk_size = N / num_threads;
        for (int i = 0; i < num_threads; i++) {
            args[i].a = h_a;
            args[i].b = h_b;
            args[i].c = h_c;
            args[i].start_idx = i * chunk_size;
            
            // Using your requested if-else logic
            if (i == num_threads - 1) {
                args[i].end_idx = N;
            } else {
                args[i].end_idx = (i + 1) * chunk_size;
            }
        }

        // ==========================================
        // BENCHMARK 0: SINGLE CPU CORE (Baseline)
        // ==========================================
        memset(h_c, 0, bytes);
        double start = get_time();
        vector_add_baseline(h_a, h_b, h_c, N);
        double end = get_time();
        
        printf("CPU (Single-Threaded Baseline): %f s\n", (end - start));
        verify_results(h_c, N, 3.0f, "Single CPU");
        double baseline_time = end - start;

        // ==========================================
        // BENCHMARK 1: POSIX THREADS (Scalar)
        // ==========================================
        memset(h_c, 0, bytes);
        start = get_time();
        
        for (int i = 0; i < num_threads; i++) {
            pool_submit(cpu_worker_scalar, (void*)&args[i]);
        }
        pool_wait(); 
        
        end = get_time();
        printf("POSIX Pool (Scalar, %d threads): %f s\n", num_threads, (end - start));
        verify_results(h_c, N, 3.0f, "Scalar C++");
        double scalar_time = end - start;

        // ==========================================
        // BENCHMARK 2: POSIX THREADS + ISPC (SIMD)
        // ==========================================
        memset(h_c, 0, bytes);
        start = get_time();
        
        for (int i = 0; i < num_threads; i++) {
            pool_submit(ispc_worker, (void*)&args[i]);
        }
        pool_wait(); 
        
        end = get_time();
        printf("POSIX Pool + ISPC (SIMD, %d threads): %f s\n", num_threads, (end - start));
        verify_results(h_c, N, 3.0f, "ISPC SIMD");
        double ispc_time = end - start;

        // ==========================================
        // BENCHMARK 3: CUDA GPU (Pure Compute)
        // ==========================================
        float *d_a, *d_b, *d_c;
        cudaMalloc(&d_a, bytes);
        cudaMalloc(&d_b, bytes);
        cudaMalloc(&d_c, bytes);

        cudaMemcpy(d_a, h_a, bytes, cudaMemcpyHostToDevice);
        cudaMemcpy(d_b, h_b, bytes, cudaMemcpyHostToDevice);

        int BLOCK_SIZE = 256;
        size_t num_blocks = (N + BLOCK_SIZE - 1) / BLOCK_SIZE;

        // WARMUP KERNEL
        vector_add_kernel<<<num_blocks, BLOCK_SIZE>>>(d_a, d_b, d_c, N);
        cudaDeviceSynchronize();

        memset(h_c, 0, bytes);
        start = get_time();
        vector_add_kernel<<<num_blocks, BLOCK_SIZE>>>(d_a, d_b, d_c, N);
        cudaDeviceSynchronize(); 
        end = get_time();
        
        printf("CUDA GPU (Compute Only): %f s\n", (end - start));
        cudaMemcpy(h_c, d_c, bytes, cudaMemcpyDeviceToHost);
        verify_results(h_c, N, 3.0f, "CUDA GPU");
        double gpu_time = end - start;

        // ==========================================
        // SPEEDUP ANALYSIS
        // ==========================================
        printf("\n--- Performance Speedup ---\n");
        printf("8-Thread Scalar is %.2fx faster than Single Core\n", baseline_time / scalar_time);
        printf("8-Thread ISPC SIMD is %.2fx faster than Single Core\n", baseline_time / ispc_time);
        printf("CUDA GPU is %.2fx faster than Single Core\n", baseline_time / gpu_time);
        printf("8-Thread ISPC SIMD is %.2fx faster than 8-Thread Scalar\n", scalar_time / ispc_time);
        printf("CUDA GPU is %.2fx faster than 8-Thread Scalar\n", scalar_time / gpu_time);
        printf("CUDA GPU is %.2fx faster than 8-Thread ISPC SIMD\n", ispc_time / gpu_time);

        // FREE MEMORY FOR THIS ITERATION SO IT DOESN'T LEAK
        cudaFree(d_a); cudaFree(d_b); cudaFree(d_c);
        free(h_a); free(h_b); free(h_c);
    }

    // ==========================================
    // CLEANUP
    // ==========================================
    pool_shutdown(); // Safely kill the persistent POSIX threads ONCE at the end
    
    return 0;
}