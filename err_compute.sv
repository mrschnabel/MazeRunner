module err_compute(
clk,
rst_n,
IR_vld,
IR_R0,IR_R1,IR_R2,IR_R3,
IR_L0,IR_L1,IR_L2,IR_L3,
error,
err_vld
);

input clk;
input rst_n;
input IR_vld;
input [11:0] IR_R0,IR_R1,IR_R2,IR_R3;
input [11:0] IR_L0,IR_L1,IR_L2,IR_L3;
output reg signed [15:0] error;
output logic err_vld;

logic [15:0] error_raw;
logic err_vld_old;
logic  en_accum,clr_accum;

logic [2:0] sel;

//instantiate Data Path
err_compute_DP iDP(.clk(clk),.en_accum(en_accum),.clr_accum(clr_accum),.sub(sel[0]),
                     .sel(sel),.IR_R0(IR_R0),.IR_R1(IR_R1),.IR_R2(IR_R2),.IR_R3(IR_R3),
                     .IR_L0(IR_L0),.IR_L1(IR_L1),.IR_L2(IR_L2),.IR_L3(IR_L3),.error(error_raw));

//instantiate SM
err_compute_SM iSM(.clk(clk),.rst_n(rst_n),.IR_vld(IR_vld),.sel(sel),.clr_accum(clr_accum),
			.en_accum(en_accum),.err_vld(err_vld_old));	

//////////////////////////////////////////
//  error register && err_vld register //
////////////////////////////////////////
always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		error <= 16'h0000;
	else if(err_vld_old)
		error <= error_raw;
end
always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		err_vld <= 0;
	else
		err_vld <= err_vld_old;
end 


endmodule