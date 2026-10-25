// cpu_worker.h
#ifndef CPU_WORKER_H
#define CPU_WORKER_H

#ifdef __cplusplus
extern "C" {
#endif

// Matches the exact signature required by pthread_create
void cpu_worker_scalar(void* arg);

#ifdef __cplusplus
}
#endif

#endif // CPU_WORKER_H