module MazePhysics(clk,RST_n,SS_n,SCLK,MISO,MOSI,PWMR,PWML,DIRR,DIRL,IR_EN,line_theta,line_present);
  //////////////////////////////////////////////////////
  // Model of physics of the MazeRunner, including a //
  // model of the line and the IR sensors.          //
  ///////////////////////////////////////////////////

  input clk;				// same 50MHz clock you give to Segway.v
  input RST_n;				// unsynchronized raw reset input
  input SS_n;				// active low slave select to inertial sensor
  input SCLK;				// Serial clock
  input MOSI;				// serial data in from master
  input IR_EN;				// enables IR sensors
  input PWMR,PWML;			// Motor drive magnitude right and left
  input DIRR,DIRL;			// 1 => reverse, 0 => forward
  input signed [12:0] line_theta;		// angle of line + => to right, - => to left 
  input line_present;		// if asserted all A2D's read 0xFFF;

  
  output MISO;				// serial data out to master
  
  //////////////////////////////////////////////////////
  // Registers needed for modeling physics of Segway //
  ////////////////////////////////////////////////////
  reg signed [12:0] alpha_lft,alpha_rght;			// angular acceleration of wheels
  reg signed [15:0] omega_lft,omega_rght;			// angular velocities of wheels
  reg signed [15:0] omega_diff;						// used to cut angular velocity diff down on line_present
  reg signed [21:0] theta_lft,theta_rght;			// amount wheels have rotated since start
  reg signed [12:0] theta_robot;					// angular orientation of robot (starts at zero) should match line_theta
  reg signed [12:0] theta_err;
  reg [2:0] chnnl;									// holds channel requested for A2D conversion
  reg [11:0] A2D_data;								// data to be sent back with A2D conversion
  reg SPI_rdy_ff;									// delayed version of SPI_rdy
  
  
  /////////////////////////////////////////////
  // Declare internal signals between units //
  ///////////////////////////////////////////
  wire [15:0] cmd;			// command that came it (bits [13:11] are what channel to convert)
  wire SPI_rdy;				// SPI transaction ready
  
  wire [10:0] mtrMagR,mtrMagL;	// inversePWM outputs telling motor drive magnitude
  wire calc_physics;			// update the physics model everytime inversePWM refreshes
  
 
  /////////////////////////////////////////////////////////////
  // Instantiate SPI slave that will serve as A2D converter //
  ///////////////////////////////////////////////////////////
  SPI_ADC128S iA2D(.clk(clk),.rst_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                   .MOSI(MOSI),.A2D_data({4'h0,A2D_data}),.cmd(cmd),.rdy(SPI_rdy));
				   
  always_ff @(posedge clk)
    if (SPI_rdy)
	  chnnl = cmd[13:11];
	  
  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
	  SPI_rdy_ff <= 1'b0;
	else
	  SPI_rdy_ff <= SPI_rdy;
				   
  //////////////////////////////////////////////////////////////
  // Instantiate inverse PWM's to get motor drive magnitudes //
  ////////////////////////////////////////////////////////////
  inverse_PWM11e iMTRR(.clk(clk),.rst_n(RST_n),.PWM_sig(PWMR),.duty_out(mtrMagR),.vld(calc_physics));
  inverse_PWM11e iMTRL(.clk(clk),.rst_n(RST_n),.PWM_sig(PWML),.duty_out(mtrMagL),.vld()); 

  /////////////////////////////////////////////
  // Next is modeling physics of MazeRunner //
  ///////////////////////////////////////////
  always @(posedge calc_physics) begin
    alpha_lft = alpha(mtrMagL,DIRL,omega_lft);		// angular accel direct to (duty - k*omega)
	alpha_rght = alpha(mtrMagR,DIRR,omega_rght);	// angular accel direct to (duty - k*omega)
	omega_lft = omega(omega_lft,alpha_lft);			// angular velocity is integral of alpha
	omega_rght = omega(omega_rght,alpha_rght);		// angular velocity is integral of alpha
	theta_lft = theta(theta_lft,omega_lft);			// wheel theta is integral of wheel omega
	theta_rght = theta(theta_rght,omega_rght);		// wheel theta is integral of wheel omega

	theta_robot = theta_plat(theta_lft,theta_rght);	// theta of platform
	theta_err = line_theta - theta_robot;
  end
    
  
  //////////////////////////////////////////////////////////
  // Update A2D_data based on displacement every SPI_rdy //
  ////////////////////////////////////////////////////////
  always @(posedge SPI_rdy_ff)
    A2D_data = A2D_val(chnnl,theta_err,line_present);
	

  initial begin
	omega_lft = 16'h0000;
	omega_rght = 16'h0000;
	theta_lft = 22'h000000;
	theta_rght = 22'h000000;
	theta_robot = 13'h0000;
  end
  
  //////////////////////////////////////////////////////////
  // returns an "V" magnitude reflection centered around //
  // center with overlap with neighboring sensor.       //
  ///////////////////////////////////////////////////////
  function [11:0] reflection (input signed [12:0] err, center);
    reg signed [13:0] diff;
	reg [12:0] diff_abs;
	
	diff = {err[12],err} - {center[12],center};
	diff_abs = (diff[13]) ? ~diff[12:0]+1 : diff[12:0];
	if (diff_abs>=13'h100) reflection = 13'hFFF;			// no reflection
	else reflection = 12'hE00 + {diff_abs[7:0],1'b0};				// caps at 0xE00
  endfunction
  
  function [11:0] A2D_val (input [2:0] chnnl1, input signed [12:0] err, input line_there);
    if (line_there && IR_EN) begin
	  case (chnnl1)
	    3'b000 : begin
		  A2D_val = reflection(err,$signed(13'h080));
		end
	    3'b001 : begin
		  A2D_val = reflection(err,$signed(13'h180));
		end
	    3'b010 : begin
		  A2D_val = reflection(err,$signed(13'h280));
		end
	    3'b011 : begin
		  A2D_val = reflection(err,$signed(13'h380));
		end
	    3'b100 : begin
		  A2D_val = reflection(err,$signed(-13'h080));
		end
	    3'b101 : begin
		  A2D_val = reflection(err,$signed(-13'h180));
		end
	    3'b110 : begin
		  A2D_val = reflection(err,$signed(-13'h280));
		end
	    3'b111 : begin
		  A2D_val = reflection(err,$signed(-13'h380));
		end		
	  endcase
	end else
	  A2D_val = 12'hFFF;			// no reflectivity
  endfunction
  
  //////////////////////////////////////////////////////
  // functions used in "physics" computations follow //
  ////////////////////////////////////////////////////
  
  //// Angular acceleration of wheel as function of duty, DIR, and omega ////
  function signed [12:0] alpha (input [10:0] duty, input DIR, input signed [15:0] omega1);
    reg [11:0] mag;
	reg signed [12:0] mag_signed;

    mag = $sqrt(real'({duty,11'h000}));
    mag_signed = (DIR) ? ~mag+1 : mag;
	alpha = mag_signed - {omega1[15],omega1[15:4]};

  endfunction
 
   //// Angular velocity of wheel as integration of alpha ////
  function signed [15:0] omega (input signed [15:0] omega1, input signed [12:0] torque);

    //// if torque is greater than friction wheel speed changes ////
    if ((torque>$signed(13'h0020)) || (torque<$signed(-13'h0020)))
	  omega = omega1 + {{7{torque[12]}},torque[12:4]};	// wheel speed integrates
	else
	  omega = omega1 - {{6{omega1[15]}},omega1[15:6]};	// friction takes its toll
	  
  endfunction

   //// Angular position of wheel as integration of omega ////  
  function signed [21:0] theta (input signed [21:0] theta1, input signed [15:0] omega);

	theta = theta1 + {{11{omega[15]}},omega[15:5]};
	
  endfunction
  
  //// Angle of platform is function of the two wheel thetas ////
  function signed [12:0] theta_plat (input signed [21:0] thetaL,thetaR);
	
	theta_plat = thetaL[21:7] - thetaR[21:7] + {thetaL[21],thetaL[21:8]} - {thetaR[21],thetaR[21:8]};
	  
  endfunction
  
endmodule

///////////////////////////////////////////////////
// Inverse PWM defined below for easy reference //
/////////////////////////////////////////////////
module inverse_PWM11e(clk,rst_n,PWM_sig,duty_out,vld);

  input clk,rst_n;
  input PWM_sig;
  output reg [10:0] duty_out;
  output reg vld;
  
  reg [10:0] pwm_cnt;
  reg [10:0] per_cnt;
  
  //////////////////////////////////////////
  // Count the duty cycle of the PWM_sig //
  ////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  pwm_cnt <= 11'h000;
	else if (&per_cnt)
	  pwm_cnt <= 11'h000;
	else if (PWM_sig)
	  pwm_cnt <= pwm_cnt + 1;
	  
  ///////////////////////////////////////
  // Need to count the PWM period off //
  /////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  per_cnt <= 11'h000;
	else
	  per_cnt <= per_cnt + 1;

  ////////////////////////////////////////////////////
  // Buffer pwm_cnt in output register so it holds //
  //////////////////////////////////////////////////  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  duty_out <= 11'h000;
	else if (&per_cnt)
	  duty_out <= pwm_cnt;
	  
  ///////////////////////////////////////
  // Pulse vld when new reading ready //
  /////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  vld <= 1'b0;
	else
	  vld <= &per_cnt;
	  
endmodule

  
