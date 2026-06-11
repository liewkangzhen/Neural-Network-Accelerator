`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.04.2026 18:30:43
// Design Name: 
// Module Name: hidden_layer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module hidden_layer_second #(
    parameter WIDTH_WEIGHT_INPUT = 8,
    parameter WIDTH_SAMPLE_DATA_INPUT = 8,
    parameter DEPTH_WEIGHT_INPUT = 4,
    parameter WIDTH_HIDDEN_DATA = 8,
    parameter NUMBER_OF_WEIGHTS_HIDDEN = 8,
    parameter DEPTH_OUTPUT_DATA = 7,
    parameter TOTAL_NUMBER_OF_OUTPUTS = 64
)
(   
    input clk,
    input ARESETN,
    
    // From hidden_layer_second
    input hidden_data_second_output_enable,
    input [15:0] hidden_data_second_multiply_0,
    input [15:0] hidden_data_second_multiply_1,
    input [15:0] hidden_data_second_phase_one_sum,
    input [15:0] hidden_data_second_phase_two_sum,

    // To output layer
    output reg hidden_data_output_enable,
    output reg [WIDTH_HIDDEN_DATA - 1:0] hidden_data_output
);
    
    // FSM 
    localparam WAIT = 3'b001;
    localparam COMPUTATIONS = 3'b010;
    localparam SIGMOID      = 3'b100;
    reg [2:0] current_state = WAIT;
    reg [2:0] next_state = WAIT;
    
    // sigmoid
    localparam WIDTH_SIGMOID = 8;
    localparam NUMBER_OF_SIGMOID = 256;
    reg [WIDTH_SIGMOID - 1:0] sigmoid_lut [0:NUMBER_OF_SIGMOID - 1];
    
    initial begin
        $readmemh("sigmoid.mem", sigmoid_lut);
    end
    
    // counters
    localparam COMPUTATION_LATENCY = 3;
    reg [1:0] cycle_counter = 0;
    
    always @(*) begin
        case (current_state)     
            WAIT: begin
                if (hidden_data_second_output_enable) begin
                    next_state = COMPUTATIONS;
                end else begin
                    next_state = WAIT;
                end
            end
                   
            COMPUTATIONS: begin
                if (cycle_counter < COMPUTATION_LATENCY - 1) begin
                    next_state = COMPUTATIONS;
                end else begin
                    next_state = SIGMOID;
                end
            end
            
            SIGMOID: begin
                next_state = WAIT;
            end
            
            default: next_state = WAIT;
        endcase
    end
    
    // control block
    always @(posedge clk) begin
        if (!ARESETN) begin
            cycle_counter <= 0;
            hidden_data_output_enable <= 0;
        end else begin
        case (current_state)
            WAIT: begin
                cycle_counter <= 0;
                hidden_data_output_enable <= 0;
            end
            
            COMPUTATIONS: begin
                cycle_counter <= cycle_counter + 1;
                hidden_data_output_enable <= 0;
            end
            
            SIGMOID: begin
                cycle_counter <= 0;
                hidden_data_output_enable <= 1;
            end
        endcase
        end
    end
    
    // data block
    reg [15:0] temp_hidden_data_second_phase_one_sum = 0;
    reg [15:0] temp_hidden_data_second_phase_two_sum = 0;
    reg [15:0] temp_hidden_data_second_multiply_0 = 0;
    reg [15:0] temp_hidden_data_second_multiply_1 = 0;
    
    reg [15:0] temporary_phase_one_sum_0 = 0;
    reg [15:0] temporary_phase_second_sum_0 = 0;
    reg [7:0] sigmoid_index = 0;
    
    always @(posedge clk) begin
        if (!ARESETN) begin
            temp_hidden_data_second_phase_one_sum <= 0;
            temp_hidden_data_second_phase_two_sum <= 0;
            temp_hidden_data_second_multiply_0 <= 0;
            temp_hidden_data_second_multiply_1 <= 0;
            temporary_phase_one_sum_0 <= 0;
            temporary_phase_second_sum_0 <= 0;
            sigmoid_index <= 0;
        end else begin
        case (current_state)
            WAIT: begin
                if (hidden_data_second_output_enable) begin
                    temp_hidden_data_second_phase_one_sum <= hidden_data_second_phase_one_sum;
                    temp_hidden_data_second_phase_two_sum <= hidden_data_second_phase_two_sum;
                    temp_hidden_data_second_multiply_0 <= hidden_data_second_multiply_0;
                    temp_hidden_data_second_multiply_1 <= hidden_data_second_multiply_1;
                end
            end
            
            COMPUTATIONS: begin
                case (cycle_counter)
                    0: begin
                        temporary_phase_one_sum_0 <= temp_hidden_data_second_multiply_0 + temp_hidden_data_second_multiply_1;
                    end
                    
                    1: begin
                        temporary_phase_second_sum_0 <= temporary_phase_one_sum_0 + temp_hidden_data_second_phase_one_sum;
                    end
                    
                    2: begin
                        sigmoid_index <= (temporary_phase_second_sum_0 + temp_hidden_data_second_phase_two_sum) >> 8;
                    end
                endcase
            end
            
            SIGMOID: begin
                hidden_data_output <= sigmoid_lut[sigmoid_index];
            end
        endcase
        end
    end
    
    always @(posedge clk) begin
       if (!ARESETN)
           current_state <= WAIT;
       else
           current_state <= next_state;
    end
    
endmodule
