

/*  Purpose: Calculate definite integral using trapezoidal rule.
 *   *
 *    * Input:   a, b, n
 *     * Output:  Estimate of integral from a to b of f(x)
 *      *          using n trapezoids.
 *       *
 *        * Compile: gcc -o trap trap.c -lpthread -lm
 *         * Usage:   ./trap
 *          *
 *           * Note:    The function f(x) is hardwired.
 *            *
 *             */

#ifdef _WIN32
#  define NOMINMAX
#endif

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include <math.h>
#include <float.h>
#include <time.h>
#include <pthread.h>

#define LEFT_ENDPOINT 5
#define RIGHT_ENDPOINT 1000
#define NUM_TRAPEZOIDS 100000000
#define NUM_THREADS 16

double compute_using_pthreads(float, float, int, float);
double compute_gold(float, float, int, float);
void* worker(void *this_arg);

typedef struct args_for_thread_t{
    int threadID;
    
    float a;
    float b;
    int n;
    double total;
    float h;
    
} ARGS_FOR_THREAD;

pthread_mutex_t mutex;
double TOTAL = 0;

int main(void)
{
    int n = NUM_TRAPEZOIDS;
    float a = LEFT_ENDPOINT;
    float b = RIGHT_ENDPOINT;
    float h = (b-a)/(float)n;
    printf("The height of the trapezoid is %f \n", h);
    struct timeval start, stop;
    gettimeofday(&start, NULL);
    double reference = compute_gold(a, b, n, h);
    printf("Reference solution computed on the CPU = %f \n", reference);
    gettimeofday(&stop, NULL);
    printf("CPU run time = %0.2f s. \n", (float)(stop.tv_sec - start.tv_sec + (stop.tv_usec - start.tv_usec)/(float)1000000));
    
    /* Write this function to complete the trapezoidal on the GPU. */
    gettimeofday(&start, NULL);
    double pthread_result = compute_using_pthreads(a, b, n, h);
    gettimeofday(&stop, NULL);
   
    printf("Solution computed using pthreads = %f \n", pthread_result);
     printf("CPU run time = %0.2f s. \n", (float)(stop.tv_sec - start.tv_sec + (stop.tv_usec - start.tv_usec)/(float)1000000));
}


/*------------------------------------------------------------------
 *  * Function:    f
 *   * Purpose:     Compute value of function to be integrated
 *    * Input args:  x
 *     * Output: (x+1)/sqrt(x*x + x + 1)
 *      
 *       */
float f(float x) {
		  return (x + 1)/sqrt(x*x + x + 1);
}  /* f */

/*------------------------------------------------------------------
 *  * Function:    Trap
 *   * Purpose:     Estimate integral from a to b of f using trap rule and
 *    *              n trapezoids
 *     * Input args:  a, b, n, h
 *      * Return val:  Estimate of the integral
 *       */
double compute_gold(float a, float b, int n, float h) {
    double integral;
    int k;
    
    integral = (f(a) + f(b))/2.0;
    for (k = 1; k <= n-1; k++) {
        integral += f(a+k*h);
    }
    integral = integral*h;
    
    return integral;
}

void* worker(void *this_arg) {

    ARGS_FOR_THREAD *args_for_me = (ARGS_FOR_THREAD *)this_arg;
    
    float local_A;
    float local_B;
    double local_SUM;
    
    local_A =args_for_me->a + args_for_me->threadID*args_for_me->n*args_for_me->h;
    local_B = local_A + args_for_me->n*args_for_me->h;
    
    
    local_SUM = compute_gold(local_A, local_B, args_for_me->n, args_for_me->h);
    
    pthread_mutex_lock(&mutex);
    TOTAL += local_SUM;
    pthread_mutex_unlock(&mutex);
    
    return NULL;
}



/* Complete this function to perform the trapezoidal rule on the GPU. */
double compute_using_pthreads(float a, float b, int n, float h)
{
    pthread_t threads[NUM_THREADS];
    ARGS_FOR_THREAD *args_for_thread;
    int i;
    
    for(i = 0; i < NUM_THREADS; i++){
        args_for_thread = (ARGS_FOR_THREAD *)malloc(sizeof(ARGS_FOR_THREAD));
        args_for_thread->threadID = i;
        args_for_thread->a =a;
        args_for_thread->b =b;
        args_for_thread->n =n/NUM_THREADS;
        args_for_thread->h = h;
        
        
        if(pthread_create(&threads[i], NULL, worker, (void *) args_for_thread)!= 0) {
            printf("Cannot create thread\n");
            exit(0);
        }
    }
    
    /* Wait for threads to finish */
    for( i = 0; i < NUM_THREADS; i++) {
        pthread_join(threads[i],NULL);
    }
    
		  return TOTAL;
}






