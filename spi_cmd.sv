`timescale 1ns / 1ps

`define STATE_IDLE 0
`define STATE_SEND 1
`define STATE_READ 2


module spi_cmd(
        //control interface
        input clk,
        input reset,
        input trigger,
        output reg busy,
        input [11:0] data_in_count,
        input [11:0] data_out_count,
        input [`maxcmd*8-1:0] data_in, //max len is: 256B data + 1B cmd + 3B addr
        output reg [63:0] data_out,
        input quad,
        
        //SPI interface
        inout [3:0] DQio,
        output reg S 
    );
    
    wire [2:0] width = quad?4:1;
    
    reg [11:0] bit_cntr;

    reg [3:0] DQ = 4'b1111;
    reg oe;
    assign DQio[0] = oe?DQ[0]:1'bZ;
    assign DQio[1] = oe?DQ[1]:1'bZ;
    assign DQio[2] = oe?DQ[2]:1'bZ;
    assign DQio[3] = quad?(oe?DQ[3]:1'bZ):1'b1; // has to be held 1 as 'hold'
    //during single IO operation, but in quad mode behaves as other IOs
    
    reg [1:0] state;    
    
     always @(posedge clk) begin
        if(reset) begin
            state <= `STATE_IDLE;
            oe <= 0;
            S <= 1;
            busy <= 1;
        end else begin
            
            case(state)
                `STATE_IDLE: begin
                    if(trigger && !busy) begin
                        state<=`STATE_SEND;
                        busy <= 1;
                        bit_cntr <= data_in_count;   
                     end else begin
                        S <= 1;
                        busy <= 0;
                     end
                 end

                `STATE_SEND: begin
                    S <= 0;
                    oe <= 1;
                    if(quad) begin
                        DQ[0] <= data_in[bit_cntr-3];
                        DQ[1] <= data_in[bit_cntr-2];
                        DQ[2] <= data_in[bit_cntr-1];
                        DQ[3] <= data_in[bit_cntr];
                    end else
                         DQ[0] <= data_in[bit_cntr];
                    
                    if(bit_cntr>width-1) begin
                        bit_cntr <= bit_cntr - width;
                    end else begin
                        if(data_out_count>0) begin
                            state <= `STATE_READ;
                            bit_cntr <= data_out_count; //7+1 because read happens on falling edge
                        end
                        else begin
                            state <= `STATE_IDLE;
                        end
                    end
                end

                `STATE_READ: begin
                    oe <= 0;
                    
                    if(bit_cntr>width-1) begin
                        bit_cntr <= bit_cntr - width;
                    end else begin
                        S <= 1;
                        state <= `STATE_IDLE;
                    end
                end
                
                
                default: begin
              
                end
            endcase
        end
    end 
   
    always @(negedge clk) begin
        if(reset)
            data_out <= 0;
        else
            if(state==`STATE_READ) begin
                if(quad)
                    data_out <= {data_out[59:0], DQio[3], DQio[2], DQio[1], DQio[0]};
                else
                    data_out <= {data_out[62:0], DQio[1]};
            end
    end

`ifdef XLNX_ILA_QSPI
xlnx_ila_qspi qspi_ila (
        .clk(clk), // input wire clk
        .probe0(S), // input wire [0:0]  probe0  
        .probe1(quad), // input wire [0:0]  probe1 
        .probe2(oe), // input wire [0:0]  probe2 
        .probe3(DQ), // input wire [3:0]  probe3 
        .probe4(busy), // input wire [0:0]  probe4 
        .probe5(bit_cntr), // input wire [0:0]  probe5 
        .probe6(state), // input wire [3:0]  probe6 
        .probe7(data_out), // input wire [0:0]  probe7
        .probe8(data_out_count), // input wire [0:0]  probe7
        .probe9(data_in_count), // input wire [0:0]  probe7
        .probe10(width) // input wire [0:0]  probe7
);
`endif //  `ifdef XLNX_ILA_QSPI
   
endmodule
