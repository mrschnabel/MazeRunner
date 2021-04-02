module cmd_proc_tb();

reg clk, rst_n;
wire RX;
reg BMPL_n;
reg BMPR_n;
reg line_present;
wire go;
wire buzz;
wire [15:0] err_opn_lp;

reg trmt;
reg [7:0] tx_data;
wire tx_done; 


localparam FAST_SIM = 1;

//////////////////////////////////////////////////////
/// Instantiate cmd_proc && UART Transmitter ////////
////////////////////////////////////////////////////

cmd_proc  #(FAST_SIM) icmd(.clk(clk),.rst_n(rst_n),.line_present(line_present),.BMPL_n(BMPL_n),.BMPR_n(BMPR_n),.RX(RX),.go(go),.err_opn_lp(err_opn_lp),.buzz(buzz));

UART_tx  iTX(.clk(clk),.rst_n(rst_n),.TX(RX),.trmt(trmt),.tx_data(tx_data),.tx_done(tx_done));
////////////////////////////////////////////////////////////////////////

initial begin

	clk = 0;
	rst_n = 0;
	BMPL_n = 1;
	BMPR_n = 1;
	line_present = 0;
	@(posedge clk)
	rst_n = 1;
	
	//setup first half of cmd to send
	tx_data = 8'b00000000;
	@(posedge clk)
	trmt = 1;
	@(posedge clk)
	trmt = 0;
	@(posedge clk) 
	//setup second half cmd
	tx_data = 8'b00111001;	//cmd sequence: veer right, veer left, turn around, stop
	
	wait(tx_done);
	@(posedge clk) 
	trmt = 1;	//send 2nd half
	@(posedge clk) 
	trmt = 0;
	@(posedge clk) 
	wait(tx_done);
	@(posedge clk) 

	//test 1: go should still be zero
	if(go != 0)begin
		$display("Test Failed! go should not be asserted!");
		$stop();
	end
	@(posedge clk) 

	//test 2: assert line present, go should now be asserted
	line_present = 1;
	@(posedge clk) 
	if(go != 1)begin
		$display("Test Failed! go should be asserted!");
		$stop();
	end
	@(posedge clk) 
	
	
	//test 3: deassert line present, start veer right sequence
	line_present = 0;
	repeat(4) @(posedge clk); 	//wait to return from obstruct state

	if(err_opn_lp != -16'h340)begin
		$display("Test Failed! err_op_lp = %h, should be %h",err_opn_lp, -16'h340);
		$stop();
	end
	@(posedge clk) 
	line_present = 1;
	@(posedge clk) 

	//test 4: deassert line present, start veer left sequence
	line_present = 0;
	repeat(4) @(posedge clk); 	//wait to return from obstruct state
	 
	if(err_opn_lp != 16'h340)begin
		$display("Test Failed! err_op_lp = %h, should be %h",err_opn_lp, 16'h340);
		$stop();
	end
	@(posedge clk) 
	line_present = 1;
	@(posedge clk) 

	//test 5: deassert line present, start turn around sequence (veered left last)
	line_present = 0;
	repeat(4) @(posedge clk); 	//wait to return from obstruct state
	//check first step of turn around sequence (should start clockwise)
	if(err_opn_lp != -16'h1E0)begin
		$display("Test Failed! err_op_lp = %h, should be %h",err_opn_lp, -16'h1E0);
		$stop();
	end

	repeat(1350000) @(posedge clk); 

	//check 2nd step of turn around sequence (should finish counter clockwise)
	if(err_opn_lp != 16'h380)begin
		$display("Test Failed! err_op_lp = %h, should be %h",err_opn_lp, 16'h380);
		$stop();
	end

	repeat(1350000) @(posedge clk);
 	//err_opn_ln should get cleared
	if(err_opn_lp != 16'h000)begin
		$display("Test Failed! err_op_lp = %h, should be %h",err_opn_lp, 16'h000);
		$stop();
	end

	$display("All Tests Passed!");
	$stop();


end

always
#2 clk = ~clk;

endmodule