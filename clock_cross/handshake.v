module handshake(
    input handshake_in,
    input clk_in,																							//input side clock domain
    input clk_out,																						//output side clock domain
	 output handshake_busy_flag,
    output handshake_out
);

reg flag_in_toggle = 1'b0;																													//since we don't have a reset, we need to remove ambiguity by giving a starting value to registers

always @(posedge clk_in) flag_in_toggle <= (flag_in_toggle ^ (handshake_in & ~handshake_busy_flag));

reg [2:0] shift_register_in_side = 3'b0;			
																					//we use a 3-bit shift register here to ensure stability (flags can be difficult to catch)
always @(posedge clk_out) begin

	shift_register_in_side <= {shift_register_in_side[1:0], flag_in_toggle};  				// now we cross the clock domains with our flag
	
end

reg [1:0] shift_register_out_side = 2'b0;																										//we do the same shift register passing the other direction

always @(posedge clk_in) begin

	shift_register_out_side <= {shift_register_out_side[0], shift_register_in_side[2]};	//we send our eventual output flag back as ACK
	
end

assign handshake_out = (shift_register_in_side[2] ^ shift_register_in_side[1]);
assign handshake_busy_flag = flag_in_toggle ^ shift_register_out_side[1];																//busy flag is set/reset when the flag toggle and the ACK signal is not the same
endmodule
