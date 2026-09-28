
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

module mac_half_switch #(
  parameter  integer DATA_WIDTH  = 64,
  parameter  integer PORTS       = 2,
  parameter  integer FIFO_DEPTH  = 4096,
  parameter          FIFO_ENABLE = (1 > 0),
  localparam integer KEEP_WIDTH  = (DATA_WIDTH / 8)
) (
  input wire clk,
  input wire rst,

  // axi stream inputs tx
  input  wire [PORTS-1:0][DATA_WIDTH-1:0] s_axis_tx_tdata,
  input  wire [PORTS-1:0][KEEP_WIDTH-1:0] s_axis_tx_tkeep,
  input  wire            [     PORTS-1:0] s_axis_tx_tvalid,
  output wire            [     PORTS-1:0] s_axis_tx_tready,
  input  wire            [     PORTS-1:0] s_axis_tx_tlast,
  input  wire            [     PORTS-1:0] s_axis_tx_tuser,

  // axi stream outputs rx
  output wire [PORTS-1:0][DATA_WIDTH-1:0] m_axis_rx_tdata,
  output wire [PORTS-1:0][KEEP_WIDTH-1:0] m_axis_rx_tkeep,
  output wire            [     PORTS-1:0] m_axis_rx_tvalid,
  input  wire            [     PORTS-1:0] m_axis_rx_tready,
  output wire            [     PORTS-1:0] m_axis_rx_tlast,
  output wire            [     PORTS-1:0] m_axis_rx_tuser,

  // axi stream output tx
  output wire [DATA_WIDTH-1:0] m_axis_tx_tdata,
  output wire [KEEP_WIDTH-1:0] m_axis_tx_tkeep,
  output wire                  m_axis_tx_tvalid,
  input  wire                  m_axis_tx_tready,
  output wire                  m_axis_tx_tlast,
  output wire                  m_axis_tx_tuser,

  // axi stream input rx
  input  wire [DATA_WIDTH-1:0] s_axis_rx_tdata,
  input  wire [KEEP_WIDTH-1:0] s_axis_rx_tkeep,
  input  wire                  s_axis_rx_tvalid,
  output wire                  s_axis_rx_tready,
  input  wire                  s_axis_rx_tlast,
  input  wire                  s_axis_rx_tuser
);

  logic [     PORTS-1:0][          47:0] mac_address;


  // axi stream outputs
  logic [     PORTS-1:0][DATA_WIDTH-1:0] m_axis_rx_tdata_fifo;
  logic [     PORTS-1:0][KEEP_WIDTH-1:0] m_axis_rx_tkeep_fifo;
  logic [     PORTS-1:0]                 m_axis_rx_tvalid_fifo;
  logic [     PORTS-1:0]                 m_axis_rx_tready_fifo;
  logic [     PORTS-1:0]                 m_axis_rx_tlast_fifo;
  logic [     PORTS-1:0]                 m_axis_rx_tuser_fifo;

  logic [DATA_WIDTH-1:0]                 m_axis_tx_tdata_fifo;
  logic [KEEP_WIDTH-1:0]                 m_axis_tx_tkeep_fifo;
  logic                                  m_axis_tx_tvalid_fifo;
  logic                                  m_axis_tx_tready_fifo;
  logic                                  m_axis_tx_tlast_fifo;
  logic                                  m_axis_tx_tuser_fifo;


  mac_splitter #(
    .DATA_WIDTH(DATA_WIDTH),
    .PORTS     (PORTS)
  ) mac_splitter_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata (s_axis_rx_tdata),
    .s_axis_tkeep (s_axis_rx_tkeep),
    .s_axis_tvalid(s_axis_rx_tvalid),
    .s_axis_tready(s_axis_rx_tready),
    .s_axis_tlast (s_axis_rx_tlast),
    .s_axis_tuser (s_axis_rx_tuser),

    .m_axis_tdata (m_axis_rx_tdata_fifo),
    .m_axis_tkeep (m_axis_rx_tkeep_fifo),
    .m_axis_tvalid(m_axis_rx_tvalid_fifo),
    .m_axis_tready(m_axis_rx_tready_fifo),
    .m_axis_tlast (m_axis_rx_tlast_fifo),
    .m_axis_tuser (m_axis_rx_tuser_fifo),

    .mac_address(mac_address)
  );

  // gen read address for each port
  generate
    for (genvar i = 0; i < PORTS; i = i + 1) begin : gen_read_address
      mac_read_address #(
        .DATA_WIDTH(DATA_WIDTH)
      ) mac_read_address_inst (
        .clk(clk),
        .rst(rst),

        .s_axis_tdata (s_axis_tx_tdata[i]),
        .s_axis_tkeep (s_axis_tx_tkeep[i]),
        .s_axis_tvalid(s_axis_tx_tvalid[i]),
        .s_axis_tready(s_axis_tx_tready[i]),
        .s_axis_tlast (s_axis_tx_tlast[i]),
        .s_axis_tuser (s_axis_tx_tuser[i]),

        .mac_address(mac_address[i])
      );

      if (FIFO_ENABLE > 0) begin : gen_fifo

        // fifo for rx
        axis_fifo #(
          .DEPTH               (FIFO_DEPTH),
          .DATA_WIDTH          (DATA_WIDTH),
          .KEEP_WIDTH          (KEEP_WIDTH),
          .LAST_ENABLE         (1),
          .FRAME_FIFO          (1),
          .USER_BAD_FRAME_VALUE(1),
          .DROP_BAD_FRAME      (1),
          .DROP_WHEN_FULL      (1)
        ) axis_fifo_inst (
          .clk(clk),
          .rst(rst),

          .s_axis_tdata (m_axis_rx_tdata_fifo[i]),
          .s_axis_tkeep (m_axis_rx_tkeep_fifo[i]),
          .s_axis_tvalid(m_axis_rx_tvalid_fifo[i]),
          .s_axis_tready(m_axis_rx_tready_fifo[i]),
          .s_axis_tlast (m_axis_rx_tlast_fifo[i]),
          .s_axis_tuser (m_axis_rx_tuser_fifo[i]),

          .m_axis_tdata (m_axis_rx_tdata[i]),
          .m_axis_tkeep (m_axis_rx_tkeep[i]),
          .m_axis_tvalid(m_axis_rx_tvalid[i]),
          .m_axis_tready(m_axis_rx_tready[i]),
          .m_axis_tlast (m_axis_rx_tlast[i]),
          .m_axis_tuser (m_axis_rx_tuser[i])
        );
      end else begin : gen_no_fifo
        assign m_axis_rx_tdata[i]       = m_axis_rx_tdata_fifo[i];
        assign m_axis_rx_tkeep[i]       = m_axis_rx_tkeep_fifo[i];
        assign m_axis_rx_tvalid[i]      = m_axis_rx_tvalid_fifo[i];
        assign m_axis_rx_tlast[i]       = m_axis_rx_tlast_fifo[i];
        assign m_axis_rx_tuser[i]       = m_axis_rx_tuser_fifo[i];

        assign m_axis_rx_tready_fifo[i] = m_axis_rx_tready[i];
      end
    end
  endgenerate

  mac_arb #(
    .DATA_WIDTH(DATA_WIDTH),
    .PORTS     (PORTS)
  ) mac_arb_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata (s_axis_tx_tdata),
    .s_axis_tkeep (s_axis_tx_tkeep),
    .s_axis_tvalid(s_axis_tx_tvalid),
    .s_axis_tready(s_axis_tx_tready),
    .s_axis_tlast (s_axis_tx_tlast),
    .s_axis_tuser (s_axis_tx_tuser),

    .m_axis_tdata (m_axis_tx_tdata_fifo),
    .m_axis_tkeep (m_axis_tx_tkeep_fifo),
    .m_axis_tvalid(m_axis_tx_tvalid_fifo),
    .m_axis_tready(m_axis_tx_tready_fifo),
    .m_axis_tlast (m_axis_tx_tlast_fifo),
    .m_axis_tuser (m_axis_tx_tuser_fifo)
  );

  //generate if
  if (FIFO_ENABLE > 0) begin : gen_fifo
    // fifo for tx
    axis_fifo #(
      .DEPTH               (FIFO_DEPTH),
      .DATA_WIDTH          (DATA_WIDTH),
      .KEEP_WIDTH          (KEEP_WIDTH),
      .LAST_ENABLE         (1),
      .FRAME_FIFO          (1),
      .USER_BAD_FRAME_VALUE(1),
      .DROP_BAD_FRAME      (1),
      .DROP_WHEN_FULL      (1)
    ) axis_fifo_inst (
      .clk(clk),
      .rst(rst),

      .s_axis_tdata (m_axis_tx_tdata_fifo),
      .s_axis_tkeep (m_axis_tx_tkeep_fifo),
      .s_axis_tvalid(m_axis_tx_tvalid_fifo),
      .s_axis_tready(m_axis_tx_tready_fifo),
      .s_axis_tlast (m_axis_tx_tlast_fifo),
      .s_axis_tuser (m_axis_tx_tuser_fifo),

      .m_axis_tdata (m_axis_tx_tdata),
      .m_axis_tkeep (m_axis_tx_tkeep),
      .m_axis_tvalid(m_axis_tx_tvalid),
      .m_axis_tready(m_axis_tx_tready),
      .m_axis_tlast (m_axis_tx_tlast),
      .m_axis_tuser (m_axis_tx_tuser)
    );
  end else begin : gen_no_fifo
    assign m_axis_tx_tdata       = m_axis_tx_tdata_fifo;
    assign m_axis_tx_tkeep       = m_axis_tx_tkeep_fifo;
    assign m_axis_tx_tvalid      = m_axis_tx_tvalid_fifo;
    assign m_axis_tx_tlast       = m_axis_tx_tlast_fifo;
    assign m_axis_tx_tuser       = m_axis_tx_tuser_fifo;

    assign m_axis_tx_tready_fifo = m_axis_tx_tready;
  end

endmodule
