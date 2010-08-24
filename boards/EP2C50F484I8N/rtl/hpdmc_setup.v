/*
 * Milkymist VJ SoC
 * Copyright (C) 2007, 2008, 2009 Sebastien Bourdeauducq
 * adjusted to FML 8x16 by Zeus Gomez Marmolejo <zeus@aluzina.org>
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

module hpdmc_setup
(
    input sys_rst,

    input sys_clk,

    output reg bypass,
    output reg sdram_rst,

    output reg sdram_initialized,

    output reg        sdram_cke,
    output reg        sdram_cs_n,
    output reg        sdram_we_n,
    output reg        sdram_dqm,
    output reg        sdram_cas_n,
    output reg        sdram_ras_n,
    output reg [12:0] sdram_adr,
    output reg [ 1:0] sdram_ba,

    /* Clocks we must wait following a PRECHARGE command (usually tRP). */
    output  [2:0] tim_rp,
    /* Clocks we must wait following an ACTIVATE command (usually tRCD). */
    output  [2:0] tim_rcd,
    /* CAS latency, 0 = 2 */
    output  tim_cas,
    /* Auto-refresh period (usually tREFI). */
    output  [10:0] tim_refi,
    /* Clocks we must wait following an AUTO REFRESH command (usually tRFC). */
    output  [3:0] tim_rfc,
    /* Clocks we must wait following the last word written to the SDRAM (usually tWR). */
    output  [1:0] tim_wr
);

assign        tim_rp      = 3'd2;      // > 20nSec
assign        tim_rcd     = 3'd2;      // > 20nSec
assign        tim_cas     = 1'b0;      // CL=2
assign        tim_refi    = 11'd740;   //
assign        tim_rfc     = 4'd8;      // > 66nSec
assign        tim_wr      = 2'd2;      // > 15nSec or 1CLK + 7.5nSec

/*
 * Various timing counters.
 * Check that the delays are appropriate for the particular SDRAM chip
 * you're using.
 */

/* The number of clocks before we can use the SDRAM after power-up */
/* This should be 100us */
reg [13:0] init_counter;
reg reload_init_counter;
wire init_done = (init_counter == 14'b0);
always @(posedge sys_clk) begin
    if(reload_init_counter)
        init_counter <= 14'd12500;
    else if(~init_done)
        init_counter <= init_counter - 4'b1;
end

/* The number of clocks we must wait following a PRECHARGE ALL command */
reg [2:0] prechargeall_counter;
reg reload_prechargeall_counter;
wire prechargeall_done = (prechargeall_counter == 3'b0);
always @(posedge sys_clk) begin
    if(reload_prechargeall_counter)
        prechargeall_counter <= 3'd4;
    else if(~prechargeall_done)
        prechargeall_counter <= prechargeall_counter - 3'b1;
end

/* The number of clocks we must wait following an AUTO REFRESH command */
reg [3:0] autorefresh_counter;
reg reload_autorefresh_counter;
wire autorefresh_done = (autorefresh_counter == 4'b0);
always @(posedge sys_clk) begin
    if(reload_autorefresh_counter)
        autorefresh_counter <= 4'd9;
    else if(~autorefresh_done)
        autorefresh_counter <= autorefresh_counter - 4'b1;
end

localparam
    RESET = 5'd0,

    INIT_PRECHARGEALL = 5'd1,
    INIT_AUTOREFRESH1 = 5'd2,
    INIT_AUTOREFRESH2 = 5'd3,
    INIT_LOADMODE = 5'd4,

    IDLE = 5'd5;

always @(posedge sys_clk)
  if(sys_rst)
    sdram_initialized <= 1'b0;
  else
    sdram_initialized <= !bypass;

reg [4:0] state;
reg [4:0] next_state;

always @(posedge sys_clk) begin
    if(sys_rst) begin
        state <= RESET;
    end else begin
    // synthesis translate_off
        if(state != next_state) $display("state:%d->%d", state, next_state);
    // synthesis translate_on
        state <= next_state;
    end
end

always @(sys_rst or state or init_done or prechargeall_done or autorefresh_done )
    if(sys_rst) begin
        bypass      = 1'b1;
        sdram_rst   = 1'b1;

        sdram_cke   = 1'b0; // this is like the COMMAND INHIBIT (NOP) due to cs# = 1
        sdram_cs_n  = 1'b1;
        sdram_ras_n = 1'b1;
        sdram_cas_n = 1'b1;
        sdram_we_n  = 1'b1;
        sdram_dqm   = 1'b0;
        sdram_adr   = 13'd0;
        sdram_ba    = 2'b00;

        next_state  = RESET;
    end else begin

    next_state = state;
    
    sdram_rst   = 1'b0;
    
    sdram_cke   = 1'b1;
    sdram_cs_n  = 1'b1;
    sdram_ras_n = 1'b1;
    sdram_cas_n = 1'b1;
    sdram_we_n  = 1'b1;
    sdram_adr   = 13'd0;
    sdram_dqm   = 1'b0;
    sdram_ba    = 2'b00;

    reload_init_counter         = 1'b0;
    reload_prechargeall_counter = 1'b0;
    reload_autorefresh_counter  = 1'b0;

    case(state)
        default: begin // 0
            bypass = 1'b1;
            reload_init_counter = 1'b1;
            next_state = INIT_PRECHARGEALL;
        end
        /* Initialization */
        INIT_PRECHARGEALL: begin // 1
            bypass      = 1'b1;
            if(init_done) begin
                /* Issue a PRECHARGE ALL command to the SDRAM array */
                sdram_cs_n  = 1'b0;
                sdram_ras_n = 1'b0;
                sdram_cas_n = 1'b1;
                sdram_we_n  = 1'b0;
                sdram_adr   = 13'd1024;

                reload_prechargeall_counter = 1'b1;
                next_state = INIT_AUTOREFRESH1;
            end
        end
        INIT_AUTOREFRESH1: begin // 2
            bypass      = 1'b1;
            if(prechargeall_done) begin
                /* Issue a first AUTO REFRESH command to the SDRAM array */
                sdram_cs_n  = 1'b0;
                sdram_ras_n = 1'b0;
                sdram_cas_n = 1'b0;
                sdram_we_n  = 1'b1;
                sdram_adr   = 13'd0;

                reload_autorefresh_counter = 1'b1;
                next_state = INIT_AUTOREFRESH2;
            end
        end
        INIT_AUTOREFRESH2: begin // 3
            bypass      = 1'b1;
            if(autorefresh_done) begin
                /* Issue a second AUTO REFRESH command to the SDRAM array */
                sdram_cs_n  = 1'b0;
                sdram_ras_n = 1'b0;
                sdram_cas_n = 1'b0;
                sdram_we_n  = 1'b1;
                sdram_adr   = 13'd0;

                reload_autorefresh_counter = 1'b1;
                next_state = INIT_LOADMODE;
            end
        end
        INIT_LOADMODE: begin // 4
            /* Load the Mode Register */
            bypass      = 1'b1;
            if(autorefresh_done) begin
                sdram_cs_n  = 1'b0;
                sdram_ras_n = 1'b0;
                sdram_cas_n = 1'b0;
                sdram_we_n  = 1'b0;
                /*
                 * Mode register encoding :
                 * See p. 18 of the Micron datasheet.
                 * A12..A10 reserved, should be 000
                 * A9       burst access, 0 = burst enabled
                 * A8 ..A7  reserved, should be 00
                 * A6 ..A4  CAS latency, 10 = CL2
                 * A3       burst type, 0 = sequential
                 * A2 ..A0  burst length, 011 = 8
                 */
                sdram_adr   = 13'b000_0_00_010_0_011;
                
                next_state = IDLE;
            end
        end
        
        IDLE: begin // 5
                bypass      = 1'b0;
                sdram_cs_n  = 1'b0;
                sdram_ras_n = 1'b1;
                sdram_cas_n = 1'b1;
                sdram_we_n  = 1'b1;
                sdram_adr   = 13'd0;
              end
    endcase
  end
endmodule