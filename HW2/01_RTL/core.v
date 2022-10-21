module core #(                             //Don't modify interface
	parameter ADDR_W = 32,
	parameter INST_W = 32,
	parameter DATA_W = 32
)(
	input                   i_clk,
	input                   i_rst_n,
	output reg [ ADDR_W-1 : 0 ] o_i_addr,
	input  [ INST_W-1 : 0 ] i_i_inst,
	output reg                 o_d_wen,
	output reg [ ADDR_W-1 : 0 ] o_d_addr,
	output reg [ DATA_W-1 : 0 ] o_d_wdata,
	input  [ DATA_W-1 : 0 ] i_d_rdata,
	output  [    1 : 0 ] o_status,
	output               o_status_valid 
);
// ---------------------------------------------------------------------------
// parameter / genvar / integer 
// ---------------------------------------------------------------------------
parameter 	STATE_IDLE 		= 	3'd0, 
			STATE_FETCH		=	3'd1, // Fetchinh from instruction code 
			STATE_DECODE 	=	3'd2, // Decoding from instruction code 
			STATE_COMPUTE 	=	3'd3, // Conputing ALU operation and load data into register file
			STATE_LOAD    	=   3'd4, // Load data from reg_file
			STATE_WRITE		=	3'd5, // Write data into reg_file
			STATE_PC 		=	3'd6, // Program counter 
			STATE_FINISH 	=	3'd7;

integer idx;

// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------

// Register File 
reg [DATA_W-1:0] reg_file[0:DATA_W-1];
reg [DATA_W-1:0] reg_file_w;

wire [DATA_W-1:0] u_tmp1, u_tmp2;
wire signed[DATA_W-1:0] tmp1, tmp2;

// Use in ADDU operation 
wire [DATA_W:0] overflow ;
assign overflow = u_tmp1 + u_tmp2;

// FSM
reg [2:0] cur_state, nx_state;

// Instruction mapping
wire [5:0 ] opcode;
wire [4:0 ] rtype_s3, rtype_s2, rtype_s1;
wire [4:0 ] itype_s2, itype_s1;
wire [15:0] itype_im;
reg  [1:0 ] inst_type;

// Pre-output
reg [1:0] o_status_w;
reg [ ADDR_W-1 : 0 ] o_i_addr_w;
reg [ ADDR_W-1 : 0 ] o_d_addr_w;

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
assign opcode = i_i_inst[31:26];
assign rtype_s2 = i_i_inst[25:21];
assign rtype_s3 = i_i_inst[20:16];
assign rtype_s1 = i_i_inst[15:11];

assign itype_s2 = i_i_inst[25:21];
assign itype_s1 = i_i_inst[20:16];
assign itype_im = i_i_inst[15:0];

assign tmp1 = ( inst_type == 0 )? reg_file[rtype_s2] : reg_file[itype_s2];
assign tmp2 = ( inst_type == 0 )? reg_file[rtype_s3] : ( itype_im[15] )? {16'hffff,itype_im} : itype_im ;

assign u_tmp1 = ( inst_type == 0 )? reg_file[rtype_s2] : reg_file[itype_s2];
assign u_tmp2 = ( inst_type == 0 )? reg_file[rtype_s3] : itype_im;

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
always @( * ) begin
	case( opcode ) 
	`OP_ADD, `OP_SUB, `OP_ADDU, `OP_SUBU, `OP_AND, `OP_OR, `OP_NOR, `OP_SLT : 	inst_type = 0;
	`OP_ADDI, `OP_LW, `OP_SW, `OP_BEQ, `OP_BNE  : 								inst_type = 1;
	`OP_EOF: 																	inst_type = 3;
	default: 																	inst_type = 3;
	endcase
end

// ---------------------------------------------------------------------------
// Register File 
// ---------------------------------------------------------------------------
always @( * ) begin
	case( opcode )
	`OP_ADD, `OP_ADDI : reg_file_w = tmp1 + tmp2;
	`OP_SUB : 			reg_file_w = tmp1 - tmp2;
	`OP_ADDU : 			reg_file_w = u_tmp1 + u_tmp2;
	`OP_SUBU : 			reg_file_w = u_tmp1 - u_tmp2;
	`OP_LW : 			reg_file_w = i_d_rdata;
	`OP_AND : 			reg_file_w = tmp1 & tmp2;
	`OP_OR : 			reg_file_w = tmp1 | tmp2;
	`OP_NOR : 			reg_file_w = ~(tmp1 | tmp2);
	`OP_SLT : 			reg_file_w = ( tmp1 < tmp2 )? 1 : 0; 
	default : 			reg_file_w = 0;
	endcase
end

always @( posedge i_clk or negedge i_rst_n ) begin
	if( !i_rst_n ) begin
		for( idx=0 ; idx<DATA_W ; idx=idx+1 ) reg_file[idx] <= 'd0;
	end
	else if( cur_state == STATE_COMPUTE && opcode != `OP_LW && opcode != `OP_SW ) begin
		if( inst_type == 0 ) reg_file[rtype_s1] <= reg_file_w;
		else if( inst_type == 1 ) reg_file[itype_s1] <= reg_file_w;
	end
	else if( cur_state == STATE_WRITE && opcode == `OP_LW ) reg_file[itype_s1] <= reg_file_w;
end

// ---------------------------------------------------------------------------
// Pre_output
// ---------------------------------------------------------------------------
always @( * ) begin
	case( opcode ) 
	`OP_BEQ : o_i_addr_w = ( reg_file[itype_s1] == reg_file[itype_s2] )? o_i_addr + itype_im + 4 : o_i_addr + 4;
	`OP_BNE : o_i_addr_w = ( reg_file[itype_s1] != reg_file[itype_s2] )? o_i_addr + itype_im + 4 : o_i_addr + 4;
	default: o_i_addr_w = o_i_addr + 4;　　
	endcase
end

always @( * ) begin
	if( opcode == `OP_LW || opcode == `OP_SW ) o_d_addr_w = tmp1 + tmp2;
	else o_d_addr_w = 0;
end

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------
assign o_status = o_status_w;
assign o_status_valid = ( cur_state == STATE_PC || cur_state == STATE_FINISH );

always @( * ) begin
	if( opcode == `OP_EOF ) o_status_w = `MIPS_END;
	else o_status_w = ( cur_state == STATE_FINISH  )?`MIPS_OVERFLOW : inst_type;
end

always @( posedge i_clk or negedge i_rst_n ) begin
	if( !i_rst_n ) o_i_addr <= 0;
	else if( cur_state == STATE_PC ) o_i_addr <= o_i_addr_w;
end

always @( posedge i_clk or negedge i_rst_n ) begin
	if( !i_rst_n ) o_d_addr <= 0;
	else if( nx_state == STATE_LOAD ) o_d_addr <= o_d_addr_w[7:0];
end

always @( posedge i_clk or negedge i_rst_n ) begin
	if( !i_rst_n ) begin
		o_d_wdata <= 0;
		o_d_wen <= 0;
	end
	else if( nx_state == STATE_WRITE && opcode == `OP_SW )begin
		o_d_wdata <= reg_file[itype_s1];
		o_d_wen <= 1;
	end
	else begin
		o_d_wdata <= 0;
		o_d_wen <= 0;
	end
end

// ---------------------------------------------------------------------------
// FSM
// ---------------------------------------------------------------------------
always @( posedge i_clk or negedge i_rst_n ) begin
	if( !i_rst_n ) cur_state <= STATE_IDLE;
	else cur_state <= nx_state;
end

always @( * ) begin
	case( cur_state )
	STATE_IDLE: 	nx_state = STATE_FETCH;
	STATE_FETCH: 	nx_state = STATE_DECODE;
	STATE_DECODE: 	begin
		case( opcode ) 
		`OP_ADD, `OP_ADDI : begin
			if( (~tmp1[31] & ~tmp2[31] & reg_file_w[31]) || ( tmp1[31] & tmp2[31] & ~reg_file_w[31] )) 
				nx_state = STATE_FINISH;
			else 
				nx_state = STATE_COMPUTE;
		end
		`OP_SUB : begin
			if( ( tmp1[31] & ~tmp2[31] & ~reg_file_w[31]) || (~tmp1[31] & tmp2[31] & reg_file_w[31]) ) 
				nx_state = STATE_FINISH;
			else 
				nx_state = STATE_COMPUTE;
		end
		`OP_ADDU : nx_state = ( overflow  > 32'hffffffff )? STATE_FINISH : STATE_COMPUTE;
		`OP_SUBU : nx_state = ( u_tmp1 < u_tmp2 )? STATE_FINISH : STATE_COMPUTE;
		`OP_LW, `OP_SW: nx_state = ( ( u_tmp1 + u_tmp2 ) > 32'd255 )? STATE_FINISH : STATE_LOAD;
		`OP_BEQ, `OP_BNE: nx_state = STATE_PC;
		`OP_EOF: nx_state = STATE_FINISH;
		default: nx_state = STATE_COMPUTE;
		endcase
	end
	STATE_COMPUTE: nx_state = STATE_PC;
	STATE_LOAD: nx_state = STATE_WRITE;   
	STATE_WRITE: nx_state = STATE_PC;	
	STATE_PC: begin
		if( opcode == `OP_BEQ || opcode == `OP_BNE )  nx_state = ( o_i_addr_w > 32'd1023 )? STATE_FINISH : STATE_FETCH;
		else nx_state = STATE_FETCH; 
	end
	STATE_FINISH: nx_state = STATE_FINISH; 
	endcase
end
endmodule


