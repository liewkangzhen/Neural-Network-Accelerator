`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.04.2026 04:16:28
// Design Name: 
// Module Name: input_layer_tb
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


`timescale 1ns / 1ps

module input_layer_tb;
    reg         ACLK    = 0;
    reg         ARESETN = 0;

    // AXI Slave (sending TO DUT)
    wire        S_AXIS_TREADY;
    reg  [31:0] S_AXIS_TDATA  = 0;
    reg         S_AXIS_TLAST  = 0;
    reg         S_AXIS_TVALID = 0;

    // AXI Master (receiving FROM DUT)
    wire        M_AXIS_TVALID;
    wire [31:0] M_AXIS_TDATA;
    wire        M_AXIS_TLAST;
    reg         M_AXIS_TREADY = 0;

    // Memory arrays loaded from .mem files
    // 19 weights:
    //   [0:7]   -> hidden_layer_0 weights (8 values)
    //   [8:15]  -> hidden_layer_1 weights (8 values)
    //   [16]    -> bias_weight_output
    //   [17]    -> weight0_output
    //   [18]    -> weight1_output
    reg [7:0] weights_mem [0:18];
    reg [7:0] sample_mem  [0:447];
    reg [0:0] expected_mem [0:63];
    reg [0:0] result_mem [0:63];
    
    // indicators
    reg M_AXIS_TLAST_prev = 1'b0;
    reg success = 1'b1;
    
    // Counters
    localparam TOTAL_NUMBER_OF_WEIGHTS = 19; 
    localparam TOTAL_NUMBER_SAMPLE_DATA = 448;
    localparam TOTAL_NUMBER_OUTPUT = 64;
    reg [4:0] weights_counter = 0;
    reg [8:0] sample_data_counter = 0;
    reg [6:0] output_counter = 0;
    reg [6:0] success_counter = 0;
    reg [6:0] fail_counter = 0;
    
    always #50 ACLK = ~ACLK;
	
	always@(posedge ACLK)
		M_AXIS_TLAST_prev <= M_AXIS_TLAST;
    
    initial begin
        $display("Loading Memory.");
        $readmemh("weights.mem", weights_mem);
        $readmemh("samples.mem", sample_mem);
        $readmemh("expected_output.mem", expected_mem);
        #25;
        S_AXIS_TVALID = 1'b0;   // no valid data placed on the S_AXIS_TDATA yet
        S_AXIS_TLAST = 1'b0; 	// not required unless we are dealing with an unknown number of inputs. Ignored by the coprocessor. We will be asserting it correctly anyway
        M_AXIS_TREADY = 1'b0;	// not ready to receive data from the co-processor yet.   

        #100 					// hold reset for 100 ns.
        ARESETN = 1'b1;			// release reset
        
        weights_counter = 0;
        S_AXIS_TVALID = 1'b1;
        while (weights_counter < TOTAL_NUMBER_OF_WEIGHTS) begin
            if(S_AXIS_TREADY) begin
                S_AXIS_TDATA = weights_mem[weights_counter];
                if (weights_counter == TOTAL_NUMBER_OF_WEIGHTS - 1) begin
                    S_AXIS_TLAST = 1'b1; 
                end else begin
                    S_AXIS_TLAST = 1'b0; 
                end
                weights_counter = weights_counter + 1;
            end
            #100;
        end
        
        S_AXIS_TVALID = 1'b1;
        S_AXIS_TLAST = 1'b0;
        M_AXIS_TREADY = 1'b1;
        while (sample_data_counter < TOTAL_NUMBER_SAMPLE_DATA) begin
            if (S_AXIS_TREADY) begin
                S_AXIS_TDATA = sample_mem[sample_data_counter];
                if (sample_data_counter == TOTAL_NUMBER_SAMPLE_DATA - 1) begin
                    S_AXIS_TLAST = 1'b1; 
                end else begin
                    S_AXIS_TLAST = 1'b0; 
                end
                sample_data_counter = sample_data_counter + 1;
            end
            #100;
        end
        
        S_AXIS_TVALID = 1'b0;
        S_AXIS_TLAST = 1'b0;
        
        output_counter = 0;

        while(~M_AXIS_TLAST_prev) begin
            if(M_AXIS_TVALID) begin
                result_mem[output_counter] = M_AXIS_TDATA;
                output_counter = output_counter + 1;
            end
            #100;
        end
        M_AXIS_TREADY = 1'b0;
        
        
        output_counter = 0;
        success_counter = 0;
        fail_counter = 0;
        for(output_counter = 0; output_counter < TOTAL_NUMBER_OUTPUT; output_counter = output_counter + 1) begin
            success = success & (result_mem[output_counter] == expected_mem[output_counter]);
            if (result_mem[output_counter] == expected_mem[output_counter]) begin
                success_counter = success_counter + 1;
            end else begin
                fail_counter = fail_counter + 1;
            end
        end
        
        if(success)
            $display("Test Passed.");
        else
            $display("Test Failed.");
            
        $display("success_counter=%d, fail_counter=%d", success_counter, fail_counter);
            
        $finish();
    end
    
    input_layer dut (
        .ACLK          (ACLK),
        .ARESETN       (ARESETN),
        .S_AXIS_TREADY (S_AXIS_TREADY),
        .S_AXIS_TDATA  (S_AXIS_TDATA),
        .S_AXIS_TLAST  (S_AXIS_TLAST),
        .S_AXIS_TVALID (S_AXIS_TVALID),
        .M_AXIS_TVALID (M_AXIS_TVALID),
        .M_AXIS_TDATA  (M_AXIS_TDATA),
        .M_AXIS_TLAST  (M_AXIS_TLAST),
        .M_AXIS_TREADY (M_AXIS_TREADY)
    );

endmodule
