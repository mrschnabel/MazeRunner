module mtr_drv(lft_duty, right_duty, clk, rst_n, PWML, PWMR, DIRL, DIRR);

  input [11:0] lft_duty, right_duty;
  input clk, rst_n;
  output PWML, PWMR;
  output DIRL, DIRR;

  logic [10:0] ABS_L, ABS_R;
  
  assign DIRL = lft_duty[11]  ? 1'b1: 1'b0;  // negative direction(dir =1) for negative motor speed
  assign DIRR = right_duty[11]? 1'b1: 1'b0;  // negative direction(dir =1) for negative motor speed
  
  assign ABS_L = lft_duty[11] ? ~lft_duty[10:0]: lft_duty[10:0];  // 1's complement instead of 2's complement for 
  // assigning duty cycle since we need to properly assign -2048  
  assign ABS_R = right_duty[11] ? ~right_duty[10:0]: right_duty[10:0];  // 1's complement instead of 2's complement for 
  // assigning duty cycle since we need to properly assign -2048  

  PWM11 PWM11_L (.duty(ABS_L), .clk(clk), .rst_n(rst_n), .PWM_sig(PWML));
  PWM11 PWM11_R (.duty(ABS_R), .clk(clk), .rst_n(rst_n), .PWM_sig(PWMR));
endmodule

  
  //assign dir = mtr_spd[11]? 1'b1: 1'b0; 
  
  //assign duty = mtr_spd[11] ? ~mtr_spd[10:0]: mtr_spd[10:0]; // 1's complement instead of 2's complement for 
  // assigning duty cycle since we need to properly assign -2048  