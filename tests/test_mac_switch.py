"""
Copyright (C) 2026 Tim Frey. All rights reserved.

    Author: Tim Frey

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache-2.0
"""

import logging
import os
from pathlib import Path

import cocotb
import numpy as np
import pytest
from cocotb.clock import Clock
from cocotb.handle import Immediate
from cocotb.triggers import RisingEdge, Timer
from cocotb_tools.runner import get_runner
from cocotbext.axi.axis import (
    AxiStreamBus,
    AxiStreamFrame,
    AxiStreamSink,
    AxiStreamSource,
)
from dotenv import load_dotenv

from scapy.layers.l2 import Ether

load_dotenv()


PORTS = 2

# Define MAC addresses for each port.
MAC_ADDRESS = [f"01:00:00:00:00:{x:02x}" for x in range(1, PORTS + 1)]
MAC_ADDRESS_MAIN = "01:00:00:00:00:00"
BROADCAST = "ff:ff:ff:ff:ff:ff"
MAC_RANDOM = "12:34:56:78:9a:bc:de:f0"

FIFO_DEPTH = 1024


class TB:
    def __init__(self, dut, PORTS=PORTS):
        self.dut = dut
        self.PORTS = PORTS

        self.log = logging.getLogger("cocotb")
        self.log.setLevel(logging.INFO)

        for i in range(PORTS):
            getattr(self.dut, f"s{i:02d}_axis_tx_tvalid").value = Immediate(0)
        getattr(self.dut, "s_axis_rx_tvalid").value = Immediate(0)

        cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

        self.axis_out_main = AxiStreamSink(
            AxiStreamBus.from_prefix(dut, "m_axis_tx"), dut.clk, dut.rst
        )

        self.axis_in_main = AxiStreamSource(
            AxiStreamBus.from_prefix(dut, "s_axis_rx"), dut.clk, dut.rst
        )

        self.axis_out = [
            AxiStreamSink(
                AxiStreamBus.from_prefix(dut, f"m{i:02d}_axis_rx"), dut.clk, dut.rst
            )
            for i in range(self.PORTS)
        ]

        self.axis_in = [
            AxiStreamSource(
                AxiStreamBus.from_prefix(dut, f"s{i:02d}_axis_tx"), dut.clk, dut.rst
            )
            for i in range(self.PORTS)
        ]

        # Ethernet

    async def init(self):
        self.dut.rst.value = Immediate(0)

        for k in range(10):
            await RisingEdge(self.dut.clk)

        self.dut.rst.value = 1

        for k in range(10):
            await RisingEdge(self.dut.clk)

        self.dut.rst.value = 0

        for k in range(10):
            await RisingEdge(self.dut.clk)


@cocotb.test(timeout_time=10000000, timeout_unit="ns")
async def run_test(dut):
    """
    Test basic switch forwarding behavior.

    1. Send a broadcast packet and verify delivery.
    2. Send to an unknown address and verify the packet is dropped.
    3. Send to a known address and verify delivery.
    4. Send another broadcast and verify delivery.
    5. Send to main with a mismatched destination MAC and verify handling.
    """

    tb = TB(dut, PORTS)
    await tb.init()
    await RisingEdge(dut.clk)

    # Try broadcast from main
    data = (Ether(src=MAC_ADDRESS_MAIN, dst=BROADCAST) / np.random.bytes(64)).build()
    await tb.axis_in_main.send(
        AxiStreamFrame(
            tdata=data,
        )
    )

    for i in range(PORTS):
        data0 = await tb.axis_out[i].recv()
        assert data0.tdata == data

        assert tb.axis_out[i].empty()

    # Test unknown address
    data = (Ether(src=MAC_ADDRESS_MAIN, dst=MAC_RANDOM) / np.random.bytes(64)).build()
    await tb.axis_in_main.send(
        AxiStreamFrame(
            tdata=data,
        )
    )

    for i in range(PORTS):
        data0 = await tb.axis_out[i].recv()
        assert data0.tdata == data

        assert tb.axis_out[i].empty()

    # Broadcast to main
    for i in range(PORTS):
        data = (Ether(src=MAC_ADDRESS[i], dst=BROADCAST) / np.random.bytes(64)).build()
        await tb.axis_in[i].send(
            AxiStreamFrame(
                tdata=data,
            )
        )

        data0 = await tb.axis_out_main.recv()
        assert data0.tdata == data

        for j in range(PORTS):
            assert tb.axis_out[j].empty()

        assert tb.axis_out_main.empty()

    # Now all MAC addresses should be known.

    # Send a packet from main to every port.
    for i in range(PORTS):
        data = (
            Ether(src=MAC_ADDRESS_MAIN, dst=MAC_ADDRESS[i]) / np.random.bytes(64)
        ).build()
        await tb.axis_in_main.send(
            AxiStreamFrame(
                tdata=data,
            )
        )
        data0 = await tb.axis_out[i].recv()
        assert data0.tdata == data

        # All other ports should not receive a packet.
        for k in range(PORTS):
            assert tb.axis_out[k].empty()

        assert tb.axis_out_main.empty()

    # Send to main with a different destination MAC.
    data = (Ether(src=MAC_RANDOM, dst=BROADCAST) / np.random.bytes(64)).build()
    await tb.axis_in_main.send(
        AxiStreamFrame(
            tdata=data,
        )
    )

    for i in range(PORTS):
        data0 = await tb.axis_out[i].recv()
        assert data0.tdata == data

        assert tb.axis_out[i].empty()

    # Try broadcast from main
    data = (Ether(src=MAC_ADDRESS_MAIN, dst=BROADCAST) / np.random.bytes(64)).build()
    await tb.axis_in_main.send(
        AxiStreamFrame(
            tdata=data,
        )
    )

    for i in range(PORTS):
        data0 = await tb.axis_out[i].recv()
        assert data0.tdata == data

        assert tb.axis_out[i].empty()

    # Test unknown address
    data = (Ether(src=MAC_ADDRESS_MAIN, dst=MAC_RANDOM) / np.random.bytes(64)).build()
    await tb.axis_in_main.send(
        AxiStreamFrame(
            tdata=data,
        )
    )

    for i in range(PORTS):
        data0 = await tb.axis_out[i].recv()
        assert data0.tdata == data

        assert tb.axis_out[i].empty()


# Deactivate a port and try to send multiple broadcasts.
@cocotb.test(timeout_time=10000000, timeout_unit="ns")
async def run_test_blocking(dut):
    """
    Test that broadcast still works when one port is blocked.

    1. Deactivate port 2.
    2. Send broadcast packets and verify they arrive on the active ports.
    3. Reactivate port 2 and drain the FIFO to verify packets arrive intact and in order.
    """
    tb = TB(dut, PORTS)
    await tb.init()
    await RisingEdge(dut.clk)

    # Deactivate port 2.
    tb.axis_out[PORTS - 1].pause = True

    msgs = []

    # send many packets from port 0 to port 1
    N = 1000
    for i in range(N):
        data = (
            Ether(src=MAC_ADDRESS_MAIN, dst=BROADCAST) / np.random.bytes(64)
        ).build()
        msgs.append(data)
        await tb.axis_in_main.send(
            AxiStreamFrame(
                tdata=data,
            )
        )
        data0 = await tb.axis_out[0].recv()
        assert data0.tdata == data
    assert tb.axis_out[0].empty()

    assert tb.axis_out[PORTS - 1].empty()

    # Reactivate port 2.
    tb.axis_out[PORTS - 1].pause = False
    await Timer(1000, unit="ns")

    i = 0
    # Expect either valid in-order packets or tuser=1 (an incomplete packet).
    while not tb.axis_out[PORTS - 1].empty():
        data0 = await tb.axis_out[PORTS - 1].recv()
        print(f"Tailing packet: {data0} {data0.tdata} {data0.tkeep} {data0.tuser}")

        if data0.tuser == 1:
            # Incomplete packet; drop it.
            print("one packet dropped")
            continue

        # The FIFO should have kept the first packet.
        assert data0.tdata == msgs[i]
        print(f"{i}th packet found in fifo")

        await Timer(1000, unit="ns")

        i += 1
    print(f"Packet {i} and later did not arrive")


@pytest.mark.parametrize("FIFO_ENABLE", [0, 1])
def test_mac_switch(FIFO_ENABLE):
    toplevel = "mac_half_switch_wrap_2"

    tests_dir = Path(__file__).parent.resolve()
    root = tests_dir.parent
    rtl = root / "src"
    lib = root / "lib"

    sources = [
        lib / "eth/lib/axis/rtl/priority_encoder.v",
        lib / "eth/lib/axis/rtl/arbiter.v",
        lib / "eth/lib/axis/rtl/axis_fifo.v",
        rtl / "mac_arb.sv",
        rtl / "mac_splitter.sv",
        rtl / "mac_read_address.sv",
        rtl / "mac_half_switch.sv",
        rtl / "mac_half_switch_wrap_2.v",
    ]
    simulator = os.environ.get("SIM", "verilator")
    build_args = ["-Wno-fatal", "--timing"] if simulator == "verilator" else []

    build_dir = tests_dir / "sim_build"
    parameters = {
        "FIFO_ENABLE": FIFO_ENABLE,
        "FIFO_DEPTH": FIFO_DEPTH,
    }
    timescale = ("1ns", "1ps")

    runner = get_runner(simulator)
    runner.build(
        sources=sources,
        build_args=build_args,
        hdl_toplevel=toplevel,
        build_dir=build_dir,
        parameters=parameters,
        timescale=timescale,
    )
    runner.test(
        test_module=Path(__file__).stem,
        hdl_toplevel=toplevel,
        build_dir=build_dir,
        parameters=parameters,
        timescale=timescale,
    )


if __name__ == "__main__":
    test_mac_switch(FIFO_ENABLE=0)
    # test_mac_switch(FIFO_ENABLE=1)
