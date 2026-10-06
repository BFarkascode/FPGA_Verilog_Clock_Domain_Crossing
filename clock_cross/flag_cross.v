module flag_cross(
    input flag_cross_in,
    input clk_in,																							//input side clock domain
    input clk_out,																						//output side clock domain
    output flag_cross_out
);

reg flag_in_toggle = 1'b0;													//since we don't have a reset, we need to remove ambiguity by giving a starting value to registers

always @(posedge clk_in) begin

	flag_in_toggle <= (flag_in_toggle ^ flag_cross_in);  			// when flag is asserted, this signal toggles (clkA domain)
																												// Note: we have a bitwise XOR, which will make the flag_in_toggle go HIGH very time when the value of the input changes 
																													//the toggle will be HIGH only for one input clock cycle
end
																													
																													
reg [2:0] shift_register = 3'b0;											//we use a 3-bit shift register here to ensure stability (flags can be difficult to catch)
																					

always @(posedge clk_out) begin

	shift_register <= {shift_register[1:0], flag_in_toggle};  // now we cross the clock domains with our flag

end

assign flag_cross_out = (shift_register[2] ^ shift_register[1]);  						// and create the clkB flag

endmodule