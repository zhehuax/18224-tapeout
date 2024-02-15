module RangeFinder
    #(parameter WIDTH=16)
    (input logic [WIDTH-1:0] data_in,
    input logic clock, reset,
    input logic go, finish,
    output logic [WIDTH-1:0] range,
    output logic debug_error);

    logic update_max, update_min;
    logic [WIDTH-1:0] max, min;
    enum logic {REST=1'd0, ON=1'd1} state, nextState;

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

endmodule: RangeFinder

/*
module top_module(
input logic clk, areset, // Freshly brainwashed Lemmings walk left.
input logic bump_left, bump_right, ground, dig,
output logic walk_left, walk_right, aaah, digging);

    enum logic [2:0] {LEFT=3'd0, RIGHT=3'd1, GROUND=3'd2, DIG = 3'd3, REST = 3'd4} state, nextState;
    logic prev_left, prev_right;

    logic [4:0] count;

    always_comb begin
        unique case(state)
            LEFT: begin
                    if (~ground) nextState = GROUND;
                    else if (dig) nextState = DIG;
                    else if (bump_left) nextState = RIGHT;
                    else nextState = LEFT;
                end
            RIGHT:begin
                    if (~ground) nextState = GROUND;
                    else if (dig) nextState = DIG;
                    else if (bump_right) nextState = LEFT;
                    else nextState = RIGHT;
                end
            GROUND: begin
                    if (count >= 'd20 && ground) nextState = REST;
                    else if (ground && prev_left) nextState = LEFT;
                    else if (ground && prev_right) nextState = RIGHT;
                    else nextState = GROUND;
                end
            DIG: begin
                    if (~ground) nextState = GROUND;    
                    else nextState = DIG;           
                end

            default: nextState = REST;
        endcase

        digging = state == DIG;
        aaah = state == GROUND;
        walk_left = state == LEFT;
        walk_right = state == RIGHT;
    end

    always_ff @(posedge clk, posedge areset) begin
        if (areset) begin
            state <= LEFT;
            prev_left <= 0;
            prev_right <= 0;
            count <= 'd0;
        end
        else begin
            state <= nextState;
            if (state == GROUND) begin
                if (count <= 'd20)
                    count <= count + 1;
                else
                    count <= count;
            end
            else count <= 'd0;

            if (state == LEFT && (nextState == GROUND || nextState == DIG)) prev_left <= 1;
            if (state == RIGHT && (nextState == GROUND || nextState == DIG)) prev_right <= 1;
            if (state == GROUND && (nextState==LEFT || nextState == RIGHT)) begin
                count <= 'd0;
                prev_left <= 0;
                prev_right <= 0;
            end
        end
    end

endmodule: top_module
*/
