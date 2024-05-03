`default_nettype none

module fpu_16 (
    input logic [15:0] a,
    input logic [15:0] b_ori,
    input logic [3:0] sel,
    output logic [15:0] y
);
    // intermediate values
    logic [4:0] max_exp;// = 8'b11111110;
    logic [4:0] min_exp;// = 8'b00000001;
    logic a_nan, b_nan, a_inf, b_inf, a_0, b_0;
    logic [15:0] g, s;
    logic [14:0] ext_g_mantisa, ext_s_mantisa, ext_y_mantisa, ext_y_mantisa_nor;
    logic [11:0] ext_y_mantisa_round;
    logic over_underflow;
    logic [4:0] y_exp_nor;
    logic [4:0] a_exp_c, b_exp_c, y_exp_c, y_exp_c_nor, y_exp_c_round;
    logic a_exp_neg, b_exp_neg, y_exp_neg, y_exp_neg_nor, y_exp_neg_round, sticky;
    logic [21:0] temp_product, product_nor;
    logic [11:0] product_round;
    logic [9:0] y_product_mantisa;
    logic [15:0] b;

    assign b = (sel == 4'b0010)? {~b_ori[15], b_ori[14:0]} : {b_ori[15], b_ori[14:0]};
    assign max_exp = 5'b11110;
    assign min_exp = 5'b00001;
    assign a_nan = (a[14:10]==5'b11111 && a[9:0]!=10'd0);
    assign b_nan = (b[14:10]==5'b11111 && b[9:0]!=10'd0);
    assign a_inf = (a[14:10]==5'b11111 && a[9:0]==10'd0);
    assign b_inf = (b[14:10]==5'b11111 && b[9:0]==10'd0);
    assign a_0 = (a[14:10]==5'd0);
    assign b_0 = (b[14:10]==5'd0);

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
        if (a_nan || b_nan) y = 16'hFFFF;
        else if (a_inf&&b_inf&&(a[15]!=b[15])&&sel[1:0]>'d0) y = 16'hFFFF;
        else if (a_inf && sel[1:0]>'d0) y = a;
        else if (b_inf && sel[1:0]>'d0) y = b;
        else if ((a_inf || b_inf) && sel[3:2]>'d0 && a[15]==b[15]) y = 16'b0111110000000000;
        else if ((a_inf || b_inf) && sel[3:2]>'d0 && a[15]!=b[15]) y = 16'b1111110000000000;
        else if (a_0 && b_0 && sel[1:0]>'d0) y = 16'd0;
        else if (a_0 && sel[1:0]>='b01) y = b;
        else if (a_0 && sel[3:2]>'d0) y = 16'd0;
        else if (b_0 && sel[1:0]=='b01) y = a;
        else if (b_0 && sel[1:0]=='b10) y = {~a[15], a[14:0]};
        else if (b_0 && sel[3:2]>'d0) y = 16'd0;

        else if (a[15]!=b[15]&&a[14:0]==b[14:0]&& sel[1:0]>'d0) y = 'd0;

        // normal case add
        else if (sel[1:0]>'d0) begin

            // case A and B have same exp
            if (a[14:10]==b[14:10]) begin
                if (a[9:0] > b[9:0]) begin
                    g = a;
                    s = b;
                end
                else begin
                    g = b;
                    s = a;
                end

                ext_g_mantisa = {2'b01,g[9:0],3'b000};
                ext_s_mantisa = {2'b01,s[9:0],3'b000};

                if (g[15]!=s[15]) ext_y_mantisa = ext_g_mantisa-ext_s_mantisa;
                else ext_y_mantisa = ext_g_mantisa+ext_s_mantisa;

                
            end

            // case A and B do not have same exp
            else begin
                if (a[14:10] > b[14:10]) begin
                    g = a;
                    s = b;
                end
                else begin
                    g = b;
                    s = a;
                end

                ext_g_mantisa = {2'b01,g[9:0],3'b000};
                ext_s_mantisa[14:1]={2'b01,s[9:0],2'b00}>>(g[14:10]-s[14:10]);
                if (g[14:10]-s[14:10] == 5'd1) ext_s_mantisa[0] = 0;
                else if (g[14:10]-s[14:10] == 'd2) ext_s_mantisa[0] = 0;
                else if (g[14:10]-s[14:10] == 'd3 && s[0]>1'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[14:10]-s[14:10] == 'd4 && s[1:0]>2'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[14:10]-s[14:10] == 'd5 && s[2:0]>3'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[14:10]-s[14:10] == 'd6 && s[3:0]>4'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[14:10]-s[14:10] == 'd7 && s[4:0]>5'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[14:10]-s[14:10] == 'd8 && s[5:0]>6'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[14:10]-s[14:10] == 'd9 && s[6:0]>7'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[14:10]-s[14:10] == 'd10 && s[7:0]>'d0) 
                        ext_s_mantisa[0] = 1;
                else if (g[14:10]-s[14:10] > 'd10) ext_s_mantisa[0] = 1;
                else ext_s_mantisa[0] = 0;

                if (g[15]!=s[15]) ext_y_mantisa = ext_g_mantisa-ext_s_mantisa;
                else ext_y_mantisa = ext_g_mantisa+ext_s_mantisa;
            end

            // now do normalization
            if (ext_y_mantisa[14]==1) begin
                if (g[14:10] < max_exp) begin
                    over_underflow = 0;
                    y_exp_nor = g[14:10]+1;
                    ext_y_mantisa_nor[14:1] = ext_y_mantisa[14:1] >> 1;
                    ext_y_mantisa_nor[0]=ext_y_mantisa[1]|ext_y_mantisa[0];
                end
                else begin
                    over_underflow = 1;
                    y[15] = g[15];
                    y[14:10] = 5'b11111;
                    y[9:0] = 10'd0;
                end
            end

            else if (ext_y_mantisa[13]==1) begin
                over_underflow = 0;
                y_exp_nor = g[14:10];
                ext_y_mantisa_nor = ext_y_mantisa;
            end

            else if (ext_y_mantisa[12]==1) begin
                if (g[14:10] > min_exp) begin
                    over_underflow = 0;
                    y_exp_nor = g[14:10]-'d1;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd1;
                end
                else begin
                    over_underflow = 1;
                    y[15] = g[15];
                    y[14:0] = 'd0;
                end
            end

            else if (ext_y_mantisa[11]==1) begin
                if (g[14:10] > min_exp+'d1) begin
                    over_underflow = 0;
                    y_exp_nor = g[14:10]-'d2;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd2;
                end
                else begin
                    over_underflow = 1;
                    y[15] = g[15];
                    y[14:0] = 'd0;
                end
            end

            else if (ext_y_mantisa[10]==1) begin
                if (g[14:10] > min_exp+'d2) begin
                    over_underflow = 0;
                    y_exp_nor = g[14:10]-'d3;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd3;
                end
                else begin
                    over_underflow = 1;
                    y[15] = g[15];
                    y[14:0] = 'd0;
                end
            end

            else if (ext_y_mantisa[9]==1) begin
                if (g[14:10] > min_exp+'d3) begin
                    over_underflow = 0;
                    y_exp_nor = g[14:10]-'d4;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd4;
                end
                else begin
                    over_underflow = 1;
                    y[15] = g[15];
                    y[14:0] = 'd0;
                end
            end

            else if (ext_y_mantisa[8]==1) begin
                if (g[14:10] > min_exp+'d4) begin
                    over_underflow = 0;
                    y_exp_nor = g[14:10]-'d5;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd5;
                end
                else begin
                    over_underflow = 1;
                    y[15] = g[15];
                    y[14:0] = 'd0;
                end
            end

            else if (ext_y_mantisa[7]==1) begin
                if (g[14:10] > min_exp+'d5) begin
                    over_underflow = 0;
                    y_exp_nor = g[14:10]-'d6;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd6;
                end
                else begin
                    over_underflow = 1;
                    y[15] = g[15];
                    y[14:0] = 'd0;
                end
            end

            else if (ext_y_mantisa[6]==1) begin
                if (g[14:10] > min_exp+'d6) begin
                    over_underflow = 0;
                    y_exp_nor = g[14:10]-'d7;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd7;
                end
                else begin
                    over_underflow = 1;
                    y[15] = g[15];
                    y[14:0] = 'd0;
                end
            end

            else if (ext_y_mantisa[5]==1) begin
                if (g[14:10] > min_exp+'d7) begin
                    over_underflow = 0;
                    y_exp_nor = g[14:10]-'d8;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd8;
                end
                else begin
                    over_underflow = 1;
                    y[15] = g[15];
                    y[14:0] = 'd0;
                end
            end

            else if (ext_y_mantisa[4]==1) begin
                if (g[14:10] > min_exp+'d8) begin
                    over_underflow = 0;
                    y_exp_nor = g[14:10]-'d9;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd9;
                end
                else begin
                    over_underflow = 1;
                    y[15] = g[15];
                    y[14:0] = 'd0;
                end
            end

            else if (ext_y_mantisa[3]==1) begin
                if (g[14:10] > min_exp+'d9) begin
                    over_underflow = 0;
                    y_exp_nor = g[14:10]-'d10;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd10;
                end
                else begin
                    over_underflow = 1;
                    y[15] = g[15];
                    y[14:0] = 'd0;
                end
            end
            else begin
                if (g[14:10] > min_exp+'d10) begin
                    over_underflow = 0;
                    y_exp_nor = g[14:10]-'d11;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd11;
                end
                else begin
                    over_underflow = 1;
                    y[15] = g[15];
                    y[14:0] = 'd0;
                end
            end


            // now do rounding and get final result
            if (~over_underflow) begin
                // case for +1
                if (ext_y_mantisa_nor[2:0] > 3'b100 || 
                    (ext_y_mantisa_nor[2:0] == 3'b100 && 
                    ext_y_mantisa_nor[3] == 1'b1)) begin
                    ext_y_mantisa_round = ext_y_mantisa_nor[14:3]+'d1;

                    // another normalization and overflow checking after +1
                    if (ext_y_mantisa_round[11]==1) begin
                        // not overflow after normalization again
                        if (y_exp_nor < max_exp) begin
                            y[15] = g[15];
                            y[14:10] = y_exp_nor+'d1;
                            y[9:0] = ext_y_mantisa_round[10:1];  
                        end
                        //overflow after normalization again
                        else begin
                            y[15] = g[15];
                            y[14:10] = 5'b11111;
                            y[9:0] = 10'd0;
                        end
                    end
                    // no need to do normalization again
                    else begin
                        y[15] = g[15];
                        y[14:10] = y_exp_nor;
                        y[9:0] = ext_y_mantisa_round[9:0];
                    end
                end

                // case for not +1
                else begin
                    ext_y_mantisa_round = ext_y_mantisa_nor[14:3];
                    y[15] = g[15];
                    y[14:10] = y_exp_nor;
                    y[9:0] = ext_y_mantisa_round[9:0];
                end
            end
        end

        // normal case multiply
        else begin
            //set sign for y
            y[15] = (a[15]==b[15]) ? 0 : 1;

            // get corrected exponents for a and b
            if (a[14:10] < 5'd15 && b[14:10] < 5'd15) begin
                a_exp_neg = 1;
                b_exp_neg = 1;
                a_exp_c = 5'd15-a[14:10];
                b_exp_c = 5'd15-b[14:10];
            end
            else if (a[14:10] < 5'd15 && b[14:10] >= 5'd15) begin
                a_exp_neg = 1;
                b_exp_neg = 0;
                a_exp_c = 5'd15-a[14:10];
                b_exp_c = b[14:10]-5'd15;
            end
            else if (a[14:10] >= 5'd15 && b[14:10] < 5'd15) begin
                a_exp_neg = 0;
                b_exp_neg = 1;
                a_exp_c = a[14:10]-5'd15;
                b_exp_c = 5'd15-b[14:10];
            end
            else begin
                a_exp_neg = 0;
                b_exp_neg = 0;
                a_exp_c = a[14:10]-5'd15;
                b_exp_c = b[14:10]-5'd15;
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
            temp_product = sel[3]? {1'b1,a[9:0]}/{1'b1,b[9:0]} : {1'b1,a[9:0]}*{1'b1,b[9:0]};
            if (temp_product[21]==1'b1) begin
                product_nor = temp_product >> 1;
                if (y_exp_neg) y_exp_c_nor = y_exp_c-5'd1;
                else y_exp_c_nor = y_exp_c+5'd1;
                if (y_exp_c_nor == 5'd0) y_exp_neg_nor = 0;
                else y_exp_neg_nor = y_exp_neg;
            end
            else begin
                product_nor = temp_product;
                y_exp_c_nor = y_exp_c;
                y_exp_neg_nor = y_exp_neg;
            end

            // rounding
            sticky = (temp_product[7:0]>=8'd1) ? 1 : 0;
            if ({product_nor[9:8],sticky} > 3'b100 ||
                ({product_nor[9:8],sticky}==3'b100 &&
                 product_nor[12] == 1)) begin
                product_round = product_nor[21:10]+1;
                // check for normalization again
                if (product_round[11]==1) begin
                    y_product_mantisa = product_round[10:1];
                    if (y_exp_neg_nor) y_exp_c_round = y_exp_c_nor-5'd1;
                    else y_exp_c_nor = y_exp_c-5'd1;
                    if (y_exp_c_round == 5'd0) y_exp_neg_round = 0;
                    else y_exp_neg_round = y_exp_neg_nor;
                end
                else begin
                    y_product_mantisa = product_round[9:0];
                    y_exp_c_round = y_exp_c_nor;
                    y_exp_neg_round = y_exp_neg_nor;
                end
            end
            else begin
                product_round = product_nor[21:10];
                y_product_mantisa = product_round[9:0];
                y_exp_c_round = y_exp_c_nor;
                y_exp_neg_round = y_exp_neg_nor;
            end

            // calculate exp and putin mantisa
            if (y_exp_neg_round && y_exp_c_round > 5'd14) begin
                y[14:0] = 15'd0;
            end
            else if (y_exp_neg_round && y_exp_c_round <= 5'd14) begin
                y[14:10] = 5'd15 - y_exp_c_round;
                y[9:0] = y_product_mantisa;
            end
            else if (~y_exp_neg_round && y_exp_c_round > (max_exp-5'd15))begin
                y[14:10] = 5'b11111;
                y[9:0] = 10'd0;
            end
            else begin
                y[14:10] = y_exp_c_round+5'd15;
                y[9:0] = y_product_mantisa;
            end
        end
    end

endmodule : fpu_16