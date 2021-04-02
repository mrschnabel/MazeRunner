module PID(
clk,
rst_n,
error,
err_vld,
go,
line_present,
rght_spd,
lft_spd
);

parameter FAST_SIM = 0;

input clk;
input rst_n;
input [15:0] error;
input err_vld;
input go;
input line_present;
output reg signed [11:0] rght_spd;
output reg signed [11:0] lft_spd;

//internal logic
logic [5:0] FRWRD;
logic [10:0] frwrd;
logic [10:0] err_sat;
logic [14:0] P_term;
logic [9:0] I_term;
logic signed [14:0] D_term;
//logic line_present;
logic moving;

logic [14:0] PID;

logic [10:0] err_sat_piped;	//pipelined err_sat
logic err_vld_piped;


//if FAST_SIM = 1 we are in simulation mode, and simulation is sped up
generate
	if(FAST_SIM)
		assign FRWRD = 6'h20;
	else
		assign FRWD = 6'h04;
endgenerate

/////////////////////////////////////////
// pipeline err_sat and err_vld ////////
///////////////////////////////////////
always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		err_sat_piped <= 0;
	else
		err_sat_piped <= err_sat;
end

always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		err_vld_piped <= 0;
	else
		err_vld_piped <= err_vld;
end


//////////////////////////////////////////
// Instantiate P, I, & D modules ////////
////////////////////////////////////////
P_term iP(.error(error),.err_sat(err_sat),.P_term(P_term));

I_term iI(.clk(clk),.rst_n(rst_n),.err_sat(err_sat_piped),.line_present(line_present),
		.go(go),.moving(moving),.err_vld(err_vld_piped),.I_term(I_term));

D_term iD(.clk(clk),.rst_n(rst_n),.err_sat(err_sat_piped),.err_vld(err_vld_piped),.D_term(D_term));

////////////////////////////////////
/// sum P, I & D terms ////////////
//////////////////////////////////
assign PID = P_term + I_term + D_term;

//////////////////////////////////
// forward register  ////////////
////////////////////////////////
always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		frwrd <= 0;
	else if(~go)
		frwrd <= 0;
	else if(err_vld && !(&frwrd[9:8]))
		frwrd <= frwrd + FRWRD;
end

//we are moving if frwrd is > than 11'h080
assign moving = (frwrd > 11'h080) ? 1'b1 : 1'b0;

/////////////////////////////
// left speed computation //
///////////////////////////
always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		lft_spd <= 12'h000;
	else if(moving && go)
		lft_spd <= PID[14:3] + {1'b0,frwrd};
	else if(moving && ~go)
		lft_spd <= 12'h000 + {1'b0,frwrd};
	else if(~moving)
		lft_spd <= {1'b0,frwrd};
end


//////////////////////////////
// right speed computation //
////////////////////////////
always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		rght_spd <= 12'h000;
	else if(moving && go)
		rght_spd <=  {1'b0,frwrd} - PID[14:3];
	else if(moving && ~go)
		rght_spd <= {1'b0,frwrd} - 12'h000;
	else if(~moving)
		rght_spd <= {1'b0,frwrd};
end

endmodule

