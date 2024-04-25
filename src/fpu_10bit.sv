`default_nettype none

module fpu (
    input logic [9:0] a,
    input logic [9:0] b_ori,
    input logic [3:0] sel,
    output logic [9:0] y
);
    // intermediate values
    logic [3:0] max_exp;
    logic [3:0] min_exp;// = 8'b00000001;
    logic a_nan, b_nan, a_inf, b_inf, a_0, b_0;
    logic [9:0] g, s;
    logic [9:0] ext_g_mantisa, ext_s_mantisa, ext_y_mantisa, ext_y_mantisa_nor;
    logic [6:0] ext_y_mantisa_round;
    logic over_underflow;
    logic [3:0] y_exp_nor;
    logic [3:0] a_exp_c, b_exp_c, y_exp_c, y_exp_c_nor, y_exp_c_round;
    logic a_exp_neg, b_exp_neg, y_exp_neg, y_exp_neg_nor, y_exp_neg_round, sticky;
    logic [11:0] temp_product, product_nor;
    logic [6:0] product_round;
    logic [4:0] y_product_mantisa;
    logic [9:0] b;

    assign b = (sel == 4'b0010)? {~b_ori[9], b_ori[8:0]} : {b_ori[9], b_ori[8:0]};
    assign max_exp = 4'b1110;
    assign min_exp = 4'b0001;
    assign a_nan = (a[8:5]==4'b1111 && a[4:0]!=5'd0);
    assign b_nan = (b[8:5]==4'b1111 && b[4:0]!=5'd0);
    assign a_inf = (a[8:5]==4'b1111 && a[4:0]==5'd0);
    assign b_inf = (b[8:5]==4'b1111 && b[4:0]==5'd0);
    assign a_0 = (a[8:5]==4'd0 && a[4:0]==5'd0);
    assign b_0 = (b[8:5]==4'd0 && b[4:0]==5'd0);

    always_comb begin
        // reset all values
        g = 'd0;
        s = 'd0;
        ext_g_mantisa = 'd0;
        ext_s_mantisa = 'd0;
        ext_y_mantisa = 'd0;
        ext_y_mantisa_nor = 'd0;
        ext_y_mantisa_round = 'd0;
        over_underflow = 'd0;
        y_exp_nor = 'd0;
        a_exp_c = 'd0;
        b_exp_c = 'd0;
        y_exp_c = 'd0;
        y_exp_c_nor = 'd0;
        y_exp_c_round = 'd0;
        a_exp_neg = 'd0;
        b_exp_neg = 'd0;
        y_exp_neg = 'd0;
        y_exp_neg_nor = 'd0;
        y_exp_neg_round = 'd0;
        sticky = 'd0;
        temp_product = 'd0;
        product_nor = 'd0;
        product_round = 'd0;
        y_product_mantisa = 'd0;
        y = 'd0;

        // special cases
        if (a_nan || b_nan) y = 10'b1111111111;
        else if (a_inf&&b_inf&&(a[9]!=b[9])&&sel[1:0]>'d0) y = 10'b1111111111;
        else if (a_inf && sel[1:0]>'d0) y = a;
        else if (b_inf && sel[1:0]>'d0) y = b;
        else if ((a_inf || b_inf) && sel[3:2]>'d0 && a[9]==b[9]) y = 10'b0111100000;
        else if ((a_inf || b_inf) && sel[3:2]>'d0 && a[9]!=b[9]) y = 10'b1111100000;
        else if (a_0 && sel[1:0]>'d0) y = b;
        else if (a_0 && sel[3:2]>'d0) y = 10'd0;
        else if (b_0 && sel[1:0]>'d0) y = a;
        else if (b_0 && sel[3:2]>'d0) y = 10'd0;

        else if (a[9]!=b[9]&&a[8:0]==b[8:0]&& sel[1:0]>'d0) y = 'd0;

        //normal case add
        else if (sel[1:0]>'d0) begin

            // case A and B have same exp
            if (a[8:5]==b[8:5]) begin
                if (a[4:0] > b[4:0]) begin
                    g = a;
                    s = b;
                end
                else begin
                    g = b;
                    s = a;
                end

                ext_g_mantisa = {2'b01,g[4:0],3'b000};
                ext_s_mantisa = {2'b01,s[4:0],3'b000};

                if (g[9]!=s[9]) ext_y_mantisa = ext_g_mantisa-ext_s_mantisa;
                else ext_y_mantisa = ext_g_mantisa+ext_s_mantisa;
            end

            // case A and B do not have same exp
            else begin
                if (a[8:5] > b[8:5]) begin
                    g = a;
                    s = b;
                end
                else begin
                    g = b;
                    s = a;
                end

                ext_g_mantisa = {2'b01,g[4:0],3'b000};
                ext_s_mantisa[9:1]={2'b01,s[4:0],2'b00}>>(g[8:5]-s[8:5]);
                if (g[8:5]-s[8:5] == 4'd1) ext_s_mantisa[0] = 0;
                else if (g[8:5]-s[8:5] == 4'd2) ext_s_mantisa[0] = 0;
                else if (g[8:5]-s[8:5] == 4'd3 && s[0]>1'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[8:5]-s[8:5] == 4'd4 && s[1:0]>2'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[8:5]-s[8:5] > 4'd4) ext_s_mantisa[0] = 1;
                else ext_s_mantisa[0] = 0;

                if (g[9]!=s[9]) ext_y_mantisa = ext_g_mantisa-ext_s_mantisa;
                else ext_y_mantisa = ext_g_mantisa+ext_s_mantisa;
            end

            // now do normalization
            if (ext_y_mantisa[9]==1) begin
                if (g[8:5] < max_exp) begin
                    over_underflow = 0;
                    y_exp_nor = g[8:5]+1;
                    ext_y_mantisa_nor[9:1] = ext_y_mantisa[9:1] >> 1;
                    ext_y_mantisa_nor[0]=ext_y_mantisa[1]|ext_y_mantisa[0];
                end
                else begin
                    over_underflow = 1;
                    y[9] = g[9];
                    y[8:5] = 4'b1111;
                    y[4:0] = 5'd0;
                end
            end

            else if (ext_y_mantisa[8]==1) begin
                over_underflow = 0;
                y_exp_nor = g[8:5];
                ext_y_mantisa_nor = ext_y_mantisa;
            end

            else if (ext_y_mantisa[7]==1) begin
                if (g[8:5] > min_exp) begin
                    over_underflow = 0;
                    y_exp_nor = g[8:5]-'d1;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd1;
                end
                else begin
                    over_underflow = 1;
                    y[9] = g[9];
                    y[8:0] = 9'd0;
                end
            end

            else if (ext_y_mantisa[6]==1) begin
                if (g[8:5] > min_exp+'d1) begin
                    over_underflow = 0;
                    y_exp_nor = g[8:5]-'d2;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd2;
                end
                else begin
                    over_underflow = 1;
                    y[9] = g[9];
                    y[8:0] = 9'd0;
                end
            end

            else if (ext_y_mantisa[5]==1) begin
                if (g[8:5] > min_exp+'d2) begin
                    over_underflow = 0;
                    y_exp_nor = g[8:5]-'d3;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd3;
                end
                else begin
                    over_underflow = 1;
                    y[9] = g[9];
                    y[8:0] = 9'd0;
                end
            end

            else if (ext_y_mantisa[4]==1) begin
                if (g[8:5] > min_exp+'d3) begin
                    over_underflow = 0;
                    y_exp_nor = g[8:5]-'d4;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd4;
                end
                else begin
                    over_underflow = 1;
                    y[9] = g[9];
                    y[8:0] = 9'd0;
                end
            end

            else if (ext_y_mantisa[5]==1) begin
                if (g[8:5] > min_exp+'d4) begin
                    over_underflow = 0;
                    y_exp_nor = g[8:5]-'d5;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd5;
                end
                else begin
                    over_underflow = 1;
                    y[9] = g[9];
                    y[8:0] = 9'd0;
                end
            end

            else begin
                if (g[6:3] > min_exp+'d5) begin
                    over_underflow = 0;
                    y_exp_nor = g[6:3]-'d6;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd6;
                end
                else begin
                    over_underflow = 1;
                    y[9] = g[9];
                    y[8:0] = 9'd0;
                end
            end


            //now do rounding and get final result
            if (~over_underflow) begin
                // case for +1
                if (ext_y_mantisa_nor[2:0] > 3'b100 || 
                    (ext_y_mantisa_nor[2:0] == 3'b100 && 
                    ext_y_mantisa_nor[3] == 1'b1)) begin
                    ext_y_mantisa_round = ext_y_mantisa_nor[9:3]+'d1;

                    // another normalization and overflow checking after +1
                    if (ext_y_mantisa_round[6]==1) begin
                        // not overflow after normalization again
                        if (y_exp_nor < max_exp) begin
                            y[9] = g[9];
                            y[8:5] = y_exp_nor+'d1;
                            y[4:0] = ext_y_mantisa_round[5:1];  
                        end
                        //overflow after normalization again
                        else begin
                            y[9] = g[9];
                            y[8:5] = 4'b1111;
                            y[4:0] = 5'd0;
                        end
                    end
                    // no need to do normalization again
                    else begin
                        y[9] = g[9];
                        y[8:5] = y_exp_nor;
                        y[4:0] = ext_y_mantisa_round[4:0];
                    end
                end

                // case for not +1
                else begin
                    ext_y_mantisa_round = ext_y_mantisa_nor[9:3];
                    y[9] = g[9];
                    y[8:5] = y_exp_nor;
                    y[4:0] = ext_y_mantisa_round[4:0];
                end
            end
        end

        // normal case multiply
        else begin
            //set sign for y
            y[9] = (a[9]==b[9]) ? 0 : 1;

            // get corrected exponents for a and b
            if (a[8:5] < 4'd7 && b[8:5] < 4'd7) begin
                a_exp_neg = 1;
                b_exp_neg = 1;
                a_exp_c = 4'd7-a[8:5];
                b_exp_c = 4'd7-b[8:5];
            end
            else if (a[8:5] < 4'd7 && b[8:5] >= 4'd7) begin
                a_exp_neg = 1;
                b_exp_neg = 0;
                a_exp_c = 4'd7-a[8:5];
                b_exp_c = b[8:5]-4'd7;
            end
            else if (a[8:5] >= 4'd7 && b[8:5] < 4'd7) begin
                a_exp_neg = 0;
                b_exp_neg = 1;
                a_exp_c = a[8:5]-4'd7;
                b_exp_c = 4'd7-b[8:5];
            end
            else begin
                a_exp_neg = 0;
                b_exp_neg = 0;
                a_exp_c = a[8:5]-4'd7;
                b_exp_c = b[8:5]-4'd7;
            end

            // set corrected exponent for y
            if (a_exp_neg && b_exp_neg) begin
                y_exp_neg = 1;
                y_exp_c = a_exp_c+b_exp_c;
            end
            else if (a_exp_neg && ~b_exp_neg && b_exp_c >= a_exp_c) begin
                y_exp_neg = 0;
                y_exp_c = b_exp_c-a_exp_c;
            end
            else if (a_exp_neg && ~b_exp_neg && b_exp_c < a_exp_c) begin
                y_exp_neg = 1;
                y_exp_c = a_exp_c-b_exp_c;
            end
            else if (~a_exp_neg && b_exp_neg && a_exp_c >= b_exp_c) begin
                y_exp_neg = 0;
                y_exp_c = a_exp_c-b_exp_c;
            end
            else if (~a_exp_neg && b_exp_neg && a_exp_c < b_exp_c) begin
                y_exp_neg = 1;
                y_exp_c = b_exp_c-a_exp_c;
            end
            if (~a_exp_neg && ~b_exp_neg) begin
                y_exp_neg = 0;
                y_exp_c = a_exp_c+b_exp_c;
            end

            // calculate mantisa
            temp_product = {1'b1,a[4:0]}*{1'b1,b[4:0]};
            if (temp_product[11]==1'b1) begin
                product_nor = temp_product >> 1;
                if (y_exp_neg) y_exp_c_nor = y_exp_c-4'd1;
                else y_exp_c_nor = y_exp_c+4'd1;
                if (y_exp_c_nor == 4'd0) y_exp_neg_nor = 0;
                else y_exp_neg_nor = y_exp_neg;
            end
            else begin
                product_nor = temp_product;
                y_exp_c_nor = y_exp_c;
                y_exp_neg_nor = y_exp_neg;
            end

            // rounding
            sticky = (temp_product[2:0]>=3'd1) ? 1 : 0;
            if ({product_nor[4:3],sticky} > 3'b100 ||
                ({product_nor[4:3],sticky}==3'b100 &&
                 product_nor[7] == 1)) begin
                product_round = product_nor[11:5]+1;
                // check for normalization again
                if (product_round[6]==1) begin
                    y_product_mantisa = product_round[5:1];
                    if (y_exp_neg_nor) y_exp_c_round = y_exp_c_nor-4'd1;
                    else y_exp_c_round = y_exp_c_nor+4'd1;
                    if (y_exp_c_round == 4'd0) y_exp_neg_round = 0;
                    else y_exp_neg_round = y_exp_neg_nor;
                end
                else begin
                    y_product_mantisa = product_round[4:0];
                    y_exp_c_round = y_exp_c_nor;
                    y_exp_neg_round = y_exp_neg_nor;
                end
            end
            else begin
                product_round = product_nor[11:5];
                y_product_mantisa = product_round[4:0];
                y_exp_c_round = y_exp_c_nor;
                y_exp_neg_round = y_exp_neg_nor;
            end

            // calculate exp and putin mantisa
            if (y_exp_neg_round && y_exp_c_round > 4'd6) begin
                y[8:0] = 9'd0;
            end
            else if (y_exp_neg_round && y_exp_c_round <= 4'd6) begin
                y[8:5] = 4'd7 - y_exp_c_round;
                y[4:0] = y_product_mantisa;
            end
            else if (~y_exp_neg_round && y_exp_c_round > (max_exp-4'd7))begin
                y[8:5] = 4'b1111;
                y[4:0] = 5'd0;
            end
            else begin
                y[8:5] = y_exp_c_round+4'd7;
                y[4:0] = y_product_mantisa;
            end
        end
    end

endmodule : fpu