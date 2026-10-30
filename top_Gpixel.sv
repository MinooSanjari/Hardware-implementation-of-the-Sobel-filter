module top_Gpixel (clk, rst, window_ready, window_in, read_pixel, pixel_valid, pixel_out);
    input clk, rst, window_ready;
    input [63:0] window_in;
    output read_pixel, pixel_valid;
    output [7:0] pixel_out;

    wire ld_G, sel_xmul2_in, sel_ymul2_in, sel_ld_Gx, sel_ld_Gy, init_regs, read_pixel;
    wire [1:0] sel_xadd3in, sel_yadd3in, sel_x2comp_in, sel_y2comp_in;

    dp_Gpixel dp_G (.clk(clk), .rst(rst), .ld_G(ld_G), .sel_xmul2_in(sel_xmul2_in), .sel_ymul2_in(sel_ymul2_in),
                .sel_xadd3in(sel_xadd3in), .sel_yadd3in(sel_yadd3in), .sel_ld_Gx(sel_ld_Gx), .sel_ld_Gy(sel_ld_Gy),
                .init_regs(init_regs), .sel_x2comp_in(sel_x2comp_in), .sel_y2comp_in(sel_y2comp_in),
                .window_in(window_in), .out_pixel(pixel_out));

    cont_Gpixel cont_G (.clk(clk), .rst(rst), .window_ready(window_ready), .ld_G(ld_G), .sel_xadd3in(sel_xadd3in),
                    .sel_yadd3in(sel_yadd3in), .sel_ld_Gx(sel_ld_Gx), .sel_ld_Gy(sel_ld_Gy), .init_regs(init_regs),
                    .read_pixel(read_pixel), .pixel_valid(pixel_valid), .sel_xmul2_in(sel_xmul2_in), .sel_ymul2_in(sel_ymul2_in),
                    .sel_x2comp_in(sel_x2comp_in), .sel_y2comp_in(sel_y2comp_in));
    
endmodule
