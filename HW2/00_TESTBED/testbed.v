`timescale 1ns/100ps
`define CYCLE       10.0
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   120000
`define RST_DELAY   5

`ifdef p0
    `define Inst "../00_TESTBED/PATTERN/p0/inst.dat"
    `define Status "../00_TESTBED/PATTERN/p0/status.dat"
    `define Data "../00_TESTBED/PATTERN/p0/data.dat"
`endif
`ifdef p1
	`define Inst "../00_TESTBED/PATTERN/p1/inst.dat"
    `define Status "../00_TESTBED/PATTERN/p1/status.dat"
    `define Data "../00_TESTBED/PATTERN/p1/data.dat"
`endif

module testbed;

	wire clk, rst_n;
	wire [ 31 : 0 ] imem_addr;
	wire [ 31 : 0 ] imem_inst;
	wire            dmem_wen;
	wire [ 31 : 0 ] dmem_addr;
	wire [ 31 : 0 ] dmem_wdata;
	wire [ 31 : 0 ] dmem_rdata;
	wire [  1 : 0 ] mips_status;
	wire            mips_status_valid;

	reg [31:0] golden_data    [0:63];
	reg [31:0] output_data   [0:63];
	reg [ 1:0] golden_status  [0:1023];
	reg [ 1:0] output_status [0:1023];

	integer flag, i, j, error_status, error_data, total_cycles;

	initial begin
		$readmemb (`Inst, u_inst_mem.mem_r); 
		$readmemb (`Data, golden_data);
		$readmemb (`Status, golden_status);
	end

	initial begin
		//$dumpfile("core.vcd");
		//$dumpvars;
		$fsdbDumpfile("core.fsdb");
		$fsdbDumpvars(0,"+mda");
	end

	
	initial begin
		i = 0;
		error_status = 0;
		error_data = 0;
		flag = 0;
		total_cycles = 0;
		
		while ( i < 1024 && !flag ) begin
			@(negedge clk)
			if( mips_status_valid )begin
				output_status[i] = mips_status;
				if(mips_status == 2'd2 || mips_status == 2'd3) flag = 1;
				
				i = i + 1;
			end
			total_cycles = total_cycles + 1;
		end

		for( j = 0; j < i; j = j + 1 ) begin
			if( golden_status[j] != output_status[j] ) begin
				error_status = error_status + 1;
				$display ( "Status Error(%d)! expected=%b, yours=%b", j, golden_status[j], output_status[j]); 
			end
		end

		for(j = 0; j < 64; j = j + 1) begin
			if( golden_data[j] != u_data_mem.mem_r[j] ) begin
				$display ("Data Error(%d)! expected=%b, yours=%b", j, golden_data[j], u_data_mem.mem_r[j]);
				error_data = error_data + 1;
			end
		end
		
		if( error_data == 0 && error_status ==0 ) begin
			$display ("----------------------------------------------------------------------------------------------------------------------");
			$display ("                                                  Congratulations!                                                    ");
			$display ("                                           You have passed all patterns!                                              ");
			$display ("                                                                                                                      ");
			$display ("                                        Your execution cycles   = %5d cycles                                          ", total_cycles);
			$display ("                                        Your clock period       = %.1f ns                                             ", `CYCLE);
			$display ("----------------------------------------------------------------------------------------------------------------------");
		end
		$finish;
    end

	core u_core (
		.i_clk( clk ),
		.i_rst_n( rst_n ),
		.o_i_addr( imem_addr ),
		.i_i_inst( imem_inst ),
		.o_d_wen( dmem_wen ),
		.o_d_addr( dmem_addr ),
		.o_d_wdata( dmem_wdata ),
		.i_d_rdata( dmem_rdata ),
		.o_status( mips_status ),
		.o_status_valid( mips_status_valid )
	);

	inst_mem  u_inst_mem (
		.i_clk( clk ),
		.i_rst_n( rst_n ),
		.i_addr( imem_addr ),
		.o_inst( imem_inst )
	);

	data_mem  u_data_mem (
		.i_clk( clk ),
		.i_rst_n( rst_n ),
		.i_wen( dmem_wen ),
		.i_addr( dmem_addr ),
		.i_wdata( dmem_wdata ),
		.o_rdata( dmem_rdata )
	);

	Clkgen u_clk (
        .clk( clk ),
        .rst_n( rst_n )
    );
	
endmodule

module Clkgen (
    output reg clk,
    output reg rst_n
);
    always # (`HCYCLE) clk = ~clk;

    initial begin
        clk = 1'b1;
        rst_n = 1; # (               0.25 * `CYCLE);
        rst_n = 0; # ((`RST_DELAY - 0.25) * `CYCLE);
        rst_n = 1; # (         `MAX_CYCLE * `CYCLE);
        $display("----------------------------------------------");
        $display("Latency of your design is over 120000 cycles!!");
        $display("----------------------------------------------");
        $finish;
    end
	
endmodule