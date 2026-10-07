# FPGA_Verilog_Clock_domain_crossing
FPGA clock domain crossing examples using a DE0Nano board (Altera Cyclone IV), Quartus Prime, Questa and Verilog.

Provided codes are related to clock domains and how to cross them without data loss.

We will not need hardware for these exercises. We will use only tb-s to showcase them instead.

## General description
Let’s follow up on the repo from before and get into more complex things, shall we? More precisely, we have to talk about a very important concept in FPGAs and one of the main source of all misery and issues: clock domains.

### Clock domain crossing
We usually generate all clocks from the same general source (here, the 50 MHz external crystal) which should mean that all clocks are in synch. This isn’t always the case though due to how we may set the clocks up (we can add a phase delay on PLLs, for instance) or due to actually having two asynch clocks driving the design (two separate physical crystals, for example). Of note, an external physical action/trigger – say, a button being pushed by a user - is ALWAYS asynchronous to the FPGA, which will lead to the introduction of a new "clock domain" (the “always” block will be executed on the external trigger, not on the clock). An external trigger is probably the most common way to encounter an asynch clock domain in early projects.

What does a separate clock domain (relative to the FPGA's own clock) mean from a practical sense? Well, it means that sampling of a signal (done by the second clock) will not likely occur the same time as the change on the signal (done by the first clock), potentially breaking setup-hold times and introducing metastability (example: if we have a signal that changes every 6 ns with a setup-hold time of 3 ns, then a 2 ns sampling trigger will generate a metastable/glitched value of the first trigger and only provide the right output on the second and the third triggers). The issue becomes even more severe if the trigger becomes asynchronous to the original clock signal, practically meaning that ALL samplings may become metastable.

Now, to get around this issue, we can do certain coding best practices to facilitate a safe domain crossing from one clock to the other.

#### Synchronisation/signal crossing
We have already touched upon these in the previous repo where, in order to ensure that an incoming value to a module is not metastable, we sent it through a synchroniser. A synchroniser is just a small shift register, something that will store the incoming signal for one clock cycle and then provide it after this cycle as the input to the module. This usually will be just an “always” block at the beginning of the module clocking on the trigger of the module and sampling the incoming signal into a 2-element shift register, the MSB of the register then used as the actual input for the module instead of the direct input. Mind, this will introduce a delay to the signal progression, something we often will have to compensate for somewhere else (or just be conscious of) even in cyclical executions. An example will be shared below.

#### Flag crossing/handshake/task crossing
To pass a flag between two different clocks – a signal that is merely one tick high in the source and on the receiving domain – some extra considerations must be followed. First and foremost, flags can be easily missed due to their short size (say, the flag is 10 ns long, but we sample the input line only every 20 ns) or can be sampled too many times, making them lose their flag shape.

The solution is to turn any flag into a level change in the source clock domain before passing it to the receiving clock domain. It is also a good idea to do something called a “handshake” where the receiving domain will send an acknowledgement back to the source to announce that it has received the flag.

A more complex version of a “handshake” is a task crossing where we have an acknowledgement as well as a “task done” flag passed between the two domains.

An example for all three of these transitions will be shared below.

#### Data crossing (FIFO)
Now, this is a the big one where we step away from only pushing singular bits over the separate domains and shift to actual data busses, something we will need to use extensively to interface with external hardware busses with our FPGA.

A FIFO – or First-In, First-Out – element should not sound new to anyone, but to be clear anyway, it is a memory device/data queue that will be loaded by one of the clocks (the input/write domain) and read out with the other (the output/read domain). The trick is that if the FIFO is full, it won’t be loaded further and if it is empty, it won’t be read out again.

To construct a FIFO, we have two memory pointers (a write pointer and a read pointer) which loop around the FIFO’s memory block, writing into or reading out the element they are pointing at. Once they have done the reading/writing, they are stepped to the next memory position. The trick comes when the two memory pointers catch up with each other, i.e. they point to the same memory element: if the read pointer catches up with the write pointer, the FIFO has run empty, if the write pointer catches up with the read pointer, the FIFO is full. We thus have to know the relative position of the two pointers and in which "direction" they arrive to their overlap. This means that the state of both memory pointers must be “known” within both the input side and the output side clock domains, after all, the pointers will be running on two different – potentially asynchronous - clock domains representing the input or the output side of the FIFO.

As such, a FIFO build demands a very good understanding of clock domain crossings. It also demands a highly accurate and reliable counter to be implemented, which is where Gray counters come to play.

### Gray counters
There is a fundamental difficulty in moving the pointers on time where it may take too long for them to properly update their position using normal binary counters (remember that changing a counter’s value will not occur under just one system/FPGA clock but will occur under whichever number of bits will have to physically change – for example, switching from 4’b0110 to 4’b0111 will be 4 times faster than stepping from 4’b0111 to 4’b1000).

A Gray counter helps with this issue by transforming any count-up or count-down step taking only one bit to change. A Gray counterup to 4 will turn

2’b0->2’b1->2’b10->2’b11

to

2’b0->2’b1->2’b11->2’b10

instead, for instance.

A Gray code is particularly useful when sending counting data over two clock domains since it will have an uncertainty of only 1 bit and would need to synchronise only one value when the count is passing the clock domains, making it a lot faster. FIFOs thus often use Gray counters to assign position data to their write/read pointers. (Mind, it is perfectly possible to use binary counters in FIFOs instead, though the handshake mechanisms to pass these counters between clock domains will be significantly more complex, introducing latency in an otherwise critical and highly timing-sensitive element.)

The only thing to keep in our minds is that a standard Gray counter is always a 2-factor sized counter, it cannot be anything different due to the natural symmetry (reflection) of its design. This limits the number of FIFO elements to factors of 2.

The conversion code to go from binary counter to Gray counter is pretty simple, and I am not sharing it. There will be a few within the FIFO code anyway (see the two pointer definition Verilog files instead).

### FPGA Block RAMs
We need to mention block rams too.

As it goes, whenever we are defining registers, those definitions will be stored in LTEs. What happens though is that if we need to store a lot of data locally, the number of available LTEs will decrease fast to the point where we may not have any left to actually develop our code. (Well, that's a bit extreme situation, but could happen.)

Anyway, the solution to this potential issue are the internal block RAMs of the FPGA. These block rams are engaged by the compiler whenever we define two-dimensional registers, the compiler moving the memory element from LTEs to the block RAM.

The number of block RAMs are limited in the FPGA and they are defined in blocks, so if we engage one, the entire block will be engaged, independent of if we are actually using up all the RAM for our two-dimensional register. The exact size and number of blocks can be found in the datasheet of the FPGA (check for the memory configuration section). When we synthesise code, the summary section will show the amount of block RAMS in use the same way how it shows he maximum clock speed and the LTEs in use.

Of note, depending on hardware, the way we manage memory blocks may differ. 

We will use a block RAM to be the memory section of our FIFO. Since they are just a one-line code element in the syntax – technically, a definition of a 2D register – I won’t be doing a separate code example on them.

At any rate, the definition should look like this to set a 256x16 bit memory block called “mem”:

Reg	[15:0]	mem	[0:7];	- first is the “row”, second is the “column”

We interact with a “row” of memory by calling/pointing to the row number:

mem[w_addr] <= w_data;	- for writing
r_data <= mem[r_addr]		- for reading

where both w_addr and r_addr are to be values between 0 and 255. Note that we don’t use integers to define this matrix but use regs instead.

## To read
I recommend, as usual, the Shawn Hymel training:

Introduction to FPGA Part 1 - What is an FPGA? | Digi-Key Electronics

Clock crossing:

fpga4fun.com - Crossing clock domains

Metastability:

Experimenting with Metastability and Multiple Clocks on FPGAs – Colin O'Flynn

FIFO:

Microsoft Word - CummingsSNUG2002SJ_FIFO1_rev1_2.doc 

Keep the Verilog syntax cheat sheet close by, as always:

Verilog_Cheat_Sheet.pdf

## Particularities
Below are the codes to reproduce the concepts from above. They will all run just in tb, no need for the DE0 Nano. Tthere won’t be a “sof” file shared either since there is no need for one when not using hardware.

Of note, we do need to assign all registers a starting “0” value in code though since, with a missing reset button, all registers will remain undefined otherwise, leading to metastability in the simulator. Alternative – and general best practice - is to add a reset signal to everything and drive that signal within the tb as the initial first item to execute.

An interesting thing I suggest playing around here (out into the “curiosity” sections) is the length of the incoming signal and the clock ratio between the two domains. The outcomes may not be as we initially expect them to be, despite the code working perfectly well (if we use a faster clock as the source, we may have some values skipped, for instance).

### Clock_cross
We will have four modules here for each of the elements discussed above. They are all simple representations of clock domain crossing and are mostly reformulations of code found on the fpga4fun website.

#### Synchronisation
There isn’t much to discuss here, we have a shift register that will delay the output compared to the input by one clock cycle.

Mind, we can have any length of a signal coming into the synchronizer.

Curiosity:  pay attention to keep the input generated by the tb in synch with the clock signal we are feeding into the module, otherwise we will have a slight jitter on the form of the output signal (that is, we will have it either slightly shorter or longer).

#### Flag crossing
Now, we will do flag crossing, which means that we will pass a signal that is only one clock cycle long (a tick or flag). We get this done by doing a XOR operation on the input and its sampled form, which technically will mean that the flag will only be HIGH if the sampled signal and the signal (i.e. the register-stored previous state of the signal and its current state) are different.

The flag will then be passed to the other clock domain through a small synchroniser and become re-generated on the receiving domain using another XOR. We can process the flag further now in the receiving domain. 

Curiosity: since we pass the incoming flag through a shift register, the receiving domain flag will be at least two clock cycles long if the source clock is faster than the receiving clock. The reason for that is that we detect both the raise of the flag and the removal of the flag on the receiving domain using the XOR operation. This will not be the case if the receiving clock is faster than the source.

#### Handshake
Here we have a “flag pass” for both domains where the initially detected flag is sent back to the source domain (so, technically two back-to-back flag crossings happen). The busy flag is then pulled back low when the acknowledge is received in the source domain.

A handshake is more reliable than a flag crossing since it includes an acknowledge from the receiving side.

#### Task crossing
This is a more advanced version of the handshake where we wait until a certain task is finished before sending back the appropriate acknowledgement. The end of the task is indicated as an input trigger set in the receiving domain (it will be an input wire, expecting a flag). The system will remain “busy” as long as the task is running.

### FIFO_by_Cummings
I very much recommend checking the “to read” document on FIFOs since it provides a very robust and easy to implement solution while explaining everything in greater detail. Below, we will implement the FIFO from this paper by Cummings.

The first thing to mention again is that the read pointer of the FIFO will be running in the read clock domain, while the write pointer will be running in the write clock domain. In order to compare them, the write pointer will have to be synchronized to the read clock domain and the read pointer will have to be synchronized to the write clock domain.

Each pointer will be assigned a counter to define at which position they currently are within the FIFO's memory. This synchronization is thus done then by passing these two counters between the domains. The counters will be Gray counters to help with the efficiency and speed of synchronisation. The counters will obviously be counting along the same values.

To get the pointers understand, where they are relative to each other, we add an indicator MSB to both counters. This MSB will indicate if the read pointer is catching up with the write pointer or the other way around: when the FIFO is running empty, both pointers’ MSB will be the same, while if the FIFO is going full, the MSB will be different (i.e., we have an overflow).

The FIFO design used by Cummings also sets the “full” and “empty” flags immediately, but removes them with a slight delay to ensure that data is not lost/there is no duplicate read by accident.

Lastly, something that may seem obvious – but it won’t be later, I assure you – is that clock domains of the FIFO must be selected appropriate to the data that is flowing into it/being read out from the FIFO. For instance, the write clock domain (so the speed at which we write info the FIFO) must be faster than the clock speed with which the input of the FIFO is changing or we are simply going to skip some values, the FIFO being too slow to capture all the changes in data. Ideally of course, the FIFO loading would be synchronized to the data changing on the input of the FIFO, but it is a mistake to assume that this is always the case. (Anyway, what I want to say is that one should always be aware of their clock domains and where they are being used.)

Now, just to reflect on the actual code, we have a load and a read clock which will be the ones moving the pointers (well, update their addresses), but, as mentioned before, these are not the same as the speed at which we put new data into the FIFO or read data out from it. Those will be controlled by the enable or increment lines, which can be left high all the time (so loading and reading out happens with the same speed as what moves the pointers), or they can be used as triggers. If we have a value that periodically changes, then we will have to set the trigger every time we want the new value to be captured by the FIFO. Simply feeding the data into the FIFO will not do the trick. What I want to emphasize then is that we will physically clock elements in our designs and data will have to pass through these physical clock domains, but they have no relation to how the data actually changes. That, for better or worse, could be asynchronous to our design, though, we usually synchronise them to the design’s input side to give sense to implementing the design the first place...

### FIFO_by_moi
I am sharing this here for a very simple reason: we will be using this particular variant of the Cummings FIFO extensively in future projects to pass data between different hardware elements.

Okay, but what is so different with this FIFO compared to the original one?

One thing is that we change the standard parameter for DATA_SIZE of the FIFO to be 16 since we will be working with half-words a lot.

Secondly, we can have “almost full” and “almost empty” signals in the FIFO by simply comparing the pointer counter values with an offset. It is recommended to use these since they can indicate the state of the FIFO before it is achieved. Mind, if we run the FIFO on full/empty outputs only, chances are that we end up loading it again/reading out from it again before the state indicator is processed.

Anyway, this FIFO modified by me has the “almost flags” added on the full and empty indicators, meaning that a few elements before the FIFO would run full or empty, we will have an additional flag activating on either side. This will be crucial later to properly time the FIFO and not allow it to run accidentally full or empty. Mind, we will be dealing with data flows in and out of the FIFO later that will be continuous, meaning that we will have to either load and read them out in a way to ensure that the data flow remains continuous (example: a camera will put a snapshot on its interface bus and not stop until all data is “published”, meaning that if we have a FIFO on the bus to receive data, we must always empty it BEFORE it would run full, otherwise some of the snapshot pixels will be lost...yes, managing the loading/unloading of FIFOs and ensuring that they are wide enough to avoid data loss is one of the difficulties using an FPGA apart from clock crossings…)

The logic behind setting the “almost flags” is identical to how the full and empty flags were set, except that we compare the synchronised Gray addresses with an offset locally to generate them. Of note, just in case somebody wondered this, unlike the one-step incremented binary and Gray values, the offset ones are not synchronised back to the other clock domain since we don’t need them outside the pointer increment modules.

The “almost flags” should always be set according to the input. If we write in/read out only one element at a time, the flag position isn’t an issue, obviously. In reality though, we very rarely do singular writes/reads and go for bursts of data instead. Most hardware elements we might be hooking the FIFO to do often come with options of data bursting 2, 4, 8 or 16 values, meaning that they will send or read out that many FIFO elements in one uninterrupted move. If we have then less space in the FIFO than the burst, we will lose data due to overflow. If we have less data in the FIFO than the burst, we will generate fake data (e.g. double reading of the same value to comply to the burst).

Lastly, if we have the burst read/write EXACTLY the same size as the almost flag, the flag can become ambiguous.

Always set the "almost flags" with caution.

## Conclusion
We have discussed clock domain crossing and how to deal with it to avoid glitches. We have also showcased a simple FIFO that will become a crucial element of our designs in later repos.

Now, we will go into practical use cases and show, how to run more interesting things on our DE0 Nano.
