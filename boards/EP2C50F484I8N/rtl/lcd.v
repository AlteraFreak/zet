/*
 *  LCD controller for VGA
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

module lcd #( parameter fml_depth      = 25 )
  (
    input clk,              // 25 Mhz clock
    input rst,

    input shift_reg1,       // if set: 320x200
    input graphics_alpha,   // if not set: 640x400 text mode

    input [15:0] start_addr,

    // CSR slave interface for reading
    output [17:1] csr_adr_o,
    input  [15:0] csr_dat_i,
    output        csr_stb_o,

    // attribute_ctrl
    input  [3:0] pal_addr,
    input        pal_we,
    output [7:0] pal_read,
    input  [7:0] pal_write,

    // dac_regs
    input        dac_we,
    input  [1:0] dac_read_data_cycle,
    input  [7:0] dac_read_data_register,
    output [7:0] dac_read_data,
    input  [1:0] dac_write_data_cycle,
    input  [7:0] dac_write_data_register,
    input  [7:0] dac_write_data,

    // VGA pad signals
    output reg [3:0] vga_red_o,
    output reg [3:0] vga_green_o,
    output reg [3:0] vga_blue_o,
    output reg       horiz_sync,
    output reg       vert_sync,

    // CRTC
    input [5:0] cur_start,
    input [5:0] cur_end,
    input [4:0] vcursor,
    input [6:0] hcursor,

    input [6:0] horiz_total,
    input [6:0] end_horiz,
    input [6:0] st_hor_retr,
    input [4:0] end_hor_retr,
    input [9:0] vert_total,
    input [9:0] end_vert,
    input [9:0] st_ver_retr,
    input [3:0] end_ver_retr,

    input x_dotclockdiv2,

    // retrace signals
    output v_retrace,
    output vh_retrace,

    output      [fml_depth-1:0] fml_adr,
    output wire                 fml_stb,
    input                       fml_ack,
    input               [15: 0] fml_di
    
  );

  // Registers and nets
  reg        video_on_v;
  reg        video_on_h_i;
  reg [1:0]  video_on_h_p;
  reg [9:0]  h_count;   // Horizontal pipeline delay is 2 cycles
  reg [9:0]  v_count;   // 0 to VER_SCAN_END

  wire [9:0] hor_disp_end;
  wire [9:0] hor_scan_end;
  wire [9:0] ver_disp_end;
  wire [9:0] ver_sync_beg;
  wire [3:0] ver_sync_end;
  wire [9:0] ver_scan_end;
  wire       video_on;

  wire [3:0] attr_wm;
  wire [3:0] attr_tm;
  wire [3:0] attr;
  wire [7:0] index;
  wire [7:0] index_pal;
  wire [7:0] color;
  reg  [7:0] index_gm;

  wire video_on_h_tm;
  wire video_on_h_wm;
  wire video_on_h_gm;
  wire video_on_h;

  reg       horiz_sync_i;
  reg [1:0] horiz_sync_p;
  wire      horiz_sync_tm;
  wire      horiz_sync_wm;
  wire      horiz_sync_gm;

  wire [16:1] csr_tm_adr_o;
  wire        csr_tm_stb_o;
  wire [17:1] csr_wm_adr_o;
  wire        csr_wm_stb_o;
  wire [17:1] csr_gm_adr_o;
  wire        csr_gm_stb_o;
  wire        csr_stb_o_tmp;

  wire [7:0] red;
  wire [7:0] green;
  wire [7:0] blue;

//assign fml_adr = { 'b1011_1000_0000_0000_0000 + { csr_adr_i , 1'b0 } };

wire      [fml_depth-1:0]   fml_adr_tm;
wire      [fml_depth-1:0]   fml_adr_gm;
wire      [fml_depth-1:0]   fml_adr_wm;
assign fml_adr = graphics_alpha ?
    (shift_reg1 ? fml_adr_gm : fml_adr_wm) : { 1'b0, fml_adr_tm };
    
wire                        fml_stb_tm;
wire                        fml_stb_gm;
wire                        fml_stb_wm;
assign fml_stb = graphics_alpha ? (shift_reg1 ? fml_stb_gm : fml_stb_wm) : fml_stb_tm;

  // Module instances
  text_mode #( .fml_depth ( 25 )
) tm (
    .clk (clk),
    .rst (rst),

    .h_subpixel ( h_subpixel ),
    .start_addr (start_addr),
    
    // CSR slave interface for reading
//    .csr_adr_o (csr_tm_adr_o),
//    .csr_dat_i (csr_dat_i),
//    .csr_stb_o (csr_tm_stb_o),

    .h_count      (h_count),
    .v_count      (v_count),
    .horiz_sync_i (horiz_sync_i),
    .video_on_h_i (video_on_h_i),
    .video_on_h_o (video_on_h_tm),

    .cur_start  (cur_start),
    .cur_end    (cur_end),
    .vcursor    (vcursor),
    .hcursor    (hcursor),

    .attr         (attr_tm),
    .horiz_sync_o (horiz_sync_tm),

    .fml_adr    ( fml_adr_tm ),
    .fml_stb    ( fml_stb_tm ),
    .fml_ack    ( fml_ack    ),
    .fml_di     ( fml_di     )
  );

  planar wm (
    .clk (clk),
    .rst (rst),

    // CSR slave interface for reading
    .csr_adr_o (csr_wm_adr_o),
    .csr_dat_i (csr_dat_i),
    .csr_stb_o (csr_wm_stb_o),

    .attr_plane_enable (4'hf),
    .x_dotclockdiv2    (x_dotclockdiv2),

    .h_count      (h_count),
    .v_count      (v_count),
    .horiz_sync_i (horiz_sync_i),
    .video_on_h_i (video_on_h_i),
    .video_on_h_o (video_on_h_wm),

    .attr         (attr_wm),
    .horiz_sync_o (horiz_sync_wm)
  );

  linear #( .fml_depth ( 25 )
) gm (
    .clk (clk),
    .rst (rst),

    .h_subpixel       ( h_subpixel ),
    .start_addr (start_addr),

    // CSR slave interface for reading
    .csr_adr_o (csr_gm_adr_o),
    .csr_dat_i (csr_dat_i),
    .csr_stb_o (csr_gm_stb_o),

    .h_count      (h_count),
    .v_count      (v_count),
    .horiz_sync_i (horiz_sync_i),
    .video_on_h_i (video_on_h_i),
    .video_on_h_o (video_on_h_gm),

    .color        (color),
    .horiz_sync_o (horiz_sync_gm),

    .fml_adr    ( fml_adr_gm ),
    .fml_stb    ( fml_stb_gm ),
    .fml_ack    ( fml_ack    ),
    .fml_di     ( fml_di     )
  );

  palette_regs pr (
    .clk (clk),

    .attr  (attr),
    .index (index_pal),

    .address    (pal_addr),
    .write      (pal_we),
    .read_data  (pal_read),
    .write_data (pal_write)
  );

  dac_regs dr (
    .clk (clk),

    .index (index),
    .red   (red),
    .green (green),
    .blue  (blue),

    .write (dac_we),

    .read_data_cycle    (dac_read_data_cycle),
    .read_data_register (dac_read_data_register),
    .read_data          (dac_read_data),

    .write_data_cycle    (dac_write_data_cycle),
    .write_data_register (dac_write_data_register),
    .write_data          (dac_write_data)
  );

  // Continuous assignments
  assign hor_scan_end = { horiz_total[6:2] + 1'b1, horiz_total[1:0], 3'h7 };
  assign hor_disp_end = { end_horiz, 3'h7 };
  assign ver_scan_end = vert_total + 10'd1;
  assign ver_disp_end = end_vert + 10'd1;
  assign ver_sync_beg = st_ver_retr;
  assign ver_sync_end = end_ver_retr + 4'd1;
  assign video_on     = video_on_h && video_on_v;

  assign attr  = graphics_alpha ? attr_wm : attr_tm;
  assign index = (graphics_alpha & shift_reg1) ? index_gm : index_pal;

  assign video_on_h    = video_on_h_p[1];

  assign csr_adr_o = graphics_alpha ?
    (shift_reg1 ? csr_gm_adr_o : csr_wm_adr_o) : { 1'b0, csr_tm_adr_o };

  assign csr_stb_o_tmp = graphics_alpha ?
    (shift_reg1 ? csr_gm_stb_o : csr_wm_stb_o) : csr_tm_stb_o;
  assign csr_stb_o     = csr_stb_o_tmp & (video_on_h_i | video_on_h) & video_on_v;

  assign v_retrace   = !video_on_v;
  assign vh_retrace  = v_retrace | !video_on_h;

  // index_gm
  always @(posedge clk)
    index_gm <= rst ? 8'h0 : ( ClockEnable25Mhz ) ? color : index_gm;

  // Sync generation & timing process
  
// Clock Enable to reduce from 100MHz to 25MHz
reg [1:0] h_subpixel;
always @ ( posedge clk )
    if (rst)
        h_subpixel <= 2'd0;
    else
      h_subpixel <= h_subpixel + 2'd1;
      
wire ClockEnable25Mhz;
assign ClockEnable25Mhz = !h_subpixel;

  // Generate horizontal and vertical timing signals for video signal
  always @(posedge clk)
    if (rst)
      begin
        h_count      <= 10'b0;
        horiz_sync_i <= 1'b1;
        v_count      <= 10'b0;
        vert_sync    <= 1'b1;
        video_on_h_i <= 1'b1;
        video_on_v   <= 1'b1;
      end
    else if ( h_subpixel[1] & h_subpixel[0] )
      begin
        h_count      <= (h_count==hor_scan_end) ? 10'b0 : h_count + 10'b1;
        horiz_sync_i <= horiz_sync_i ? (h_count[9:3]!=st_hor_retr)
                                     : (h_count[7:3]==end_hor_retr);
        v_count      <= (v_count==ver_scan_end && h_count==hor_scan_end) ? 10'b0
                      : ((h_count==hor_scan_end) ? v_count + 10'b1 : v_count);
        vert_sync    <= vert_sync ? (v_count!=ver_sync_beg)
                                  : (v_count[3:0]==ver_sync_end);

        video_on_h_i <= (h_count==hor_scan_end) ? 1'b1
                      : ((h_count==hor_disp_end) ? 1'b0 : video_on_h_i);
        video_on_v   <= (v_count==10'h0) ? 1'b1
                      : ((v_count==ver_disp_end) ? 1'b0 : video_on_v);
      end

  // Horiz sync
  always @(posedge clk)
    if ( rst ) 
      begin
        { horiz_sync, horiz_sync_p } <= 3'b0;
      end
    else //if ( ClockEnable25Mhz )
      begin
        { horiz_sync, horiz_sync_p } <= { horiz_sync_p[1:0], graphics_alpha ? (shift_reg1 ? horiz_sync_gm : horiz_sync_wm) : horiz_sync_tm };
      end

  // Video_on pipe
  always @(posedge clk)
    if ( rst )
      begin
        video_on_h_p <= 2'b0;
      end
    else //if ( ClockEnable25Mhz ) 
      begin 
        video_on_h_p <= { video_on_h_p[0], graphics_alpha ? (shift_reg1 ? video_on_h_gm : video_on_h_wm) : video_on_h_tm };
      end
                     
  // Colour signals
  always @(posedge clk)
    if (rst)
      begin
        vga_red_o     <= 4'b0;
        vga_green_o   <= 4'b0;
        vga_blue_o    <= 4'b0;
      end
    else
      begin
        vga_blue_o  <= video_on ? blue[5:2] : 4'h0;
        vga_green_o <= video_on ? green[5:2] : 4'h0;
        vga_red_o   <= video_on ? red[5:2] : 4'h0;
      end

endmodule
