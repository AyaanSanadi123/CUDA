#include "thread_pool.h"
#include <stdlib.h>
#include <stdio.h>

typedef struct {
    pthread_mutex_t lock;
    pthread_cond_t notify; // this wakes up a thread when a task is pushed into the queue 
    pthread_cond_t all_done;
    pthread_t* threads; // array that holds pointers to all the threads 
    // queue head and tail pointers
    task_t * queue_head;
    task_t * queue_tail; 
    int thread_count;
    int active_tasks;
    int shutdown; // flag to shutdown the pool
} thread_pool_t;

// declare a thead pool as a global variable 
static thread_pool_t* pool = NULL;

// create the infinit running threads 
static void* thread_worker(void* arg){
    while(1){
        pthread_mutex_lock(&(pool -> lock)); // threads compete to get this lock, only after the aquire this lock can they be allocated work 

        while(pool->queue_head == NULL && !pool ->shutdown){
            pthread_cond_wait(&(pool->notify),&(pool->lock));
            // if no task is availabe and we are not shutting down
            // wait for tasks to be pushed into the queue
        }
        // this is the shutdown sequence 
        if (pool->shutdown && pool->queue_head == NULL) {
            pthread_mutex_unlock(&(pool->lock));
            break;
        }

        // Pop the task off the queue
        task_t* task = pool->queue_head;
        pool->queue_head = task->next;
        if (pool->queue_head == NULL) pool->queue_tail = NULL;
        
        pthread_mutex_unlock(&(pool->lock));

        // Execute the actual math operation
        (*(task->function))(task->arg);
        free(task);

        // Safely decrement the active task counter
        pthread_mutex_lock(&(pool->lock));
        pool->active_tasks--;
        if (pool->active_tasks == 0) {
            pthread_cond_signal(&(pool->all_done)); // Wake the main thread if finished
        }
        pthread_mutex_unlock(&(pool->lock));

    }
    return NULL;
}

void pool_init(int num_threads){
    pool = (thread_pool_t*)malloc(sizeof(thread_pool_t));
    pool->thread_count = num_threads;
    pool->active_tasks = 0;
    pool->shutdown = 0;
    pool->queue_head = NULL;
    pool->queue_tail = NULL;
    
    pthread_mutex_init(&(pool->lock), NULL);
    pthread_cond_init(&(pool->notify), NULL);
    pthread_cond_init(&(pool->all_done), NULL);
    
    pool->threads = (pthread_t*)malloc(sizeof(pthread_t) * num_threads);
    for (int i = 0; i < num_threads; i++) {
        pthread_create(&(pool->threads[i]), NULL, thread_worker, NULL);
    }
}

void pool_submit(void (*function)(void*),void* argument){
    // this function is the only entry point for the maker 
    // the main file can access this 

    // create a new task 
    task_t* new_task = (task_t*)malloc(sizeof(task_t));
    new_task -> function = function;
    new_task->arg = argument;
    new_task -> next = NULL;

    // the main thread competes for the lock, with the spawned threads in the consumer 
    pthread_mutex_lock(&(pool -> lock));
    // check the queue 
    if(pool ->queue_tail == NULL){
        pool -> queue_head = new_task;
        pool -> queue_tail = new_task;
    }else {
        // update the last items pointer 
        pool -> queue_tail -> next = new_task;
        // make the tail point to the new task 
        // this is classic linked list 
        pool -> queue_tail = new_task;
    }
    pool -> active_tasks ++;
    pthread_cond_signal(&(pool->notify)); // Wake exactly one sleeping thread
    pthread_mutex_unlock(&(pool->lock));

}

void pool_wait(){
    // make the main thread get the lock
    pthread_mutex_lock(&(pool ->lock));
    while(pool -> active_tasks > 0){
        // releases the locks and waits
        pthread_cond_wait(&(pool -> all_done),&(pool -> lock));
    }
    pthread_mutex_unlock(&(pool -> lock));
}

void pool_shutdown() {
    pthread_mutex_lock(&(pool->lock));
    pool->shutdown = 1;
    pthread_cond_broadcast(&(pool->notify)); // Wake all threads so they can exit
    pthread_mutex_unlock(&(pool->lock));

    for (int i = 0; i < pool->thread_count; i++) {
        pthread_join(pool->threads[i], NULL);
    }
    
    free(pool->threads);
    pthread_mutex_destroy(&(pool->lock));
    pthread_cond_destroy(&(pool->notify));
    pthread_cond_destroy(&(pool->all_done));
    free(pool);
}