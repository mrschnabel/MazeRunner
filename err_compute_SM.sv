module err_compute_SM(
clk,
rst_n,
IR_vld,
sel,
clr_accum,
en_accum,
err_vld
);

input clk;
input rst_n;
input IR_vld;
output reg [2:0] sel;
output logic clr_accum;
output logic en_accum;
output logic err_vld;

logic inc_sel;  //tells counter to increment sel

//counter to increment sel
always @(posedge clk, negedge rst_n)begin
	if(!rst_n)begin
		sel <= 3'b000;
	end
	else if(clr_accum)begin	//clear the count each time computation initiates
		sel <= 3'b000;
	end
	else if(inc_sel)begin	//increment the count once signal given by SM
		sel <= sel + 1;
	end
end
			

//state machine
typedef enum reg [2:0] {IDLE,COMPUTE,VALID} state_t;

state_t state, nxt_state;

always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;
end

always_comb begin
	//default outputs
	clr_accum = 0;
	en_accum = 0;
	err_vld = 0;
	inc_sel = 0;
	nxt_state = state_t'(state);

	case(state)
		IDLE: begin
			if(IR_vld)begin		//wait for IR readings to be valid
				clr_accum = 1;		//clear the error accumulator
				nxt_state = COMPUTE;
			end
		end

		COMPUTE: begin
			en_accum = 1;		//enable the error accumulator for duration of error computation
			if(sel < 7)begin	//keep incrementing IR selector while less than 7 
				inc_sel = 1;
				nxt_state = COMPUTE;
			end
			else if(sel >= 7)begin	//once max val of selector reached, end computation
				inc_sel = 0;
				nxt_state = VALID;
			end	
				
		end

		VALID : begin
			err_vld = 1;		//assert the error to be valid
			nxt_state = IDLE;
		end
	endcase
end


endmodule





