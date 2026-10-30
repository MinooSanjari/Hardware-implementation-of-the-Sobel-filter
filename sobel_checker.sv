module sobel_checker #(
  parameter int W    = 640,
  parameter int H    = 853,
  parameter int NPIX = W*H,
  parameter int NOUT = (W-2)*(H-2),
  parameter int LAT  = 7      // get_in of a window-completing pixel -> pixel_valid
)(
  input logic        clk, rst, start, get_in, done, pixel_valid,
  input logic [7:0]  pixel_out,
  input logic        window_ready, read_pixel,   // internal control signals
  input logic [10:0] sum_in                      // internal: |Gx|+|Gy| before clamping
);

  // ---------- bookkeeping (checker-side only, not part of the RTL)
  int in_cnt, out_cnt, in_row, in_col;
  int n_fail    = 0;      // number of assertion failures seen
  int stop_after = 0;     // +SVA_STOP_AFTER=N : end the simulation after N failures (0 = never)

  initial begin
    void'($value$plusargs("SVA_STOP_AFTER=%d", stop_after));
    $display("[SVA] sobel_checker active: W=%0d H=%0d LAT=%0d stop_after=%0d", W, H, LAT, stop_after);
  end

  always @(n_fail)
    if (stop_after > 0 && n_fail >= stop_after) begin
      $display("[SVA] stopping simulation: %0d assertion failures reached the +SVA_STOP_AFTER limit", n_fail);
      $finish;
    end

  always_ff @(posedge clk) begin
    if (rst || (start && done)) begin
      in_cnt <= 0; out_cnt <= 0; in_row <= 0; in_col <= 0;
    end else begin
      if (get_in) begin
        in_cnt <= in_cnt + 1;
        if (in_col == W-1) begin in_col <= 0; in_row <= in_row + 1; end
        else                     in_col <= in_col + 1;
      end
      if (pixel_valid) out_cnt <= out_cnt + 1;
    end
  end

  // pixel whose arrival completes a 3x3 window (row>=2, col>=2): (W-2)*(H-2) of them
  logic win_ev;
  assign win_ev = get_in && (in_row >= 2) && (in_col >= 2);

  default clocking cb @(posedge clk); endclocking
  default disable iff (rst);

  // =====================================================================
  // 1. State during reset (async reset: outputs are in reset state one edge later)
  // =====================================================================
  a_reset_state: assert property (disable iff (1'b0)
      rst |=> (!pixel_valid && !get_in && done && !read_pixel && !window_ready && pixel_out == 8'd0))
    else begin $error("[SVA][reset] expected pixel_valid=0 get_in=0 done=1 pixel_out=0 during reset"); n_fail++; end

  // =====================================================================
  // 2. Output validity
  // =====================================================================
  a_valid_known: assert property (!$isunknown(pixel_valid))
    else begin $error("[SVA][valid] pixel_valid is X/Z"); n_fail++; end

  a_data_known_when_valid: assert property (pixel_valid |-> !$isunknown(pixel_out))
    else begin $error("[SVA][valid] pixel_valid=1 but pixel_out contains X/Z"); n_fail++; end

  a_no_valid_too_early: assert property (pixel_valid |-> (in_cnt >= 2*W+3))
    else begin $error("[SVA][valid] pixel_valid before first 3x3 window was fed (in_cnt=%0d)", in_cnt); n_fail++; end

  a_valid_count_limit: assert property (pixel_valid |-> (out_cnt < NOUT))
    else begin $error("[SVA][valid] more than %0d valid outputs", NOUT); n_fail++; end

  a_valid_not_idle: assert property (pixel_valid |-> !done)
    else begin $error("[SVA][valid] pixel_valid while done=1 (design idle)"); n_fail++; end

  a_valid_pulse_spacing: assert property (pixel_valid |=> !pixel_valid[*6])
    else begin $error("[SVA][valid] pixel_valid repeated sooner than 7 cycles (one pixel per 7 cycles)"); n_fail++; end

  // =====================================================================
  // 3. Datapath latency
  // =====================================================================
  a_latency_fwd: assert property (win_ev |-> ##LAT pixel_valid)
    else begin $error("[SVA][latency] no pixel_valid %0d cycles after a window-completing get_in", LAT); n_fail++; end

  a_latency_bwd: assert property (pixel_valid |-> $past(win_ev, LAT))
    else begin $error("[SVA][latency] pixel_valid without a window-completing get_in %0d cycles earlier", LAT); n_fail++; end

  a_first_valid: assert property ((start && done) |-> ##(2*W+3+LAT) pixel_valid)
    else begin $error("[SVA][latency] first pixel_valid not exactly %0d cycles after start", 2*W+3+LAT); n_fail++; end

  a_calc_latency: assert property ($rose(window_ready) |-> ##4 read_pixel)
    else begin $error("[SVA][latency] read_pixel not 4 cycles after window_ready rose (Gpixel FSM)"); n_fail++; end

  a_valid_after_read: assert property (read_pixel |=> pixel_valid)
    else begin $error("[SVA][latency] pixel_valid not 1 cycle after read_pixel"); n_fail++; end

  a_valid_only_after_read: assert property (pixel_valid |-> $past(read_pixel))
    else begin $error("[SVA][latency] pixel_valid without read_pixel in the previous cycle"); n_fail++; end

  // =====================================================================
  // 4. Output range: saturation to 8 bits (the 8-bit port width itself is trivially in range)
  // =====================================================================
  a_range_saturation: assert property (pixel_valid |->
        (pixel_out == (($past(sum_in) > 11'd255) ? 8'd255 : $past(sum_in[7:0]))))
    else begin $error("[SVA][range] pixel_out=%0d does not match clamp(|Gx|+|Gy|=%0d)", pixel_out, $past(sum_in)); n_fail++; end

  // =====================================================================
  // 5. Control signal behaviour
  // =====================================================================
  a_start_response: assert property ((start && done) |=> (!done && get_in))
    else begin $error("[SVA][ctrl] start in idle did not begin processing (done must fall, get_in must rise)"); n_fail++; end

  a_fill_phase: assert property ((start && done) |=> get_in[*(2*W+3)] ##1 !get_in)
    else begin $error("[SVA][ctrl] fill phase must read exactly %0d back-to-back pixels, then stop", 2*W+3); n_fail++; end

  a_getin_only_when_busy: assert property (get_in |-> !done)
    else begin $error("[SVA][ctrl] get_in asserted while done=1"); n_fail++; end

  a_no_getin_while_window: assert property (window_ready |-> !get_in)
    else begin $error("[SVA][ctrl] get_in asserted while a window is being processed"); n_fail++; end

  a_read_needs_window: assert property (read_pixel |-> window_ready)
    else begin $error("[SVA][ctrl] read_pixel without window_ready"); n_fail++; end

  a_window_drops_after_read: assert property ($fell(window_ready) |-> $past(read_pixel))
    else begin $error("[SVA][ctrl] window_ready dropped without read_pixel acknowledging it"); n_fail++; end

  a_done_after_all: assert property ($rose(done) |-> (in_cnt == NPIX && out_cnt == NOUT))
    else begin
      $error("[SVA][ctrl] done rose with in_cnt=%0d (exp %0d), out_cnt=%0d (exp %0d)", in_cnt, NPIX, out_cnt, NOUT);
      n_fail++;
    end

  // =====================================================================
  // Cover: proves the assertions were really exercised (not vacuous)
  // =====================================================================
  c_start:       cover property (start && done);
  c_first_valid: cover property ($rose(pixel_valid));
  c_last_valid:  cover property (pixel_valid && out_cnt == NOUT-1);
  c_saturated:   cover property (pixel_valid && pixel_out == 8'd255);
  c_done_rise:   cover property ($rose(done));

  // ---------- end-of-simulation summary
  final $display("[SVA] SUMMARY: pixels in=%0d, valid outputs=%0d (expected %0d), assertion failures=%0d",
                 in_cnt, out_cnt, NOUT, n_fail);
endmodule
