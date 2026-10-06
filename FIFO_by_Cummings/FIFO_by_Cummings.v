//The write and the read clocks can be whatever we want them to be
//but the w_data change has to be slower than w_clk, otherwise we lose data
//similarly, r_data has to be sampled appropriately (with faster than twice r_clk) otherwise we might update it before we sample it, leading to data loss
//w_en and r_en can be active at the same time. Additional timing and control can be achieved by triggering the enable pins.

// Asynchronous FIFO module
module FIFO_by_Cummings #(

    // Parameters
    parameter   DATA_SIZE = 8,              // Number of data bits
    parameter   ADDR_SIZE = 4               // Number of bits for address
) (

    // Inputs
    input       [DATA_SIZE-1:0] w_data,     // Data to be written to FIFO
    input                       w_en,       // Write data and increment addr (for a constant data flow FIFO, this will be an enable signal, for one that is load occasionally, a trigger)
    input                       w_clk,      // Write domain clock
    input                       w_rst,      // Write domain reset
    input                       r_en,       // Read data and increment addr (for a constant data flow FIFO, this will be an enable signal, for one that is read out occasionally, a trigger)
    input                       r_clk,      // Read domain clock
    input                       r_rst,      // Read domain reset
    
    // Outputs
    output                      w_full,     // Flag: 1 if FIFO is full
    output  reg [DATA_SIZE-1:0] r_data,     // Data to be read from FIFO
    output                      r_empty     // Flag: 1 if FIFO is empty
);

    // Constants
    localparam  FIFO_DEPTH  = (1 << ADDR_SIZE);
    
    // Internal signals
    wire    [ADDR_SIZE-1:0] w_addr;				//write counter/pointer FIFO address
    wire    [ADDR_SIZE:0]   w_gray;				//Gray counter for write
    wire    [ADDR_SIZE-1:0] r_addr;				//read counter/pointer FIFO address
    wire    [ADDR_SIZE:0]   r_gray;				//Gray counter for read
    
    // Internal storage elements
    reg     [ADDR_SIZE:0]   w_syn_r_gray;
    reg     [ADDR_SIZE:0]   w_syn_r_gray_shift_reg;		//we will use just a 1 element shift register for synchronisation
    reg     [ADDR_SIZE:0]   r_syn_w_gray;
    reg     [ADDR_SIZE:0]   r_syn_w_gray_shift_reg;		//we will use just a 1 element shift register for synchronisation
    
    // Declare FIFO memory block
    reg     [DATA_SIZE-1:0] mem [0:FIFO_DEPTH-1];
    
    //--------------------------------------------------------------------------
    // Dual-port memory (should be inferred as block RAM)

	 // Define write pointer    
    // Write data logic for dual-port memory (separate write clock)
    // Do not write if FIFO is full!
    always @ (posedge w_clk) begin
        if (w_en & ~w_full) begin
            mem[w_addr] <= w_data;
        end
    end
    
	 // Define read pointer
    // Read data logic for dual-port memory (separate read clock)
    // Do not read if FIFO is empty!
    always @ (posedge r_clk) begin
        if (r_en & ~r_empty) begin
            r_data <= mem[r_addr];
        end
    end
    
    //--------------------------------------------------------------------------
    // Synchronizer logic
    
    // Pass read-domain Gray code pointer address to write domain
    always @ (posedge w_clk or posedge w_rst) begin
        if (w_rst == 1'b1) begin
            w_syn_r_gray_shift_reg <= 0;
            w_syn_r_gray <= 0;
        end else begin
            w_syn_r_gray_shift_reg <= r_gray;
            w_syn_r_gray <= w_syn_r_gray_shift_reg;
        end
    end
    
    // Pass write-domain Gray code pointer address to read domain
    always @ (posedge r_clk or posedge r_rst) begin
        if (r_rst == 1'b1) begin
            r_syn_w_gray_shift_reg <= 0;
            r_syn_w_gray <= 0;
        end else begin
            r_syn_w_gray_shift_reg <= w_gray;
            r_syn_w_gray <= r_syn_w_gray_shift_reg;
        end
    end
    
    //--------------------------------------------------------------------------
    // Instantiate incrementer and full/empty checker modules
    
    // Write address increment and full check module
    w_ptr_full #(
			.ADDR_SIZE(ADDR_SIZE)
	 ) 
	 w_ptr_full (
        .w_syn_r_gray(w_syn_r_gray),						//write synched read pointer address
        .w_inc(w_en),											//write increment/enable
        .w_clk(w_clk),											//write clock
        .w_rst(w_rst),											//write side reset
        .w_addr(w_addr),										//write pointer address
        .w_gray(w_gray),										//write pointer address in gray
        .w_full(w_full)											//FIFO full flag
    );
    
    // Read address increment and empty check module
    r_ptr_empty #(
			.ADDR_SIZE(ADDR_SIZE)
	 )
	 r_ptr_empty (
        .r_syn_w_gray(r_syn_w_gray),						//read synched write pointer address
        .r_inc(r_en),											//read increment/enable
        .r_clk(r_clk),											//read clock
        .r_rst(r_rst),											//read side reset
        .r_addr(r_addr),										//read pointer address
        .r_gray(r_gray),										//read pointer address in gray
        .r_empty(r_empty)										//FIFO empty flag
    );
    
endmodule