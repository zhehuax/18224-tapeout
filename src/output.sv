module output_buf(
    input logic clock, reset,
    input logic [9:0] ans,
    input logic done_calc,
    output logic [9:0] out,
    output logic done
);

    always_ff @(posedge clock or posedge reset) begin
        // reset
        if (reset) begin
            out <= 'd0;
            done <= 0;
        end
        // start to feed out
        else if (done_calc) begin
            out <= ans[9:0];
            done <= 1;
        end

        // only fire done for 1 cycle
        else if (done)
            done <= 0;
    end

endmodule