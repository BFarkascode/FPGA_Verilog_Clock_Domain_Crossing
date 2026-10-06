// write pointer counter setup and full state check
// Increment write address and check if FIFO is full
// everything clocks at w_clk
module w_ptr_full #(

    // Parameters
    parameter   ADDR_SIZE = 4                   // Number of bits for address
) (
    
    // Inputs
    input       [ADDR_SIZE:0]   w_syn_r_gray,   // Synced read Gray pointer
    input                       w_inc,          // 1 to increment address
    input                       w_clk,          // Write domain clock
    input                       w_rst,          // Write domain reset
    
    // Outputs 
    output      [ADDR_SIZE-1:0] w_addr,         // Mem address to write to
    output  reg [ADDR_SIZE:0]   w_gray,         // Gray adress with +1 MSb
    output  reg                 w_full          // 1 if FIFO is full   
);

    // Internal signals
    wire    [ADDR_SIZE:0]   w_gray_next;    // Gray code version of address
    wire    [ADDR_SIZE:0]   w_bin_next;     // Binary version of address
    wire                    w_full_val;     // FIFO is full
    
    // Internal storage elements
    reg     [ADDR_SIZE:0]   w_bin;          // Registered binary address
    
    // Drop extra most significant bit (MSb) for addressing into memory
    assign w_addr = w_bin[ADDR_SIZE-1:0];
    
    // Be ready with next (incremented) address (if inc set and not full)
    assign w_bin_next = w_bin + (w_inc & ~w_full);
    
    // Convert next binary address to Gray code value
    assign w_gray_next = (w_bin_next >> 1) ^ w_bin_next;
    
    // Compare write Gray code to synced read Gray code to see if FIFO is full
    // If:  extra MSb of read and write Gray codes are not equal AND
    //      2nd MSb of read and write Gray codes are not equal AND
    //      the rest of the bits are equal
    // Then: address pointers are same with write pointer ahead by 2^ADDR_SIZE
    // elements (i.e. wrapped around), so FIFO is full.
	 //Note: we loop on Gray, not on the binary, that's why we have the 2nd MSB checked - i.e., on an 8 element FIFO, 4 is 0110 and 12 (the 4+8 overloop) is 1010
    assign w_full_val = ((w_gray_next[ADDR_SIZE] != w_syn_r_gray[ADDR_SIZE]) &&
                   (w_gray_next[ADDR_SIZE-1] != w_syn_r_gray[ADDR_SIZE-1]) &&
                   (w_gray_next[ADDR_SIZE-2:0] == w_syn_r_gray[ADDR_SIZE-2:0]));
    
    // Register/sample the binary and Gray Gray code pointer positions in the write clock domain
    always @ (posedge w_clk or posedge w_rst) begin
        if (w_rst == 1'b1) begin
            w_bin <= 0;
            w_gray <= 0;
        end else begin
            w_bin <= w_bin_next;
            w_gray <= w_gray_next;
        end
    end
    
    // Register/sample the full flag
    always @ (posedge w_clk or posedge w_rst) begin
        if (w_rst == 1'b1) begin
            w_full <= 1'b0;
        end else begin
            w_full <= w_full_val;
        end
    end
    
endmodule