#include <stdlib.h>
extern "C"
void compute_gold( float*, const float*, const float*, unsigned int, unsigned int);

void
compute_gold(float* Y, const float* A, const float* X, unsigned int num_rows, unsigned int num_columns){
    	for (unsigned int i = 0; i < num_rows; ++i){
		double sum = 0.0;
        	for (unsigned int j = 0; j < num_columns; ++j) {
          		double a = A[i * num_columns + j];
			double b = X[j]; // Pick X[j]
                	sum += a * b;
           	 }	
            	Y[i] = (float)sum;
}	
}
