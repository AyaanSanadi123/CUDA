# ==========================================
# Linux/WSL Makefile for POSIX Threads + CUDA + ISPC
# ==========================================

# Compilers
NVCC = nvcc
ISPC = ispc
CC = gcc

# Compilation Flags
# -arch=sm_89 optimizes PTX assembly for Ada Lovelace (RTX 40-series)
NVCC_FLAGS = -O3 -arch=sm_89
ISPC_FLAGS = -O3 --target=avx2-i32x8 --arch=x86-64
# Added -pthread for strict POSIX compliance in the C compiler
CFLAGS = -O3 -Wall -pthread 

# Targets
TARGET = benchmark
OBJS = vector_add_ispc.o thread_pool.o cpu_worker.o ispc_worker.o main.o

# Default rule to build the executable
all: $(TARGET)

# 1. Link everything together using nvcc
# -lpthread is explicitly required here so the CUDA linker binds the POSIX thread library
$(TARGET): $(OBJS)
	$(NVCC) $(NVCC_FLAGS) $(OBJS) -o $(TARGET) -lpthread

# 2. Compile the ISPC kernel and generate the C header
vector_add_ispc.o vector_add_ispc.h: vector_add.ispc
	$(ISPC) $(ISPC_FLAGS) vector_add.ispc -o vector_add_ispc.o -h vector_add_ispc.h

# 3. Compile the C POSIX thread pool
thread_pool.o: thread_pool.c thread_pool.h
	$(CC) $(CFLAGS) -c thread_pool.c -o thread_pool.o

# 4. Compile the CPU scalar worker
cpu_worker.o: cpu_worker.c cpu_worker.h types.h
	$(CC) $(CFLAGS) -c cpu_worker.c -o cpu_worker.o

# 5. Compile the ISPC wrapper (Switched to pure C gcc)
ispc_worker.o: ispc_worker.c ispc_worker.h types.h vector_add_ispc.h
	$(CC) $(CFLAGS) -c ispc_worker.c -o ispc_worker.o

# 6. Compile the main CUDA driver
main.o: main.cu types.h
	$(NVCC) $(NVCC_FLAGS) -c main.cu -o main.o

# Clean rule for Linux Bash
clean:
	rm -f *.o $(TARGET) vector_add_ispc.h