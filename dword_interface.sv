`timescale 1ns / 1ps

`include "defs.vh"

module dword_interface(
        input clk_in,
        input reset,
        input wr,
        input [31:0] data_from_PC,
        output reg busy, 
        output error,
        output [63:0] readout,
        inout [3:0] DQio,
        output S
    );
   
    STARTUPE2 #(
       .PROG_USR("FALSE"),      // Activate program event security feature. Requires encrypted bitstreams.
       .SIM_CCLK_FREQ(10.0)     // Set the Configuration Clock Frequency(ns) for simulation.
    )
    STARTUPE2_inst (
        .CFGCLK(),              // 1-bit output: Configuration main clock output
        .CFGMCLK(),             // 1-bit output: Configuration internal oscillator clock output
        .EOS(),                 // 1-bit output: Active high output signal indicating the End Of Startup.
        .PREQ(),                // 1-bit output: PROGRAM request to fabric output
        .CLK(1'b0),             // 1-bit input: User start-up clock input
        .GSR(1'b0),             // 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
        .GTS(1'b0),             // 1-bit input: Global 3-state input (GTS cannot be used for the port name)
        .KEYCLEARB(1'b0),       // 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
        .PACK(1'b0),            // 1-bit input: PROGRAM acknowledge input
        .USRCCLKO(~clk_in),     // 1-bit input: User CCLK input
        .USRCCLKTS(1'b0),       // 1-bit input: User CCLK 3-state enable input
        .USRDONEO(1'b1),        // 1-bit input: User DONE pin output control
        .USRDONETS(1'b1)        // 1-bit input: User DONE 3-state enable output
    );
 
    reg [3:0] state;
    reg trigger;
    reg quad;
    reg [7:0] cmd;
    reg [(3+`maxcmd)*8-1:0] data_send;
    reg [7:0] len;
    wire mc_busy;

    qspi_mem_controller mc(
    .clk(clk_in), 
    .reset(reset),
    .S(S), 
    .DQio(DQio),
    .trigger(trigger),
    .quad(quad),
    .cmd(cmd),
    .data_send(data_send),
    .readout(readout),
    .busy(mc_busy),
    .error(error));


    always @(posedge clk_in) begin
        if(reset) begin
            trigger <= 0;
            state <= 0;
            quad <= 0;
            busy <= 1;
        end else begin
        
            case(state)
                0: begin
                    trigger <= 0;
                    if(busy && !mc_busy) begin
                        busy <= 0;
                    end else begin
                        if(!busy && wr) begin
                            busy <= 1;
                            cmd <= data_from_PC[7:0];
                            len <= data_from_PC[15:8];
                            quad <= data_from_PC[16];
                            state <= state+1;
                        end
                    end
                end
            
                1: begin
                    if (len > 0) begin
                        if (wr) begin
                            data_send <= {data_send[(3+`maxcmd)*8-1-32:0], data_from_PC}; // shifting in the data
                            len <= len-1;
                        end
                    end else begin
                        trigger <= 1;
                        state <= state+1;
                    end
                end
                
                2: begin
                    if (mc_busy)
                        state <= 0; // as our clock here is faster, holding the trigger high until the controller captures it
                end
                
                default:
                    state <= state+1;
            endcase
        end
    end



endmodule
