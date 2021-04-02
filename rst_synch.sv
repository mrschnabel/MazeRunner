module rst_synch(RST_n,clk,rst_n);

input RST_n;
input clk;
output reg rst_n;

reg dff1;

always_ff @(negedge clk, negedge RST_n)begin
	if(!RST_n) begin
		dff1 <= 0;
		rst_n <= 0;
	end
	else begin
		dff1 <= 1;
		rst_n <= dff1;	
	end
end

endmodule	