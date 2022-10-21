// opcode definition
`define OP_ADD  1
`define OP_SUB  2
`define OP_ADDU 3
`define OP_SUBU 4
`define OP_ADDI 5
`define OP_LW   6
`define OP_SW   7
`define OP_AND  8
`define OP_OR   9
`define OP_NOR  10
`define OP_BEQ  11
`define OP_BNE  12
`define OP_SLT  13
`define OP_EOF  14

// MIPS status definition
`define R_TYPE_SUCCESS 0
`define I_TYPE_SUCCESS 1
`define MIPS_OVERFLOW 2
`define MIPS_END 3
