module cont_Gpixel (clk, rst, window_ready, ld_G, sel_xadd3in, sel_yadd3in, sel_ld_Gx, sel_ld_Gy, init_regs, read_pixel, pixel_valid,
                    sel_xmul2_in, sel_ymul2_in, sel_x2comp_in, sel_y2comp_in);
    input clk, rst, window_ready;
    output reg ld_G, sel_xmul2_in, sel_ymul2_in, sel_ld_Gx, sel_ld_Gy, init_regs, read_pixel, pixel_valid;
    output reg [1:0] sel_xadd3in, sel_yadd3in, sel_x2comp_in, sel_y2comp_in;

    localparam WAIT_FOR_WINDOW =3'd0;
    localparam FIRST_MUL=3'd1;
    localparam SECOND_MUL=3'd2;
    localparam THIRD_MUL=3'd3;
    localparam CAL_G=3'd4;

    reg [2:0] Pstate, Nstate;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            Pstate <= WAIT_FOR_WINDOW;
        else
            Pstate <= Nstate;
    end

    `ifdef INJECT_LAT_BUG
    reg pv_d;                                   // extra pipeline stage = deliberate bug
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pv_d        <= 1'b0;
            pixel_valid <= 1'b0;
        end else begin
            pv_d        <= (Pstate == CAL_G);
            pixel_valid <= pv_d;                // valid now 1 cycle late
        end
    end
    `else
        always_ff @(posedge clk or posedge rst) begin
            if (rst)
                pixel_valid <= 1'b0;
            else
                pixel_valid <= (Pstate == CAL_G);   // G_reg holds the result in the cycle after CAL_G
        end
    `endif

    always_comb begin
        case (Pstate)
            WAIT_FOR_WINDOW: begin
                Nstate = window_ready ? FIRST_MUL : WAIT_FOR_WINDOW;
            end

            FIRST_MUL: begin
                Nstate = SECOND_MUL;
            end

            SECOND_MUL: begin
                Nstate = THIRD_MUL;
            end

            THIRD_MUL: begin
                Nstate = CAL_G;
            end

            CAL_G: begin
                Nstate = WAIT_FOR_WINDOW;
            end

            default: Nstate = WAIT_FOR_WINDOW; //added this line after first synthesis that gave a warning about latches for Nstate because of the absence of default

        endcase
    end

    always_comb begin

        ld_G=1'b0;
        sel_ld_Gx=1'b0;
        sel_ld_Gy=1'b0;
        init_regs=1'b0;
        read_pixel=1'b0;
        sel_xmul2_in=1'b0;
        sel_ymul2_in=1'b0;
        sel_xadd3in=2'b00;
        sel_yadd3in=2'b00;
        sel_x2comp_in=2'b00;
        sel_y2comp_in=2'b00;
            
        case (Pstate)

            WAIT_FOR_WINDOW: begin
                init_regs=1'b1;
            end

            FIRST_MUL: begin
                sel_ld_Gx =1'b1;
                sel_ld_Gy =1'b1;
                sel_xmul2_in =1'b0;
                sel_ymul2_in =1'b0;
                sel_xadd3in =2'b01;
                sel_yadd3in =2'b01;
                sel_x2comp_in =2'b00;
                sel_y2comp_in =2'b00;
            end

            SECOND_MUL: begin
                sel_ld_Gx =1'b1;
                sel_ld_Gy =1'b1;
                sel_xmul2_in =1'b1;
                sel_ymul2_in =1'b1;
                sel_xadd3in =2'b00;
                sel_yadd3in =2'b00;
                sel_x2comp_in =2'b01;
                sel_y2comp_in =2'b01;
            end

            THIRD_MUL: begin
                sel_ld_Gx =1'b1;
                sel_ld_Gy =1'b1;
                sel_xadd3in =2'b10;
                sel_yadd3in =2'b10;
                sel_x2comp_in =2'b10;
                sel_y2comp_in =2'b10;
            end

            CAL_G: begin
                sel_ld_Gx =1'b0;
                sel_ld_Gy =1'b0;
                sel_x2comp_in =2'b11;
                sel_y2comp_in =2'b11;
                ld_G=1'b1;
                read_pixel = 1'b1;
            end

        endcase
    end

endmodule
