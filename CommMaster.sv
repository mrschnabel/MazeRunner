module CommMaster(
clk,
rst_n,
cmd,
send_cmd,
TX,
cmd_sent
);

input clk;
input rst_n;
input [15:0] cmd;
input send_cmd;
output reg TX;
output reg cmd_sent;

reg [7:0] LOWER_BYTE;	//lower half byte of cmd

reg [7:0] tx_data;	//data input to UART transmitter
logic trmt;		//SM output telling transmitter to begin
logic tx_done;		//signal from UART transmitter, high when transmitting complete
logic set_cmd_cmplt;	//signal from SM indicating end of cmd division
logic sel;		//SM signal used to select upper half byte if high or lower byte if low
logic clr_cmd_cmplt;	//SM signal used to deassert cmd_cplt

///////////////////////////////////
// Instantiate UART Transmitter //
/////////////////////////////////

UART_tx iTX(.clk(clk),.rst_n(rst_n),.TX(TX),.trmt(trmt),.tx_data(tx_data),.tx_done(tx_done));

////////////////
// Data Path //
//////////////

//This block stores the lower byte of cmd
always_ff @(posedge clk)begin
	if(send_cmd)
		LOWER_BYTE <= cmd[7:0];
end

assign tx_data = (sel) ? cmd[15:8] : LOWER_BYTE;	//send half of cmd at a time

///////////////////////
// State Machine /////
/////////////////////

typedef enum reg [2:0] {UPPER,LOWER,DONE} state_t;

state_t state, nxt_state;

always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		state <= UPPER;
	else
		state <= nxt_state;
end

always_comb begin
	//default outputs
	sel = 0;
	trmt = 0;
	set_cmd_cmplt = 0;
	clr_cmd_cmplt = 0;
	nxt_state = state_t'(state);

	case(state)
		UPPER: begin	//transmit the upper byte first
			
			if(send_cmd)begin	//when data is ready to be sent, store the lower byte
				sel = 1;	//select the upper byte to send
				trmt= 1;	//transmit the data
				clr_cmd_cmplt = 1;
				nxt_state = LOWER;
			end

		end
					
		LOWER: begin	//transmit the lower byte
			if(tx_done)begin	//wait for all bits of higher byte to be sent
				trmt = 1;	
				nxt_state = DONE;
			end
		end
			
		DONE: begin
			if(tx_done)begin	//wait for lower byte to be sent
				set_cmd_cmplt = 1;
				nxt_state = UPPER;
			end
			
		end

		default: begin
			nxt_state = UPPER;
		end
	endcase
end

//final output flop
always @(posedge clk, negedge rst_n)begin
	if(!rst_n)begin
		cmd_sent <= 0;
	end
	else if(set_cmd_cmplt)begin
		cmd_sent <= 1;
	end
	else if(clr_cmd_cmplt)begin
		cmd_sent <= 0;
	end
end

endmodule
