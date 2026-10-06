module clock_cross(
    input clk_in,
    input signal_in,
    input clk_out, 
    output synch_out,
	 output flag_out,
	 output hand_busy_out,	 
	 output hand_out,
	 output t_in_busy_flag,
	 output t_out_busy_flag,
	 output t_start_flag,
	 output t_done_in_flag,
	 input t_done_out_flag
);


//synchroniser module
	synchroniser synch (												
			.synch_in(signal_in),
			.clk(clk_in),																
			.synch_out(synch_out)
	);

	
//flag cross module	
	flag_cross flag(
		 .flag_cross_in(signal_in),
		 .clk_in(clk_in),																						
		 .clk_out(clk_out),																				
		 .flag_cross_out(flag_out)
	);

//handshake module	
	handshake hand(
    .handshake_in(signal_in),
    .clk_in(clk_in),																							
    .clk_out(clk_out),																					
	 .handshake_busy_flag(hand_busy_out),
    .handshake_out(hand_out)
	);

//task cross module	
	task_cross t_cross(	
	 .task_in(signal_in),
    .clk_in(clk_in),																							
    .clk_out(clk_out),	
	 .task_in_busy_flag(t_in_busy_flag),
	 .task_out_busy_flag(t_out_busy_flag),
	 .task_start_flag(t_start_flag),
	 .task_in_done_flag(t_done_in_flag),
    .task_out_done_flag(t_done_out_flag) 
	);
	
	
	
//add task pass as well	
	
endmodule