module CounterNbit #(parameter WIDTH=8)(clk,rst,init,init_val,inc,co,cnt_num);
    input clk,rst,init,inc;
    input[WIDTH-1:0] init_val;
    output co;
    output reg[WIDTH-1:0] cnt_num;

	always@(posedge clk or posedge rst)begin
		if(rst)
			cnt_num<={WIDTH{1'b0}};
		else if(init)
		    cnt_num<=init_val;
		else if(inc)
			cnt_num<=cnt_num+1;
		else
			cnt_num<=cnt_num;
	end
    assign co=&cnt_num;
endmodule
