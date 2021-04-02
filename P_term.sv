module P_term(
error,
err_sat,
P_term
);

input [15:0] error;
output logic signed [10:0] err_sat; //11 bit saturated error
output logic signed [14:0] P_term;

localparam P_COEFF = 4'h6;
 
logic signed [16:0] mult;

//11-bit saturation
assign err_sat = (error[15] && ~&error[14:10]) ? 11'b10000000000 :			
			(~error[15] && |error[14:10]) ? 11'b01111111111 : error[10:0];

			
assign mult = $signed(P_COEFF) * err_sat;	//signed multiplication of P_COEFF and err_sat

//15-bit saturation
assign P_term = (mult[16] && ~&mult[15:14]) ? 15'b100000000000000 :
			(~mult[16] && |mult[15:14]) ? 15'b011111111111111 : mult[14:0];

endmodule