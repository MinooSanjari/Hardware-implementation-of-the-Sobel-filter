module mux_2to1 #(parameter WIDTH = 8)(a, b, sel, out);
    input [WIDTH-1:0] a, b; 
    input sel;
    output [WIDTH-1:0] out;

    assign out = sel ? b : a;
endmodule


module mux_4to1 #(parameter WIDTH = 8)(a, b, c, d, sel, out);
    input [WIDTH-1:0] a, b, c, d;
    input [1:0] sel;
    output [WIDTH-1:0] out;

    assign out =    (sel==2'd0) ? a :
                    (sel==2'd1) ? b :
                    (sel==2'd2) ? c :
                    (sel==2'd3) ? d :
                    {WIDTH{1'b0}};
    
endmodule
