module task_cross (
	
		input task_in,
      input clk_in, clk_out,
		input task_out_done_flag,																			//trigger that the task is done (it is an input in the receving clock domain!)
	   output task_in_busy_flag,task_out_busy_flag,task_start_flag,task_in_done_flag
		
);

		reg 							flag_in_toggle = 1'b0;
		reg 							flag_out_toggle = 1'b0;
		reg 							busy_hold_out = 1'b0;
		reg 			[2:0] 		shift_register_out_side = 3'b0;
		reg 			[2:0] 		shift_register_in_side = 3'b0;

	always @(posedge clk_in) begin
	
		flag_in_toggle <= flag_in_toggle ^ (task_in & ~task_in_busy_flag);	//define a task toggle dependent on incoming flag and busy state 
		
	end
	
	
	always @(posedge clk_out) begin
	
		shift_register_out_side <= {shift_register_out_side[1:0], flag_in_toggle};		//pass the toggle over to the second clock
		
	end
	
	assign task_start_flag = shift_register_out_side[2] ^ shift_register_out_side[1];								//if the passed over toggle changes, this XOR will be 1 - the two parallel running signals will differ
	assign task_out_busy_flag = task_start_flag | busy_hold_out;								//define a flag for second item being busy
	
	always @(posedge clk_out) begin 
	
		busy_hold_out <= ~task_out_done_flag & task_out_busy_flag;			//ensure the second item remains busy as long as necessary
	
	end
	
	always @(posedge clk_out) begin 
	
		if(task_out_busy_flag & task_out_done_flag) flag_out_toggle <= flag_in_toggle;	//copy the toggle
	
	end
	
	always @(posedge clk_in) begin 
	
		shift_register_in_side <= {shift_register_in_side[1:0], flag_out_toggle};		//pass the second item's toggle back
	
	end
	
	assign task_in_busy_flag = flag_in_toggle ^ shift_register_in_side[2];								//while the original flag is the same as the caried over, the XOR will be 0
	assign task_in_done_flag = shift_register_in_side[2] ^ shift_register_in_side[1];									//if the toggle changes between two clocks, we are done

endmodule