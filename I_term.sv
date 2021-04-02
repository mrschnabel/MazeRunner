module I_term(
clk,
rst_n,
err_sat,
line_present,
go,
moving,
err_vld,
I_term
);

input clk;
input rst_n;
input [10:0] err_sat;
input line_present;
input go;
input moving;
input err_vld;
output reg [9:0] I_term;

logic [15:0] err_sat_ext;  	//sign extended err_sat
logic [15:0] integrator;	
logic over;  			//asserted when overflow occurs
logic [15:0] add_result;	//result of addition b/t err_sat and integrator

//signals used to synch line_present with clk && rise-edge detect
logic line_1;	//first flop
logic line_2;	//second flop
logic line_3;	//third flop
logic line_present_edge;	//asserted when pos edge of line_present detected


//sign extension of err_sat
assign err_sat_ext = {{6{err_sat[10]}}, err_sat[9:0]};

/////////////////////////////////////////
// Addition of err_sat and integrator //
///////////////////////////////////////
assign add_result = err_sat_ext + integrator;


/////////////////////////////
//  Overflow detect ////////
///////////////////////////

assign over = ((err_sat_ext[15] == integrator[15]) && (add_result[15] != integrator[15]))? 1'b1 : 1'b0;

/////////////////////////////////////
// +Edge detect for line_present ///
///////////////////////////////////
always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)begin
		line_1 <= 0;
		//line_2 <= 0;
		//line_3 <= 0;
	end
	else begin
		line_1 <= line_present;
		//line_2 <= line_1;
		//line_3 <= line_2;
	end
end

assign line_present_edge = (~line_1 && line_present) ? 1'b1 : 1'b0; 

//////////////////////////
//  Accumulator  ////////
////////////////////////

always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		integrator <= 16'h0000;

	else if(~go || ~moving || line_present_edge)
		integrator <= 16'h0000;

	else if(~over && err_vld)
		integrator <= add_result;
end

//////////////////////
// compute I_term  //
////////////////////
assign I_term = integrator[15:6];

endmodule