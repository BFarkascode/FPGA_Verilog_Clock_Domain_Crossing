module synchroniser(
    input 	wire	synch_in,
    input 	wire	clk,											//synchronizer clocking
																		//we don't need a second clock for a synchroniser
    output 	wire	synch_out
);

reg 	[1:0] 	shift_register;								// We use a two-bit shift-register to synchronize the input to the clk clock domain

always @(posedge clk) begin
	shift_register[0] <= synch_in;   						// notice that we use non-blocking operators
																		//we sample the input wire into the first element of the shift register
	shift_register[1] <= shift_register[0];				//we push the shift register one value towards MSB
end

assign synch_out = shift_register[1];  					//we assign the MSB to the output wire
endmodule