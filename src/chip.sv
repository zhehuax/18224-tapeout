`default_nettype none

module my_chip (
    input logic [11:0] io_in, // Inputs to your chip
    output logic [11:0] io_out, // Outputs from your chip
    input logic clock,
    input logic reset // Important: Reset is ACTIVE-HIGH
);

    logic [9:0] a, b, y;
    logic [3:0] sel;
    logic signal;

    // input_buf in1(.clock, .reset, .in(io_in), .num1(a), .num2(b), .op(sel), .start(signal));
    // fpu_10 calc(.a, .b_ori(b), .sel, .y);
    // output_buf out1(.clock, .reset, .ans(y), .done_calc(signal), .out(io_out[11:2]), .done(io_out[0]));

    logic [31:0] y;
    fpu calc(.a({20'd0, io_in}), .b(io_in, 20'd0), .sel(io_in[3:0]), .y);
    always_ff @(posedge clock, posedge reset) begin
        if (reset)
            io_out <= 'd0;
        else
            io_out <= y[11:0];
    end

endmodule
