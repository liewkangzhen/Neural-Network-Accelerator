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


module hidden_layer_first #(
    parameter WIDTH_WEIGHT_INPUT = 8,
    parameter WIDTH_SAMPLE_DATA_INPUT = 8,
    parameter DEPTH_WEIGHT_INPUT = 4,
    parameter WIDTH_HIDDEN_DATA = 8,
    parameter NUMBER_OF_WEIGHTS_HIDDEN = 8,
    parameter DEPTH_OUTPUT_DATA = 7,
    parameter TOTAL_NUMBER_OF_OUTPUTS = 64,
    parameter TOTAL_NUMBER_OF_INPUTS = 448
)
(   
    input clk,
    input ARESETN,
    // From input layer
    input Start,
    input [WIDTH_WEIGHT_INPUT - 1:0] weight_bias,
    input [WIDTH_WEIGHT_INPUT - 1:0] weight_read_input,
    input [WIDTH_SAMPLE_DATA_INPUT - 1:0] sample_data_read_input,
    
    // To weights RAM
    output reg weight_read_enable,
    output reg [DEPTH_WEIGHT_INPUT - 1:0] weight_read_address,
    
    // To hidden_layer_second
    output reg hidden_data_second_output_enable,
    output reg [15:0] hidden_data_second_multiply_0,
    output reg [15:0] hidden_data_second_multiply_1,
    output reg [15:0] hidden_data_second_phase_one_sum,
    output reg [15:0] hidden_data_second_phase_two_sum
);
    
    // FSM 
    localparam WAIT = 3'b001;
    localparam COMPUTATIONS = 3'b010;
    localparam SEND = 3'b100;

    reg [2:0] current_state = WAIT;
    reg [2:0] next_state = WAIT;
    
    // counters
    localparam COMPUTATION_LATENCY = 7;
    reg [3:0] cycle_counter = 0;
    reg [8:0] sample_data_counter = 0;
    reg [8:0] temp_sample_data_counter = 0;
    reg [DEPTH_OUTPUT_DATA - 1:0] number_output_counter = 0;
    
    reg [WIDTH_SAMPLE_DATA_INPUT - 1:0] sample_data_reg [0 : TOTAL_NUMBER_OF_INPUTS - 1];
    
    always @(*) begin
        case (current_state)
            WAIT: begin
                if (Start) begin
                    next_state = COMPUTATIONS;
                end else begin 
                    next_state = WAIT;
                end
            end
            
            COMPUTATIONS: begin
                if (cycle_counter < COMPUTATION_LATENCY - 1) begin
                    next_state = COMPUTATIONS;
                end else begin
                    next_state = SEND;
                end
            end
            
            SEND: begin
                if (number_output_counter < TOTAL_NUMBER_OF_OUTPUTS - 1) begin
                    next_state = COMPUTATIONS;
                end else begin
                    next_state = WAIT;
                end
            end
            
            default: next_state = WAIT;
        endcase
    end
    
    // Control 
    always @(posedge clk) begin
        if (!ARESETN) begin
            weight_read_address <= 0;
            weight_read_enable <= 0;
            number_output_counter <= 0;
            cycle_counter <= 0;
            hidden_data_second_output_enable <= 0;
            sample_data_counter <= 0;
            temp_sample_data_counter <= 0;
        end else begin
        case (current_state)
            WAIT: begin 
                if (Start) begin
                    weight_read_address <= 0;
                    weight_read_enable <= 1;
                    number_output_counter <= 0;
                end else begin
                    weight_read_enable <= 0;
                end
                cycle_counter <= 0;
                hidden_data_second_output_enable <= 0;
                sample_data_counter <= 0;
                temp_sample_data_counter <= 0;
            end
            
            COMPUTATIONS: begin
                cycle_counter <= cycle_counter + 1;
                if (sample_data_counter < TOTAL_NUMBER_OF_INPUTS) begin
                    sample_data_counter <= sample_data_counter + 1;
                    sample_data_reg[sample_data_counter] <= sample_data_read_input;
                end else begin
                    sample_data_counter <= sample_data_counter;
                end
                
                if (cycle_counter >= 1 && cycle_counter <= 6) begin
                    temp_sample_data_counter <= temp_sample_data_counter + 1;
                end else begin
                    temp_sample_data_counter <= temp_sample_data_counter;
                end
                
                hidden_data_second_output_enable <= 0;
                weight_read_address <= weight_read_address + 1;
            end
            
            SEND: begin
                if (sample_data_counter < TOTAL_NUMBER_OF_INPUTS) begin
                    sample_data_counter <= sample_data_counter + 1;
                    sample_data_reg[sample_data_counter] <= sample_data_read_input;
                end else begin
                    sample_data_counter <= sample_data_counter;
                end
                cycle_counter <= 0;
                weight_read_address <= 0;
                number_output_counter <= number_output_counter + 1;
                temp_sample_data_counter <= temp_sample_data_counter + 1;
                hidden_data_second_output_enable <= 1;
            end
        endcase
        end
    end
    
    // data block
    // two registers to store the input multiplication (reusing registers)
    reg [15:0] temporary_multiply_0;
    reg [15:0] temporary_multiply_1;
    
    // two registers to store phase 1 summation (reusing registers)
    reg [16:0] temporary_phase_one_sum_0 = 0;
    reg [16:0] temporary_phase_one_sum_1 = 0;
    
    // two registers to store phase 2 summation (reusing registers)
    reg [17:0] temporary_phase_second_sum_0 = 0;
    
    
    always @(posedge clk) begin
        if (!ARESETN) begin
            temporary_multiply_0 <= 0;
            temporary_multiply_1 <= 0;
            temporary_phase_one_sum_0 <= 0;
            temporary_phase_one_sum_1 <= 0;
            temporary_phase_second_sum_0 <= 0;
        end else begin
        case(current_state)
            WAIT: begin
                temporary_multiply_0 <= 0;
                temporary_multiply_1 <= 0;
                temporary_phase_one_sum_0 <= 0;
                temporary_phase_one_sum_1 <= 0;
                temporary_phase_second_sum_0 <= 0;
            end
            
            COMPUTATIONS: begin
                case (cycle_counter) 
                    0: begin
                        temporary_multiply_0 <= weight_bias * 256;
                    end
                    
                    1: begin
                        temporary_multiply_1 <= weight_read_input * sample_data_reg[temp_sample_data_counter];
                    end
                    
                    2: begin
                        temporary_multiply_0 <= weight_read_input * sample_data_reg[temp_sample_data_counter];
                        temporary_phase_one_sum_0 <= temporary_multiply_0 + temporary_multiply_1;
                    end
                    
                    3: begin
                        temporary_multiply_1 <= weight_read_input * sample_data_reg[temp_sample_data_counter];
                    end
                    
                    4: begin
                        temporary_multiply_0 <= weight_read_input * sample_data_reg[temp_sample_data_counter];
                        temporary_phase_one_sum_1 <=  temporary_multiply_0 + temporary_multiply_1;
                    end
                    
                    5: begin
                        temporary_multiply_1 <= weight_read_input * sample_data_reg[temp_sample_data_counter];
                        temporary_phase_second_sum_0 <= temporary_phase_one_sum_0 + temporary_phase_one_sum_1;
                    end
                    
                    6: begin
                        temporary_multiply_0 <= weight_read_input * sample_data_reg[temp_sample_data_counter];
                        temporary_phase_one_sum_0 <=  temporary_multiply_0 + temporary_multiply_1;
                    end
                endcase
            end
            
            SEND: begin
                hidden_data_second_multiply_0 <= temporary_multiply_0;
                hidden_data_second_multiply_1 <= weight_read_input * sample_data_reg[temp_sample_data_counter];
                hidden_data_second_phase_one_sum <= temporary_phase_one_sum_0;
                hidden_data_second_phase_two_sum <= temporary_phase_second_sum_0;
                temporary_multiply_0 <= 0;
                temporary_multiply_1 <= 0;
                temporary_phase_one_sum_0 <= 0;
                temporary_phase_one_sum_1 <= 0;
                temporary_phase_second_sum_0 <= 0;
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
