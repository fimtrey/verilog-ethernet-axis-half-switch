
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

module mac_arb #(
  parameter  integer PORTS                 = 2,
  parameter  integer DATA_WIDTH            = 64,
  localparam integer KEEP_WIDTH            = (DATA_WIDTH / 8),
  parameter  integer ARB_TYPE_ROUND_ROBIN  = 1,
  parameter  integer ARB_LSB_HIGH_PRIORITY = 0
) (
  input wire clk,
  input wire rst,

  input  wire [PORTS-1:0][DATA_WIDTH-1:0] s_axis_tdata,
  input  wire [PORTS-1:0][KEEP_WIDTH-1:0] s_axis_tkeep,
  input  wire            [     PORTS-1:0] s_axis_tvalid,
  output wire            [     PORTS-1:0] s_axis_tready,
  input  wire            [     PORTS-1:0] s_axis_tlast,
  input  wire            [     PORTS-1:0] s_axis_tuser,

  output wire [DATA_WIDTH-1:0] m_axis_tdata,
  output wire [KEEP_WIDTH-1:0] m_axis_tkeep,
  output wire                  m_axis_tvalid,
  input  wire                  m_axis_tready,
  output wire                  m_axis_tlast,
  output wire                  m_axis_tuser
);

  parameter CL_PORTS = $clog2(PORTS);


  wire [   PORTS-1:0] request;
  wire [   PORTS-1:0] acknowledge;
  wire [   PORTS-1:0] grant;
  wire                grant_valid;
  wire [CL_PORTS-1:0] grant_encoded;

  // arbiter instance
  arbiter #(
    .PORTS                (PORTS),
    .ARB_TYPE_ROUND_ROBIN (ARB_TYPE_ROUND_ROBIN),
    .ARB_BLOCK            (1),
    .ARB_BLOCK_ACK        (1),
    .ARB_LSB_HIGH_PRIORITY(ARB_LSB_HIGH_PRIORITY)
  ) arb_inst (
    .clk          (clk),
    .rst          (rst),
    .request      (request),
    .acknowledge  (acknowledge),
    .grant        (grant),
    .grant_valid  (grant_valid),
    .grant_encoded(grant_encoded)
  );

  assign request = s_axis_tvalid & ~grant;
  assign acknowledge = grant & s_axis_tvalid & s_axis_tready &
      s_axis_tlast;  // Wait for last before new decsion

  assign s_axis_tready = (m_axis_tready && grant_valid) << grant_encoded;

  assign m_axis_tdata = s_axis_tdata[grant_encoded];
  assign m_axis_tkeep = s_axis_tkeep[grant_encoded];
  assign m_axis_tvalid = s_axis_tvalid[grant_encoded] && grant_valid;
  assign m_axis_tlast = s_axis_tlast[grant_encoded];
  assign m_axis_tuser = s_axis_tuser[grant_encoded];

endmodule
