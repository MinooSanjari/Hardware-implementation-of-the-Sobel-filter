module twoscomp #(parameter WIDTH = 9) (in, out);
    input [WIDTH-1:0] in;
    output [WIDTH-1:0] out;

    assign out = (~in) + 1;

endmodule
