module multiply2 #(parameter WIDTH = 8) (in, out);
    input [WIDTH-1:0] in;
    output [WIDTH:0] out;

    assign out = {in, 1'b0};
endmodule
