# ==========================================
# Windows Makefile for ISPC + CUDA + C++ Threads
# ==========================================

# Compilers
NVCC = nvcc
ISPC = ispc

# Compilation Flags
# -arch=sm_89 optimizes PTX assembly for Ada Lovelace (RTX 40-series)
NVCC_FLAGS = -O3 -arch=sm_89
ISPC_FLAGS = -O2 --target=avx2-i32x8 --arch=x86-64

# Targets
TARGET = benchmark.exe
OBJS = vector_add_ispc.obj thread_pool.obj cpu_worker.obj ispc_worker.obj main.obj

# Default rule to build the executable
all: $(TARGET)

# 1. Link everything together using nvcc
$(TARGET): $(OBJS)
	$(NVCC) $(NVCC_FLAGS) $(OBJS) -o $(TARGET)

# 2. Compile the ISPC kernel (MUST happen first to generate the .h file)
vector_add_ispc.obj: vector_add.ispc
	$(ISPC) $(ISPC_FLAGS) vector_add.ispc -o vector_add_ispc.obj -h vector_add_ispc.h

# 3. Compile the C++ thread pool
thread_pool.obj: thread_pool.cpp thread_pool.h types.h
	$(NVCC) $(NVCC_FLAGS) -c thread_pool.cpp -o thread_pool.obj

# 4. Compile the CPU scalar worker
cpu_worker.obj: cpu_worker.cpp cpu_worker.h types.h
	$(NVCC) $(NVCC_FLAGS) -c cpu_worker.cpp -o cpu_worker.obj

# 5. Compile the ISPC wrapper (depends on the generated header)
ispc_worker.obj: ispc_worker.cpp ispc_worker.h types.h vector_add_ispc.obj
	$(NVCC) $(NVCC_FLAGS) -c ispc_worker.cpp -o ispc_worker.obj

# 6. Compile the main CUDA driver
main.obj: main.cu
	$(NVCC) $(NVCC_FLAGS) -c main.cu -o main.obj

# Clean rule for Windows PowerShell
clean:
	del *.obj *.exe vector_add_ispc.h