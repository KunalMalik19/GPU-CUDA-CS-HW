/* Vector-matrix multiplication: Y = A * X.
 * Host code.
 * Author: Naga Kandasamy
 * Date: 11/11/2015
*/

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <string.h>
#include <math.h>
#include <sys/time.h>



#include "vec_mat_mult_kernel.cu"

#define MIN_NUMBER 1
#define MAX_NUMBER 4


extern "C" void compute_gold(float*, const float*, const float*, unsigned int, unsigned int);
Matrix allocate_matrix_on_gpu(const Matrix);
Matrix allocate_matrix(int, int, int);
void copy_matrix_to_device(Matrix, const Matrix);
void copy_matrix_from_device(Matrix, const Matrix);
void vec_mat_mult_on_device_using_global_memory(const Matrix, const Matrix, Matrix);
void vec_mat_mult_on_device_using_shared_memory(const Matrix, const Matrix, Matrix);
void print_matrix(const Matrix);
float get_random_number(int, int);
int checkResults(float *, float *, int, float);
void checkCUDAError(const char *msg);



int 
main(int argc, char** argv) {
Matrix  A;
Matrix  X;
Matrix  Y_cpu, Y_gpu_1, Y_gpu_2; 
srand(time(NULL));
if(argc > 1){
		printf("Error. This program accepts no arguments. \n");
		exit(0);
	}	
A  = allocate_matrix(MATRIX_SIZE, MATRIX_SIZE, 1);
X  = allocate_matrix(MATRIX_SIZE, 1, 1);
Y_cpu  = allocate_matrix(MATRIX_SIZE, 1, 0);
Y_gpu_1 = allocate_matrix(MATRIX_SIZE, 1, 0);
Y_gpu_2 = allocate_matrix(MATRIX_SIZE, 1, 0);
struct timeval start, stop;	
	gettimeofday(&start, NULL);	
	printf("Performing serial calculation using CPU. \n");
	
	compute_gold(Y_cpu.elements, A.elements, X.elements, A.num_rows, A.num_columns);
	
	gettimeofday(&stop, NULL);
	printf("Execution time = %fs. \n", (float)(stop.tv_sec - start.tv_sec + (stop.tv_usec - start.tv_usec)/(float)1000000));

vec_mat_mult_on_device_using_global_memory(A, X, Y_gpu_1);
 printf("Checking against reference result. \n");
	int size_elements = NUM_ROWS;
	int res = checkResults(Y_cpu.elements, Y_gpu_1.elements, size_elements, 0.0001);
	printf("Test %s\n", (1 == res) ? "PASSED" : "FAILED");

vec_mat_mult_on_device_using_shared_memory(A, X, Y_gpu_2);
 printf("Checking against reference result. \n");
    res = checkResults(Y_cpu.elements, Y_gpu_2.elements, size_elements, 0.0001);
	printf("Test %s\n", (1 == res) ? "PASSED" : "FAILED");

free(A.elements); A.elements = NULL;
	free(X.elements); X.elements = NULL;
	free(Y_cpu.elements); Y_cpu.elements = NULL;
	free(Y_gpu_1.elements); Y_gpu_1.elements = NULL;
    free(Y_gpu_2.elements); Y_gpu_2.elements = NULL;

	return 0;
}
void 
vec_mat_mult_on_device_using_global_memory(const Matrix A, const Matrix X, Matrix Y)
{
	/* Allocate and move A to device */
	Matrix Ad = allocate_matrix_on_gpu(A);
	copy_matrix_to_device(Ad, A);
	
	/* Allocate and move X to device */
	Matrix Xd = allocate_matrix_on_gpu(X);
	copy_matrix_to_device(Xd, X);
	
	/* Allocate Y on device to store result */
	Matrix Yd = allocate_matrix_on_gpu(Y);
	
	/* Setup thread block */
	dim3 threads(TILE_SIZE, 1); 
	
	/* Setup execution grid */
	dim3 grid(MATRIX_SIZE/TILE_SIZE, 1);
	printf("Creating a %d x 1 grid of %d x 1 thread blocks.\n", MATRIX_SIZE/TILE_SIZE, TILE_SIZE);
	
	struct timeval start, stop;	
	gettimeofday(&start, NULL);

	printf("Performing multiplication using global memory. \n");
	vec_mat_kernel_naive<<< grid, threads >>>(Ad.elements, Xd.elements, Yd.elements);
	cudaThreadSynchronize();
	
	gettimeofday(&stop, NULL);
	printf("Execution time = %fs. \n", (float)(stop.tv_sec - start.tv_sec + (stop.tv_usec - start.tv_usec)/(float)1000000));

	checkCUDAError("Error in kernel");
	
	copy_matrix_from_device(Y, Yd);
cudaFree(Ad.elements);
	cudaFree(Xd.elements);
	cudaFree(Yd.elements);
}

void 
vec_mat_mult_on_device_using_shared_memory(const Matrix A, const Matrix X, Matrix Y)
{
	/* Allocate and move A to device */
	Matrix Ad = allocate_matrix_on_gpu(A);
	copy_matrix_to_device(Ad, A);
	
	/* Allocate and move X to device */
	Matrix Xd = allocate_matrix_on_gpu(X);
	copy_matrix_to_device(Xd, X);
	
	/* Allocate Y on device to store result */
	Matrix Yd = allocate_matrix_on_gpu(Y);
	
	/* Setup thread block */
	dim3 threads(TILE_SIZE, TILE_SIZE); 
	
	/* Setup execution grid */
	dim3 grid(MATRIX_SIZE/TILE_SIZE, 1);
	printf("Creating a %d x 1 grid of %d x %d thread blocks.\n", MATRIX_SIZE/TILE_SIZE, TILE_SIZE, TILE_SIZE);
	
	struct timeval start, stop;	
	gettimeofday(&start, NULL);

	printf("Performing multiplication using shared memory. \n");
	vec_mat_kernel_optimized<<< grid, threads >>>(Ad.elements, Xd.elements, Yd.elements);
	cudaThreadSynchronize();
	
	gettimeofday(&stop, NULL);
	printf("Execution time = %fs. \n", (float)(stop.tv_sec - start.tv_sec + (stop.tv_usec - start.tv_usec)/(float)1000000));

	checkCUDAError("Error in kernel");
	
	copy_matrix_from_device(Y, Yd);
	cudaFree(Ad.elements);
	cudaFree(Xd.elements);
	cudaFree(Yd.elements);
}

Matrix 
allocate_matrix_on_gpu(const Matrix M)
{
    Matrix Mdevice = M;
    int size = M.num_rows * M.num_columns * sizeof(float);
    cudaMalloc((void**)&Mdevice.elements, size);
    return Mdevice;
}

Matrix 
allocate_matrix(int num_rows, int num_columns, int init)
{
    	Matrix M;
    	M.num_columns = M.pitch = num_columns;
    	M.num_rows = num_rows;
    	int size = M.num_rows * M.num_columns;
		
	M.elements = (float*) malloc(size*sizeof(float));
	for(unsigned int i = 0; i < size; i++){
		if(init == 0) M.elements[i] = 0; 
		else
			M.elements[i] = get_random_number(MIN_NUMBER, MAX_NUMBER);
	}
    return M;
}
void 
copy_matrix_to_device(Matrix Mdevice, const Matrix Mhost)
{
    int size = Mhost.num_rows * Mhost.num_columns * sizeof(float);
    Mdevice.num_rows = Mhost.num_rows;
    Mdevice.num_columns = Mhost.num_columns;
    Mdevice.pitch = Mhost.pitch;
    cudaMemcpy(Mdevice.elements, Mhost.elements, size, cudaMemcpyHostToDevice);
}

void 
copy_matrix_from_device(Matrix Mhost, const Matrix Mdevice)
{
    int size = Mdevice.num_rows * Mdevice.num_columns * sizeof(float);
    cudaMemcpy(Mhost.elements, Mdevice.elements, size, cudaMemcpyDeviceToHost);
}
void 
print_matrix(const Matrix M)
{
	for(unsigned int i = 0; i < M.num_rows; i++){
		for(unsigned int j = 0; j < M.num_columns; j++)
			printf("%f ", M.elements[i*M.num_columns + j]);
		printf("\n");
	} 
	printf("\n");
}
float 
get_random_number(int min, int max){
	return (float)floor((double)(min + (max - min + 1)*((float)rand()/(float)RAND_MAX)));
}

int 
checkResults(float *reference, float *gpu_result, int num_elements, float threshold)
{
    int checkMark = 1;
    float epsilon = 0.0;
    
    for(int i = 0; i < num_elements; i++)
        if(fabsf((reference[i] - gpu_result[i])/reference[i]) > threshold){
            checkMark = 0;
            break;
        }

    for(int i = 0; i < num_elements; i++)
        if(fabsf((reference[i] - gpu_result[i])/reference[i]) > epsilon){
            epsilon = fabsf((reference[i] - gpu_result[i])/reference[i]);
        }

    printf("Max epsilon = %f. \n", epsilon); 
    return checkMark;
}

void 
checkCUDAError(const char *msg)
{
	cudaError_t err = cudaGetLastError();
	if( cudaSuccess != err) 
	{
		printf("CUDA ERROR: %s (%s).\n", msg, cudaGetErrorString(err));
		exit(EXIT_FAILURE);
	}						 
}

	
