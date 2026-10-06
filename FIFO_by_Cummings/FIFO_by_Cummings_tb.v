// Define timescale
`timescale 1 ns / 10 ps

// Define our testbench
module FIFO_by_Cummings_tb();

    // Settings
    localparam  DATA_SIZE = 8;															//this will be the width of the FIFO - 8 means a byte
    localparam  ADDR_SIZE = 4;															//this will be the length of the FIFO - 4 means an 8 element FIFO
																									//mind, FIFO is a dynamic element meaning that if the clocks are reasonably close, it will take a lot of time to actually fill it up
																									//to test full and empty functions, decrease address size to 2, otherwise we will empty the FIFO faster than we fill it up
    
    // Internal signals
    wire    [DATA_SIZE-1:0]     r_data;
    wire                        r_empty;
    wire                        w_full;
    
    // Internal storage elements
    reg                         r_en = 0;
    reg                         r_clk = 0;
    reg                         r_rst = 0;
    reg     [DATA_SIZE-1:0]     w_data;
    reg                         w_en = 0;
    reg                         w_clk = 0;
    reg                         w_rst = 0;
    
    // Variables
    integer                     fifo_input;
    
    // Simulation time
    localparam DURATION = 100;
    
    // Generate read clock signal (about 50 MHz)
    always begin
        #0.1																					//if the write clock is slower than the read clock, we lose data
        r_clk = ~r_clk;
    end
    
    // Generate write clock signal (25 MHz)
    always begin
        #0.2																					//if the write clock is slower than the read clock, we lose data
        w_clk = ~w_clk;																		//clock should be in alignment with the data update
																									//mind, one cycle is twice the time we adjust our clock to
		  
    end
    
    // Instantiate FIFO
    FIFO_by_Cummings # (DATA_SIZE, ADDR_SIZE)
	 
	 FIFO_test (
        .w_data(w_data),
        .w_en(w_en),
        .w_clk(w_clk),
        .w_rst(w_rst),
        .r_en(r_en),
        .r_clk(r_clk),
        .r_rst(r_rst),
        .w_full(w_full),
        .r_data(r_data),
        .r_empty(r_empty)
    );
    
	 
	 localparam  VALUE_NUMBER_TO_WRITE = 180;
	 
    // Test control: write and read data to/from FIFO
    initial begin
    
        // Pulse resets high to initialize memory and counters
        #0.1
        w_rst = 1;
        r_rst = 1;
        #0.01
        w_rst = 0;
        r_rst = 0;
        
        // Write some data to the FIFO
        for (fifo_input = 0; fifo_input < VALUE_NUMBER_TO_WRITE; fifo_input = fifo_input + 1) begin
            #0.4																					//the data flow in has to be aligned to the write clock
																										//bug came from the data changing faster than how fast the clock was stepping the write pointer
            w_data = fifo_input;
            w_en = 1'b1;																		//w_en and r_en can be HIGH at the same time, no problems there				
				r_en = 1'b1;																		//here we enable the read
        end
        #0.2
        w_en = 1'b0;
		  r_en = 1'b0;		  

    end
    
        // Run simulation
    initial begin
           
        // Wait for given amount of time for simulation to complete
        #(DURATION)
        
        $stop;
    end

endmodule