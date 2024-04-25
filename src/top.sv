module top(
    input logic clock, reset,
    input logic [11:0] inp,
    output logic [9:0] out,
    output logic done
);
    logic [9:0] a, b, y;
    logic [3:0] sel;
    logic signal;

    input_buf in1(.clock, .reset, .in(inp), .num1(a), .num2(b), .op(sel), .start(signal));
    fpu calc(.a, .b_ori(b), .sel, .y);
    output_buf out1(.clock, .reset, .ans(y), .done_calc(signal), .out, .done);

endmodule