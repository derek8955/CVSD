module alu #(
    parameter INT_W  = 3,
    parameter FRAC_W = 5,
    parameter INST_W = 3,
    parameter DATA_W = INT_W + FRAC_W
)(
    input                     i_clk,
    input                     i_rst_n,
    input                     i_valid,
    input signed [DATA_W-1:0] i_data_a,
    input signed [DATA_W-1:0] i_data_b,
    input        [INST_W-1:0] i_inst,
    output                    o_valid,
    output signed      [DATA_W-1:0] o_data
);
// ---------------------------------------------------------------------------
// Paramerter & genvar & integer 
// ---------------------------------------------------------------------------
   parameter OP_ADD 	= 3'd0,
			 OP_SUB 	= 3'd1,
			 OP_MULT 	= 3'd2,
			 OP_NAND 	= 3'd3,
			 OP_XNOR	= 3'd4,
			 OP_SIGMOID = 3'd5,
			 OP_SHIFT 	= 3'd6,
			 OP_MIN 	= 3'd7;
	
integer i;
	
// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
reg signed [DATA_W:0] o_data_w, o_data_r;
reg             o_valid_w, o_valid_r;

wire [DATA_W-2:0]	upper_limit;
wire [DATA_W-2:0]	bottom_limit;
wire signed [DATA_W*2-1:0] mult;
wire signed [DATA_W-1:0] signed_sigmoid;
wire signed [DATA_W-1:0] compare_positive;
wire signed [DATA_W-1:0] compare_negtive;
wire [DATA_W-1:0] 	unsigned_idatab;
wire [DATA_W-1:0] 	amount_shift;

wire [DATA_W-1:0] 	shift0, shift1, shift2, shift3, shift4, shift5, shift6, shift7;

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
assign o_valid = o_valid_r;
assign o_data = o_data_r;

assign upper_limit = ~i_data_a[6:0];
assign bottom_limit = i_data_a[6:0];
assign mult = i_data_a * i_data_b;
assign signed_sigmoid = (i_data_a >>> 2);
assign compare_positive = 8'b01100000 ;
assign compare_negtive = 8'b11000000 ;
assign unsigned_idatab = i_data_b;
assign amount_shift = unsigned_idatab % 8;

assign shift0 = i_data_a;
assign shift1 = {i_data_a[0],i_data_a[7:1]};
assign shift2 = {i_data_a[1:0],i_data_a[7:2]};
assign shift3 = {i_data_a[2:0],i_data_a[7:3]};
assign shift4 = {i_data_a[3:0],i_data_a[7:4]};
assign shift5 = {i_data_a[4:0],i_data_a[7:5]};
assign shift6 = {i_data_a[5:0],i_data_a[7:6]};
assign shift7 = {i_data_a[6:0],i_data_a[7]};

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
always@(*) o_valid_w = i_valid;

always@(*) begin	
	if( i_valid ) begin
		case( i_inst )
		OP_ADD : begin
			if( i_data_a[7] ) begin
				if( i_data_b[7] == 0 ) o_data_w = i_data_a + i_data_b;	
				else if( -i_data_b > bottom_limit ) o_data_w = -128;
				else o_data_w = i_data_a + i_data_b;	
			end
			else begin
				if( i_data_b[7] ) o_data_w = i_data_a + i_data_b;	
				else if( i_data_b > upper_limit ) o_data_w = 127;
				else o_data_w = i_data_a + i_data_b;	
			end
		end
		OP_SUB : begin
			if( i_data_a[7] ) begin
				if( i_data_b[7] ) o_data_w = i_data_a - i_data_b;	
				else if( i_data_b > bottom_limit ) o_data_w = -128;
				else o_data_w = i_data_a - i_data_b;	
			end
			else begin
				if( i_data_b[7] == 0 ) o_data_w = i_data_a - i_data_b;	
				else if( -i_data_b > upper_limit ) o_data_w = 127;
				else o_data_w = i_data_a - i_data_b;	
			end
		end
		OP_MULT : begin
			if( mult[15] == 0 ) begin
				if( mult[14:10] > 3 ) o_data_w = 127;
				else o_data_w = ( mult[4] )? mult[12:5] + 1 : mult[12:5];
			end
			else begin
				if( mult[14:10] < 5'b11100 ) o_data_w = -128;
				else o_data_w = ( mult[4] )? {1'b1,mult[11:5]+1'b1}: {1'b1,mult[11:5]};
			end

		end
		OP_NAND : o_data_w = ~(i_data_a & i_data_b);	
		OP_XNOR	: o_data_w = ~(i_data_a ^ i_data_b);
		OP_SIGMOID : begin 
			if( i_data_a >= compare_positive ) o_data_w = 8'b00100000;
			else if( i_data_a <= compare_negtive ) o_data_w = 0;
			else o_data_w = 8'b00010000 + signed_sigmoid;
		end
		OP_SHIFT : begin 
			case(amount_shift)
			0: o_data_w = shift0;	
			1: o_data_w = shift1;	
			2: o_data_w = shift2;	
			3: o_data_w = shift3;	
			4: o_data_w = shift4;	
			5: o_data_w = shift5;	
			6: o_data_w = shift6;	
			7: o_data_w = shift7;	
			endcase
		end
		OP_MIN : begin 
			if( i_data_a > i_data_b ) o_data_w = i_data_b;
			else o_data_w = i_data_a;
		end
		endcase
	end
	else 	o_data_w = 0;
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
always@(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        o_data_r  <= 0;
        o_valid_r <= 0;
    end 
	else begin
        o_data_r  <= o_data_w;
        o_valid_r <= o_valid_w;
    end
end
endmodule



