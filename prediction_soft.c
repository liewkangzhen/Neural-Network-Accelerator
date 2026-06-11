
/*
----------------------------------------------------------------------------------
--	(c) Rajesh C Panicker, NUS,
--	Modified from XLlFifo_polling_example.c, (c) Xilinx Inc
--  Description : Self-checking sample program for AXI Stream Coprocessor interfaced using AXI Stream FIFO.
--	License terms :
--	You are free to use this code as long as you
--		(i) DO NOT post a modified version of this on any public repository;
--		(ii) use it only for educational purposes;
--		(iii) accept the responsibility to ensure that your implementation does not violate any intellectual property of any entity.
--		(iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(v) send an email to rajesh.panicker@ieee.org briefly mentioning its use (except when used for the course EE4218 at the National University of Singapore);
--		(vi) retain this notice in this file or any files derived from this.
----------------------------------------------------------------------------------
*/

/***************************** Include Files *********************************/
#include "xaxidma.h"
#include "xdebug.h"
#include "xparameters.h"
#include "xil_exception.h"
#include "xil_cache.h"
#include "xstatus.h"
#include "xuartps.h"
#include "xtmrctr.h"

/***************** Transmit and receive buffers *********************/
#ifndef DDR_BASE_ADDR
#warning CHECK FOR THE VALID DDR ADDRESS IN XPARAMETERS.H, \
DEFAULT SET TO 0x01000000
#define MEM_BASE_ADDR		0x01000000
#else
#define MEM_BASE_ADDR		(DDR_BASE_ADDR + 0x1000000)
#endif

// Transmit and receive buffer allocated sufficiently away from the start of DDR, hopefully not overlapping with the program's other memory segments.
// It is better to hard code transmit and receive buffers to avoid it being in the same cache line as other variables, and for better alignment.
#define TX_BUFFER_BASE		(MEM_BASE_ADDR + 0x00100000) 
#define RX_BUFFER_BASE		(MEM_BASE_ADDR + 0x00300000)
#define RX_BUFFER_HIGH		(MEM_BASE_ADDR + 0x004FFFFF)

/***************** Macros *********************/
// #define NUMBER_OF_INPUT_WORDS 520  // length of an input vector
// #define NUMBER_OF_OUTPUT_WORDS 64  // length of an input vector
// #define NUMBER_OF_TEST_VECTORS 1  // number of such test vectors (cases)
// #define MATRIX_A_SIZE			512 //number of words in matrix A
// #define MATRIX_A_ROWS			64	//number of rows in matrix A
// #define MATRIX_A_COLS			8	//number of columns in matrix A
// #define MATRIX_B_SIZE			8	//number of words in matrix B
// #define MATRIX_B_ROWS			8	//number of columns in matrix B
// #define MATRIX_B_COLS			1	//number of columns in matrix B
// #define MATRIX_RES_SIZE			64 	//number of words in the result matrix

//input matrix size
#define NUMBER_OF_INPUT_WORDS 448       // 64 * 7 matrix
#define NUMBER_OF_OUTPUT_WORDS 64
#define INPUT_ROWS 64        
#define INPUT_COLS 7
#define HIDDEN_WEIGHT_ROWS 8
#define HIDDEN_WEIGHT_COLS 2
#define SHARED_DIMENSION 8
#define OUTPUT_WEIGHT_ROWS 3
#define OUTPUT_WEIGHT_COLS 1
#define HIDDEN_LAYER_OUTPUT_ROWS 64
#define HIDDEN_LAYER_OUTPUT_COLS 2
#define FINAL_OUTPUT_ROWS 64
#define FINAL_OUTPUT_COLS 1
#define SIGMOID_LUT_SIZE 256

#define DMA_DEV_ID              XPAR_XAXIDMA_0_BASEADDR
#define	XUARTPS_BASEADDRESS		XPAR_XUARTPS_0_BASEADDR //UART Base Address
#define XTMRCTR_BASEADDRESS		XPAR_XTMRCTR_0_BASEADDR //AXI Timer Base Address
/*
 * This example only uses the 1st of the 2 timer counters contained in a
 * single timer counter hardware device
 */
#define TIMER_COUNTER_0	 0

#define BITMASK_15      0x7FFF

/************************** Variable Definitions *****************************/
XAxiDma AxiDma;	// Device instance
XAxiDma *InstancePtr = &AxiDma; // Device pointer
XUartPs Uart_Ps;		/* The instance of the UART Driver */
XTmrCtr TimerCounter; /* The instance of the Tmrctr Device */

// Commenting out the lines below as we are using hardcoded buffers, and not compiler/linker allocated.

// 64 * 7 input matrix
u8 input_matrix[NUMBER_OF_INPUT_WORDS] = {44,90,0,0,24,81,22,
  159,250,140,176,121,183,138,
  167,158,172,134,172,161,118,
  130,178,136,120,135,121,86,
  34,112,142,112,163,159,43,
  63,28,145,126,190,165,66,
  88,214,157,140,205,174,128,
  185,203,170,110,211,138,126,
  140,255,110,136,133,156,131,
  73,90,164,118,75,121,111,
  16,93,187,88,162,101,27,
  31,110,120,77,166,101,45,
  183,181,155,175,135,211,185,
  129,193,104,159,184,183,161,
  190,183,143,124,139,138,145,
  79,113,115,111,164,101,88,
  213,213,149,159,133,199,183,
  13,94,127,146,132,150,89,
  103,175,164,139,187,147,128,
  42,82,104,83,167,50,71,
  26,90,109,143,135,220,106,
  69,90,101,180,125,222,108,
  143,225,125,147,196,197,121,
  73,87,125,29,8,87,67,
  100,136,254,119,170,140,77,
  110,136,101,137,186,174,126,
  165,143,179,151,167,156,147,
  182,207,131,105,130,101,124,
  34,51,194,94,90,94,58,
  108,85,116,25,24,0,59,
  18,70,110,118,179,138,50,
  35,165,120,72,126,72,82,
  72,99,85,76,210,101,56,
  27,85,85,109,122,133,54,
  149,166,176,111,135,115,98,
  138,180,136,131,255,139,84,
  120,97,115,96,110,128,44,
  183,181,183,152,119,174,148,
  38,113,125,67,88,26,68,
  180,188,169,137,188,124,145,
  86,87,80,72,76,73,71,
  219,224,155,165,197,252,218,
  31,65,145,38,112,32,78,
  21,134,48,83,94,78,111,
  111,62,128,89,163,209,65,
  224,206,128,155,167,170,150,
  231,225,139,174,149,202,208,
  140,146,106,124,192,142,104,
  116,191,196,136,192,170,108,
  43,136,131,58,44,50,118,
  39,76,130,63,71,62,39,
  103,166,170,115,236,131,75,
  83,148,206,120,142,156,102,
  73,41,150,63,123,78,51,
  159,136,93,153,140,149,198,
  14,77,160,67,68,72,56,
  37,70,131,53,72,46,37,
  225,171,136,148,136,161,188,
  64,177,76,69,92,92,84,
  44,54,166,93,158,101,59,
  153,170,150,125,152,171,166,
  86,155,136,41,36,131,63,
  138,160,104,119,149,124,100,
  19,56,140,139,217,161,51
};

/*Hidden layer weights (8 * 2) */
u8 hidden_weights[HIDDEN_WEIGHT_ROWS * HIDDEN_WEIGHT_COLS] = {
  26,6,
  25,18,
  31,6,
  29,26,
  22,1,
  1,28,
  11,9,
  26,45
};

u8 output_weights[OUTPUT_WEIGHT_ROWS * OUTPUT_WEIGHT_COLS] = {
  80,
  50,
  200
};

u8 sigmoid_function[SIGMOID_LUT_SIZE] = {
12,12,12,12,13,13,13,14,14,14,15,15,15,16,16,16,17,17,18,18,18,19,19,20,20,21,21,21,22,22,23,23,24,24,25,26,26,27,27,28,28,29,30,30,31,32,32,33,34,34,35,36,36,37,38,39,39,40,41,42,43,44,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,66,67,68,69,70,72,73,74,75,76,78,79,80,82,83,84,86,87,88,90,91,92,94,95,97,98,99,101,102,104,105,107,108,110,111,113,114,116,117,119,120,122,123,125,126,128,129,130,132,133,135,136,138,139,141,142,144,145,147,148,150,151,153,154,156,157,158,160,161,163,164,165,167,168,169,171,172,173,175,176,177,179,180,181,182,183,185,186,187,188,189,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,211,212,213,214,215,216,216,217,218,219,219,220,221,221,222,223,223,224,225,225,226,227,227,228,228,229,229,230,231,231,232,232,233,233,234,234,234,235,235,236,236,237,237,237,238,238,239,239,239,240,240,240,241,241,241,242,242,242,243,243,243
};

u8 expected_results[FINAL_OUTPUT_ROWS * FINAL_OUTPUT_COLS] = {
  0,
  1,
  1,
  1,
  0,
  0,
  1,
  1,
  1,
  0,
  0,
  0,
  1,
  1,
  1,
  0,
  1,
  0,
  1,
  0,
  0,
  1,
  1,
  0,
  1,
  1,
  1,
  1,
  0,
  0,
  0,
  0,
  0,
  0,
  1,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  0,
  1,
  1,
  1,
  1,
  1,
  0,
  0,
  1,
  1,
  0,
  1,
  0,
  0,
  1,
  0,
  0,
  1,
  0,
  1,
  0
};

// u8 RecvBuffer [2048]; // Buffer for receiving bytes from UART FIFO
// u8 SendBuffer [2048]; // BUffer for sending bytes to UART FIFO
// u32 matrix_A_DDR [MATRIX_A_SIZE]; // DDR/cache memory to store matrix A in processor
// u32 matrix_B_DDR [MATRIX_B_SIZE]; // DDR/cache memory to store matrix B in processor

u32* test_input_memory = (u32*)TX_BUFFER_BASE;
u32* result_memory = (u32*)RX_BUFFER_BASE;
u8 hidden_layer_output[HIDDEN_LAYER_OUTPUT_ROWS * HIDDEN_LAYER_OUTPUT_COLS];
u8 final_output[FINAL_OUTPUT_ROWS * FINAL_OUTPUT_COLS];

int TmrCtrInitialization(UINTPTR BaseAddr, u8 TmrCtrNumber);

/*****************************************************************************
* Main function
******************************************************************************/
int main()
{
	int Status;
	int word_cnt;
	int success;
	int value1;
	int value2;
	Status = XST_SUCCESS;

    //Hardcoding input word matrices into the DDR buffer
    // for (word_cnt = 0; word_cnt < MATRIX_A_SIZE; word_cnt++) {
    //     test_input_memory[word_cnt] = matrix_A_test[word_cnt];
    // }

    // for (word_cnt = 0; word_cnt < MATRIX_B_SIZE; word_cnt++) {
    //     test_input_memory[word_cnt + MATRIX_A_SIZE] = matrix_B_test[word_cnt];
    // }

	/************************** Initializations *****************************/


    /************************** Transmit the Data Stream *****************************/
    /*Configure and Initialize the AXI TIMER and starts the timer*/
    Status = TmrCtrInitialization(XTMRCTR_BASEADDRESS, TIMER_COUNTER_0);

    /* Start the timer counter such that it's incrementing by default*/
    XTmrCtr_Start(&TimerCounter, TIMER_COUNTER_0);

    /* Get a snapshot of the timer counter value before it's started to compare against later*/
    value1 = XTmrCtr_GetValue(&TimerCounter, TIMER_COUNTER_0);

    //Matrix multiplication for the first hidden layer
    int i;
    int j;
    int k;
    u16 acc; // declared as 16 bits integer to accomodate the multiplication of two 0.8 
    u8 lut_index;
    for (i = 0; i < INPUT_ROWS; i++) {
        for (j = 0; j < HIDDEN_WEIGHT_COLS; j++) {
            acc = 0;
            for (k = 0; k < SHARED_DIMENSION; k++) {
                if (k == 0) {
                    // Bias term: Weight * 256 (representing 1.0 in 0.8 fixed point)
                    acc += (1 * hidden_weights[j + k*HIDDEN_WEIGHT_COLS] * 256) & BITMASK_15;
                } else {
                    acc += (input_matrix[i*INPUT_COLS + (k-1)] * hidden_weights[j + k*HIDDEN_WEIGHT_COLS]) & BITMASK_15;
                }
            }
            lut_index = acc / 256;
            if (lut_index < 0) lut_index = 0;
            if (lut_index > 255) lut_index = 255;
            hidden_layer_output[i * HIDDEN_LAYER_OUTPUT_COLS + j] = sigmoid_function[lut_index];
        }
    }

    acc = 0;
    //Matrix multiplication for the output layer
    for (i = 0; i < HIDDEN_LAYER_OUTPUT_ROWS; i++) {
        for (j = 0; j < OUTPUT_WEIGHT_COLS; j++) {
            acc = 0;
            for (k = 0; k < OUTPUT_WEIGHT_ROWS; k++) {
                if (k == 0) {
                    acc += (1 * output_weights[j + k*OUTPUT_WEIGHT_COLS] * 256) & BITMASK_15;
                } else {
                    acc += (hidden_layer_output[i*HIDDEN_LAYER_OUTPUT_COLS + (k-1)] * output_weights[j + k*OUTPUT_WEIGHT_COLS]) & BITMASK_15;
                }
            }
            final_output[i*FINAL_OUTPUT_COLS + j] = ((acc / 256) > 128) ? 1 : 0;
        }
    }

    value2 = XTmrCtr_GetValue(&TimerCounter, TIMER_COUNTER_0);

	/*Printing the time taken for matrix muliplication in the co-processor and time taken to sen*/
	xil_printf("Time taken for Pure SOFT Prediction: %d ticks\n\r", value2 - value1);

	/*
	 * Disable the Autoreload mode of the timer counters.
	 */
	XTmrCtr_SetOptions(&TimerCounter, TIMER_COUNTER_0, 0);

	/************************** Checking correctness of results *****************************/

    xil_printf("Actual results:\r\n");
    for(word_cnt=1; word_cnt < NUMBER_OF_OUTPUT_WORDS+1; word_cnt++){
		xil_printf("%d\t", final_output[word_cnt-1]);
        if (word_cnt % 16 == 0) {
            xil_printf("\n\r");
        }
	}

    xil_printf("Expected results:\r\n");
    for(word_cnt=1; word_cnt < NUMBER_OF_OUTPUT_WORDS+1; word_cnt++){
		xil_printf("%d\t", expected_results[word_cnt-1]);
        if (word_cnt % 16 == 0) {
            xil_printf("\n\r");
        }
	}

	success = 1;

	/* Compare the data send with the data received */
	xil_printf(" Comparing data ...\r\n");
	for(word_cnt=0; word_cnt < NUMBER_OF_OUTPUT_WORDS; word_cnt++){
		success = success & (final_output[word_cnt] == expected_results[word_cnt]);
	}

	if (success != 1){
		xil_printf("Test Failed\r\n");
		return XST_FAILURE;
	}

	xil_printf("Test Success\r\n");

	return XST_SUCCESS;
}


int TmrCtrInitialization(UINTPTR BaseAddr, u8 TmrCtrNumber)
{
	int Status;
	XTmrCtr *TmrCtrInstancePtr = &TimerCounter;

	/*
	 * Initialize the timer counter so that it's ready to use,
	 * specify the device ID that is generated in xparameters.h
	 */

	Status = XTmrCtr_Initialize(TmrCtrInstancePtr, BaseAddr);

	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	 * Perform a self-test to ensure that the hardware was built
	 * correctly, use the 1st timer in the device (0)
	 */
	Status = XTmrCtr_SelfTest(TmrCtrInstancePtr, TmrCtrNumber);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	 * Enable the Autoreload mode of the timer counters.
	 */
	XTmrCtr_SetOptions(TmrCtrInstancePtr, TmrCtrNumber,
			   XTC_AUTO_RELOAD_OPTION);

	/*
	 * Start the timer counter such that it's incrementing by default
	 */
	XTmrCtr_Start(TmrCtrInstancePtr, TmrCtrNumber);

	return XST_SUCCESS;
}