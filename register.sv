module register_with_ld #(parameter WIDTH = 8) (clk, rst, ld, init, init_val, in, out);
    input clk, rst, ld, init;
    input [WIDTH-1:0] init_val, in;
    output reg [WIDTH-1:0] out;

    always @(posedge clk or posedge rst) begin
        if (rst)
            out <= 0;     
        else if (init)
            out <= init_val;
        else if (ld)
            out <= in;
    end

endmodule

module register_without_ld #(parameter WIDTH = 8) (clk, rst, init, init_val, in, out);
    input clk, rst, init;
    input [WIDTH-1:0] init_val, in;
    output reg [WIDTH-1:0] out;

    always @(posedge clk or posedge rst) begin
        if (rst)
            out <= 0;
        else if (init)
            out <= init_val;   
        else
            out <= in;
    end

endmodule

