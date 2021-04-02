module PWM11(duty, clk, rst_n, PWM_sig);

  input [10:0] duty;
  input clk, rst_n;
  output logic PWM_sig;
  logic PWM_sig_next;
  logic [10:0] cnt;

  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) begin
      PWM_sig <= 1'b0;
      cnt <= 11'h000;
    end
    else begin
      PWM_sig <= PWM_sig_next;
      cnt <= cnt+1;
    end

  assign PWM_sig_next = (cnt<duty) ? 1'b1: 1'b0;
  
endmodule
