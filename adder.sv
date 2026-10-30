module csa_3in #(parameter int WIDTH = 8)(a, b, c, y);
    input  logic signed [WIDTH-1:0] a, b, c;
    output logic signed [WIDTH-1:0] y;

    logic [WIDTH-1:0] s, cy;
    assign s  = a ^ b ^ c;
    assign cy = ((a & b) | (a & c) | (b & c)) << 1;
    assign y  = s + cy;

endmodule

module adder2in_clamp #(parameter IN_WIDTH = 10, parameter OUT_WIDTH = 8) (
    input  logic [IN_WIDTH-1:0]  in1, in2,
    output logic [OUT_WIDTH-1:0] out
);
    logic [IN_WIDTH:0] sum;
    assign sum = in1 + in2;
    assign out = (|sum[IN_WIDTH:OUT_WIDTH]) ? {OUT_WIDTH{1'b1}} : sum[OUT_WIDTH-1:0];
endmodule

