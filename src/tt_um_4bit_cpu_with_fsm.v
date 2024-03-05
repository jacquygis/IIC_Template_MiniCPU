// Copyright 2024 Jacqueline Gislai
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE−2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`default_nettype none
`timescale 1ns/1ps


module tt_um_4bit_cpu_with_fsm (
    input  wire [7:0] ui_in,  	// input data
    input  wire [7:0] uio_in,	// I/Os inputs
    output wire [7:0] uo_out, 	// output data
    input  wire       ena,	// high when design is selected
    input  wire       clk,      // clock
    input  wire       rst_n,    // reset_n - low to reset
    output wire [7:0] uio_oe,	// enable path 0=input
    output wire	[7:0] uio_out   // I/Os outputs - not used
);

    //signals for converting
    wire rst = ! rst_n;
    wire [3:0] out_data;
    wire [7:0] uio_out_unused;
    wire [3:0] in_data = 	ui_in[7:4];  // input data
    wire [3:0] in_addr = 	ui_in[3:0];  // storage addresses
    wire [3:0] in_opcode = 	uio_in [7:4]; // opcode for chosing operations
    wire       in_write_enable   = uio_in[0];  // high when writing for storage is active

    //registerdeclaration accumulator,memory, Flip_Flops write-enabling,FSM-state
    reg [3:0] accumulator;	//accumulator
    reg [3:0] next_accumulator;
    reg [3:0] memory [0:15];	//Storage -array of registers
    reg [3:0] next_memory [0:15];
    reg write_enable_ff;	//Flip-Flop for write-enabling
    reg [3:0] operand_a;	//operand A for ALU
    reg [3:0] next_operand_a;
    reg [3:0] operand_b;	//operand B for ALU
    reg [3:0] next_operand_b;
    integer i = 0; 		//for for-loops
    
    reg [2:0]fsm_state, next_fsm_state;
    localparam IDLE	= 3'b000;
    localparam LOAD	= 3'b001;
    localparam STORE	= 3'b010;
    localparam ADD_SUB	= 3'b011;
    localparam LOGIC	= 3'b100;
    localparam SHIFT	= 3'b101;

    
    //Regproc
    always @(posedge clk or posedge rst) begin
	    if (rst) begin
		    accumulator <= 4'b0000;
		    write_enable_ff <= 1'b0;
		    fsm_state <= IDLE;
		    for (i=0 ; i<=15 ; i = i+1)
		    begin
			    memory[i] <= 4'b0000;
		    end
	    end else begin
		    write_enable_ff <= in_write_enable;
		    fsm_state <= next_fsm_state;
		    operand_a <= next_operand_a;
		    operand_b <= next_operand_b;
		    accumulator <= next_accumulator;
		    for (i=0; i<=15; i = i+1)
		    begin
			    memory[i] <= next_memory[i];
		    end
	    end
	    i = 0;
    end


    //FSM Logik
    always @(posedge clk) begin
	    case(fsm_state)
		    IDLE:	next_fsm_state <=	(in_opcode == 4'b0011) ? LOAD	:
			    				(in_opcode == 4'b0010) ? STORE	:
							(in_opcode == 4'b0000 || in_opcode == 4'b0001) ? ADD_SUB:
							(in_opcode == 4'b0100 || in_opcode == 4'b0101 || in_opcode == 4'b0110 || in_opcode == 4'b0111) ? LOGIC:
							(in_opcode == 4'b1000 || in_opcode == 4'b1001) ? SHIFT  :
							IDLE;
						
		    LOAD: 	next_fsm_state <= IDLE;
		    STORE:	next_fsm_state <= IDLE;
		    ADD_SUB:	next_fsm_state <= IDLE;
		    LOGIC:	next_fsm_state <= IDLE;
		    SHIFT:	next_fsm_state <= IDLE;
		    default:	next_fsm_state <= IDLE;
	    endcase
    end


    //chose operand with MUX
    always @(posedge clk) begin
	    case(in_opcode)
		    4'b0000, 4'b0001, 4'b0101, 4'b0110, 4'b0111: 
		    begin
			    next_operand_a <= accumulator;
		    	    next_operand_b <= in_data;
		    end
		    default: 
		    begin
			    next_operand_a <= in_data;
		    	    next_operand_b <= 4'b0000;
		    end
	    endcase
    end


    //Accumulator-Logic Operations depending on FSM-state
    always @(posedge clk) begin
	    case(fsm_state)
		    IDLE: next_accumulator <= accumulator;
		    LOAD: next_accumulator <= memory[in_addr];
		    STORE: if (write_enable_ff) next_memory[in_addr] <= accumulator; //store if writing is enabled
		    ADD_SUB: next_accumulator <= (in_opcode == 4'b0000) ? operand_a + operand_b: //ADD
			    		    (in_opcode == 4'b0001) ? operand_a - operand_b: //SUB
					    accumulator;
		    LOGIC: next_accumulator <=	(in_opcode == 4'b0101) ? operand_a & operand_b: //AND
						(in_opcode == 4'b0110) ? operand_a | operand_b: //OR
						(in_opcode == 4'b0111) ? operand_a ^ operand_b: //XOR
						(in_opcode == 4'b1000) ? ~operand_a: //NOT
						accumulator;
		    SHIFT: next_accumulator <= 	(in_opcode == 4'b1001) ? operand_a << 1: //SHIFT LEFT
						(in_opcode == 4'b1010) ? operand_a >> 1: //SHIFT LEFT
						accumulator; 
		    default: next_accumulator <= accumulator;
	    endcase
    end


    assign out_data = accumulator;
    assign uo_out = {4'b0000, out_data};
    assign uio_out = 8'b00000000;
    assign uio_oe = 8'b00000000; //used bidirectional pins as input

endmodule
