#ifndef _MATRIXMUL_H_
#define _MATRIXMUL_H_

#define MATRIX_SIZE 8192
#define NUM_COLUMNS MATRIX_SIZE // Number of columns in Matrix A
#define NUM_ROWS MATRIX_SIZE // Number of rows in Matrix A
#define TILE_SIZE 16

typedef struct {
unsigned int num_columns;
 unsigned int num_rows;
 unsigned int pitch;
 float* elements;
} Matrix;


#endif // _MATRIXMUL_H_
