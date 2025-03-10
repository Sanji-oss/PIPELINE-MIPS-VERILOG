module shiftLeft32bitLeft(
    input  [31:0] inData,
    output reg [31:0] outData
);

    always @(inData) begin
        outData = inData << 2;
    end

endmodule

module shiftLeftForJump(
    input  [25:0] inData,
    output reg [27:0] outData
);

    always @(inData) begin
        outData = {inData, 2'b0};
    end

endmodule
