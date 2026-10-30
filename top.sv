module top (clk, rst, get_in, start, in_data, pixel_valid, done, pixel_out);
input clk, rst, start;
input [7:0] in_data;
output get_in, done, pixel_valid;
output [7:0] pixel_out;

wire window_ready, read_pixel;
wire [63:0] window;

    top_Gpixel Gpixel (.clk(clk), .rst(rst), .window_ready(window_ready), .window_in(window), .read_pixel(read_pixel), .pixel_valid(pixel_valid), .pixel_out(pixel_out));
    top_LineBuffer_and_windowreg lb_and_window (.clk(clk), .rst(rst), .start(start), .in_data(in_data), .read_pixel(read_pixel), .window_ready(window_ready),
                                    .done(done), .get_in(get_in), .window_out(window));

endmodule
