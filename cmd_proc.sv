module cmd_proc(clk, rst_n, line_present,BMPL_n,BMPR_n, RX, go, err_opn_lp,buzz);

input clk;
input rst_n;
input line_present;
input RX;
input BMPL_n;
input BMPR_n;
output reg go;
output reg [15:0] err_opn_lp;
output reg buzz;

parameter FAST_SIM = 0;

//internal SM logic
logic last_veer_rght;
logic nxt_cmd;
logic [15:0] cmd_reg;
logic [1:0] cmd_2bit;
logic cmd_rdy;
logic cap_cmd;
logic rev1;
logic rev2;
logic veer;
logic clr_err_opn_lp;
logic BMP_wait;	//bypass clearing of timer while removing obstruction
logic buzz_en;	//enables buzzer oscillator

/*AUTOLOGIC*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
logic [15:0]		cmd;			// From iUART of UART_wrapper.v
// End of automatics

logic REV_tmr1;	//reverse timer step 1
logic REV_tmr2;	//reverse timer step 2
logic BMP_DBNC_tmr;	//debounce time of bump switches
logic [25:0] tmr;	//26-bit free running counter
logic [14:0] buzz_cnt;	//15 bit counter used to create 1.526kHz buzzer

//instantiate UART_wrapper
UART_wrapper iUART(/*AUTOINST*/
		   // Outputs
		   .cmd_rdy		(cmd_rdy),
		   .cmd			(cmd[15:0]),
		   // Inputs
		   .clk			(clk),
		   .rst_n		(rst_n),
		   .clr_cmd_rdy		(cap_cmd),
		   .RX			(RX));

///////////////////////////////////
// Select Sim mode or Real mode //
// //////////////////////////////

assign REV_tmr1 = (tmr[20:16] == 5'h0A && FAST_SIM)? 1 : (tmr[25:21] == 5'h16 && ~FAST_SIM)? 1 : 0;

assign REV_tmr2 =  (tmr[20:16] == 5'h10 && FAST_SIM)? 1 : (tmr[25:21] == 5'h1F && ~FAST_SIM)? 1 : 0;

assign BMP_DBNC_tmr = (FAST_SIM && &tmr[16:0])? 1 : (~FAST_SIM && &tmr[21:0])? 1:0;

//26-bit timer, cleared by 'go' signal
always_ff @(posedge clk,negedge rst_n)begin
	if(!rst_n)
		tmr <= 26'h0000000;
	else if(~go && ~BMP_wait)
		tmr <= 26'h0000000;
	else
		tmr <= tmr + 1;
end


///////////////////////////
//  Buzzer oscillator ////
/////////////////////////
always_ff @(posedge clk,negedge rst_n)begin
	if(!rst_n)
		buzz_cnt <= 0;
	else if(!buzz_en)
		buzz_cnt <= 0;
	else if(buzz_en)
		buzz_cnt <= buzz_cnt + 1;
end

assign buzz = buzz_cnt[14];	//buzz is tied to bit 14 of the buzz counter



////////////////////////////
// CMD Shift Reg //////////
//////////////////////////
always_ff @(posedge clk,negedge rst_n)begin
	if(!rst_n)
		cmd_reg <= 16'h0000;
	else if(cap_cmd)
		cmd_reg <= cmd;
	else if(nxt_cmd)
		cmd_reg <= {2'b00,cmd_reg[15:2]};
end

assign cmd_2bit = cmd_reg[1:0];

/////////////////////////
// last veer dir. reg //
///////////////////////
always_ff @(posedge clk,negedge rst_n)begin
	if(!rst_n)
		last_veer_rght <= 0;
	else if(nxt_cmd)
		last_veer_rght <= cmd_reg[0];
end

/////////////////////////
// err_opn_lp reg //////
///////////////////////
always @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		err_opn_lp <= 16'h0000;
	else if(clr_err_opn_lp)
		err_opn_lp <= 16'h0000;
	else if(veer && cmd_2bit[0])
		err_opn_lp <= 16'h340;
	else if(veer && cmd_2bit[1])
		err_opn_lp <= -16'h340;
	else if(rev1 && last_veer_rght)
		err_opn_lp <= -16'h1E0;
	else if(rev1 && ~last_veer_rght)
		err_opn_lp <= 16'h1E0;
	else if(rev2 && last_veer_rght)
		err_opn_lp <= 16'h380;
	else if(rev2 && ~last_veer_rght)
		err_opn_lp <= -16'h380;
end

//////////////////////////////
//  cmd_proc state machine //
////////////////////////////
typedef enum reg [7:0] {IDLE,LINE_PRESENT,OBSTRUCT,WAIT,EDGE_DETECT,WAIT_SHORT,WAIT_LONG,WAIT_LINE_PRESENT} state_t;
state_t state, nxt_state;

always_ff @(posedge clk or negedge rst_n)begin
	  if (!rst_n)
		      state <= IDLE;
	  else
		      state <= nxt_state;
end

always_comb begin
	//default SM outputs
	go = 1;
	//err_opn_lp = 16'h0000;
	buzz_en = 0;
	cap_cmd = 0;
	nxt_cmd = 0;
	rev1 = 0;
	rev2 = 0;
	veer = 0;
	clr_err_opn_lp = 0;
	BMP_wait = 0;
	nxt_state = state;

	case(state)
		IDLE: begin
			go = 0;
			if(cmd_rdy && line_present)begin
				nxt_state = LINE_PRESENT;
				go = 1;
				cap_cmd = 1;
			end
		end

	
		//check to see if there is a line present
		LINE_PRESENT: begin
			//turining around
			if(~line_present && cmd_2bit == 2'b11)begin
				nxt_state = WAIT_SHORT;
				go = 0;
				//err_opn_lp = (last_veer_rght)? 16'h1E0 : -16'h1E0;
				rev1 = 1;
			end
			//veering left or right to pick up new line
			else if(~line_present && |cmd_2bit[1:0])begin
				nxt_state = WAIT_LINE_PRESENT;
				//err_opn_lp =  (last_veer_rght)? 16'h340 : -16'h340;
				veer = 1;
			end
			//Stop
			else if(~line_present && cmd_2bit == 2'b00)begin
				go = 0;
				nxt_state = IDLE;
			end
			//continue to sequece to check for obstruction
			else if(line_present)begin
				nxt_state = OBSTRUCT;
			end


		end

	//begin obstruction sequence
		OBSTRUCT: begin
			//check to see if robot hit object
			if(~BMPR_n || ~BMPL_n)begin
				nxt_state = WAIT;
				go = 0;
				buzz_en = 1;
			end
			else
				nxt_state = LINE_PRESENT;

		end
		//wait 100ms before checking to see if object removed
		WAIT: begin
			go = 0;
			BMP_wait = 1;
			buzz_en = 1;

			//if button pressed again we assume object has been
				//removed
			if(BMP_DBNC_tmr)begin
				nxt_state = EDGE_DETECT;
				go = 0;
				buzz_en = 1;
			end

		end
		
		//wait for button to be pressed again (object removed)
		EDGE_DETECT: begin
			go = 0;
			buzz_en = 1;

			//if button pressed again we assume object has been
				//removed
			if(~BMPR_n || ~BMPL_n)begin
				nxt_state = LINE_PRESENT;
				go = 1;
			end

		end

	//the below states are for turning around
		WAIT_SHORT: begin
			if(REV_tmr1)begin
				nxt_state = WAIT_LONG;
				go = 0;
				//err_opn_lp = (last_veer_rght)? 16'h380 : -16'h380;
				rev2 = 1;
			end

		end

		WAIT_LONG: begin
			if(REV_tmr2)begin
				nxt_state = WAIT_LINE_PRESENT;
				clr_err_opn_lp = 1;
			end

		end

		WAIT_LINE_PRESENT: begin
			if(line_present)begin
				nxt_state = LINE_PRESENT;
				clr_err_opn_lp = 1;
				nxt_cmd = 1;
			end
		end

		
		default: begin
			nxt_state = IDLE;
		end
	endcase

end
endmodule
