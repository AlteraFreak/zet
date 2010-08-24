/*
 *  Copyright (c) 2009  Zeus Gomez Marmolejo <zeus@opencores.org>
 *
 *  This file is part of the Zet processor. This processor is free
 *  hardware; you can redistribute it and/or modify it under the terms of
 *  the GNU General Public License as published by the Free Software
 *  Foundation; either version 3, or (at your option) any later version.
 *
 *  Zet is distrubuted in the hope that it will be useful, but WITHOUT
 *  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 *  or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
 *  License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Zet; see the file COPYING. If not, see
 *  <http://www.gnu.org/licenses/>.
 */

module flash (
    // Wishbone slave interface
    input         wb_clk_i,
    input         wb_rst_i,
    input  [15:0] wb_dat_i,
    output [15:0] wb_dat_o,
    input  [16:1] wb_adr_i,
    input         wb_we_i,
    input         wb_tga_i,
    input         wb_stb_i,
    input         wb_cyc_i,
    input  [ 1:0] wb_sel_i,
    output reg    wb_ack_o,

    // Pad signals
    output [22:1] flash_addr_,
    input  [15:0] flash_data_,
    output        flash_we_n_,
    output        flash_oe_n_,
    output        flash_ce_n_,
    output        flash_rst_n_
  );

// Registers and nets
wire        op;
wire        opbase;
reg  [11:0] base;

// Continuous assignments
assign op = wb_stb_i & wb_cyc_i;
assign opbase  = op & wb_tga_i & wb_we_i;

assign flash_rst_n_ = 1'b1;
assign flash_we_n_  = 1'b1;
assign flash_oe_n_  = !op;
assign flash_ce_n_  = !op;
//assign flash_addr_[22:1] = { 6'h0, wb_adr_i };
assign flash_addr_[22:1] = wb_tga_i ? { 1'b0, 1'b1, base, wb_adr_i[8:1] } : { 6'h0, wb_adr_i };


assign wb_dat_o = flash_data_;

// wb_ack_o
always @(posedge wb_clk_i)
  wb_ack_o <= wb_rst_i ? 1'b0 : (wb_ack_o ? 1'b0 : op);

// base
always @(posedge wb_clk_i)
  base <= wb_rst_i ? 12'h0: ((opbase) ? wb_dat_i[11:0] : base);

endmodule
