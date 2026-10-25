#include <stdio.h>
#include <stdlib.h>
#include <chrono>
#include <cuda_runtime.h>
#include<string.h>

// Include our C headers
extern "C" {
    #include "thread_pool.h"
    #include "cpu_worker.h"
    #include "ispc_worker.h"
}

// ---------------------------------------------------------
// 1. TIMING HELPER
// ---------------------------------------------------------
double get_time() {
    auto now = std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double>(now.time_since_epoch()).count();
}

// ---------------------------------------------------------
// 2. CUDA KERNEL (Now lives directly in main.cu)
// ---------------------------------------------------------
__global__ void vector_add_kernel(const float* a, const float* b, float* c, int N) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < N) {
        c[i] = a[i] + b[i];
    }
}

// ---------------------------------------------------------
// 0. SINGLE-THREADED BASELINE
// ---------------------------------------------------------
void vector_add_baseline(const float* a, const float* b, float* c, int N) {
    for (int i = 0; i < N; i++) {
        c[i] = a[i] + b[i];
    }
}


void verify_results(const float* c, int N, float expected, const char* engine_name) {
    for (int i = 0; i < N; i++) {
        // We use an exact equality check here since 1.0 + 2.0 = 3.0 is exact in IEEE 754 float
        if (c[i] != expected) {
            printf("[%s] FAILED at index %d! Expected %f, got %f\n", engine_name, i, expected, c[i]);
            return;
        }
    }
    printf("[%s] Results verified successfully.\n", engine_name);
}

// ---------------------------------------------------------
// 3. MAIN BENCHMARK DRIVER
// ---------------------------------------------------------
int main() {
    int N = 500000000; // 50 million elements
    size_t bytes = N * sizeof(float);
    int num_threads = 8; // For POSIX threads

    // --- ALLOCATE HOST MEMORY ---
    float *h_a = (float*)malloc(bytes);
    float *h_b = (float*)malloc(bytes);
    float *h_c = (float*)malloc(bytes);

    // Initialize data
    for (int i = 0; i < N; i++) {
        h_a[i] = 1.0f;
        h_b[i] = 2.0f;
    }

    printf("Benchmarking Vector Addition (N = %d)\n", N);
    printf("-------------------------------------------\n");

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
    launch_thread_pool(h_a, h_b, h_c, N, num_threads, cpu_worker_scalar);
     end = get_time();
    printf("Pthreads (Scalar, %d threads): %f s\n", num_threads, (end - start));
    verify_results(h_c, N, 3.0f, "Scalar C++");
    double scalar_time = end - start;

    // ==========================================
    // BENCHMARK 2: POSIX THREADS + ISPC (SIMD)
    // ==========================================
    memset(h_c, 0, bytes);
    start = get_time();
    launch_thread_pool(h_a, h_b, h_c, N, num_threads, ispc_worker);
    end = get_time();
    printf("Pthreads + ISPC (SIMD, %d threads): %f s\n", num_threads, (end - start));
    verify_results(h_c, N, 3.0f, "ISPC SIMD");
    double ispc_time = end - start;
    // ==========================================
    // BENCHMARK 3: CUDA GPU (Pure Compute)
    // ==========================================
    float *d_a, *d_b, *d_c;
    
    // Memory allocation is OUTSIDE the timer
    cudaMalloc(&d_a, bytes);
    cudaMalloc(&d_b, bytes);
    cudaMalloc(&d_c, bytes);

    // Data transfer is OUTSIDE the timer
    cudaMemcpy(d_a, h_a, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, h_b, bytes, cudaMemcpyHostToDevice);

    int BLOCK_SIZE = 256;
    int num_blocks = (N + BLOCK_SIZE - 1) / BLOCK_SIZE;

    // WARMUP: Spin up the GPU context (OUTSIDE the timer)
    vector_add_kernel<<<num_blocks, BLOCK_SIZE>>>(d_a, d_b, d_c, N);
    cudaDeviceSynchronize();

    // The actual timed benchmark: pure kernel execution
    memset(h_c, 0, bytes);
    start = get_time();
    vector_add_kernel<<<num_blocks, BLOCK_SIZE>>>(d_a, d_b, d_c, N);
    cudaDeviceSynchronize(); // Crucial to wait before stopping the clock
    end = get_time();
    
    printf("CUDA GPU (Compute Only): %f s\n", (end - start));
    cudaMemcpy(h_c, d_c, bytes, cudaMemcpyDeviceToHost);
    verify_results(h_c, N, 3.0f, "CUDA GPU");
    double gpu_time = end - start;

    // ==========================================
    // SPEEDUP ANALYSIS
    // ==========================================
    printf("\n--- Performance Speedup ---\n");
    
    // Baseline comparisons
    printf("8-Thread Scalar is %.2fx faster than Single Core\n", baseline_time / scalar_time);
    printf("8-Thread ISPC SIMD is %.2fx faster than Single Core\n", baseline_time / ispc_time);
    printf("CUDA GPU is %.2fx faster than Single Core\n", baseline_time / gpu_time);
    
    // Multi-core vs SIMD vs GPU
    printf("8-Thread ISPC SIMD is %.2fx faster than 8-Thread Scalar\n", scalar_time / ispc_time);
    printf("CUDA GPU is %.2fx faster than 8-Thread Scalar\n", scalar_time / gpu_time);
    printf("CUDA GPU is %.2fx faster than 8-Thread ISPC SIMD\n", ispc_time / gpu_time);


    // Cleanup OUTSIDE the timer
    cudaMemcpy(h_c, d_c, bytes, cudaMemcpyDeviceToHost);
    cudaFree(d_a); cudaFree(d_b); cudaFree(d_c);
    free(h_a); free(h_b); free(h_c);

    return 0;
}