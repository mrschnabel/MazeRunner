module A2D_intf(clk, rst_n, strt_cnv, chnnl, MISO, cnv_cmplt, res, SS_n, SCLK, MOSI);

  input clk, rst_n;
  input strt_cnv;    // starts the data conversion
  input [2:0] chnnl;  // each channel corresponds to a sensor
  input MISO;     // data from SPI master
  
  output logic cnv_cmplt;
  output logic [11:0] res;  // data to be flopped
  output SS_n;  // SPI signals
  output SCLK;
  output MOSI;

  logic [15:0] rd_data;  // SPI signals
  logic wrt, done;
  logic [15:0] cmd;

/////////////////////////////  
// SPI master module ////

  SPI_mstr16 SPI0(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .wrt(wrt), .cmd(cmd), .done(done), .rd_data(rd_data));

/////////////////////////////////////////

  assign res = ~rd_data[11:0];
  assign cmd = {2'b00, chnnl, 11'h000};

//////////////////////////////////////////
// state machine logic /////

  typedef enum logic [1:0] {IDLE, CONV, WAIT, READ} state_t;
  state_t state, nxt_state;

  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else 
      state <= nxt_state;

/////////////////////////////////////////////
// State transition logic //////

  logic set_cmplt;  // to assert conversion completion

  always_comb begin
    nxt_state = state;
    wrt = 1'b0;
    set_cmplt = 1'b0;
    case (state)
      IDLE: 
        if (strt_cnv) begin  /// kicks off conversion
          wrt = 1'b1;
          set_cmplt = 1'b0;    
          nxt_state = CONV;
        end

      CONV: 
        if (done) begin  // waits for SPI to be done  
          set_cmplt = 1'b0;
          nxt_state = WAIT;
        end
        else begin
          set_cmplt = 1'b0;
        end

      WAIT: // waits for 1 clock cycle to allow A2D module to "breath"
        begin
          wrt = 1'b1;
          set_cmplt = 1'b0;
          nxt_state = READ;
        end

      READ:  // goes to idle if spi is done and sets conversion complete
        if (done) begin
          nxt_state = IDLE;
          set_cmplt = 1'b1;  // does 2 conversion with 1 clk rest in between
        end
        else begin
          set_cmplt = 1'b0;
        end      

      default: nxt_state = IDLE;

    endcase
  end

///////////////////////////////////////
//  latching set_cmplt signal ///////

  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      cnv_cmplt <= 1'b0;
    else if (strt_cnv)  // resets at the start of transaction
      cnv_cmplt <= 1'b0;
    else
      cnv_cmplt <= set_cmplt;  // sets at the end of transaction

/////////////////////////////

endmodule