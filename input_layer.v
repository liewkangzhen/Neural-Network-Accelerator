`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.04.2026 18:30:43
// Design Name: 
// Module Name: input_layer
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


module input_layer
    (
		// DO NOT EDIT BELOW THIS LINE ////////////////////
		ACLK,
		ARESETN,
		S_AXIS_TREADY,
		S_AXIS_TDATA,
		S_AXIS_TLAST,
		S_AXIS_TVALID,
		M_AXIS_TVALID,
		M_AXIS_TDATA,
		M_AXIS_TLAST,
		M_AXIS_TREADY
		// DO NOT EDIT ABOVE THIS LINE ////////////////////
	);

	input					ACLK;            // Synchronous clock
	input					ARESETN;         // System reset, active low
	// slave in interface
	output reg				S_AXIS_TREADY;   // Ready to accept data in
	input	   [31 : 0]		S_AXIS_TDATA;    // Data in
	input					S_AXIS_TLAST;    // Optional data in qualifier
	input					S_AXIS_TVALID;   // Data in is valid
	// master out interface
	output reg				M_AXIS_TVALID;   // Data out is valid
	output     [31 : 0]	    M_AXIS_TDATA;    // Data Out
	output 				    M_AXIS_TLAST;    // Optional data out qualifier
	input					M_AXIS_TREADY;   // Connected slave device is ready to accept data out
	
	// localparams
    localparam WIDTH_WEIGHT_INPUT = 8;
    localparam WIDTH_SAMPLE_DATA_INPUT = 8;
    localparam WIDTH_HIDDEN_DATA = 8;
    localparam WIDTH_OUTPUT_DATA = 1;   // change this 
    localparam DEPTH_WEIGHT_INPUT = 3;
    localparam DEPTH_OUTPUT_DATA = 7;
    
	// FSM
	localparam WAIT         = 4'b0001;
	localparam READ_INPUTS  = 4'b0010;
	localparam COMPUTATION  = 4'b0100;
	localparam SEND_OUTPUTS = 4'b1000;
	reg [3:0] current_state = WAIT;
	reg [3:0] next_state = WAIT;
	
	// Connections to other Modules
	reg weight_write_enable_0;
	reg weight_write_enable_1;
	reg [DEPTH_WEIGHT_INPUT - 1:0] weight_write_address;
	reg [WIDTH_WEIGHT_INPUT - 1:0] weight_write_input;
	wire [WIDTH_WEIGHT_INPUT - 1:0] weight_read_output_0;
	wire [WIDTH_WEIGHT_INPUT - 1:0] weight_read_output_1;
	reg [WIDTH_SAMPLE_DATA_INPUT - 1:0] sample_data_read_input;
	reg Start;
	reg [WIDTH_WEIGHT_INPUT - 1:0] bias_weight_output;
	reg [WIDTH_WEIGHT_INPUT - 1:0] weight0_output;
	reg [WIDTH_WEIGHT_INPUT - 1:0] weight1_output;
	reg output_read_enable;
	wire [DEPTH_OUTPUT_DATA - 1:0] output_read_data_address;
	
	wire weight_read_enable_0;
	wire weight_read_enable_1;
	wire [DEPTH_WEIGHT_INPUT - 1:0] weight_read_address_0;
	wire [DEPTH_WEIGHT_INPUT - 1:0] weight_read_address_1;
	wire sample_data_read_enable_0;
	wire sample_data_read_enable_1;
	wire hidden_data_output_enable_0;
	wire hidden_data_output_enable_1;
	wire [WIDTH_HIDDEN_DATA - 1:0] hidden_data_output_0;
	wire [WIDTH_HIDDEN_DATA - 1:0] hidden_data_output_1;
	wire Done;
	wire output_write_enable;
	wire [WIDTH_OUTPUT_DATA - 1:0] output_write_data;
	wire [DEPTH_OUTPUT_DATA - 1:0] output_write_data_address;
	wire [WIDTH_OUTPUT_DATA - 1:0] output_read_data;
	
	reg [WIDTH_WEIGHT_INPUT - 1:0] bias_weight_0;
	reg [WIDTH_WEIGHT_INPUT - 1:0] bias_weight_1;
	
	// counters
	localparam TOTAL_NUMBER_OF_WEIGHTS = 19; 
	localparam NUMBER_OF_WEIGHTS_HIDDEN = 8;
	localparam TOTAL_NUMBER_OF_WEIGHTS_HIDDEN = 16;
	localparam NUMBER_OF_WEIGHTS_OUTPUT = 3;
	reg [4:0] weights_counter = 0;
	
	localparam TOTAL_NUMBER_OF_OUTPUTS = 64;
	reg [DEPTH_OUTPUT_DATA - 1:0] output_data_counter = 0;
	
	localparam TOTAL_NUMBER_OF_INPUTS = 448;
	
	reg M_AXIS_TLAST_reg = 0;
	
	always @(*) begin
       case (current_state)
           WAIT: begin
               if (S_AXIS_TVALID) begin
                   next_state = READ_INPUTS;
               end else begin
                   next_state = WAIT;
               end
           end
           
           READ_INPUTS: begin
               if (weights_counter < TOTAL_NUMBER_OF_WEIGHTS) begin
                   next_state = READ_INPUTS;
               end else begin
                   next_state = COMPUTATION;
               end
           end
           
           COMPUTATION: begin
               if (Done) begin
                   next_state = SEND_OUTPUTS;
               end else begin
                   next_state = COMPUTATION;
               end
           end
           
           SEND_OUTPUTS: begin
               if (M_AXIS_TREADY && M_AXIS_TLAST_reg) begin
                   next_state = WAIT;
               end else begin
                   next_state = SEND_OUTPUTS;
               end
           end
           
           default: next_state = WAIT;
       endcase
	end
    
    // Control Block
	always @(posedge ACLK) begin
	   case (current_state)
	       WAIT: begin
	           if (S_AXIS_TVALID) begin
	               S_AXIS_TREADY <= 1;
	           end else begin
	               S_AXIS_TREADY <= 0;
	           end
	           
	           weight_write_enable_0 <= 0;
	           weight_write_enable_1 <= 0;
	           weights_counter <= 0;
	           output_data_counter <= 0;
	           M_AXIS_TLAST_reg <= 0;
	           M_AXIS_TVALID <= 0;
	       end
	       
	       READ_INPUTS: begin
	           S_AXIS_TREADY <= 1;
	           
	           if (S_AXIS_TVALID) begin
                   if (weights_counter < TOTAL_NUMBER_OF_WEIGHTS) begin
                       weights_counter <= weights_counter + 1;
                       
                       if (weights_counter == 0) begin
                           bias_weight_0 <= S_AXIS_TDATA;
                       end else if (weights_counter == 8) begin
                           bias_weight_1 <= S_AXIS_TDATA;
                       end else if (weights_counter < NUMBER_OF_WEIGHTS_HIDDEN) begin
                           weight_write_enable_0 <= 1;
                           weight_write_address <= weights_counter - 1;
                           weight_write_input <= S_AXIS_TDATA;
                       end else if (weights_counter < TOTAL_NUMBER_OF_WEIGHTS_HIDDEN) begin
                           weight_write_enable_0 <= 0;
                           weight_write_enable_1 <= 1;
                           weight_write_address <= weights_counter - 5'd9;
                           weight_write_input <= S_AXIS_TDATA;
                       end else begin
                           case (weights_counter)
                               5'd16: bias_weight_output <= S_AXIS_TDATA;
                               5'd17: weight0_output <= S_AXIS_TDATA;
                               5'd18: weight1_output <= S_AXIS_TDATA;
                           endcase
                           
                           weight_write_enable_0 <= 0;
                           weight_write_enable_1 <= 0;
                       end
                   end else begin
                       Start <= 1;
                       S_AXIS_TREADY <= 0;
                   end
	           end
	           
	           if (weights_counter == TOTAL_NUMBER_OF_WEIGHTS) begin
	               Start <= 1;
                   S_AXIS_TREADY <= 0;
	           end
	       end
	       
	       COMPUTATION: begin
	           Start <= 0;
	           S_AXIS_TREADY <= 1;
	           if (S_AXIS_TVALID) begin
	               sample_data_read_input <= S_AXIS_TDATA;
               end

	           if (Done) begin
	               M_AXIS_TVALID <= 0;
	               output_read_enable <= 1;
	               output_data_counter <= 0;
	               S_AXIS_TREADY <= 0;
	           end
	       end
	       
	       SEND_OUTPUTS: begin
	          M_AXIS_TVALID <= 1;
	          
	          if (M_AXIS_TREADY == 1) begin
                  if (output_data_counter < TOTAL_NUMBER_OF_OUTPUTS - 1) begin
                      output_read_enable  <= 1;
                      output_data_counter <= output_data_counter + 1;
                  end
                  
                  if (output_data_counter == TOTAL_NUMBER_OF_OUTPUTS - 1) begin
                      M_AXIS_TLAST_reg <= 1;  
                  end
	          end 
	       end
	   endcase
	end

	
	assign output_read_data_address = output_data_counter;
	assign M_AXIS_TLAST = M_AXIS_TLAST_reg;
	assign M_AXIS_TDATA = {{(32 - WIDTH_OUTPUT_DATA){1'b0}}, output_read_data};
	
	always @(posedge ACLK) begin
	   if (!ARESETN) begin
	       current_state <= WAIT;
	   end else begin
	       current_state <= next_state;
	   end
	end
	
	wire hidden_data_second_output_enable_0;
    wire [15:0] hidden_data_second_multiply_0_0;
    wire [15:0] hidden_data_second_multiply_1_0;
    wire [15:0] hidden_data_second_phase_one_sum_0;
    wire [15:0] hidden_data_second_phase_two_sum_0;
    wire hidden_data_second_output_enable_1;
    wire [15:0] hidden_data_second_multiply_0_1;
    wire [15:0] hidden_data_second_multiply_1_1;
    wire [15:0] hidden_data_second_phase_one_sum_1;
    wire [15:0] hidden_data_second_phase_two_sum_1;
	
	output_layer #(
	   .WIDTH_HIDDEN_DATA(WIDTH_HIDDEN_DATA),
	   .WIDTH_WEIGHT_INPUT(WIDTH_WEIGHT_INPUT),
	   .WIDTH_OUTPUT_DATA(WIDTH_OUTPUT_DATA),
	   .DEPTH_OUTPUT_DATA(DEPTH_OUTPUT_DATA),
	   .TOTAL_NUMBER_OF_OUTPUTS(TOTAL_NUMBER_OF_OUTPUTS)
	) out_layer (
	   .clk(ACLK),
	   .ARESETN(ARESETN),
	   .hidden_data_output_enable_0(hidden_data_output_enable_0),
	   .hidden_data_output_enable_1(hidden_data_output_enable_1),
	   .hidden_data_output_0(hidden_data_output_0),
	   .hidden_data_output_1(hidden_data_output_1),
	   .bias_weight_output(bias_weight_output),
	   .weight0_output(weight0_output),
	   .weight1_output(weight1_output),
	   .Done(Done),
	   .output_write_enable(output_write_enable),
	   .output_write_data(output_write_data),
	   .output_write_data_address(output_write_data_address)
	);
	
	hidden_layer_first #(
	   .WIDTH_WEIGHT_INPUT(WIDTH_WEIGHT_INPUT),
	   .WIDTH_SAMPLE_DATA_INPUT(WIDTH_SAMPLE_DATA_INPUT),
	   .DEPTH_WEIGHT_INPUT(DEPTH_WEIGHT_INPUT),
	   .WIDTH_HIDDEN_DATA(WIDTH_HIDDEN_DATA),
	   .NUMBER_OF_WEIGHTS_HIDDEN(NUMBER_OF_WEIGHTS_HIDDEN),
	   .DEPTH_OUTPUT_DATA(DEPTH_OUTPUT_DATA),
	   .TOTAL_NUMBER_OF_OUTPUTS(TOTAL_NUMBER_OF_OUTPUTS),
	   .TOTAL_NUMBER_OF_INPUTS(TOTAL_NUMBER_OF_INPUTS)
	) hidden_layer_first_0 (
	   .clk(ACLK),
	   .ARESETN(ARESETN),
	   .Start(Start),
	   .weight_bias(bias_weight_0),
	   .weight_read_input(weight_read_output_0),
	   .sample_data_read_input(sample_data_read_input),
	   .weight_read_enable(weight_read_enable_0),
	   .weight_read_address(weight_read_address_0),
	   .hidden_data_second_output_enable(hidden_data_second_output_enable_0),
	   .hidden_data_second_multiply_0(hidden_data_second_multiply_0_0),
	   .hidden_data_second_multiply_1(hidden_data_second_multiply_1_0),
	   .hidden_data_second_phase_one_sum(hidden_data_second_phase_one_sum_0),
	   .hidden_data_second_phase_two_sum(hidden_data_second_phase_two_sum_0)
	);
	
	hidden_layer_first #(
	   .WIDTH_WEIGHT_INPUT(WIDTH_WEIGHT_INPUT),
	   .WIDTH_SAMPLE_DATA_INPUT(WIDTH_SAMPLE_DATA_INPUT),
	   .DEPTH_WEIGHT_INPUT(DEPTH_WEIGHT_INPUT),
	   .WIDTH_HIDDEN_DATA(WIDTH_HIDDEN_DATA),
	   .NUMBER_OF_WEIGHTS_HIDDEN(NUMBER_OF_WEIGHTS_HIDDEN),
	   .DEPTH_OUTPUT_DATA(DEPTH_OUTPUT_DATA),
	   .TOTAL_NUMBER_OF_OUTPUTS(TOTAL_NUMBER_OF_OUTPUTS),
	   .TOTAL_NUMBER_OF_INPUTS(TOTAL_NUMBER_OF_INPUTS)
	) hidden_layer_first_1 (
	   .clk(ACLK),
	   .ARESETN(ARESETN),
	   .Start(Start),
	   .weight_bias(bias_weight_1),
	   .weight_read_input(weight_read_output_1),
	   .sample_data_read_input(sample_data_read_input),
	   .weight_read_enable(weight_read_enable_1),
	   .weight_read_address(weight_read_address_1),
	   .hidden_data_second_output_enable(hidden_data_second_output_enable_1),
	   .hidden_data_second_multiply_0(hidden_data_second_multiply_0_1),
	   .hidden_data_second_multiply_1(hidden_data_second_multiply_1_1),
	   .hidden_data_second_phase_one_sum(hidden_data_second_phase_one_sum_1),
	   .hidden_data_second_phase_two_sum(hidden_data_second_phase_two_sum_1)
	);
	
	hidden_layer_second #(
	   .WIDTH_WEIGHT_INPUT(WIDTH_WEIGHT_INPUT),
	   .WIDTH_SAMPLE_DATA_INPUT(WIDTH_SAMPLE_DATA_INPUT),
	   .DEPTH_WEIGHT_INPUT(DEPTH_WEIGHT_INPUT),
	   .WIDTH_HIDDEN_DATA(WIDTH_HIDDEN_DATA),
	   .NUMBER_OF_WEIGHTS_HIDDEN(NUMBER_OF_WEIGHTS_HIDDEN),
	   .DEPTH_OUTPUT_DATA(DEPTH_OUTPUT_DATA),
	   .TOTAL_NUMBER_OF_OUTPUTS(TOTAL_NUMBER_OF_OUTPUTS)
	) hidden_layer_second_0 (
	   .clk(ACLK),
	   .ARESETN(ARESETN),
	   .hidden_data_second_output_enable(hidden_data_second_output_enable_0),
	   .hidden_data_second_multiply_0(hidden_data_second_multiply_0_0),
	   .hidden_data_second_multiply_1(hidden_data_second_multiply_1_0),
	   .hidden_data_second_phase_one_sum(hidden_data_second_phase_one_sum_0),
	   .hidden_data_second_phase_two_sum(hidden_data_second_phase_two_sum_0),
	   .hidden_data_output_enable(hidden_data_output_enable_0),
	   .hidden_data_output(hidden_data_output_0)
	);

	hidden_layer_second #(
	   .WIDTH_WEIGHT_INPUT(WIDTH_WEIGHT_INPUT),
	   .WIDTH_SAMPLE_DATA_INPUT(WIDTH_SAMPLE_DATA_INPUT),
	   .DEPTH_WEIGHT_INPUT(DEPTH_WEIGHT_INPUT),
	   .WIDTH_HIDDEN_DATA(WIDTH_HIDDEN_DATA),
	   .NUMBER_OF_WEIGHTS_HIDDEN(NUMBER_OF_WEIGHTS_HIDDEN),
	   .DEPTH_OUTPUT_DATA(DEPTH_OUTPUT_DATA),
	   .TOTAL_NUMBER_OF_OUTPUTS(TOTAL_NUMBER_OF_OUTPUTS)
	) hidden_layer_second_1 (
	   .clk(ACLK),
	   .ARESETN(ARESETN),
	   .hidden_data_second_output_enable(hidden_data_second_output_enable_1),
	   .hidden_data_second_multiply_0(hidden_data_second_multiply_0_1),
	   .hidden_data_second_multiply_1(hidden_data_second_multiply_1_1),
	   .hidden_data_second_phase_one_sum(hidden_data_second_phase_one_sum_1),
	   .hidden_data_second_phase_two_sum(hidden_data_second_phase_two_sum_1),
	   .hidden_data_output_enable(hidden_data_output_enable_1),
	   .hidden_data_output(hidden_data_output_1)
	);
	
	memory_RAM #(
	   .width(WIDTH_OUTPUT_DATA), 
	   .depth_bits(DEPTH_OUTPUT_DATA)
    ) output_layer_RAM (
       .clk(ACLK),
       .write_en(output_write_enable),
       .write_address(output_write_data_address),
       .write_data_in(output_write_data),
       .read_en(output_read_enable),
       .read_address(output_read_data_address),
       .read_data_out(output_read_data)
    );
	
	memory_RAM #(
	   .width(WIDTH_WEIGHT_INPUT), 
	   .depth_bits(DEPTH_WEIGHT_INPUT)
    ) weight_hidden_layer_RAM_0 (
       .clk(ACLK),
       .write_en(weight_write_enable_0),
       .write_address(weight_write_address),
       .write_data_in(weight_write_input),
       .read_en(weight_read_enable_0),
       .read_address(weight_read_address_0),
       .read_data_out(weight_read_output_0)
    );
    
    memory_RAM #(
	   .width(WIDTH_WEIGHT_INPUT), 
	   .depth_bits(DEPTH_WEIGHT_INPUT)
    ) weight_hidden_layer_RAM_1 (
       .clk(ACLK),
       .write_en(weight_write_enable_1),
       .write_address(weight_write_address),
       .write_data_in(weight_write_input),
       .read_en(weight_read_enable_1),
       .read_address(weight_read_address_1),
       .read_data_out(weight_read_output_1)
    );
    
endmodule
