module input_buf(
    input logic clock, reset,
    input logic [11:0] in,
    output logic [9:0] num1, num2,
    output logic [3:0] op,
    output logic start
);

    always_ff @(posedge clock or posedge reset) begin
        // reset
        if (reset) begin
            num1 <= 'd0;
            num2 <= 'd0;
            op <= 'd0;
            start <= 0;
        end

        // get num1
        else if (in[1:0] == 2'b01) begin
            num1 <= in[11:2];
        end

        // get num2
        else if (in[1:0] == 2'b10) begin
            num2 <= in[11:2];
        end

        // get op and start to calculate
        else if (in[1:0] == 2'b11) begin
            op <= in[5:2];
            start <= 'd1;
        end

        // only fire start for 1 cycle
        else if (start)
            start <= 0;
    end

endmodule