module LineBuffer #(parameter WIDTH = 640, parameter DEPTH = 3, parameter SIZE = 8) (
    input  logic clk, rst, inc_cnt_col, inc_cnt_depth, shift_up, ld_init_dpth, ld_cnt_init, get_in,
    input  logic [1:0] row_i,
    input  logic [SIZE-1:0] in_data,
    output logic finish_row, row_end, finish_depth, first_window,
    output logic [63:0] out_data
);
    wire [9:0] cnt_depth, lb_pointer;
    wire co_not_used;

    assign first_window = (lb_pointer == 10'd2);
    assign finish_row   = (lb_pointer == WIDTH-1);
    assign row_end      = (lb_pointer == WIDTH);       // all 640 pixels written

    // logic [0:WIDTH-1][SIZE-1:0] lb [0:DEPTH-1];
    logic [SIZE-1:0] lb [0:DEPTH-1][0:WIDTH-1];     // lb[row][col], each element SIZE bits

    CounterNbit #(.WIDTH(10)) col_cnt   (.clk(clk), .rst(rst), .init(ld_cnt_init), .init_val(10'd0),   .inc(inc_cnt_col),   .co(co_not_used),  .cnt_num(lb_pointer));
    CounterNbit #(.WIDTH(10)) depth_cnt (.clk(clk), .rst(rst), .init(ld_init_dpth), .init_val(10'd173), .inc(inc_cnt_depth), .co(finish_depth), .cnt_num(cnt_depth));


    always_ff @(posedge clk) begin
        if (shift_up) begin
            for (int c = 0; c < WIDTH; c++) begin
                lb[0][c] <= lb[1][c];
                lb[1][c] <= lb[2][c];
            end
        end
        else if (get_in) begin
            lb[row_i][lb_pointer] <= in_data;
        end
    end

    // newest stored pixel is at lb_pointer-1
    assign out_data = {lb[0][lb_pointer-3], lb[0][lb_pointer-2], lb[0][lb_pointer-1],
                       lb[1][lb_pointer-3],                      lb[1][lb_pointer-1],
                       lb[2][lb_pointer-3], lb[2][lb_pointer-2], lb[2][lb_pointer-1]};
endmodule


module dp_LineBuffer_and_windowreg (clk, rst, window_out, in_data,
                                    finish_row, row_end, finish_depth, first_window, inc_cnt_col,
                                    inc_cnt_depth, shift_up, ld_init_dpth, ld_window, ld_cnt_init, get_in, row_i);
    input clk, rst;
    input [7:0] in_data;
    output [63:0] window_out;

    output finish_row, finish_depth, first_window, row_end;
    input inc_cnt_col, inc_cnt_depth, shift_up, ld_init_dpth, ld_window, ld_cnt_init, get_in;
    input [1:0] row_i;

    wire [63:0] out_data;

    LineBuffer #(.WIDTH(640), .DEPTH(3), .SIZE(8)) linebuff (.clk(clk), .rst(rst), .inc_cnt_col(inc_cnt_col), .inc_cnt_depth(inc_cnt_depth),
                                                            .shift_up(shift_up), .ld_init_dpth(ld_init_dpth), .ld_cnt_init(ld_cnt_init), .get_in(get_in),
                                                            .row_i(row_i), .in_data(in_data), .finish_row(finish_row), .row_end(row_end),
                                                            .finish_depth(finish_depth), .first_window(first_window), .out_data(out_data));
    register_with_ld #(.WIDTH(64)) window_reg (.clk(clk), .rst(rst), .ld(ld_window), .init(1'b0), .init_val(64'd0),
                                                .in(out_data), .out(window_out));

endmodule



module cnt_LineBuffer_and_windowreg (clk, rst, start, finish_row, finish_depth, first_window, read_pixel, row_end, done,
                                    inc_cnt_col, inc_cnt_depth, shift_up, ld_init_dpth, get_in, ld_window, window_ready,
                                    ld_cnt_init, row_i);
    input clk, rst, start, finish_row, finish_depth, first_window, read_pixel, row_end;
    output reg inc_cnt_col, inc_cnt_depth, shift_up, ld_init_dpth, get_in, ld_window, window_ready, ld_cnt_init;
    output reg done;
    output reg [1:0] row_i;

    localparam IDLE =3'd0;
    localparam FIRST_ROW=3'd1;
    localparam SECOND_ROW=3'd2;
    localparam IN_THIRD_ROW=3'd3;
    localparam LD_WINDOW = 3'd4;
    localparam WINDOW_READY=3'd5;
    localparam THIRD_ROW_NEXT = 3'd6;
    localparam THIRD_ROW_FINISHED = 3'd7;

    reg [2:0] Pstate, Nstate;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            Pstate <= IDLE;
        else
            Pstate <= Nstate;
    end

    always_comb begin
        case (Pstate)
            IDLE: begin
                Nstate = start ? FIRST_ROW : IDLE;
            end

            FIRST_ROW: begin
                Nstate = finish_row ? SECOND_ROW : FIRST_ROW;
            end

            SECOND_ROW: begin
                Nstate = finish_row ? IN_THIRD_ROW : SECOND_ROW;
            end

            IN_THIRD_ROW: begin
                Nstate = first_window ? LD_WINDOW : IN_THIRD_ROW;
            end

            LD_WINDOW : begin
                Nstate = WINDOW_READY;
            end

            WINDOW_READY: begin
                 Nstate = !read_pixel ? WINDOW_READY : 
                            (row_end ? THIRD_ROW_FINISHED : THIRD_ROW_NEXT);
            end

            THIRD_ROW_NEXT: begin
                Nstate = LD_WINDOW;
            end

            THIRD_ROW_FINISHED: begin
                Nstate = finish_depth ? IDLE : IN_THIRD_ROW;
            end

            default: Nstate = IDLE; //added this line after first synthesis that gave a warning about latches for Nstate because of the absence of default

        endcase
    end

    always @(*) begin

        inc_cnt_col=1'b0;
        inc_cnt_depth=1'b0;
        shift_up=1'b0;
        ld_init_dpth=1'b0;
        get_in=1'b0;
        ld_window=1'b0;
        window_ready=1'b0;
        ld_cnt_init=1'b0;
        done=1'b0;
        row_i=2'b10;
                    
        case (Pstate)

            IDLE: begin
                done=1'b1;
                ld_init_dpth=1'b1;
                ld_cnt_init=1'b1;
                row_i=2'b00;
            end

            FIRST_ROW: begin
                inc_cnt_col=1'b1;
                get_in=1'b1;
                row_i=2'b00;
                ld_cnt_init=finish_row;
            end

            SECOND_ROW: begin
                inc_cnt_col=1'b1;
                get_in=1'b1;
                row_i=2'b01;
                ld_cnt_init=finish_row;
            end

            IN_THIRD_ROW: begin
                inc_cnt_col=1'b1;
                get_in=1'b1;
            end

            LD_WINDOW: begin
                ld_window=1'b1;
            end

            WINDOW_READY: begin
                window_ready=1'b1;
            end

            THIRD_ROW_NEXT: begin
                inc_cnt_col=1'b1;
                get_in=1'b1;
            end

            THIRD_ROW_FINISHED: begin
                inc_cnt_depth=1'b1;
                shift_up=1'b1;
                ld_cnt_init=1'b1;
            end

        endcase
    end


endmodule


module top_LineBuffer_and_windowreg (clk, rst, start, in_data, read_pixel, window_ready, done, get_in, window_out);
    input clk, rst, start, read_pixel;
    input [7:0] in_data;
    output window_ready, done, get_in;
    output [63:0] window_out;

    wire finish_row, finish_depth, first_window, inc_cnt_col;
    wire inc_cnt_depth, shift_up, ld_init_dpth, ld_window, ld_cnt_init;
    wire [1:0] row_i;
    wire row_end;
    
    dp_LineBuffer_and_windowreg lb_dp (.clk(clk), .rst(rst), .window_out(window_out), .in_data(in_data),
                                    .finish_row(finish_row), .row_end(row_end), .finish_depth(finish_depth), .first_window(first_window),
                                    .inc_cnt_col(inc_cnt_col), .inc_cnt_depth(inc_cnt_depth), .shift_up(shift_up), .ld_init_dpth(ld_init_dpth),
                                    .ld_window(ld_window), .ld_cnt_init(ld_cnt_init), .get_in(get_in), .row_i(row_i));

    cnt_LineBuffer_and_windowreg lb_cont (.clk(clk), .rst(rst), .start(start), .finish_row(finish_row), .finish_depth(finish_depth),
                                    .first_window(first_window), .read_pixel(read_pixel), .row_end(row_end), .done(done),
                                    .inc_cnt_col(inc_cnt_col), .inc_cnt_depth(inc_cnt_depth), .shift_up(shift_up), .ld_init_dpth(ld_init_dpth),
                                    .get_in(get_in), .ld_window(ld_window), .window_ready(window_ready), .ld_cnt_init(ld_cnt_init), .row_i(row_i));
endmodule
