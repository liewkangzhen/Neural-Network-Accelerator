/*
----------------------------------------------------------------------------------
--	(c) Rajesh C Panicker, NUS,
--  Description : Self-checking testbench for AXI Stream Coprocessor (HLS) implementing the sum of 4 numbers
--	License terms :
--	You are free to use this code as long as you
--		(i) DO NOT post a modified version of this on any public repository;
--		(ii) use it only for educational purposes;
--		(iii) accept the responsibility to ensure that your implementation does not violate any intellectual property of any entity.
--		(iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(v) send an email to rajesh.panicker@ieee.org briefly mentioning its use (except when used for the course EE4218/CEG5203 at the National University of Singapore);
--		(vi) retain this notice in this file or any files derived from this.
----------------------------------------------------------------------------------
*/

#include <stdio.h>
#include "hls_stream.h"
#include "ap_axi_sdata.h"

typedef ap_axis<32,0,0,0> AXIS;

/***************** Coprocessor function declaration *********************/


void my_prediction_ip_v2_HLS(hls::stream<AXIS>& S_AXIS, hls::stream<AXIS>& M_AXIS);



/***************** Macros *********************/
#define NUMBER_OF_TEST_VECTORS 1  // number of such test vectors (cases)
//input matrix size
#define NUMBER_OF_INPUT_WORDS 448       // 64 * 7 matrix
#define NUMBER_OF_OUTPUT_WORDS 64
#define NUMBER_OF_HIDDEN_WEIGHTS 16
#define NUMBER_OF_OUTPUT_WEIGHTS 3
#define NUMBER_OF_HIDDEN_LAYER_OUTPUTS 128
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
#define WORD_SIZE 4   //in bytes


/************************** Variable Definitions *****************************/
int INPUT [NUMBER_OF_INPUT_WORDS] = 
{
    44,90,0,0,24,81,22,
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

/*Hard-coded matrix B*/
int HIDDEN_LAYER_WEIGHTS [NUMBER_OF_HIDDEN_WEIGHTS] = {
    26,6,
  25,18,
  31,6,
  29,26,
  22,1,
  1,28,
  11,9,
  26,45
};

int OUTPUT_WEIGHTS [NUMBER_OF_OUTPUT_WEIGHTS] = {
  80,
  50,
  200
};


int TEST_EXPECTED_RESULT [NUMBER_OF_OUTPUT_WORDS] = {
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

int OUTPUT_RESULT [NUMBER_OF_OUTPUT_WORDS]; // same size as test_result_expected_memory

/*****************************************************************************
* Main function
******************************************************************************/
int main()
{
	int word_cnt, test_case_cnt = 0;
	int success;
	AXIS read_output, write_input;
	hls::stream<AXIS> S_AXIS;
	hls::stream<AXIS> M_AXIS;

	for (test_case_cnt=0 ; test_case_cnt < NUMBER_OF_TEST_VECTORS ; test_case_cnt++){


		/******************** Input to Coprocessor : Transmit the Data Stream ***********************/

		printf(" Transmitting Data for test case %d ... \r\n", test_case_cnt);

    for (word_cnt=0 ; word_cnt < NUMBER_OF_HIDDEN_WEIGHTS ; word_cnt++){
			write_input.data = HIDDEN_LAYER_WEIGHTS[word_cnt];
      write_input.keep = 0xF;  
      write_input.strb = 0xF;  
			write_input.last = 0;
			S_AXIS.write(write_input); // insert one word into the stream
		}

    for (word_cnt=0 ; word_cnt < NUMBER_OF_OUTPUT_WEIGHTS ; word_cnt++){
			write_input.data = OUTPUT_WEIGHTS[word_cnt];
      write_input.keep = 0xF;  
      write_input.strb = 0xF; 
			write_input.last = 0;
      S_AXIS.write(write_input); // insert one word into the stream
		}

    for (word_cnt=0 ; word_cnt < NUMBER_OF_INPUT_WORDS ; word_cnt++){
			write_input.data = INPUT[word_cnt];
      write_input.keep = 0xF;  
      write_input.strb = 0xF; 
			write_input.last = 0;
      if(word_cnt==NUMBER_OF_INPUT_WORDS-1)
			{
				write_input.last = 1;
				// S_AXIS_TLAST is asserted for the last word.
				// Actually, doesn't matter since we are not making using of S_AXIS_TLAST.
			}
      S_AXIS.write(write_input); // insert one word into the stream
		}

		/* Transmission Complete */

		/********************* Call the hardware function (invoke the co-processor / ip) ***************/

		my_prediction_ip_v2_HLS(S_AXIS, M_AXIS);


		/******************** Output from Coprocessor : Receive the Data Stream ***********************/

		printf(" Receiving data for test case %d ... \r\n", test_case_cnt);

    while(M_AXIS.empty());

		for (word_cnt=0 ; word_cnt < NUMBER_OF_OUTPUT_WORDS ; word_cnt++){

			read_output = M_AXIS.read(); // extract one word from the stream
			OUTPUT_RESULT[word_cnt+test_case_cnt*NUMBER_OF_OUTPUT_WORDS] = read_output.data;
		}

		/* Reception Complete */
	}

	/************************** Checking correctness of results *****************************/

	success = 1;

    /* Print the values of the actual result and the expected result*/
    for(word_cnt=0; word_cnt < NUMBER_OF_OUTPUT_WORDS; word_cnt++){
		if (word_cnt % 16 == 0 ) {
            printf("\r\n");
        }
        printf("%d", OUTPUT_RESULT[word_cnt]);
	}

    printf("\r\n");
    printf("\r\n");

    for(word_cnt=0; word_cnt < NUMBER_OF_OUTPUT_WORDS; word_cnt++){
		if (word_cnt % 16 == 0 ) {
            printf("\r\n");
        }
        printf("%d", TEST_EXPECTED_RESULT[word_cnt]);
	}

    printf("\r\n");

	/* Compare the data send with the data received */
	printf(" Comparing data ...\r\n");
	for(word_cnt=0; word_cnt < NUMBER_OF_TEST_VECTORS*NUMBER_OF_OUTPUT_WORDS; word_cnt++){
		success = success & (OUTPUT_RESULT[word_cnt] == TEST_EXPECTED_RESULT[word_cnt]);
	}

	if (success != 1){
		printf("Test Failed\r\n");
		return 1;
	}

	printf("Test Success\r\n");

	return 0;
}
