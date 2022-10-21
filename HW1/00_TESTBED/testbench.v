`timescale 1ns/100ps
`define CYCLE       10.0
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   100000
`define RST_DELAY   5

`define Inst0_I "../00_TESTBED/my_pat/INST0_I.dat"
`define Inst0_O "../00_TESTBED/my_pat/INST0_O.dat"
`define Inst1_I "../00_TESTBED/my_pat/INST1_I.dat"
`define Inst1_O "../00_TESTBED/my_pat/INST1_O.dat"
`define Inst2_I "../00_TESTBED/my_pat/INST2_I.dat"
`define Inst2_O "../00_TESTBED/my_pat/INST2_O.dat"
`define Inst3_I "../00_TESTBED/my_pat/INST3_I.dat"
`define Inst3_O "../00_TESTBED/my_pat/INST3_O.dat"
`define Inst4_I "../00_TESTBED/my_pat/INST4_I.dat"
`define Inst4_O "../00_TESTBED/my_pat/INST4_O.dat"
`define Inst5_I "../00_TESTBED/my_pat/INST5_I.dat"
`define Inst5_O "../00_TESTBED/my_pat/INST5_O.dat"
`define Inst6_I "../00_TESTBED/my_pat/INST6_I.dat"
`define Inst6_O "../00_TESTBED/my_pat/INST6_O.dat"
`define Inst7_I "../00_TESTBED/my_pat/INST7_I.dat"
`define Inst7_O "../00_TESTBED/my_pat/INST7_O.dat"
/*
`define Inst0_I "../00_TESTBED/pattern/INST0_I.dat"
`define Inst0_O "../00_TESTBED/pattern/INST0_O.dat"
`define Inst1_I "../00_TESTBED/pattern/INST1_I.dat"
`define Inst1_O "../00_TESTBED/pattern/INST1_O.dat"
`define Inst2_I "../00_TESTBED/pattern/INST2_I.dat"
`define Inst2_O "../00_TESTBED/pattern/INST2_O.dat"
`define Inst3_I "../00_TESTBED/pattern/INST3_I.dat"
`define Inst3_O "../00_TESTBED/pattern/INST3_O.dat"
`define Inst4_I "../00_TESTBED/pattern/INST4_I.dat"
`define Inst4_O "../00_TESTBED/pattern/INST4_O.dat"
`define Inst5_I "../00_TESTBED/pattern/INST5_I.dat"
`define Inst5_O "../00_TESTBED/pattern/INST5_O.dat"
`define Inst6_I "../00_TESTBED/pattern/INST6_I.dat"
`define Inst6_O "../00_TESTBED/pattern/INST6_O.dat"
`define Inst7_I "../00_TESTBED/pattern/INST7_I.dat"
`define Inst7_O "../00_TESTBED/pattern/INST7_O.dat"
*/
module test_alu;

    parameter INT_W  = 3;
    parameter FRAC_W = 5;
    parameter INST_W = 3;
    parameter DATA_W = INT_W + FRAC_W;

    initial begin
        // $dumpfile("alu_test.vcd");
        // $dumpvars;
        $fsdbDumpfile("alu.fsdb");
        $fsdbDumpvars(0, "+mda");
    end

    wire                  clk;
    wire                  rst_n;
    wire                  ivalid;
    wire [ DATA_W-1 : 0 ] idata_a;
    wire [ DATA_W-1 : 0 ] idata_b;
    wire [ INST_W-1 : 0 ] inst;
    wire                  ovalid;
    wire [ DATA_W-1 : 0 ] odata;

    alu #(
        .INT_W (INT_W),
        .FRAC_W(FRAC_W),
        .INST_W(INST_W)
    ) u_alu (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_valid(ivalid),
        .i_data_a(idata_a),
        .i_data_b(idata_b),
        .i_inst(inst),
        .o_valid(ovalid),
        .o_data(odata)
    );

    alu_test #(
        .INT_W (INT_W),
        .FRAC_W(FRAC_W),
        .INST_W(INST_W)
    ) u_alu_test (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .o_valid(ivalid), //alu_test provide test pattern and valid signals
        .o_data_a(idata_a),
        .o_data_b(idata_b),
        .o_inst(inst),
        .i_valid(ovalid),
        .i_data(odata)
    );

    Clkgen u_clk (
        .clk(clk),
        .rst_n(rst_n)
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
        $display("Latency of your design is over 100000 cycles!!");
        $display("----------------------------------------------");
        $finish;
    end
endmodule

module alu_test #(
    parameter INT_W  = 3,
    parameter FRAC_W = 5,
    parameter INST_W = 3,
    parameter DATA_W = INT_W + FRAC_W
)(
    input                       i_clk,
    input                       i_rst_n,
    output reg                  o_valid,
    output reg [ DATA_W-1 : 0 ] o_data_a,
    output reg [ DATA_W-1 : 0 ] o_data_b,
    output reg [ INST_W-1 : 0 ] o_inst,
    input                       i_valid,
    input      [ DATA_W-1 : 0 ] i_data,
    input                       i_overflow
);
    
    localparam
        Fsm_Idle  = 0,
        Fsm_Inst0 = 1,
        Fsm_Inst1 = 2,
        Fsm_Inst2 = 3,
        Fsm_Inst3 = 4,
        Fsm_Inst4 = 5,
        Fsm_Inst5 = 6,
        Fsm_Inst6 = 7,
        Fsm_Inst7 = 8,
        Fsm_Done  = 9;


    reg  [4:0] cs, ns;
    reg  [7:0] tif_start;
    wire [7:0] tif_done;
    wire [DATA_W-1:0] tif_dataA [7:0];
    wire [DATA_W-1:0] tif_dataB [7:0];
    wire [INST_W-1:0] tif_inst [7:0];
    wire [7:0] tif_valid;
    genvar test_id;

    generate //multiply module instances, because there're 8 test files
        for(test_id = 0; test_id < 8; test_id = test_id + 1) begin: u_tif
            test_interface #(
                .DATA_W(DATA_W),
                .INST_W(INST_W)
            ) inst (
                .i_clk(i_clk),
                .i_rst_n(i_rst_n),
                .i_start(tif_start[test_id]), // separating each test file's start signals
                .o_done(tif_done[test_id]), // separating each test file's done signals
                .i_inst(test_id),
                .o_valid(tif_valid[test_id]),
                .o_data_a(tif_dataA[test_id]),
                .o_data_b(tif_dataB[test_id]),
                .o_inst(tif_inst[test_id]),
                .i_valid(i_valid),
                .i_data(i_data)
            );
        end
    endgenerate

    initial $readmemb (`Inst0_I, u_tif[0].inst.inst_idata);
    initial $readmemb (`Inst0_O, u_tif[0].inst.inst_odata);
    initial $readmemb (`Inst1_I, u_tif[1].inst.inst_idata);
    initial $readmemb (`Inst1_O, u_tif[1].inst.inst_odata);
    initial $readmemb (`Inst2_I, u_tif[2].inst.inst_idata);
    initial $readmemb (`Inst2_O, u_tif[2].inst.inst_odata);
    initial $readmemb (`Inst3_I, u_tif[3].inst.inst_idata);
    initial $readmemb (`Inst3_O, u_tif[3].inst.inst_odata);
    initial $readmemb (`Inst4_I, u_tif[4].inst.inst_idata);
    initial $readmemb (`Inst4_O, u_tif[4].inst.inst_odata);
    initial $readmemb (`Inst5_I, u_tif[5].inst.inst_idata);
    initial $readmemb (`Inst5_O, u_tif[5].inst.inst_odata);
    initial $readmemb (`Inst6_I, u_tif[6].inst.inst_idata);
    initial $readmemb (`Inst6_O, u_tif[6].inst.inst_odata);
    initial $readmemb (`Inst7_I, u_tif[7].inst.inst_idata);
    initial $readmemb (`Inst7_O, u_tif[7].inst.inst_odata);

    // Testcase FSM
    always@(*) begin
        ns = cs;
        case(cs)
            Fsm_Idle : begin
                `ifdef ALL
                    ns = Fsm_Inst0;
                `elsif I0
                    ns = Fsm_Inst0;
                `elsif I1
                    ns = Fsm_Inst1;
                `elsif I2
                    ns = Fsm_Inst2;
                `elsif I3
                    ns = Fsm_Inst3;
                `elsif I4
                    ns = Fsm_Inst4;
                `elsif I5
                    ns = Fsm_Inst5;
                `elsif I6
                    ns = Fsm_Inst6;
                `elsif I7
                    ns = Fsm_Inst7;
                `else
                    ns = Fsm_Inst0;
                `endif
            end
            Fsm_Inst0: begin
                if(tif_done[0]) begin
                    `ifdef I0
                        ns = Fsm_Done;
                    `else
                        ns = Fsm_Inst1;
                    `endif
                end
            end
            Fsm_Inst1: begin
                if(tif_done[1]) begin
                    `ifdef I1
                        ns = Fsm_Done;
                    `else
                        ns = Fsm_Inst2;
                    `endif
                end
            end
            Fsm_Inst2: begin
                if(tif_done[2]) begin
                    `ifdef I2
                        ns = Fsm_Done;
                    `else
                        ns = Fsm_Inst3;
                    `endif
                end
            end
            Fsm_Inst3: begin
                if(tif_done[3]) begin
                    `ifdef I3
                        ns = Fsm_Done;
                    `else
                        ns = Fsm_Inst4;
                    `endif
                end
            end
            Fsm_Inst4: begin
                if(tif_done[4]) begin
                    `ifdef I4
                        ns = Fsm_Done;
                    `else
                        ns = Fsm_Inst5;
                    `endif
                end
            end
            Fsm_Inst5: begin
                if(tif_done[5]) begin
                    `ifdef I5
                        ns = Fsm_Done;
                    `else
                        ns = Fsm_Inst6;
                    `endif
                end
            end
            Fsm_Inst6: begin
                if(tif_done[6]) begin
                    `ifdef I6
                        ns = Fsm_Done;
                    `else
                        ns = Fsm_Inst7;
                    `endif
                end
            end
            Fsm_Inst7: begin
                if(tif_done[7]) begin
                    ns = Fsm_Done;
                end
            end
            Fsm_Done : begin
                ns = Fsm_Done;
                $finish;
            end
        endcase
    end

    // Test interface enable
    always@(*) begin
        tif_start = 0;
        case(cs)
            Fsm_Inst0: tif_start[0] = 1'b1;
            Fsm_Inst1: tif_start[1] = 1'b1;
            Fsm_Inst2: tif_start[2] = 1'b1;
            Fsm_Inst3: tif_start[3] = 1'b1;
            Fsm_Inst4: tif_start[4] = 1'b1;
            Fsm_Inst5: tif_start[5] = 1'b1;
            Fsm_Inst6: tif_start[6] = 1'b1;
            Fsm_Inst7: tif_start[7] = 1'b1;
        endcase
    end

    // Data output selection
    always@(*) begin
        o_valid = 0;
        o_data_a = 0;
        o_data_b = 0;
        o_inst = 0;
        case(cs)
            Fsm_Inst0: begin
                o_valid = tif_valid[0];
                o_data_a = tif_dataA[0];
                o_data_b = tif_dataB[0];
                o_inst = tif_inst[0];
            end
            Fsm_Inst1: begin
                o_valid = tif_valid[1];
                o_data_a = tif_dataA[1];
                o_data_b = tif_dataB[1];
                o_inst = tif_inst[1];
            end
            Fsm_Inst2: begin
                o_valid = tif_valid[2];
                o_data_a = tif_dataA[2];
                o_data_b = tif_dataB[2];
                o_inst = tif_inst[2];
            end
            Fsm_Inst3: begin
                o_valid = tif_valid[3];
                o_data_a = tif_dataA[3];
                o_data_b = tif_dataB[3];
                o_inst = tif_inst[3];
            end
            Fsm_Inst4: begin
                o_valid = tif_valid[4];
                o_data_a = tif_dataA[4];
                o_data_b = tif_dataB[4];
                o_inst = tif_inst[4];
            end
            Fsm_Inst5: begin
                o_valid = tif_valid[5];
                o_data_a = tif_dataA[5];
                o_data_b = tif_dataB[5];
                o_inst = tif_inst[5];
            end
            Fsm_Inst6: begin
                o_valid = tif_valid[6];
                o_data_a = tif_dataA[6];
                o_data_b = tif_dataB[6];
                o_inst = tif_inst[6];
            end
            Fsm_Inst7: begin
                o_valid = tif_valid[7];
                o_data_a = tif_dataA[7];
                o_data_b = tif_dataB[7];
                o_inst = tif_inst[7];
            end
        endcase
    end

    always@(negedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            cs <= Fsm_Idle;
        end else begin
            cs <= ns;
        end
    end

endmodule

module test_interface #(
    parameter DATA_W = 8,
    parameter INST_W = 3
)(
    input                   i_clk,
    input                   i_rst_n,

    input                   i_start,
    output                  o_done,
    input  [ INST_W-1 : 0 ] i_inst,
    
    output                  o_valid,
    output [ DATA_W-1 : 0 ] o_data_a,
    output [ DATA_W-1 : 0 ] o_data_b,
    output [ INST_W-1 : 0 ] o_inst,
    input                   i_valid,
    input  [ DATA_W-1 : 0 ] i_data
);

    localparam
        Test_Idle   = 0,
        Test_Read   = 1,
        Test_Write  = 2,
        Test_Done   = 3,
        Test_Finish = 4;
	
	
	reg [2*DATA_W-1:0] inst_idata [19:0];
    reg [  DATA_W-1:0] inst_odata [19:0];

    reg                   o_valid_w, o_valid_r;
    reg  [ DATA_W-1 : 0 ] o_data_a_w, o_data_a_r;
    reg  [ DATA_W-1 : 0 ] o_data_b_w, o_data_b_r;
    reg  [        2 : 0 ] test_cs, test_ns; // current_state and next_state
    reg  [        7 : 0 ] test_idx_w, test_idx_r;
    wire                  test_finish;
    wire [ DATA_W-1 : 0 ] test_inA, test_inB, test_outD;
    wire                  test_outO;
    integer error;

    assign o_done = (test_cs == Test_Finish);
    assign o_valid = o_valid_r;
    assign o_data_a = o_data_a_r;
    assign o_data_b = o_data_b_r;
    assign o_inst = i_inst;
    assign test_finish = (test_idx_r == 9);
    assign test_inA = inst_idata[test_idx_r][DATA_W-1:0];
    assign test_inB = inst_idata[test_idx_r][2*DATA_W-1:DATA_W];
    assign test_outD = inst_odata[test_idx_r][DATA_W-1:0];

    // FSM
    always@(*) begin
        test_ns = test_cs;
        case(test_cs)
            Test_Idle  : test_ns = (i_start) ? Test_Read : Test_Idle ;
            Test_Read  : test_ns = Test_Write;
            Test_Write : test_ns = (i_valid) ? (test_finish ? Test_Done : Test_Read) : Test_Write;
            Test_Done  : test_ns = Test_Finish;
            Test_Finish: test_ns = Test_Finish;
        endcase
    end

    // Testing data output
    always@(*) begin
        test_idx_w = test_idx_r;
        o_valid_w = 0;
        o_data_a_w = 0;
        o_data_b_w = 0;
        case(test_cs)
            Test_Read: begin
                o_valid_w = 1;
                o_data_a_w = inst_idata[test_idx_r][DATA_W-1:0];
                o_data_b_w = inst_idata[test_idx_r][2*DATA_W-1:DATA_W];
            end
            Test_Write: begin
                test_idx_w = (i_valid && !test_finish) ? test_idx_r+1 : test_idx_r;
            end
        endcase
    end

    // Input data checking
    always@(negedge i_clk) begin
        if(test_cs == Test_Idle) begin
            error = 0;
        end else if(test_cs == Test_Write && i_valid) begin
            if((i_data !== inst_odata[test_idx_r][DATA_W-1:0])) begin
                $display("Test[%d]: Error! A=%b, B=%b, Golden=%b, Yours=%b", test_idx_r, test_inA, test_inB, test_outD, i_data);
                error = error+1;
            end else if ((i_data == inst_odata[test_idx_r][DATA_W-1:0]))begin
                $display("Test[%d]: PASS ", test_idx_r);
            end else begin
                $display("Test[%d]:Unknown output! A=%b, B=%b, Golden=%b, Yours=%b", test_idx_r, test_inA, test_inB, test_outD, i_data);
                error = error+1;
            end
        end 
        else if(test_cs == Test_Done) begin
            if(error == 0) begin
                $display("Inst %b ALL PASS!", i_inst);
            end else begin
                $display("Wrong! Total error: %d", error);
            end
        end
    end

    always@(negedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            test_cs <= Test_Idle;
            test_idx_r <= 0;
            o_valid_r <= 0;
            o_data_a_r <= 0;
            o_data_b_r <= 0;
        end else begin
            test_cs <= test_ns;
            test_idx_r <= test_idx_w;
            o_valid_r <= o_valid_w;
            o_data_a_r <= o_data_a_w;
            o_data_b_r <= o_data_b_w;
        end
    end
endmodule
