`timescale 1ns/1ps

module tb_top;

    // ------------------------------------------------ parameters
    parameter int    W          = 640;
    parameter int    H          = 853;
    parameter int    NPIX       = W*H;          // 545920
    parameter int    OW         = W-2;          // 638 valid windows per row
    parameter int    OH         = H-2;          // 851 rows
    parameter int    NOUT       = OW*OH;        // 542938
    parameter int    PAD_MODE   = 2;            // 0: zeros, 1: nearest interior pixel, 2: half of it (corners always 0)
    parameter string IN_FILE    = "image_in.hex";
    parameter string OUT_FILE   = "image_out.hex";
    parameter int    CLK_PERIOD = 10;           // 100 MHz
    parameter int    MAX_CYCLES = 20_000_000;   // watchdog

    // ------------------------------------------------ signals and memories
    logic clk = 0, rst = 1, start = 0;
    wire  [7:0] in_data;
    wire        get_in, done, pixel_valid;
    wire  [7:0] pixel_out;

    logic [7:0] mem      [0:NPIX-1];            // input image
    logic [7:0] interior [0:NOUT-1];            // captured valid outputs, raster order
    logic [7:0] full     [0:NPIX-1];            // final padded output image

    int addr = 0;
    int cyc = 0, nvalid = 0, ngetin = 0, nmis = 0;
    int orow = 0, ocol = 0;
    int start_cyc = 0, first_valid_cyc = -1, done_cyc = 0;

    // ------------------------------------------------ golden model (exact software Sobel on interior pixels)
    function automatic int px(input int r, input int c);
        px = int'(mem[r*W + c]);
    endfunction

    function automatic logic [7:0] sobel_ref(input int r, input int c);
        int gx, gy, g;
        gx = -px(r-1,c-1) + px(r-1,c+1) - 2*px(r,c-1) + 2*px(r,c+1) - px(r+1,c-1) + px(r+1,c+1);
        gy = -px(r-1,c-1) - 2*px(r-1,c) - px(r-1,c+1) + px(r+1,c-1) + 2*px(r+1,c) + px(r+1,c+1);
        g  = ((gx < 0) ? -gx : gx) + ((gy < 0) ? -gy : gy);
        sobel_ref = (g > 255) ? 8'd255 : g[7:0];
    endfunction

    function automatic logic [7:0] pad_val(input logic [7:0] nb);
        case (PAD_MODE)
            1:       pad_val = nb;
            2:       pad_val = nb >> 1;
            default: pad_val = 8'h00;
        endcase
    endfunction

    // ------------------------------------------------ DUT and clock
    top dut (.clk(clk), .rst(rst), .get_in(get_in), .start(start), .in_data(in_data),
             .done(done), .pixel_out(pixel_out), .pixel_valid(pixel_valid));

    sobel_checker #(.W(W), .H(H), .LAT(7)) chk (
        .clk(clk), .rst(rst), .start(start), .get_in(get_in), .done(done),
        .pixel_valid(pixel_valid), .pixel_out(pixel_out),
        .window_ready(dut.window_ready),
        .read_pixel  (dut.read_pixel),
        .sum_in      (dut.Gpixel.dp_G.add2in.sum)   // 11-bit sum before the clamp
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // ------------------------------------------------ memory model: sends the next pixel on get_in
    initial $readmemh(IN_FILE, mem);

    assign in_data = (addr < NPIX) ? mem[addr] : 8'h00;   // always shows the next unconsumed pixel

    always @(posedge clk) begin
        if (rst)         addr <= 0;
        else if (get_in) addr <= addr + 1;                // advance only when the design took the pixel
    end

    // ------------------------------------------------ monitor: capture only valid outputs
    always @(posedge clk) begin
        cyc = cyc + 1;
        if (!rst && get_in) ngetin = ngetin + 1;

        if (!rst && pixel_valid) begin
            if (nvalid < NOUT) begin
                interior[nvalid] = pixel_out;
                if (pixel_out !== sobel_ref(orow+1, ocol+1)) begin
                    nmis = nmis + 1;
                    if (nmis <= 10)
                        $display("[TB] MISMATCH at (row=%0d, col=%0d): hw=%0d ref=%0d",
                                 orow+1, ocol+1, pixel_out, sobel_ref(orow+1, ocol+1));
                end
            end
            if (first_valid_cyc < 0) first_valid_cyc = cyc;
            nvalid = nvalid + 1;
            if (ocol == OW-1) begin ocol = 0; orow = orow + 1; end
            else                    ocol = ocol + 1;
        end
    end

    // ------------------------------------------------ build the 640x853 image: interior + padding
    task automatic build_full_image;
        int i, j;
        begin
            for (i = 0; i < NPIX; i++) full[i] = 8'h00;              // zeros everywhere (corners stay 0)
            for (i = 0; i < OH; i++)
                for (j = 0; j < OW; j++)
                    full[(i+1)*W + (j+1)] = interior[i*OW + j];
            if (PAD_MODE != 0) begin
                for (j = 1; j < W-1; j++) begin
                    full[j]                = pad_val(full[W + j]);                 // top row
                    full[(H-1)*W + j]      = pad_val(full[(H-2)*W + j]);           // bottom row
                end
                for (i = 1; i < H-1; i++) begin
                    full[i*W]              = pad_val(full[i*W + 1]);               // left column
                    full[i*W + (W-1)]      = pad_val(full[i*W + (W-2)]);           // right column
                end
            end
        end
    endtask

    task automatic write_file;
        int fd, i;
        begin
            fd = $fopen(OUT_FILE, "w");
            if (fd == 0) begin
                $display("[TB] ERROR: cannot open %s", OUT_FILE);
                $finish;
            end
            for (i = 0; i < NPIX; i++) $fwrite(fd, "%02x\n", full[i]);   // one pixel per line, raster order
            $fclose(fd);
        end
    endtask

    // ------------------------------------------------ stimulus
    initial begin
        #1;
        if ((^mem[0] === 1'bx) || (^mem[NPIX-1] === 1'bx)) begin
            $display("[TB] ERROR: %s is missing or has fewer than %0d lines", IN_FILE, NPIX);
            $finish;
        end
        $display("[TB] loaded %s (%0d pixels)", IN_FILE, NPIX);

        repeat (5) @(negedge clk);
        rst = 0;
        repeat (3) @(negedge clk);

        // one-cycle start pulse; done is already 1 in IDLE, so first wait for it to drop
        start = 1;
        @(negedge clk);
        start = 0;
        start_cyc = cyc;
        wait (done === 1'b0);
        $display("[TB] processing started (cycle %0d)", cyc);

        wait (done === 1'b1);                 // the run is over
        done_cyc = cyc;
        repeat (10) @(posedge clk);           // let the last pixel_valid drain

        if (ngetin != NPIX) $display("[TB] ERROR: design consumed %0d pixels, expected %0d", ngetin, NPIX);
        if (nvalid != NOUT) $display("[TB] ERROR: %0d valid outputs, expected %0d", nvalid, NOUT);

        build_full_image;
        write_file;

        $display("--------------------------------------------------------");
        $display("[TB] pixels consumed (get_in)        : %0d", ngetin);
        $display("[TB] valid outputs captured          : %0d (expected %0d)", nvalid, NOUT);
        $display("[TB] first valid pixel after start   : %0d cycles", first_valid_cyc - start_cyc);
        $display("[TB] total run                       : %0d cycles", done_cyc - start_cyc);
        $display("[TB] average cycles per output pixel : %0d", (done_cyc - start_cyc) / NOUT);
        $display("[TB] interior mismatches vs golden   : %0d", nmis);
        $display("[TB] padding mode                    : %0d", PAD_MODE);
        $display("[TB] wrote %s (%0d lines)", OUT_FILE, NPIX);
        if (nmis == 0 && nvalid == NOUT && ngetin == NPIX)
            $display("[TB] PASS: interior matches the reference exactly");
        else
            $display("[TB] FAIL");
        $finish;
    end

    // ------------------------------------------------ watchdog
    initial begin
        repeat (MAX_CYCLES) @(posedge clk);
        $display("[TB] TIMEOUT: done did not return after %0d cycles", MAX_CYCLES);
        $finish;
    end

endmodule