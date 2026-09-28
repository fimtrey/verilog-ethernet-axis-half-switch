
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

module mac_splitter #(
  parameter  integer DATA_WIDTH = 64,
  parameter  integer PORTS      = 2,
  localparam integer KEEP_WIDTH = (DATA_WIDTH / 8)
) (
  input wire clk,
  input wire rst,

  // axi stream input
  input  wire [DATA_WIDTH-1:0] s_axis_tdata,
  input  wire [KEEP_WIDTH-1:0] s_axis_tkeep,
  input  wire                  s_axis_tvalid,
  output wire                  s_axis_tready,
  input  wire                  s_axis_tlast,
  input  wire                  s_axis_tuser,

  // axi stream outputs
  output wire [PORTS-1:0][DATA_WIDTH-1:0] m_axis_tdata,
  output wire [PORTS-1:0][KEEP_WIDTH-1:0] m_axis_tkeep,
  output wire            [     PORTS-1:0] m_axis_tvalid,
  input  wire            [     PORTS-1:0] m_axis_tready,
  output wire            [     PORTS-1:0] m_axis_tlast,
  output wire            [     PORTS-1:0] m_axis_tuser,

  input wire [PORTS-1:0][47:0] mac_address
);
  // axis register
  logic axis_tvalid_q, axis_tvalid_d;
  logic axis_tlast_q, axis_tlast_d;
  logic [DATA_WIDTH-1:0] axis_tdata_q, axis_tdata_d;
  logic [KEEP_WIDTH-1:0] axis_tkeep_q, axis_tkeep_d;
  logic axis_tuser_q, axis_tuser_d;

  // state
  logic [PORTS-1:0] connected_q, connected_d;
  logic [PORTS-1:0] failed_q, failed_d;
  logic frame_q, frame_d;

  // little endian to big endian
  wire [47:0] dest_mac = {
    s_axis_tdata[7:0],
    s_axis_tdata[15:8],
    s_axis_tdata[23:16],
    s_axis_tdata[31:24],
    s_axis_tdata[39:32],
    s_axis_tdata[47:40]
  };

  generate
    for (genvar i = 0; i < PORTS; i = i + 1) begin : gen_axis_outputs
      assign m_axis_tdata[i]  = axis_tdata_q;
      assign m_axis_tkeep[i]  = axis_tkeep_q;
      assign m_axis_tvalid[i] = (axis_tvalid_q && connected_q[i]) || failed_q[i];
      // signal "bad frame" with tuser = 1 tlast = 1
      assign m_axis_tlast[i]  = axis_tlast_q || failed_q[i];
      assign m_axis_tuser[i]  = axis_tuser_q || failed_q[i];
    end
  endgenerate

  // ready if
  //   - not valid
  //   - ready from at least one port
  //   - not sending to any port (dropping)
  assign s_axis_tready = (!axis_tvalid_q) || (|(m_axis_tready & connected_q)) || (!(|connected_q));


  always_comb begin
    axis_tdata_d  = axis_tdata_q;
    axis_tkeep_d  = axis_tkeep_q;
    axis_tlast_d  = axis_tlast_q;
    axis_tuser_d  = axis_tuser_q;
    axis_tvalid_d = axis_tvalid_q;

    connected_d   = connected_q;
    failed_d      = failed_q;
    frame_d       = frame_q;

    // reset failed flag when port is ready
    for (int i = 0; i < PORTS; i = i + 1) begin
      if (m_axis_tready[i] == 1'b1) begin
        failed_d[i] = 1'b0;
      end
    end

    if (s_axis_tready) begin
      if (s_axis_tvalid) begin
        axis_tdata_d  = s_axis_tdata;
        axis_tkeep_d  = s_axis_tkeep;
        axis_tlast_d  = s_axis_tlast;
        axis_tuser_d  = s_axis_tuser;
        axis_tvalid_d = 1'b1;

        if (frame_q == 1'b0) begin
          connected_d = {PORTS{1'b1}};  // Broadcast

          for (int i = 0; i < PORTS; i = i + 1) begin
            if (dest_mac == mac_address[i]) begin
              // set all other to 0 except the one that matches
              connected_d = (1 << i);
            end
          end

          frame_d = 1'b1;
        end

        if (axis_tvalid_q == 1'b1) begin
          for (int i = 0; i < PORTS; i = i + 1) begin
            if (connected_q[i] == 1'b1 && m_axis_tready[i] == 1'b0) begin
              // Broadcast case but port to slow
              // if port was not ready but we updated, set failed flag
              failed_d[i]    = 1'b1;
              connected_d[i] = 1'b0;
            end
          end
        end

        if (s_axis_tlast == 1'b1) begin
          frame_d = 1'b0;
        end
      end else begin
        axis_tvalid_d = 1'b0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      axis_tdata_q  <= 0;
      axis_tkeep_q  <= 0;
      axis_tlast_q  <= 0;
      axis_tuser_q  <= 0;
      axis_tvalid_q <= 0;

      connected_q   <= 0;
      failed_q      <= 0;
      frame_q       <= 0;
    end else begin
      axis_tdata_q  <= axis_tdata_d;
      axis_tkeep_q  <= axis_tkeep_d;
      axis_tlast_q  <= axis_tlast_d;
      axis_tuser_q  <= axis_tuser_d;
      axis_tvalid_q <= axis_tvalid_d;

      connected_q   <= connected_d;
      failed_q      <= failed_d;
      frame_q       <= frame_d;
    end
  end

endmodule
