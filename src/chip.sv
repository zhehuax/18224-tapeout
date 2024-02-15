`default_nettype none

module my_chip (
    input logic [11:0] io_in, // Inputs to your chip
    output logic [11:0] io_out, // Outputs from your chip
    input logic clock,
    input logic reset // Important: Reset is ACTIVE-HIGH
);

    // RangeFinder stuff here
    logic [7:0] data_in;
    logic go, finish;
    logic [7:0] range;
    logic debug_error;

    logic update_max, update_min;
    logic [7:0] max, min;
    enum logic {REST=1'd0, ON=1'd1} state, nextState;

    assign data_in = io_in[7:0];
    assign range = io_out[7:0];
    assign go = io_in[8];
    assign finish = io_in[9];
    assign debug_error = io_out[8];

    always_comb begin
        unique case(state)
            REST:   begin
                        update_max = go;
                        update_min = go;
                        nextState = (go && ~finish)? ON : REST;
                    end

            ON:     begin
                        if (finish) begin
                            update_max = 0;
                            update_min = 0;
                            nextState = REST;
                        end

                        else begin
                            update_max = (data_in>max);
                            update_min = (data_in<min);
                            nextState = ON;
                        end
                    end 


            default: nextState = REST;
        endcase
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            state <= REST;
            max <= 'd0;
            min <= 'd0;
            debug_error <= 0;
            range <= 'd0;
        end

        else begin
            state <= nextState;
            if (finish) begin
                if (data_in>max) range <= data_in - min;
                else if (data_in<min) range <= max-data_in;
                else range <= max-min;
                max <='d0;
                min <= 'd0;
            end

            else begin
                if (update_max) max <= data_in;
                if (update_min) min <= data_in;
            end

            if (state == REST && finish) debug_error <= 1;
            if (go && ~finish) debug_error <= 0;
                
        end
    end
    
    // Basic counter design as an example

    /*
    wire [6:0] led_out;
    assign io_out[6:0] = led_out;

    // external clock is 1000Hz, so need 10 bit counter
    reg [9:0] second_counter;
    reg [3:0] digit;

    always @(posedge clock) begin
        // if reset, set counter to 0
        if (reset) begin
            second_counter <= 0;
            digit <= 0;
        end else begin
            // if up to 16e6
            if (second_counter == 1000) begin
                // reset
                second_counter <= 0;

                // increment digit
                digit <= digit + 1'b1;

                // only count from 0 to 9
                if (digit == 9)
                    digit <= 0;

            end else
                // increment counter
                second_counter <= second_counter + 1'b1;
        end
    end

    // instantiate segment display
    seg7 seg7(.counter(digit), .segments(led_out));
    */

endmodule
