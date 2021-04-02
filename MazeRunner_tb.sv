module MazeRunner_tb();

	reg clk,RST_n;
 	reg send_cmd;					// assert to send travel plan via CommMaster
	reg [15:0] cmd;					// traval plan command word to maze runner
	reg signed [12:0] line_theta;	// angle of line (starts at zero)
	reg line_present;				// is there a line or a gap?
	reg BMPL_n, BMPR_n;				// bump switch inputs

	///////////////////////////////////////////////////////////////
	// Declare internals sigs between DUT and supporting blocks //
	/////////////////////////////////////////////////////////////
	wire SS_n,MOSI,MISO,SCLK;		// SPI bus to A2D
	wire PWMR,PWML,DIRR,DIRL;		// motor controls
	wire IR_EN;						// IR sensor enable
	wire RX_TX;						// comm line between CommMaster and UART_wrapper
	wire cmd_sent;					// probably don't need this
	wire buzz,buzz_n;				// hooked to piezo buzzer outputs
	wire signed [12:0] theta_robot;
	

	assign theta_robot = iPHYS.theta_robot;

  	 //////////////////////
	// Instantiate DUT //
	////////////////////
	MazeRunner iDUT(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.MOSI(MOSI),.MISO(MISO),.SCLK(SCLK),
					.PWMR(PWMR),.PWML(PWML),.DIRR(DIRR),.DIRL(DIRL),.IR_EN(IR_EN),
					.BMPL_n(BMPL_n),.BMPR_n(BMPR_n),.buzz(buzz),.buzz_n(buzz_n),.RX(RX_TX),
					.LED());
					
	////////////////////////////////////////////////
	// Instantiate Physical Model of Maze Runner //
	//////////////////////////////////////////////
	MazePhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.MOSI(MOSI),.MISO(MISO),.SCLK(SCLK),
	                  .PWMR(PWMR),.PWML(PWML),.DIRR(DIRR),.DIRL(DIRL),.IR_EN(IR_EN),
					  .line_theta(line_theta),.line_present(line_present));
					  
	/////////////////////////////
	// Instantiate CommMaster //
	///////////////////////////
	CommMaster iMST(.clk(clk), .rst_n(RST_n), .TX(RX_TX), .send_cmd(send_cmd), .cmd(cmd),
                    .cmd_sent(cmd_sent));					  
		
//////////////////////////////////////////////////////////////////////////

	//////////////////////////
	// testbench tasks //////
	////////////////////////


	task Initialize();
		RST_n = 0;
		line_theta = 13'h0000;
		line_present = 1;
		BMPL_n = 1;
		BMPR_n = 1;

	endtask

	/*initial begin
		$monitor("IR_EN= ",IR_EN);
	end*/

	//Begin testing	
	initial begin

	////////////////////////////////////////////////////////////
	//////  Part I: Veer Right command ////////////////////
	//////////////////////////////////////////////////////////
     		/*clk = 0;
		Initialize();
		@(posedge clk)
		@(negedge clk)
		RST_n = 1;
		cmd = 16'h0001;	//right

		//send the command
		@(posedge clk)
		send_cmd = 1;
		@(posedge clk)
		@(posedge clk)
		send_cmd = 0;
	
		//Test 1: bend line 15 degrees to the right
		repeat(500000) @(posedge clk);	//wait 1.5 million clks before adjusting angle of line
		line_theta = 150;
		repeat(800000) @(posedge clk);	//wait for robot to adjust

		//line_robot should be within 3 degrees of line_theta
		if((theta_robot < line_theta - 30)  || (theta_robot > line_theta + 30))begin
			$display("Test Failed! robot should be adjusting it's position towards the right. theta_robot = %d, line_theta = %d",theta_robot,line_theta);
			$stop();
		end

		//Test 2: veer right (this starts veer right sequence)
		line_present = 0;
		repeat(300000) @(posedge clk);
		line_present = 1;
		line_theta = 500;	//adjust the position of the line to sim right turn
		
		repeat(400000) @(posedge clk);	//wait for robot to adjust
		
		//line_robot should be within 10 degrees of line_theta
		if((theta_robot < line_theta - 100)  || (theta_robot > line_theta + 100))begin
			$display("Test Failed! robot should be veering towards the right. theta_robot = %d, line_theta = %d",theta_robot,line_theta);
			$stop();
		end*/

	/////////////////////////////////////////////////////////////////////////////////////////////
	//////  Part II: Turn Around command  (clockwise, then counterclockwise)////////////////////
	///////////////////////////////////////////////////////////////////////////////////////////
		clk = 0;
		Initialize();
		@(posedge clk)
		@(negedge clk)
		RST_n = 1;
		cmd = 16'h0003;	//turn around

		//send the command
		@(posedge clk)
		send_cmd = 1;
		@(posedge clk)
		@(posedge clk)
		send_cmd = 0;
	
		//Test 1: bend line 15 degrees to the right
		repeat(500000) @(posedge clk);	//wait 1.5 million clks before adjusting angle of line
		line_theta = 150;
		repeat(800000) @(posedge clk);	//wait for robot to adjust

		//line_robot should be within 3 degrees of line_theta
		if((theta_robot < line_theta - 30)  || (theta_robot > line_theta + 30))begin
			$display("Test Failed! robot should be adjusting it's position towards the right. theta_robot = %d, line_theta = %d",theta_robot,line_theta);
			$stop();
		end

		//Test 2: turnaround (this starts turnaround sequence)
		line_present = 0;
		repeat(1750000) @(posedge clk);
		line_present = 1;
		line_theta = -1650;	//adjust the position of the line to sim turnaround
		
		repeat(400000) @(posedge clk);	//wait for robot to adjust
		
		//line_robot should be within 40 degrees of line_theta
		if((theta_robot < line_theta - 400)  || (theta_robot > line_theta + 400))begin
			$display("Test Failed! robot should be veering towards the right. theta_robot = %d, line_theta = %d",theta_robot,line_theta);
			$stop();
		end

	////////////////////////////////////////////////////////////
	//////  Part III: Stop command         ////////////////////
	//////////////////////////////////////////////////////////

		/*clk = 0;
		Initialize();
		@(posedge clk)
		@(negedge clk)
		RST_n = 1;
		cmd = 16'h0000;	//stop

		//send the command
		@(posedge clk)
		send_cmd = 1;
		@(posedge clk)
		@(posedge clk)
		send_cmd = 0;
	
		//Test 1: bend line 15 degrees to the right
		repeat(500000) @(posedge clk);	//wait 1.5 million clks before adjusting angle of line
		line_theta = 150;
		repeat(800000) @(posedge clk);	//wait for robot to adjust

		//line_robot should be within 3 degrees of line_theta
		if((theta_robot < line_theta - 30)  || (theta_robot > line_theta + 30))begin
			$display("Test Failed! robot should be adjusting it's position towards the right. theta_robot = %d, line_theta = %d",theta_robot,line_theta);
			$stop();
		end

		//Test 2: stop (this stops the robot)
		line_present = 0;
		repeat(1750000) @(posedge clk);
		line_present = 1;
	
		
		repeat(400000) @(posedge clk);	
		
		//omega right and omega left should decrease, indicating the robot is slowing down
		if(iPHYS.omega_rght > 16'h1000 || iPHYS.omega_lft > 16'h1000)begin
			$display("Test Failed! robot should be stopped. omega_rght = %d, omega_lft = %d",iPHYS.omega_rght,iPHYS.omega_lft);
			$stop();
		end*/

		
	////////////////////////////////////////////////////////////
	//////  Part IV: Veer Left command ////////////////////
	//////////////////////////////////////////////////////////
     		/*clk = 0;
		Initialize();
		@(posedge clk)
		@(negedge clk)
		RST_n = 1;
		cmd = 16'h0002;	//veer left

		//send the command
		@(posedge clk)
		send_cmd = 1;
		@(posedge clk)
		@(posedge clk)
		send_cmd = 0;
	
		//Test 1: bend line 15 degrees to the right
		repeat(500000) @(posedge clk);	//wait 1.5 million clks before adjusting angle of line
		line_theta = 150;
		repeat(800000) @(posedge clk);	//wait for robot to adjust

		//line_robot should be within 3 degrees of line_theta
		if((theta_robot < line_theta - 30)  || (theta_robot > line_theta + 30))begin
			$display("Test Failed! robot should be adjusting it's position towards the right. theta_robot = %d, line_theta = %d",theta_robot,line_theta);
			$stop();
		end

		//Test 2: veer left (this starts veer right sequence)
		line_present = 0;
		repeat(300000) @(posedge clk);
		line_present = 1;
		line_theta = -200;	//adjust the position of the line to sim right turn
		
		repeat(400000) @(posedge clk);	//wait for robot to adjust
		
		//line_robot should be within 10 degrees of line_theta
		if((theta_robot < line_theta - 100)  || (theta_robot > line_theta + 100))begin
			$display("Test Failed! robot should be veering towards the right. theta_robot = %d, line_theta = %d",theta_robot,line_theta);
			$stop();
		end*/

	////////////////////////////////////////////////////////////
	//////  Part V: Add an Obstacle	       ////////////////////
	//////////////////////////////////////////////////////////
     		/*clk = 0;
		Initialize();
		@(posedge clk)
		@(negedge clk)
		RST_n = 1;
		cmd = 16'h0000;	//stop at first gap in line

		//send the command
		@(posedge clk)
		send_cmd = 1;
		@(posedge clk)
		@(posedge clk)
		send_cmd = 0;
	
		//Test 1: bend line 15 degrees to the right
		repeat(500000) @(posedge clk);	//wait 1.5 million clks before adjusting angle of line
		line_theta = 150;
		repeat(800000) @(posedge clk);	//wait for robot to adjust

		//line_robot should be within 3 degrees of line_theta
		if((theta_robot < line_theta - 30)  || (theta_robot > line_theta + 30))begin
			$display("Test Failed! robot should be adjusting it's position towards the right. theta_robot = %d, line_theta = %d",theta_robot,line_theta);
			$stop();
		end

		//Test 2: add an obstacle after waiting a while
		repeat(500000) @(posedge clk);	//wait 1.5 million clks before adjusting angle of line
		
		BMPL_n = 0; //left bumper asserted = obstacle encountered
		repeat(500000) @(posedge clk);

		if(!iDUT.icmd.buzz_en)begin
			$display("Test Failed! Buzzer should be enabled.");
			$stop();
		end

		BMPL_n = 1;
		repeat(500000) @(posedge clk);	//wait for 'person' to remove object
		BMPL_n = 0; 	//press button again to signal object removed
		@(posedge clk)
		BMPL_n = 1;	//deassert button pressed
		
		repeat(50000) @(posedge clk);
		if(iDUT.icmd.buzz_en)begin
			$display("Test Failed! Buzzer should not be enabled.");
			$stop();
		end*/

	/////////////////////////////////////////////////////////////////////////////////////////////
	////// 	 Part VI: Turn Around command (start with veer right)           ////////////////////
	///////////////////////////////////////////////////////////////////////////////////////////
		/*clk = 0;
		Initialize();
		@(posedge clk)
		@(negedge clk)
		RST_n = 1;
		cmd = 16'h000d;	//right

		//send the command
		@(posedge clk)
		send_cmd = 1;
		@(posedge clk)
		@(posedge clk)
		send_cmd = 0;
	
		//Test 1: bend line 15 degrees to the right
		repeat(500000) @(posedge clk);	//wait 1.5 million clks before adjusting angle of line
		line_theta = 150;
		repeat(800000) @(posedge clk);	//wait for robot to adjust

		//line_robot should be within 3 degrees of line_theta
		if((theta_robot < line_theta - 30)  || (theta_robot > line_theta + 30))begin
			$display("Test Failed! robot should be adjusting it's position towards the right. theta_robot = %d, line_theta = %d",theta_robot,line_theta);
			$stop();
		end

		//Test 2: veer right (this starts veer right sequence)
		line_present = 0;
		repeat(300000) @(posedge clk);
		line_present = 1;
		line_theta = 500;	//adjust the position of the line to sim right turn
		
		repeat(400000) @(posedge clk);	//wait for robot to adjust
		
		//line_robot should be within 10 degrees of line_theta
		if((theta_robot < line_theta - 100)  || (theta_robot > line_theta + 100))begin
			$display("Test Failed! robot should be veering towards the right. theta_robot = %d, line_theta = %d",theta_robot,line_theta);
			$stop();
		end

		//Test 3: turnaround (this starts turnaround sequence)
		repeat(800000) @(posedge clk);
		line_present = 0;
		repeat(1750000) @(posedge clk);
		line_present = 1;
		line_theta = 2650;	//adjust the position of the line to sim turnaround
		
		repeat(400000) @(posedge clk);	//wait for robot to adjust
		
		//line_robot should be within 40 degrees of line_theta
		if((theta_robot < line_theta - 400)  || (theta_robot > line_theta + 400))begin
			$display("Test Failed! robot should be veering towards the right. theta_robot = %d, line_theta = %d",theta_robot,line_theta);
			$stop();
		end*/
		
		
		$display("All Tests Passed!");
		$stop();
		
	end	
	always
	  #2 clk = ~clk;
				  
endmodule