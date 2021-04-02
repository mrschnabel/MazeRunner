module IR_intf(clk,rst_n,SS_n,SCLK,MOSI,MISO,
				IR_L0,IR_L1,IR_L2,IR_L3,
				IR_R0,IR_R1,IR_R2,IR_R3,
				IR_en,IR_vld,line_present);
	
	parameter FAST_SIM = 0;
	
	localparam LINE_THRES = 12'h040;	// threshold to determine line presence
	
	input clk,rst_n;	// System clock and active low asynch reset
	output logic SS_n;	// Active low slave select (to A2D)
	output logic SCLK;	// Serial clock to A2D
	output logic MOSI;	// Master Out Slave In (serial data to the A2D)
	input MISO;		// Master In Slave Out (serial data from the A2D)
	
	output logic [11:0] IR_L0,IR_L1,IR_L2,IR_L3;	// right sensor readings
	output logic [11:0] IR_R0,IR_R1,IR_R2,IR_R3;	// left sensor readings
	output logic IR_en;		// Asserted when sensor collection should be started
	output logic IR_vld;		// Asserted when all sensors have been converted
	output logic line_present;	// Asserted when the max reading is higher than the threshold
	
	typedef enum reg[3:0]{IDLE,SETTLE,CONV,STRT_CONV} state_t;
	state_t state, nxt_state;
	
	logic [17:0] tmr;	// free-running 18-bit timer
	
	logic nxt_round;	// Asserted when next round of conversions should occur
	logic settled;		// Asseretd when sensor reading has settled
	
	logic inc_chnnl;	// Asserted to increment channel select
	
	logic strt_cnv;		// Asserted when converstion should start (to A2D)
	logic cnv_cmplt;	// Asserted when conversion has been complete (from A2D)
	logic clr_chnnl;	// clears channel select when new round starts
	logic clr;		// clears IR_max register
	logic set_IR_en;	//asserts IR_en signal
	logic clr_IR_en;	//clears IR_en signal
	
	logic [2:0] chnnl;	// channel select
	logic [11:0] res;	// result from A2D_intf
	
	logic [11:0] IR_max;	// Maximum sensor reading
	
	///////////////////
	// Set Up Timer //
	/////////////////
	generate
		if(FAST_SIM) begin
			assign nxt_round = &tmr[13:0];
			assign settled = &tmr[10:0];
		end else begin
			assign nxt_round = &tmr;
			assign settled = &tmr[11:0];
		end
	endgenerate
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			tmr <= 18'h3FFFF;
		else if(nxt_round) // account for FAST_SIM roll over
			tmr <= 0;
		else
			tmr <= tmr + 1;
	end

	/////////////////////
	// IR_en register //
	///////////////////
	always_ff @(posedge clk, negedge rst_n)begin
		if(!rst_n)
			IR_en <= 0;
		else if(clr_IR_en)
			IR_en <= 0;
		else if(set_IR_en)
			IR_en <= 1;
	end
			
	///////////////////////////
	// Instantiate A2D_intf //
	/////////////////////////
	A2D_intf iA2D(.clk(clk),.rst_n(rst_n),.strt_cnv(strt_cnv),
				.cnv_cmplt(cnv_cmplt),.chnnl(chnnl),.res(res),
				.SS_n(SS_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO));
				
	////////////////////////
	// Set Up Next State //
	//////////////////////
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
	end
	
	////////////////////
	// State Machine //
	//////////////////
	always_comb begin
		// default outputs
		inc_chnnl = 0;
		clr_chnnl = 0;
		strt_cnv = 0;
		clr = 0;	
		IR_vld = 0;
		set_IR_en = 0;
		clr_IR_en = 0;
		nxt_state = state;
		
		case(state)
		
			IDLE:	// Wait until next round begins
				if(nxt_round) begin
					clr = 1;
					clr_chnnl = 1;
					set_IR_en = 1;
					nxt_state = SETTLE;
				end
			
			SETTLE: 	// Wait until sensor reading has settled then initiate conversion
				
				if(settled) begin
					//IR_en = 0;
					//clr_chnnl = 1;
					strt_cnv = 1;
					nxt_state = CONV;
				end
			
				
			CONV:	// iterate through channels to allow for conversion to complete
				if(cnv_cmplt) begin
					if(chnnl == 7) begin
						IR_vld = 1;
						clr_IR_en = 1;
						nxt_state = IDLE;
					end else begin
						//IR_en = 1;
						inc_chnnl = 1;
						nxt_state = STRT_CONV;
						//strt_cnv = 1;
					end
				end
			STRT_CONV: begin
				strt_cnv = 1;
				nxt_state = CONV;
				end
			default: 
				nxt_state = IDLE;
			
		endcase
	end
	
	//////////////////////
	// IR_max register //
	////////////////////
	always_ff @(posedge clk) begin
	// Document the maximum sensor reading
		if(clr)
			IR_max <= 0;
		else if(cnv_cmplt) begin
			if(res > IR_max)
				IR_max <= res;
		end
	end	
	
	///////////////////////////////////
	// Determine if line is present //
	/////////////////////////////////
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			line_present <= 0;
		else if(IR_vld) begin
			if(IR_max > LINE_THRES)
				line_present <= 1;
			else
				line_present <= 0;
		end 
			
	end
	
	//////////////////////////
	// Channel Incrementer //
	////////////////////////
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			chnnl <= 0;
		else if(clr_chnnl)
			chnnl <= 0;
		else if(inc_chnnl)
			chnnl <= chnnl + 1;
			
	end

	///////////////////////////////
	// Sensor Reading Registers //
	/////////////////////////////
	always_ff @(posedge clk) begin
		if(chnnl == 3'h0)
			IR_R0 <= res;
	end
	always_ff @(posedge clk) begin
		if(chnnl == 3'h1)
			IR_R1 <= res;
	end
	always_ff @(posedge clk) begin
		if(chnnl == 3'h2)
			IR_R2 <= res;
	end
	always_ff @(posedge clk) begin
		if(chnnl == 3'h3)
			IR_R3 <= res;
	end
	always_ff @(posedge clk) begin
		if(chnnl == 3'h4)
			IR_L0 <= res;
	end
	always_ff @(posedge clk) begin
		if(chnnl == 3'h5)
			IR_L1 <= res;
	end
	always_ff @(posedge clk) begin
		if(chnnl == 3'h6)
			IR_L2 <= res;
	end
	always_ff @(posedge clk) begin
		if(chnnl == 3'h7)
			IR_L3 <= res;
	end
	
endmodule