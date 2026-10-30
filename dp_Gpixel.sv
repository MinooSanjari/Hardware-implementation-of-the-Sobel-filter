module dp_Gpixel (clk, rst, ld_G, sel_xmul2_in, sel_ymul2_in,
            sel_xadd3in, sel_yadd3in, sel_ld_Gx, sel_ld_Gy, init_regs, sel_x2comp_in, sel_y2comp_in,
            window_in, out_pixel);
    input clk, rst, ld_G, sel_xmul2_in, sel_ymul2_in, sel_ld_Gx, sel_ld_Gy, init_regs;
    input[1:0]  sel_x2comp_in, sel_y2comp_in, sel_xadd3in, sel_yadd3in;
    input [63:0] window_in;
    output[7:0] out_pixel;


    wire [7:0] x00, x01, x02, x10, x12, x20, x21, x22; 
    wire [10:0] Gxreg_in, Gyreg_in, Gxreg_out, Gyreg_out;
    wire [7:0] add2_to_Greg;
    // wire [7:0] Greg_out;
    // wire sel_outpixel;
    wire [10:0] mux_to_x2comp, mux_to_y2comp, x_2comp_out, y_2comp_out;
    wire [7:0] mux_to_xmul2, mux_to_ymul2;
    wire [8:0] x_mul2_out, y_mul2_out, x_mul2_to_2comp, y_mul2_to_2comp;
    wire [9:0] Gxreg_pos, Gyreg_pos;
    wire [8:0] mux_to_3inadderx, mux_to_3inaddery;
    wire [10:0] add3_to_Gxreg, add3_to_Gyreg;


    assign x00 = window_in[63:56];
    assign x01 = window_in[55:48];
    assign x02 = window_in[47:40];
    assign x10 = window_in[39:32];
    assign x12 = window_in[31:24];
    assign x20 = window_in[23:16];
    assign x21 = window_in[15:8];
    assign x22 = window_in[7:0];


    register_without_ld #(.WIDTH(9)) x_mul2_reg (.clk(clk), .rst(rst),.init(init_regs), .init_val(9'd0), .in(x_mul2_out), .out(x_mul2_to_2comp));
    register_without_ld #(.WIDTH(9)) y_mul2_reg (.clk(clk), .rst(rst),.init(init_regs), .init_val(9'd0), .in(y_mul2_out), .out(y_mul2_to_2comp));
    register_without_ld #(.WIDTH(11)) Gx_reg (.clk(clk), .rst(rst),.init(init_regs), .init_val(11'd0), .in(Gxreg_in), .out(Gxreg_out));
    register_without_ld #(.WIDTH(11)) Gy_reg (.clk(clk), .rst(rst),.init(init_regs), .init_val(11'd0), .in(Gyreg_in), .out(Gyreg_out));
    register_with_ld #(.WIDTH(8)) G_reg (.clk(clk), .rst(rst), .ld(ld_G), .init(1'b0), .init_val(8'd0), .in(add2_to_Greg), .out(out_pixel));

    mux_4to1 #(.WIDTH(11)) x_comp_in (.a({3'd0,x20}), .b({2'd0,x_mul2_to_2comp}), .c({3'd0,x00}), .d(Gxreg_out), .sel(sel_x2comp_in), .out(mux_to_x2comp));
    twoscomp #(.WIDTH(11)) x_2comp (.in(mux_to_x2comp), .out(x_2comp_out));

    mux_4to1 #(.WIDTH(11)) y_comp_in (.a({3'd0,x02}), .b({2'd0,y_mul2_to_2comp}), .c({3'd0,x00}), .d(Gyreg_out), .sel(sel_y2comp_in), .out(mux_to_y2comp));
    twoscomp #(.WIDTH(11)) y_2comp (.in(mux_to_y2comp), .out(y_2comp_out));

    mux_2to1 #(.WIDTH(8)) x_mul2_in (.a(x10), .b(x12), .sel(sel_xmul2_in), .out(mux_to_xmul2));
    multiply2 #(.WIDTH(8)) x_mul2 (.in(mux_to_xmul2), .out(x_mul2_out));

    mux_2to1 #(.WIDTH(8)) y_mul2_in (.a(x01), .b(x21), .sel(sel_ymul2_in), .out(mux_to_ymul2));
    multiply2 #(.WIDTH(8)) y_mul2 (.in(mux_to_ymul2), .out(y_mul2_out));

    mux_4to1 #(.WIDTH(9)) x_add3_in (.a(x_mul2_out), .b({1'd0,x02}), .c({1'd0,x22}), .d(9'd0), .sel(sel_xadd3in), .out(mux_to_3inadderx));
    csa_3in #(.WIDTH(11)) x_add3 (.a(Gxreg_out), .b(x_2comp_out), .c({2'd0,mux_to_3inadderx}), .y(add3_to_Gxreg));
    mux_4to1 #(.WIDTH(9)) y_add3_in (.a(y_mul2_out), .b({1'd0,x20}), .c({1'd0,x22}), .d(9'd0), .sel(sel_yadd3in), .out(mux_to_3inaddery));
    csa_3in #(.WIDTH(11)) y_add3 (.a(Gyreg_out), .b(y_2comp_out), .c({2'd0,mux_to_3inaddery}), .y(add3_to_Gyreg));


    mux_2to1 #(.WIDTH(11)) x_Gxreg_in (.a(Gxreg_out), .b(add3_to_Gxreg), .sel(sel_ld_Gx), .out(Gxreg_in));
    mux_2to1 #(.WIDTH(11)) y_Gyreg_in (.a(Gyreg_out), .b(add3_to_Gyreg), .sel(sel_ld_Gy), .out(Gyreg_in));

    mux_2to1 #(.WIDTH(10)) x_add2_in (.a(Gxreg_out[9:0]), .b(x_2comp_out[9:0]), .sel(Gxreg_out[10]), .out(Gxreg_pos));
    mux_2to1 #(.WIDTH(10)) y_add2_in (.a(Gyreg_out[9:0]), .b(y_2comp_out[9:0]), .sel(Gyreg_out[10]), .out(Gyreg_pos));
    adder2in_clamp #(.IN_WIDTH(10), .OUT_WIDTH(8)) add2in (.in1(Gxreg_pos), .in2(Gyreg_pos), .out(add2_to_Greg));
    // comparator #(.WIDTH(8)) comp_threshold (.in(Greg_out), .threshold(threshold), .out(sel_outpixel));
    // mux_2to1 #(.WIDTH(8)) output_pixel (.a(8'd0), .b(8'd255), .sel(sel_outpixel), .out(out_pixel));

endmodule
