/*
 *  Linear mode graphics for VGA
 *  Copyright (C) 2010  Zeus Gomez Marmolejo <zeus@aluzina.org>
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

module linear #( parameter fml_depth      = 25 )
  (
    input clk,
    input rst,

    input [1:0] h_subpixel,
    input [15:0] start_addr,

    // CSR slave interface for reading
    output [17:1] csr_adr_o,
    input  [15:0] csr_dat_i,
    output        csr_stb_o,

    input [9:0] h_count,
    input [9:0] v_count,
    input       horiz_sync_i,
    input       video_on_h_i,
    output      video_on_h_o,

    output [7:0] color,
    output       horiz_sync_o,

    // FML slave interface for reading
    output reg  [fml_depth-1:0] fml_adr,
    output reg                  fml_stb,
    input                       fml_ack,
    input               [15: 0] fml_di

  );

  // Registers
  reg [ 9:0] row_addr;
  reg [ 6:0] col_addr;
  reg [14:1] word_offset;
  reg [ 1:0] plane_addr;
  reg [ 1:0] plane_addr0;
  reg [ 7:0] color_l;

  reg [4:0] video_on_h;
  reg [4:0] horiz_sync;
  reg [5:0] pipe;
  reg [15:0] word_color;

  // Continous assignments
//  assign csr_adr_o = { plane_addr, word_offset, 1'b0 };
//  assign csr_stb_o = pipe[1];

  assign color = ( pipe[4] & h_subpixel[1] & h_subpixel[0]) ? fml_data[7:0] : color_l;

  assign video_on_h_o = video_on_h[4];// & h_subpixel[1] & h_subpixel[0];
  assign horiz_sync_o = horiz_sync[4];// & h_subpixel[1] & h_subpixel[0];

  // Behaviour
  // Pipeline count
  always @(posedge clk)
    pipe <= rst ? 6'b0 : ( h_subpixel[1] & h_subpixel[0] ) ? { pipe[4:0], ~h_count[0] } : pipe;

  // video_on_h
  always @(posedge clk)
    video_on_h <= rst ? 5'b0 : ( h_subpixel[1] & h_subpixel[0] ) ? { video_on_h[3:0], video_on_h_i } : video_on_h;

  // horiz_sync
  always @(posedge clk)
    horiz_sync <= rst ? 5'b0 : ( h_subpixel[1] & h_subpixel[0] ) ? { horiz_sync[3:0], horiz_sync_i } : horiz_sync;

always @ ( posedge clk )
  fml_stb <= ( fml_ack ) ? 1'b0 : ( fml_stb ) ? fml_stb : (pipe[1] & h_subpixel[1] & h_subpixel[0]);

reg [15: 0] fml_data;
// attr_data_out
always @(posedge fml_ack ) fml_data[15: 0] <= fml_di[15: 0];

  // Address generation
  always @(posedge clk)
    if (rst)
      begin
        row_addr    <= 10'h0;
        col_addr    <= 7'h0;
        plane_addr0 <= 2'b00;
        word_offset <= 14'h0;
        plane_addr  <= 2'b00;
        fml_adr     <= {fml_depth{1'b0}};
      end
    else
      begin
        // Loading new row_addr and col_addr when h_count[3:0]==4'h0
        // v_count * 5 * 32
        row_addr    <= { v_count[8:1], 2'b00 } + v_count[8:1];
        col_addr    <= h_count[9:3];
        plane_addr0 <= h_count[2:1];

        word_offset <= { row_addr + col_addr[6:4], col_addr[3:0] };
        plane_addr  <= plane_addr0;
        fml_adr     <= { 'b1010_0000_0000_0000_0000 + { plane_addr, word_offset , 1'b0 } + start_addr };
      end

  // color_l
  always @(posedge clk)
    color_l <= rst ? 8'h0 : ((pipe[4]&h_subpixel[1] & h_subpixel[0]) ? fml_data[7:0] : color_l);

endmodule
