`default_nettype none

module my_chip (
    input logic [11:0] io_in, // Inputs to your chip
    output logic [11:0] io_out, // Outputs from your chip
    input logic clock,
    input logic reset // Important: Reset is ACTIVE-HIGH
);

    // logic [9:0] a, b, y;
    // logic [3:0] sel;
    // logic signal;

    // input_buf in1(.clock, .reset, .in(io_in), .num1(a), .num2(b), .op(sel), .start(signal));
    // fpu_10 calc(.a, .b_ori(b), .sel, .y);
    // output_buf out1(.clock, .reset, .ans(y), .done_calc(signal), .out(io_out[11:2]), .done(io_out[0]));

    logic [15:0] a, b, y;
    logic [3:0] sel;
    logic signal;

    input_buf in1(.clock, .reset, .in(io_in[9:0]), .num1(a), .num2(b), .op(sel), .start(signal));
    fpu_16 calc(.a, .b, .sel, .y);
    output_buf out1(.clock, .reset, .ans(y), .done_calc(signal), .out(io_out[9:0]));


endmodule
