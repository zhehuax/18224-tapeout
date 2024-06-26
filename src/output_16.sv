module output_16(
    input logic clock, reset,
    input logic [15:0] ans,
    input logic done_calc,
    output logic [9:0] data_out
);

    logic count;

    always_ff @(posedge clock or posedge reset) begin
        // reset
        if (reset) begin
            data_out <= 'd0;
            count <= 0;
        end
        // start to feed data_out
        else if (done_calc) begin
            data_out[9:2] <= ans[15:8];
            data_out[1:0] <= 2'b11;
            count <= 1;
        end
        else if (count) begin
            data_out[9:2] <= ans[7:0];
            data_out[1:0] <= 2'b11;
            count <= 0;
        end
        else
            data_out <= 'd0;
    end

endmodule: output_16