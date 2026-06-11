`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.04.2026 18:30:43
// Design Name: 
// Module Name: output_layer
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


module output_layer #(
    parameter WIDTH_HIDDEN_DATA = 8,
    parameter WIDTH_WEIGHT_INPUT = 8,
    parameter WIDTH_OUTPUT_DATA = 1,    // change this
    parameter DEPTH_OUTPUT_DATA = 7,
    parameter TOTAL_NUMBER_OF_OUTPUTS = 64
)
(   
    input clk,
    input ARESETN,
    
    // From hidden layer
    input hidden_data_output_enable_0,
    input hidden_data_output_enable_1,
    input [WIDTH_HIDDEN_DATA - 1:0] hidden_data_output_0,
    input [WIDTH_HIDDEN_DATA - 1:0] hidden_data_output_1,
    
    // From input layer
    input [WIDTH_WEIGHT_INPUT - 1:0] bias_weight_output,
    input [WIDTH_WEIGHT_INPUT - 1:0] weight0_output,
    input [WIDTH_WEIGHT_INPUT - 1:0] weight1_output,
    
    // To input layer
    output reg Done,
    output reg output_write_enable,
    output reg [WIDTH_OUTPUT_DATA - 1:0] output_write_data,
    output reg [DEPTH_OUTPUT_DATA - 1:0] output_write_data_address
);

    // FSM
    localparam WAIT = 3'b001;
    localparam COMPUTATION = 3'b010;
    localparam SEND_OUTPUT = 3'b100;
    reg [2:0] current_state = WAIT;
    reg [2:0] next_state = WAIT;

    // counters
    reg [DEPTH_OUTPUT_DATA - 1:0] number_output_counter = 0;
    
    always @(*) begin
        case (current_state) 
            WAIT: begin
                if (hidden_data_output_enable_0 && hidden_data_output_enable_1) begin
                    next_state = COMPUTATION;
                end else begin 
                    next_state = WAIT;
                end
            end
            
            COMPUTATION: begin
                next_state = SEND_OUTPUT;
            end
            
            SEND_OUTPUT: begin
                next_state = WAIT;
            end
            
            default: next_state = WAIT;
        endcase
    end
    
    // control block: counters
    always @(posedge clk) begin
        if (!ARESETN) begin
            Done <= 0;
            output_write_enable <= 0;
            number_output_counter <= 0;
            output_write_data_address <= 0;
        end else begin
        case (current_state)
            WAIT: begin
                Done <= 0;
                output_write_data_address <= 0;
                output_write_enable <= 0;
            end
            
            COMPUTATION: begin
                output_write_enable <= 0;
            end
            
            SEND_OUTPUT: begin
                output_write_enable <= 1;
                output_write_data_address <= number_output_counter;
                if (number_output_counter < TOTAL_NUMBER_OF_OUTPUTS - 1) begin
                    number_output_counter <= number_output_counter + 1;
                end else begin
                    number_output_counter <= 0;
                    Done <= 1;
                end
            end
        endcase
        end
    end
    
    // data block
    reg [15:0] temporary_multiply_0 = 0;
    reg [15:0] temporary_multiply_1 = 0;
    reg [15:0] temporary_multiply_2 = 0;
    
    reg [7:0] temp_output_write_data = 0;
    
    always @(posedge clk) begin
        if (!ARESETN) begin
            temporary_multiply_0 <= 0;
            temporary_multiply_1 <= 0;
            temporary_multiply_2 <= 0;
            temp_output_write_data <= 0;
        end else begin
        case (current_state)
            WAIT: begin
                if (hidden_data_output_enable_0 && hidden_data_output_enable_1) begin
                    temporary_multiply_0 <= hidden_data_output_0 * weight0_output;
                    temporary_multiply_1 <= hidden_data_output_1 * weight1_output;
                    temporary_multiply_2 <= bias_weight_output * 256;
                end
            end
            
            COMPUTATION: begin
                temp_output_write_data <= (({2'b00, temporary_multiply_0} + {2'b00, temporary_multiply_1} + {2'b00, temporary_multiply_2}) >> 8);
            end
            
            SEND_OUTPUT: begin
                output_write_data <= temp_output_write_data > 128 ? 1'b1 : 1'b0;
//                output_write_data <= temp_output_write_data;
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
