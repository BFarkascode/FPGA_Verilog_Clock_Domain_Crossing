`timescale 1 ns / 1 ns

module clock_cross_tb ();

	reg 									clk0 = 0;				//input side clock
	reg 									clk1 = 0;				//output side clock
	reg									signal_in = 0;
	reg 									t_done_out_flag = 0;				//trigger to indicate task is done
	
	wire 									synch_out;
	wire 									flag_out;
	wire 									hand_busy_out;
	wire 									hand_out;
	wire 									t_in_busy_flag;
	wire 									t_out_busy_flag;
	wire 									t_start_flag;
	wire 									t_done_in_flag;
	
	localparam							DURATION = 1000;
	
	initial begin
		#(DURATION)
		$stop;
	end
	
	
	//50 MHz clk
	always begin
		#20
			clk0 = ~clk0;
	end
	
	//25 MHz clk
	always begin
		#10
			clk1 = ~clk1;
	end
		
		
	//input signal
	always begin							//Note: if the cyclical flag setting is not synched to the input clock, we will have some jitter on theoutput
		#10
			signal_in = 1'b1;
		#40
			signal_in = 1'b0;
		#170	
			signal_in = 1'b0;
		#10
			t_done_out_flag = 1'b1;
	end	

	clock_cross clock_cross_test (

   		.clk_in(clk0),
    		.signal_in(signal_in),
			.clk_out(clk1),
    		.synch_out(synch_out),	
			.flag_out(flag_out),
			.hand_busy_out(hand_busy_out),	 
			.hand_out(hand_out),
			.t_in_busy_flag(t_in_busy_flag),
			.t_out_busy_flag(t_out_busy_flag),
			.t_start_flag(t_start_flag),
			.t_done_in_flag(t_done_in_flag),
			.t_done_out_flag(t_done_out_flag)
			
	);

endmodule