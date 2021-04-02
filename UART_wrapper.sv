module UART_wrapper(
clk,
rst_n,
clr_cmd_rdy,
RX,
cmd_rdy,
cmd
);

input clk;
input rst_n;
input clr_cmd_rdy;
input RX;
output reg cmd_rdy;
output reg [15:0] cmd;

reg [7:0] UPPER_BYTE; 	//upper half bits of cmd
reg [7:0] rx_data;	//data from UART_rcv
logic store;		//selects rx_data to be stored when high
logic rdy;		//signal from UART_rcv telling SM that data is ready to be processed
logic set_cmd_rdy;	//signal from SM upon completion
logic clr_rdy;		//sent to UART_rcv to lower rdy signal

/////////////////////////////
/// Instantiate UART_rcv ///
///////////////////////////

UART_rcv iRCV(.clk(clk),.rst_n(rst_n),.RX(RX),.clr_rdy(clr_rdy),.rx_data(rx_data),.rdy(rdy));

////////////////
// Data path //
//////////////

//This block stores the upper half byte of cmd
//The byte is stored when store signal from SM is high
always_ff @(posedge clk) begin
	if(store)
		UPPER_BYTE <= rx_data;
end

assign cmd = {UPPER_BYTE,rx_data};  //cmd = UPPER + LOWER bytes

////////////////////
// State Machine //
//////////////////

typedef enum reg [1:0] {UPPER,LOWER} state_t;

state_t state, nxt_state;

always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		state <= UPPER;
	else
		state <= nxt_state;
end

always_comb begin
	//default outputs
	store = 0;
	clr_rdy = 0;
	set_cmd_rdy = 0;
	nxt_state = state_t'(state);

	case(state)
		UPPER: begin
			if(rdy)begin	//when data from UART is ready, store the upper byte
				store = 1;
				clr_rdy = 1;	//clear the ready signal
				nxt_state = LOWER;
			end
		end
					
		LOWER: begin
			if(rdy)begin
				set_cmd_rdy = 1;	//cmd is ready for use
				clr_rdy = 1;	//clear the ready signal
				nxt_state = UPPER;
			end
		end

		default: begin
			nxt_state = UPPER;
		end
	endcase
end

//final output flops
always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)begin
		cmd_rdy <= 0;
	end
	else if(set_cmd_rdy)begin
		cmd_rdy <= 1;
	end
	else if(clr_cmd_rdy)begin
		cmd_rdy <= 0;
	end
end

endmodule
