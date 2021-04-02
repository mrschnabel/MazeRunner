module SPI_mstr16(clk,rst_n,SS_n,SCLK,MOSI,MISO,wrt,cmd,done,rd_data);

  input clk,rst_n;
  input wrt;
  input [15:0] cmd;
  input MISO;
  output reg done;		// done will come from a flop
  output reg SS_n;		// SS will come from a flop
  output SCLK, MOSI;
  output [15:0] rd_data;
  
  typedef enum reg[1:0] {IDLE, FRNT_PRCH, MAIN, BCK_PRCH} state_t;
  state_t state, nxt_state;
  
  //////////////////////////////
  // Define needed registers //
  ////////////////////////////
  reg [15:0] shft_reg;
  reg [4:0] sclk_div;
  reg MISO_smpl;
  reg [3:0] bit_cnt;
  
  ////////////////////////////
  // State Machine Outputs //
  //////////////////////////
  logic set_done,initialize,rst_sclk_div,shft,smpl;
  
  ////////////////////////////////////////
  // define any needed internal signal //
  //////////////////////////////////////
  wire SCLK_rise_nxt, SCLK_fall_nxt;
  
  ////////////////////////////////
  // infer main shift register //
  //////////////////////////////
  always @(posedge clk)
    if (initialize)
	  shft_reg <= cmd;
	else if (shft)
	  shft_reg <= {shft_reg[14:0],MISO_smpl};
	  
  assign rd_data = shft_reg;
  assign MOSI = shft_reg[15];
	
  /////////////////////////////////////////////
  // Infer flop to sample MISO on SCLK rise //
  ///////////////////////////////////////////
  always @(posedge clk)
    if (smpl)
	  MISO_smpl <= MISO;
	  
  /////////////////////////////////
  // Infer divider to make SCLK //
  ///////////////////////////////
  always @(posedge clk)
    if (rst_sclk_div)
	  sclk_div <= 5'b10111;
	else
	  sclk_div <= sclk_div + 1;
	  
  assign SCLK = sclk_div[4];
  assign SCLK_fall_nxt = &sclk_div;
  assign SCLK_rise_nxt = ~sclk_div[4] & &sclk_div[3:0];
  
  ////////////////////
  // Infer bit_cnt //
  //////////////////
  always @(posedge clk)
    if (initialize)
	  bit_cnt <= 4'b0000;
	else if (shft)
	  bit_cnt <= bit_cnt + 1;
	  
  //////////////////////
  // Infer done flop //
  ////////////////////
  always @(posedge clk,negedge rst_n)
    if (!rst_n)
	  done <= 1'b0;			// starts as 0
	else if (set_done)
	  done <= 1'b1;
	else if (initialize)
	  done <= 1'b0;
	  
  /////////////////
  // Infer SS_n //
  ///////////////
  always @(posedge clk,negedge rst_n)
    if (!rst_n)
	  SS_n <= 1'b1;			// starts as 1
	else if (set_done)
	  SS_n <= 1'b1;
	else if (initialize)
	  SS_n <= 1'b0;
	  
  ////////////////////////
  // Infer state flops //
  //////////////////////
  always @(posedge clk, negedge	rst_n)
    if (!rst_n)
	  state <= IDLE;
	else
	  state <= nxt_state;
	  
  /////////////////////////////////////////////////
  // SM state transition logic and outputs next //
  ///////////////////////////////////////////////
  always_comb begin
    nxt_state = IDLE;
	initialize = 0;
	rst_sclk_div = 0;
	set_done = 0;
	shft = 0;
	smpl = 0;
	case (state)
	  IDLE : begin
	    if (wrt) begin
		  initialize = 1;
		  nxt_state = FRNT_PRCH;
		end	 
        rst_sclk_div = 1;			// always reset it in this state
	  end
	  FRNT_PRCH : begin
	    if (SCLK_rise_nxt) begin
		  smpl = 1;
		  nxt_state = MAIN;
		end else
		  nxt_state = FRNT_PRCH;
	  end
	  MAIN : begin
	    smpl = SCLK_rise_nxt;
		shft = SCLK_fall_nxt;
		if (&bit_cnt & SCLK_rise_nxt)
		  nxt_state = BCK_PRCH;
		else
		  nxt_state = MAIN;
	  end
	  BCK_PRCH : begin
	    if (SCLK_fall_nxt) begin
		  rst_sclk_div = 1;			// freeze sclk_div so SCLK stays 1
		  set_done = 1;
		  shft = 1;
		  nxt_state = IDLE;
		end else
		  nxt_state = BCK_PRCH;  
	  end
	endcase
  end
	  
endmodule
  