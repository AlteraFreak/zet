/*
 * Milkymist VJ SoC
 * Copyright (C) 2007, 2008, 2009, 2010 Sebastien Bourdeauducq
 * adjusted to FML 8x16 by Zeus Gomez Marmolejo <zeus@aluzina.org>
 * updated with dcb by AlteraFreak <AlteraFreak@t-online.de>
 * removed reg as they were no reg due to always @(*) what makes them 
 * simple muxers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

module fmlarb #(
    parameter fml_depth = 25
) (
    input sys_clk,
    input sys_rst,

    /* Interface 0 has higher priority than the others */
    input [fml_depth-1:0] m0_adr,
    input m0_stb,
    input m0_we,
    output m0_ack,
    input [1:0] m0_sel,
    input [15:0] m0_di,
    output [15:0] m0_do,

    input [fml_depth-1:0] m1_adr,
    input m1_stb,
    input m1_we,
    output m1_ack,
    input [1:0] m1_sel,
    input [15:0] m1_di,
    output [15:0] m1_do,

    output [fml_depth-1:0] s_adr,
    output s_stb,
    output s_we,
    input s_ack,
    output [1:0] s_sel,
    input [15:0] s_di,
    output [15:0] s_do
);

assign m0_do = s_di;
assign m1_do = s_di;

reg master;
reg next_master;

always @(posedge sys_clk) begin
    if(sys_rst)
        master <= 1'd0;
    else
        master <= next_master;
end

/* Decide the next master */
always @(*) begin
    /* By default keep our current master */
    next_master = master;

    case(master)
        1'd0: if(~m0_stb | s_ack) begin
            if(m1_stb) next_master = 1'd1;
        end
        default: if(~m1_stb | s_ack) begin
            if(m0_stb) next_master = 1'd0;
        end
    endcase
end

/* Generate ack signals */
assign m0_ack = (master == 1'd0) & s_ack;
assign m1_ack = (master == 1'd1) & s_ack;

assign s_adr = ( master ) ? m1_adr : m0_adr;
assign s_stb = ( master ) ? m1_stb : m0_stb;
assign s_we  = ( master ) ? m1_we  : m0_we;
assign s_do  = ( master ) ? m1_do  : m0_do;
assign s_sel = ( master ) ? m1_sel : m0_sel;

/* Mux data write signals */

wire write_burst_start = s_we & s_ack;

reg wmaster;
reg [1:0] burst_counter;

always @(posedge sys_clk) begin
    if(sys_rst) begin
        wmaster <= 1'd0;
        burst_counter <= 2'd0;
    end else begin
        if(|burst_counter)
            burst_counter <= burst_counter - 2'd1;
        if(write_burst_start)
            burst_counter <= 2'd2;
        if(~write_burst_start & ~(|burst_counter))
            wmaster <= next_master;
    end
end

endmodule

