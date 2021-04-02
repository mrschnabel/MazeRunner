module D_term(
clk,
rst_n,
err_sat,
err_vld,
D_term
);

input clk;
input rst_n;
input [10:0] err_sat;
input err_vld;
output signed [14:0] D_term;

localparam D_COEFF = 7'h38;

logic [10:0] err_current;
logic [10:0] err_prev;
logic [10:0] D_diff;
logic signed [7:0] D_diff_sat;
logic signed [7:0] D_diff_sat_piped;

////////////////////////////////////////
// store current and previous error  //
//////////////////////////////////////

always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)begin
		err_current <= 15'h0000;
		err_prev <= 15'h0000;
	end
	else if(err_vld)begin
		err_current <= err_sat;
		err_prev <= err_current;
	end
end

/*always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		err_prev <= 15'h0000;
	else if(err_vld)
		err_prev <= err_current;
end*/

///////////////////////////////////////////////////////
//  Subtract previous error from current error  //////
/////////////////////////////////////////////////////

assign D_diff = err_sat - err_prev;

//saturate result to 8-bits
assign D_diff_sat = (D_diff[10] && ~D_diff[9:7]) ? 8'b10000000 :
			(~D_diff[10] && |D_diff[9:7]) ? 8'b01111111 : D_diff[7:0];

//add pipeline to help meet timing and reduce area
always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		D_diff_sat_piped <= 0;
	else
		D_diff_sat_piped <= D_diff_sat;
end

//Signed multiplication of D_diff and D_COEFF
assign D_term = $signed(D_COEFF) * D_diff_sat_piped;

endmodule