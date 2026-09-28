
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

module mac_read_address #(
  parameter  integer DATA_WIDTH = 64,
  localparam integer KEEP_WIDTH = (DATA_WIDTH / 8)
) (
  input wire clk,
  input wire rst,

  input wire [DATA_WIDTH-1:0] s_axis_tdata,
  input wire [KEEP_WIDTH-1:0] s_axis_tkeep,
  input wire                  s_axis_tvalid,
  input wire                  s_axis_tready,
  input wire                  s_axis_tlast,
  input wire                  s_axis_tuser,

  output wire [47:0] mac_address
);


  logic [1:0] cnt_q, cnt_d;
  logic [47:0] mac_address_int_q, mac_address_int_d;

  logic [47:0] mac_address_out_q, mac_address_out_d;

  assign mac_address = mac_address_out_q;

  always_comb begin
    mac_address_out_d = mac_address_out_q;
    mac_address_int_d = mac_address_int_q;
    cnt_d             = cnt_q;

    if (s_axis_tvalid && s_axis_tready) begin
      if (cnt_q == 2'd0) begin
        mac_address_int_d[47:40] = s_axis_tdata[55:48];
        mac_address_int_d[39:32] = s_axis_tdata[63:56];
        cnt_d                    = cnt_q + 1;
      end else if (cnt_q == 2'd1) begin
        mac_address_int_d[31:24] = s_axis_tdata[7:0];
        mac_address_int_d[23:16] = s_axis_tdata[15:8];
        mac_address_int_d[15:8]  = s_axis_tdata[23:16];
        mac_address_int_d[7:0]   = s_axis_tdata[31:24];
        cnt_d                    = cnt_q + 1;
      end else if (cnt_q == 2'd2) begin
        mac_address_out_d = mac_address_int_q;
        cnt_d             = cnt_q + 1;
      end

      if (s_axis_tlast) begin
        cnt_d = 2'd0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      cnt_q             <= 2'd0;
      mac_address_int_q <= 48'd0;
      mac_address_out_q <= 48'd0;
    end else begin
      cnt_q             <= cnt_d;
      mac_address_int_q <= mac_address_int_d;
      mac_address_out_q <= mac_address_out_d;
    end
  end
endmodule
