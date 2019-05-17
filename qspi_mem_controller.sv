`timescale 1ns / 1ps

`include "defs.vh"

`define STATE_IDLE   0
`define STATE_WAIT 2
`define STATE_CUSTOMCMD 15

module qspi_mem_controller(
        input clk,
        input reset,
        input trigger,
        input quad,
        input [11:0] data_in_count,
        input [11:0] data_out_count,
        input [(3+`maxcmd)*8-1:0] data_in, //max: 256B page data + 3B address
        output reg [63:0] readout,
        output reg busy,
        output reg error,

        inout [3:0] DQio,
        output S
    );
    
    reg spi_trigger;
    wire spi_busy;
    
    wire [63:0] data_out;
    
    spi_cmd sc(.clk(clk), .reset(reset), .trigger(spi_trigger), .busy(spi_busy), .quad(quad),
        .data_in_count(data_in_count), .data_out_count(data_out_count), .data_in(data_in), .data_out(data_out),
        .DQio(DQio[3:0]), .S(S));
        
    reg [5:0] state;
    reg [5:0] nextstate;
    
    always @(posedge clk) begin
        if(reset) begin
            state <= `STATE_WAIT;
            nextstate <= `STATE_IDLE;
            spi_trigger <= 0;
            busy <= 1;
            error <= 0;
            readout <= 0;
        end
        
        else
            case(state)
                `STATE_IDLE: begin
                    if(trigger) begin
                        busy <= 1;
                        error <= 0;
                        state <= `STATE_CUSTOMCMD;
                    end else
                        busy <= 0;
                end            

                `STATE_WAIT: begin
                    spi_trigger <= 0;
                    if (!spi_trigger && !spi_busy) begin
                        state <= nextstate;
                        readout <= data_out;
                    end
                end
                
                `STATE_CUSTOMCMD: begin
                    spi_trigger <= 1;
                    state <= `STATE_WAIT;
                    nextstate <= `STATE_IDLE;
                end                

            endcase
    end
    
    
endmodule
