#include "hls_stream.h"
#include "ap_int.h"
#include "ap_axi_sdata.h"

#define NUMBER_OF_INPUT_WORDS 448
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

typedef ap_axis<32,0,0,0> AXIS;

static void load_inputs(
    hls::stream<AXIS>& S_AXIS,
    hls::stream<int>& input_fifo,
    hls::stream<int>& hw_fifo,
    hls::stream<int>& ow_fifo)
{
    AXIS read_input;

    for (int i = 0; i < NUMBER_OF_HIDDEN_WEIGHTS; i++) {
        read_input = S_AXIS.read();
        hw_fifo.write(read_input.data);
    }
    for (int i = 0; i < NUMBER_OF_OUTPUT_WEIGHTS; i++) {
        read_input = S_AXIS.read();
        ow_fifo.write(read_input.data);
    }
    for (int i = 0; i < NUMBER_OF_INPUT_WORDS; i++) {
        read_input = S_AXIS.read();
        input_fifo.write(read_input.data);
    }
}

static void compute_hidden(
    hls::stream<int>& input_fifo,
    hls::stream<int>& hw_fifo,
    hls::stream<int>& hidden_out_fifo)
{
    static const int SIGMOID_LUT[256] = {
        12,  12,  12,  12,  13,  13,  13,  14,  14,  14,  15,  15,  15,  16,  16,  16,
        17,  17,  18,  18,  18,  19,  19,  20,  20,  21,  21,  21,  22,  22,  23,  23,
        24,  24,  25,  26,  26,  27,  27,  28,  28,  29,  30,  30,  31,  32,  32,  33,
        34,  34,  35,  36,  36,  37,  38,  39,  39,  40,  41,  42,  43,  44,  44,  45,
        46,  47,  48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,  59,  60,  61,
        62,  63,  64,  66,  67,  68,  69,  70,  72,  73,  74,  75,  76,  78,  79,  80,
        82,  83,  84,  86,  87,  88,  90,  91,  92,  94,  95,  97,  98,  99, 101, 102,
       104, 105, 107, 108, 110, 111, 113, 114, 116, 117, 119, 120, 122, 123, 125, 126,
       128, 129, 130, 132, 133, 135, 136, 138, 139, 141, 142, 144, 145, 147, 148, 150,
       151, 153, 154, 156, 157, 158, 160, 161, 163, 164, 165, 167, 168, 169, 171, 172,
       173, 175, 176, 177, 179, 180, 181, 182, 183, 185, 186, 187, 188, 189, 191, 192,
       193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208,
       209, 210, 211, 211, 212, 213, 214, 215, 216, 216, 217, 218, 219, 219, 220, 221,
       221, 222, 223, 223, 224, 225, 225, 226, 227, 227, 228, 228, 229, 229, 230, 231,
       231, 232, 232, 233, 233, 234, 234, 234, 235, 235, 236, 236, 237, 237, 237, 238,
       238, 239, 239, 239, 240, 240, 240, 241, 241, 241, 242, 242, 242, 243, 243, 243
    };
    #pragma HLS BIND_STORAGE variable=SIGMOID_LUT type=ROM_1P impl=BRAM

    int W[HIDDEN_WEIGHT_ROWS * HIDDEN_WEIGHT_COLS];
    #pragma HLS ARRAY_PARTITION variable=W complete
    for (int i = 0; i < NUMBER_OF_HIDDEN_WEIGHTS; i++)
        W[i] = hw_fifo.read();

    for (int i = 0; i < INPUT_ROWS; i++) {
        int row[INPUT_COLS];
        for (int c = 0; c < INPUT_COLS; c++)
            row[c] = input_fifo.read();

        for (int j = 0; j < HIDDEN_WEIGHT_COLS; j++) {
            int acc = 0;
            for (int k = 0; k < SHARED_DIMENSION; k++) {
                if (k == 0)
                    acc += W[j + k*HIDDEN_WEIGHT_COLS] * 256;
                else
                    acc += row[k-1] * W[j + k*HIDDEN_WEIGHT_COLS];
            }
            int lut_index = acc / 256;
            if (lut_index < 0)   lut_index = 0;
            if (lut_index > 255) lut_index = 255;
            hidden_out_fifo.write(SIGMOID_LUT[lut_index]);
        }
    }
}

static void compute_output(
    hls::stream<int>& ow_fifo,
    hls::stream<int>& hidden_out_fifo,
    hls::stream<int>& final_out_fifo)
{
    ap_uint<8> OW[OUTPUT_WEIGHT_ROWS * OUTPUT_WEIGHT_COLS];
    #pragma HLS ARRAY_PARTITION variable=OW complete
    for (int i = 0; i < NUMBER_OF_OUTPUT_WEIGHTS; i++)
        OW[i] = ow_fifo.read();

    for (int i = 0; i < HIDDEN_LAYER_OUTPUT_ROWS; i++) {
        int h_row[HIDDEN_LAYER_OUTPUT_COLS];
        for (int c = 0; c < HIDDEN_LAYER_OUTPUT_COLS; c++)
            h_row[c] = hidden_out_fifo.read();

        for (int j = 0; j < OUTPUT_WEIGHT_COLS; j++) {
            int acc = 0;
            for (int k = 0; k < OUTPUT_WEIGHT_ROWS; k++) {
                if (k == 0)
                    acc += OW[j + k*OUTPUT_WEIGHT_COLS] * 256;
                else
                    acc += h_row[k-1] * OW[j + k*OUTPUT_WEIGHT_COLS];
            }
            final_out_fifo.write((acc / 256) > 128 ? 1 : 0);
        }
    }
}

static void write_outputs(
    hls::stream<int>& final_out_fifo,
    hls::stream<AXIS>& M_AXIS)
{
    AXIS write_output;
    write_output.keep = 0xFU;
    write_output.strb = 0xFU;
    for (int i = 0; i < NUMBER_OF_OUTPUT_WORDS; i++) {
        write_output.data = final_out_fifo.read();
        write_output.last = (i == NUMBER_OF_OUTPUT_WORDS - 1) ? 1 : 0;
        M_AXIS.write(write_output);
    }
}

void my_prediction_ip_v2_HLS(hls::stream<AXIS>& S_AXIS, hls::stream<AXIS>& M_AXIS) {
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE axis port=S_AXIS
#pragma HLS INTERFACE axis port=M_AXIS
#pragma HLS DATAFLOW

    hls::stream<int> input_fifo("input_fifo");
    hls::stream<int> hw_fifo("hw_fifo");
    hls::stream<int> ow_fifo("ow_fifo");
    hls::stream<int> hidden_out_fifo("hidden_out_fifo");
    hls::stream<int> final_out_fifo("final_out_fifo");

    #pragma HLS STREAM variable=input_fifo      depth=7
    #pragma HLS STREAM variable=hw_fifo         depth=16
    #pragma HLS STREAM variable=ow_fifo         depth=3
    #pragma HLS STREAM variable=hidden_out_fifo depth=2
    #pragma HLS STREAM variable=final_out_fifo  depth=1

    load_inputs   (S_AXIS, input_fifo, hw_fifo, ow_fifo);
    compute_hidden(input_fifo, hw_fifo, hidden_out_fifo);
    compute_output(ow_fifo, hidden_out_fifo, final_out_fifo);
    write_outputs (final_out_fifo, M_AXIS);
}