/*
 * Milkymist VJ SoC
 * Copyright (C) 2007, 2008, 2009, 2010 Sebastien Bourdeauducq
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

    output reg [fml_depth-1:0] s_adr,
    output reg s_stb,
    output reg s_we,
    input s_ack,
    output reg [1:0] s_sel,
    input [15:0] s_di,
    output reg [15:0] s_do
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

/* Mux control signals */
always @(*) begin
    case(master)
        1'd0: begin
            s_adr = m0_adr;
            s_stb = m0_stb;
            s_we = m0_we;
        end
        default: begin
            s_adr = m1_adr;
            s_stb = m1_stb;
            s_we = m1_we;
        end
    endcase
end

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

always @(*) begin
    case(wmaster)
        1'd0: begin
            s_do = m0_di;
            s_sel = m0_sel;
        end
        default: begin
            s_do = m1_di;
            s_sel = m1_sel;
        end
    endcase
end

endmodule

