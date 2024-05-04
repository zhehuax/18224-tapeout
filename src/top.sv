module top(
    input logic clock, reset,
    input logic [9:0] inp,
    output logic [9:0] out
);
    logic [15:0] a, b, y;
    logic [3:0] sel;
    logic signal;

    input_16 in1(.clock, .reset, .data_in(inp), .num1(a), .num2(b), .op(sel), .start(signal));
    fpu_16 calc(.a, .b_ori(b), .sel, .y);
    output_16 out1(.clock, .reset, .ans(y), .done_calc(signal), .data_out(out));

endmodule