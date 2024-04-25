module input_buf(
    input logic clock, reset,
    input logic [9:0] in,
    output logic [15:0] num1, num2,
    output logic [3:0] op,
    output logic start
);
    logic count;

    always_ff @(posedge clock or posedge reset) begin
        // reset
        if (reset) begin
            num1 <= 'd0;
            num2 <= 'd0;
            op <= 'd0;
            start <= 0;
            count <= 'd0;
        end

        // get num1
        else if (in[1:0] == 2'b01) begin
            if (count == 0) begin
                num1[15:8] <= in[9:2];
                count <= 1;
            end
            else begin
                num1[7:0] <= in[9:2];
                count <= 0;
            end
        end

        // get num2
        else if (in[1:0] == 2'b10) begin
            if (count == 0) begin
                num2[15:8] <= in[9:2];
                count <= 1;
            end
            else begin
                num2[7:0] <= in[9:2];
                count <= 0;
            end
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