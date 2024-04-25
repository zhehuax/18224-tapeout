module output_16(
    input logic clock, reset,
    input logic [15:0] ans,
    input logic done_calc,
    output logic [9:0] out
);

    logic count;

    always_ff @(posedge clock or posedge reset) begin
        // reset
        if (reset) begin
            out <= 'd0;
            count <= 0;
        end
        // start to feed out
        else if (done_calc) begin
            if (count == 0) begin
                out[9:2] <= ans[15:8];
                out[1:0] <= 2'b11;
                count <= 1;
            end
            else begin
                out[9:2] <= ans[7:0];
                out[1:0] <= 2'b11;
                count <= 0;
            end
        end

        // only fire done for 1 cycle
        else
            out <= 'd0;
    end

endmodule: output_16