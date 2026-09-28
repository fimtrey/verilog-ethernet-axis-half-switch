
// Copyright 2026 Tim Frey
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// Tim Frey
//------------------------------------------------------------------------------

// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * MAC switch 2 port (wrapper)
 */
module mac_half_switch_wrap_2 #(
  parameter integer DATA_WIDTH  = 64,
  parameter integer FIFO_DEPTH  = 4096,
  parameter integer FIFO_ENABLE = (1 > 0),
  parameter integer KEEP_WIDTH  = (DATA_WIDTH / 8),
  parameter integer USER_WIDTH  = 1
) (
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET rst, ASSOCIATED_BUSIF m_axis_tx:s_axis_rx:s00_axis_tx:m00_axis_rx:s01_axis_tx:m01_axis_rx" *)
  input wire clk,
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst RST" *)
  (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
  input wire rst,

  /*
     * TX inputs
     */
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s00_axis_tx TVALID" *)
  input wire s00_axis_tx_tvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s00_axis_tx TREADY" *)
  output wire s00_axis_tx_tready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s00_axis_tx TDATA" *)
  input wire [DATA_WIDTH-1:0] s00_axis_tx_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s00_axis_tx TKEEP" *)
  input wire [KEEP_WIDTH-1:0] s00_axis_tx_tkeep,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s00_axis_tx TLAST" *)
  input wire s00_axis_tx_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s00_axis_tx TUSER" *)
  input wire [USER_WIDTH-1:0] s00_axis_tx_tuser,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s01_axis_tx TVALID" *)
  input wire s01_axis_tx_tvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s01_axis_tx TREADY" *)
  output wire s01_axis_tx_tready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s01_axis_tx TDATA" *)
  input wire [DATA_WIDTH-1:0] s01_axis_tx_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s01_axis_tx TKEEP" *)
  input wire [KEEP_WIDTH-1:0] s01_axis_tx_tkeep,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s01_axis_tx TLAST" *)
  input wire s01_axis_tx_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s01_axis_tx TUSER" *)
  input wire [USER_WIDTH-1:0] s01_axis_tx_tuser,


  /*
     * AXIS TX output
     */
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_tx TDATA" *)
  output wire [DATA_WIDTH-1:0] m_axis_tx_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_tx TKEEP" *)
  output wire [KEEP_WIDTH-1:0] m_axis_tx_tkeep,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_tx TVALID" *)
  output wire m_axis_tx_tvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_tx TREADY" *)
  input wire m_axis_tx_tready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_tx TLAST" *)
  output wire m_axis_tx_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_tx TUSER" *)
  output wire [USER_WIDTH-1:0] m_axis_tx_tuser,

  /*
    * AXIS RX outputs
    */
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m00_axis_rx TDATA" *)
  output wire [DATA_WIDTH-1:0] m00_axis_rx_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m00_axis_rx TKEEP" *)
  output wire [KEEP_WIDTH-1:0] m00_axis_rx_tkeep,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m00_axis_rx TVALID" *)
  output wire m00_axis_rx_tvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m00_axis_rx TREADY" *)
  input wire m00_axis_rx_tready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m00_axis_rx TLAST" *)
  output wire m00_axis_rx_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m00_axis_rx TUSER" *)
  output wire [USER_WIDTH-1:0] m00_axis_rx_tuser,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m01_axis_rx TDATA" *)
  output wire [DATA_WIDTH-1:0] m01_axis_rx_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m01_axis_rx TKEEP" *)
  output wire [KEEP_WIDTH-1:0] m01_axis_rx_tkeep,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m01_axis_rx TVALID" *)
  output wire m01_axis_rx_tvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m01_axis_rx TREADY" *)
  input wire m01_axis_rx_tready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m01_axis_rx TLAST" *)
  output wire m01_axis_rx_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m01_axis_rx TUSER" *)
  output wire [USER_WIDTH-1:0] m01_axis_rx_tuser,


  /*
     * AXIS RX input
     */
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_rx TDATA" *)
  input wire [DATA_WIDTH-1:0] s_axis_rx_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_rx TKEEP" *)
  input wire [KEEP_WIDTH-1:0] s_axis_rx_tkeep,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_rx TVALID" *)
  input wire s_axis_rx_tvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_rx TREADY" *)
  output wire s_axis_rx_tready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_rx TLAST" *)
  input wire s_axis_rx_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_rx TUSER" *)
  input wire [USER_WIDTH-1:0] s_axis_rx_tuser

);

  mac_half_switch #(
    .PORTS      (2),
    .DATA_WIDTH (DATA_WIDTH),
    .FIFO_DEPTH (FIFO_DEPTH),
    .FIFO_ENABLE(FIFO_ENABLE)
  ) mac_switch_inst (
    .clk(clk),
    .rst(rst),

    // AXIS TX inputs
    .s_axis_tx_tdata ({s01_axis_tx_tdata, s00_axis_tx_tdata}),
    .s_axis_tx_tkeep ({s01_axis_tx_tkeep, s00_axis_tx_tkeep}),
    .s_axis_tx_tvalid({s01_axis_tx_tvalid, s00_axis_tx_tvalid}),
    .s_axis_tx_tready({s01_axis_tx_tready, s00_axis_tx_tready}),
    .s_axis_tx_tlast ({s01_axis_tx_tlast, s00_axis_tx_tlast}),
    .s_axis_tx_tuser ({s01_axis_tx_tuser, s00_axis_tx_tuser}),

    // UDP TX output
    .m_axis_tx_tdata (m_axis_tx_tdata),
    .m_axis_tx_tkeep (m_axis_tx_tkeep),
    .m_axis_tx_tvalid(m_axis_tx_tvalid),
    .m_axis_tx_tready(m_axis_tx_tready),
    .m_axis_tx_tlast (m_axis_tx_tlast),
    .m_axis_tx_tuser (m_axis_tx_tuser),

    // AXIS RX outputs
    .m_axis_rx_tdata ({m01_axis_rx_tdata, m00_axis_rx_tdata}),
    .m_axis_rx_tkeep ({m01_axis_rx_tkeep, m00_axis_rx_tkeep}),
    .m_axis_rx_tvalid({m01_axis_rx_tvalid, m00_axis_rx_tvalid}),
    .m_axis_rx_tready({m01_axis_rx_tready, m00_axis_rx_tready}),
    .m_axis_rx_tlast ({m01_axis_rx_tlast, m00_axis_rx_tlast}),
    .m_axis_rx_tuser ({m01_axis_rx_tuser, m00_axis_rx_tuser}),

    // AXIS RX input
    .s_axis_rx_tdata (s_axis_rx_tdata),
    .s_axis_rx_tkeep (s_axis_rx_tkeep),
    .s_axis_rx_tvalid(s_axis_rx_tvalid),
    .s_axis_rx_tready(s_axis_rx_tready),
    .s_axis_rx_tlast (s_axis_rx_tlast),
    .s_axis_rx_tuser (s_axis_rx_tuser)
  );

endmodule
