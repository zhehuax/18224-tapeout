`default_nettype none

module fpu (
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [3:0] sel,
    output logic [31:0] y
);
    // intermediate values
    logic [7:0] max_exp;// = 8'b11111110;
    logic [7:0] min_exp;// = 8'b00000001;
    logic a_nan, b_nan, a_inf, b_inf, a_0, b_0;
    logic [31:0] g, s;
    logic [27:0] ext_g_mantisa, ext_s_mantisa, ext_y_mantisa, ext_y_mantisa_nor;
    logic [24:0] ext_y_mantisa_round;
    logic over_underflow;
    logic [7:0] y_exp_nor;
    logic [7:0] a_exp_c, b_exp_c, y_exp_c, y_exp_c_nor, y_exp_c_round;
    logic a_exp_neg, b_exp_neg, y_exp_neg, y_exp_neg_nor, y_exp_neg_round, sticky;
    logic [47:0] temp_product, product_nor;
    logic [24:0] product_round;
    logic [22:0] y_product_mantisa;

    assign max_exp = 8'b11111110;
    assign min_exp = 8'b00000001;
    assign a_nan = (a[30:23]==8'b11111111 && a[22:0]!=23'd0);
    assign b_nan = (b[30:23]==8'b11111111 && b[22:0]!=23'd0);
    assign a_inf = (a[30:23]==8'b11111111 && a[22:0]==23'd0);
    assign b_inf = (b[30:23]==8'b11111111 && b[22:0]==23'd0);
    assign a_0 = (a[30:23]==8'd0 && a[22:0]==23'd0);
    assign b_0 = (b[30:23]==8'd0 && b[22:0]==23'd0);

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
        if (a_nan || b_nan) y = 32'hFFFFFFFF;
        else if (a_inf&&b_inf&&(a[31]!=b[31])&&sel[1:0]>'d0) y = 32'hFFFFFFFF;
        else if (a_inf && sel[1:0]>'d0) y = a;
        else if (b_inf && sel[1:0]>'d0) y = b;
        else if ((a_inf || b_inf) && sel[3:2]>'d0 && a[31]==b[31]) y = 32'h7F800000;
        else if ((a_inf || b_inf) && sel[3:2]>'d0 && a[31]!=b[31]) y = 32'hFF800000;
        else if (a_0 && sel[1:0]>'d0) y = b;
        else if (a_0 && sel[3:2]>'d0) y = 32'd0;
        else if (b_0 && sel[1:0]>'d0) y = a;
        else if (b_0 && sel[3:2]>'d0) y = 32'd0;

        else if (a[31]!=b[31]&&a[30:0]==b[30:0]&& sel[1:0]>'d0) y = 32'd0;

        // normal case add
        else if (sel[1:0]>'d0) begin

            // case A and B have same exp
            if (a[30:23]==b[30:23]) begin
                if (a[22:0] > b[22:0]) begin
                    g = a;
                    s = b;
                end
                else begin
                    g = b;
                    s = a;
                end

                ext_g_mantisa = {2'b01,g[22:0],3'b000};
                ext_s_mantisa = {2'b01,s[22:0],3'b000};

                if (g[31]!=s[31]) ext_y_mantisa = ext_g_mantisa-ext_s_mantisa;
                else ext_y_mantisa = ext_g_mantisa+ext_s_mantisa;

                
            end

            // case A and B do not have same exp
            else begin
                if (a[30:23] > b[30:23]) begin
                    g = a;
                    s = b;
                end
                else begin
                    g = b;
                    s = a;
                end

                ext_g_mantisa = {2'b01,g[22:0],3'b000};
                ext_s_mantisa[27:1]={2'b01,s[22:0],2'b00}>>(g[30:23]-s[30:23]);
                if (g[30:23]-s[30:23] == 8'd1) ext_s_mantisa[0] = 0;
                else if (g[30:23]-s[30:23] == 8'd2) ext_s_mantisa[0] = 0;
                else if (g[30:23]-s[30:23] == 8'd3 && s[0]>1'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd4 && s[1:0]>2'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd5 && s[2:0]>3'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd6 && s[3:0]>4'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd7 && s[4:0]>5'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd8 && s[5:0]>6'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd9 && s[6:0]>7'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd10 && s[7:0]>8'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd11 && s[8:0]>9'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd12 && s[9:0]>10'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd13 && s[10:0]>11'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd14 && s[11:0]>12'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd15 && s[12:0]>13'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd16 && s[13:0]>14'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd17 && s[14:0]>15'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd18 && s[15:0]>16'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd19 && s[16:0]>17'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd20 && s[17:0]>18'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd21 && s[18:0]>19'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd22 && s[19:0]>20'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd23 && s[20:0]>21'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd24 && s[21:0]>22'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] == 8'd25 && s[22:0]>23'd0) 
                        ext_s_mantisa[0] = 1;
                else if (g[30:23]-s[30:23] > 8'd25) ext_s_mantisa[0] = 1;
                else ext_s_mantisa[0] = 0;

                
                if (g[31]!=s[31]) ext_y_mantisa = ext_g_mantisa-ext_s_mantisa;
                else ext_y_mantisa = ext_g_mantisa+ext_s_mantisa;

            end

            // now do normalization
            if (ext_y_mantisa[27]==1) begin
                if (g[30:23] < max_exp) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]+1;
                    ext_y_mantisa_nor[27:1] = ext_y_mantisa[27:1] >> 1;
                    ext_y_mantisa_nor[0]=ext_y_mantisa[1]|ext_y_mantisa[0];
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:23] = 8'b11111111;
                    y[22:0] = 23'd0;
                end
            end

            else if (ext_y_mantisa[26]==1) begin
                over_underflow = 0;
                y_exp_nor = g[30:23];
                ext_y_mantisa_nor = ext_y_mantisa;
            end

            else if (ext_y_mantisa[25]==1) begin
                if (g[30:23] > min_exp) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d1;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd1;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[24]==1) begin
                if (g[30:23] > min_exp+'d1) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d2;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd2;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[23]==1) begin
                if (g[30:23] > min_exp+'d2) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d3;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd3;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[22]==1) begin
                if (g[30:23] > min_exp+'d3) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d4;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd4;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[21]==1) begin
                if (g[30:23] > min_exp+'d4) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d5;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd5;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[20]==1) begin
                if (g[30:23] > min_exp+'d5) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d6;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd6;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[19]==1) begin
                if (g[30:23] > min_exp+'d6) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d7;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd7;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[18]==1) begin
                if (g[30:23] > min_exp+'d7) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d8;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd8;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[17]==1) begin
                if (g[30:23] > min_exp+'d8) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d9;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd9;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[16]==1) begin
                if (g[30:23] > min_exp+'d9) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d10;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd10;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[15]==1) begin
                if (g[30:23] > min_exp+'d10) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d11;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd11;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[14]==1) begin
                if (g[30:23] > min_exp+'d11) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d12;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd12;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[13]==1) begin
                if (g[30:23] > min_exp+'d12) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d13;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd13;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[12]==1) begin
                if (g[30:23] > min_exp+'d13) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d14;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd14;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[11]==1) begin
                if (g[30:23] > min_exp+'d14) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d15;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd15;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[10]==1) begin
                if (g[30:23] > min_exp+'d15) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d16;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd16;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[9]==1) begin
                if (g[30:23] > min_exp+'d16) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d17;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd17;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[8]==1) begin
                if (g[30:23] > min_exp+'d17) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d18;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd18;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[7]==1) begin
                if (g[30:23] > min_exp+'d18) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d19;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd19;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[6]==1) begin
                if (g[30:23] > min_exp+'d19) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d20;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd20;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[5]==1) begin
                if (g[30:23] > min_exp+'d20) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d21;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd21;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[4]==1) begin
                if (g[30:23] > min_exp+'d21) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d22;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd22;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else if (ext_y_mantisa[3]==1) begin
                if (g[30:23] > min_exp+'d22) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d23;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd23;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end

            else begin
                if (g[30:23] > min_exp+'d23) begin
                    over_underflow = 0;
                    y_exp_nor = g[30:23]-'d24;
                    ext_y_mantisa_nor = ext_y_mantisa <<< 'd24;
                end
                else begin
                    over_underflow = 1;
                    y[31] = g[31];
                    y[30:0] = 31'd0;
                end
            end


            // now do rounding and get final result
            if (~over_underflow) begin
                // case for +1
                if (ext_y_mantisa_nor[2:0] > 3'b100 || 
                    (ext_y_mantisa_nor[2:0] == 3'b100 && 
                    ext_y_mantisa_nor[3] == 1'b1)) begin
                    ext_y_mantisa_round = ext_y_mantisa_nor[27:3]+'d1;

                    // another normalization and overflow checking after +1
                    if (ext_y_mantisa_round[24]==1) begin
                        // not overflow after normalization again
                        if (y_exp_nor < max_exp) begin
                            y[31] = g[31];
                            y[30:23] = y_exp_nor+'d1;
                            y[22:0] = ext_y_mantisa_round[23:1];  
                        end
                        //overflow after normalization again
                        else begin
                            y[31] = g[31];
                            y[30:23] = 8'b11111111;
                            y[22:0] = 23'd0;
                        end
                    end
                    // no need to do normalization again
                    else begin
                        y[31] = g[31];
                        y[30:23] = y_exp_nor;
                        y[22:0] = ext_y_mantisa_round[22:0];
                    end
                end

                // case for not +1
                else begin
                    ext_y_mantisa_round = ext_y_mantisa_nor[27:3];
                    y[31] = g[31];
                    y[30:23] = y_exp_nor;
                    y[22:0] = ext_y_mantisa_round[22:0];
                end
            end
        end

        // normal case multiply
        else begin
            //set sign for y
            y[31] = (a[31]==b[31]) ? 0 : 1;

            // get corrected exponents for a and b
            if (a[30:23] < 8'd127 && b[30:23] < 8'd127) begin
                a_exp_neg = 1;
                b_exp_neg = 1;
                a_exp_c = 8'd127-a[30:23];
                b_exp_c = 8'd127-b[30:23];
            end
            else if (a[30:23] < 8'd127 && b[30:23] >= 8'd127) begin
                a_exp_neg = 1;
                b_exp_neg = 0;
                a_exp_c = 8'd127-a[30:23];
                b_exp_c = b[30:23]-8'd127;
            end
            else if (a[30:23] >= 8'd127 && b[30:23] < 8'd127) begin
                a_exp_neg = 0;
                b_exp_neg = 1;
                a_exp_c = a[30:23]-8'd127;
                b_exp_c = 8'd127-b[30:23];
            end
            else begin
                a_exp_neg = 0;
                b_exp_neg = 0;
                a_exp_c = a[30:23]-8'd127;
                b_exp_c = b[30:23]-8'd127;
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
            temp_product = {1'b1,a[22:0]}*{1'b1,b[22:0]};
            if (temp_product[47]==1'b1) begin
                product_nor = temp_product >> 1;
                if (y_exp_neg) y_exp_c_nor = y_exp_c-8'd1;
                else y_exp_c_nor = y_exp_c+8'd1;
                if (y_exp_c_nor == 8'd0) y_exp_neg_nor = 0;
                else y_exp_neg_nor = y_exp_neg;
            end
            else begin
                product_nor = temp_product;
                y_exp_c_nor = y_exp_c;
                y_exp_neg_nor = y_exp_neg;
            end

            // rounding
            sticky = (temp_product[20:0]>=21'd1) ? 1 : 0;
            if ({product_nor[22:21],sticky} > 3'b100 ||
                ({product_nor[22:21],sticky}==3'b100 &&
                 product_nor[25] == 1)) begin
                product_round = product_nor[47:23]+1;
                // check for normalization again
                if (product_round[24]==1) begin
                    y_product_mantisa = product_round[23:1];
                    if (y_exp_neg_nor) y_exp_c_round = y_exp_nor-8'd1;
                    else y_exp_c_nor = y_exp_c-8'd1;
                    if (y_exp_c_round == 8'd0) y_exp_neg_round = 0;
                    else y_exp_neg_round = y_exp_neg_nor;
                end
                else begin
                    y_product_mantisa = product_round[22:0];
                    y_exp_c_round = y_exp_c_nor;
                    y_exp_neg_round = y_exp_neg_nor;
                end
            end
            else begin
                product_round = product_nor[47:23];
                y_product_mantisa = product_round[22:0];
                y_exp_c_round = y_exp_c_nor;
                y_exp_neg_round = y_exp_neg_nor;
            end

            // calculate exp and putin mantisa
            if (y_exp_neg_round && y_exp_c_round > 8'd126) begin
                y[30:0] = 31'd0;
            end
            else if (y_exp_neg_round && y_exp_c_round <= 8'd126) begin
                y[30:23] = 8'd127 - y_exp_c_round;
                y[22:0] = y_product_mantisa;
            end
            else if (~y_exp_neg_round && y_exp_c_round > (max_exp-8'd127))begin
                y[30:23] = 8'b11111111;
                y[22:0] = 23'd0;
            end
            else begin
                y[30:23] = y_exp_c_round+8'd127;
                y[22:0] = y_product_mantisa;
            end
        end
    end

endmodule : fpu
