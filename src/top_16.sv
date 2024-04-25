module top(
    input logic clock, reset,
    input logic [9:0] inp,
    output logic [9:0] out
);
    logic [15:0] a, b, y;
    logic [3:0] sel;
    logic signal;

    input_buf in1(.clock, .reset, .in(inp), .num1(a), .num2(b), .op(sel), .start(signal));
    fpu_16 calc(.a, .b, .sel, .y);
    output_buf out1(.clock, .reset, .ans(y), .done_calc(signal), .out);

endmodule