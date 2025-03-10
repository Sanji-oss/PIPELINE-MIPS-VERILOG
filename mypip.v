//-----------------------------------------------------------------------------
// Module: Mypip
// Description: Top-level MIPS pipeline implementation
//-----------------------------------------------------------------------------
module Mypip(
    input clk                     // System clock
);

    //==========================================================================
    // Pipeline Stage Wire Declarations
    //==========================================================================
    
    // Instruction Fetch (IF) stage wires
    wire [31:0] PC;              // Program Counter
    wire [31:0] nextPC;          // Next PC value
    wire [31:0] instrWire;       // Fetched instruction
    
    // Instruction Decode (ID) stage wires
    wire [31:0] instrWireID, nextPCID;
    wire [2:0]  ALUOp;
    wire RegDest, RegWrite, ALUSrc, MemRead, MemWrite, MemToReg, Branch, Jump;
    
    // Execute (EX) stage wires
    wire [31:0] instrWireEX, nextPCEX, readData1EX, readData2EX, NPC1EX, outSignEXTEX;
    wire [4:0]  writeRegWireEX;
    wire RegDestEX, RegWriteEX, ALUSrcEX, MemReadEX, MemWriteEX, MemToRegEX, BranchEX, JumpEX;
    wire [3:0]  ALUCtrlEX;
    
    // Memory (MEM) stage wires
    wire [31:0] instrWireMEM, readData2MEM, ALUResultMEM, nextPCBranchMEM, NPC1MEM, nextPCMEM;
    wire [4:0]  writeRegWireMEM;
    wire RegDestMEM, RegWriteMEM, ALUSrcMEM, MemReadMEM, MemWriteMEM, MemToRegMEM, BranchMEM, JumpMEM;
    wire [3:0]  ALUCtrlMEM;
    wire ZeroOutMEM;
    
    // Writeback (WB) stage wires
    wire [31:0] instrWireWB, ALUResultWB, outputDataWB;
    wire [4:0]  writeRegWireWB;
    wire RegDestWB, RegWriteWB, ALUSrcWB, MemReadWB, MemWriteWB, MemToRegWB, BranchWB, JumpWB;
    wire [3:0]  ALUCtrlWB;

    // Hazard and stall control wires
    wire dataStall;              // Data hazard stall signal
    wire controlStall;           // Control hazard stall signal
    wire [31:0] instrWireIDhazard, instrWireHazard;

    //==========================================================================
    // Pipeline Stage Components
    //==========================================================================

    // Instruction Fetch Stage
    IMemBank u0(1'b1, PC, instrWire);
    adder32bit u4(32'b100, PC, nextPC);

    // Hazard Detection and Control
    stallUnit u90(clk, instrWireID[25:21], instrWireID[20:16],instrWireID[31:26]/*opcode*/,instrWireID,
    instrWireEX,instrWireMEM,writeRegWireWB,RegWriteWB,instrWireWB,dataStall);

    // Control Stall Logic
    Controlstall u92(clk,instrWireID[31:26],instrWireEX[31:26],instrWireMEM[31:26],/*instrWireWB[31:26],*/controlStall);//agar Dstall 0 nop be vorodi midim

    // NOP Insertion Logic
    nopSet u91(clk,dataStall,controlStall,instrWire,instrWireID,instrWireHazard,instrWireIDhazard);

    // Instruction Decode Stage
    controlUnit u1(clk,instrWireIDhazard[31:26],instrWireIDhazard[5:0],//age enable 0bashe stall darim
    ALUOp,RegDest,RegWrite,ALUSrc,MemRead,MemWrite,MemToReg,Branch,Jump,instrWireIDhazard);/*ID*/

    wire [4:0]writeRegWire;
    mux2A u10(RegDest,instrWireID[20:16],instrWireID[15:11],writeRegWire);/*ID*/

    wire [31:0]readData1,readData2;
    wire [31:0]WBData;
    RegFile u11(clk, instrWireID[25:21], instrWireID[20:16], 
    writeRegWireWB, WBData, RegWriteWB, 
    readData1, readData2);/*ID*//*WB*/

    wire [31:0]ALUSrc1;
    wire [31:0]outSignEXT;
    signExt u2(instrWireID[15:0],outSignEXT);/*ID*/
    mux2 u12(ALUSrcEX,readData2EX,outSignEXTEX,ALUSrc1);/*EX*/

    wire [3:0]ALUCtrl;
    ALUcontrol u13(clk,instrWireID[5:0],ALUOp,ALUCtrl);/*ID*/

    wire [31:0]ALUResult;
    wire ZeroOut;
    ALU u14(readData1EX,ALUSrc1,ALUCtrlEX,ALUResult,ZeroOut, , );/*EX*/

    wire [31:0]outputData;
    DMemBank u15(MemReadMEM, MemWriteMEM,ALUResultMEM , readData2MEM, outputData);/*MEM*/

    mux2 u16(MemToRegWB,ALUResultWB,outputDataWB,WBData);/*WB*/

    // Execute Stage Components
    wire [31:0]outputSLL;
    shiftLeft32bitLeft u3(outSignEXTEX,outputSLL);/*EX*/

    wire [31:0]nextPCBranch;
    adder32bit u5(nextPCEX,outputSLL,nextPCBranch);/*EX*/

    wire branchEnable;
    assign branchEnable= ZeroOutMEM & BranchMEM;/*MEM*/

    wire [31:0]NPC0;
    mux2 u6(branchEnable,nextPCMEM,nextPCBranchMEM,NPC0);/*MEM*/

    wire [27:0]nextPCJump;
    shiftLeftForJump u7(instrWireID[25:0],nextPCJump);/*ID*/

    wire [31:0]NPC1;
    concatForJump u20(nextPC[31:28],nextPCJump,NPC1);/*ID*/

    wire [31:0]NPCValue;
    mux2 u8(JumpMEM,NPC0,NPC1MEM,NPCValue);/*MEM*/

    PCRegWrite u9(clk,NPCValue,PC,dataStall);/*MEM*/

    //==========================================================================
    // Pipeline Registers
    //==========================================================================
    
    // IF/ID Pipeline Register
    IFID p1(clk,instrWireHazard,nextPC,instrWireID,nextPCID,dataStall);

    // ID/EX Pipeline Register
    IDEX p2(clk,RegDest,RegWrite,ALUSrc,MemRead,MemWrite,MemToReg,Branch,Jump,ALUCtrl,
    instrWireID,nextPCID,readData1,readData2,writeRegWire,outSignEXT,NPC1,
    RegDestEX,RegWriteEX,ALUSrcEX,MemReadEX,MemWriteEX,MemToRegEX,BranchEX,JumpEX,ALUCtrlEX,
    instrWireEX,nextPCEX,readData1EX,readData2EX,writeRegWireEX,outSignEXTEX,NPC1EX,1'b1);

    // EX/MEM Pipeline Register
    EXMEM p3(clk,RegDestEX,RegWriteEX,ALUSrcEX,MemReadEX,MemWriteEX,MemToRegEX,BranchEX,JumpEX,ALUCtrlEX,
    instrWireEX,nextPCEX,readData2EX,ALUResult,writeRegWireEX,nextPCBranch,NPC1EX,ZeroOut,
    RegDestMEM,RegWriteMEM,ALUSrcMEM,MemReadEX,MemWriteMEM,MemToRegMEM,BranchMEM,JumpMEM,ALUCtrlMEM,
    instrWireMEM,nextPCMEM,readData2MEM,ALUResultMEM,writeRegWireMEM,nextPCBranchMEM,NPC1MEM,ZeroOutMEM,1'b1);

    // MEM/WB Pipeline Register
    MEMWB p4(clk,RegDestMEM,RegWriteMEM,ALUSrcMEM,MemReadMEM,MemWriteMEM,MemToRegMEM,BranchMEM,JumpMEM,ALUCtrlMEM,
    instrWireMEM,outputData,ALUResultMEM,writeRegWireMEM,
    RegDestWB,RegWriteWB,ALUSrcWB,MemReadWB,MemWriteWB,MemToRegWB,BranchWB,JumpWB,ALUCtrlWB,
    instrWireWB,outputDataWB,ALUResultWB,writeRegWireWB,1'b1);

endmodule
