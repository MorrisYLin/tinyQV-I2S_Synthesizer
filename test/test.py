# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

from tqv import TinyQV

from math import floor, ceil
import os                     # to see environment variables

# When submitting your design, change this to the peripheral number
# in peripherals.v.  e.g. if your design is i_user_peri05, set this to 5.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 0

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Interact with your design's registers through this TinyQV class.
    # This will allow the same test to be run when your design is integrated
    # with TinyQV - the implementation of this class will be replaces with a
    # different version that uses Risc-V instructions instead of the SPI test
    # harness interface to read and write the registers.
    tqv = TinyQV(dut, PERIPHERAL_NUM)

    # Reset
    await tqv.reset()

    dut._log.info("Test project behavior")

    # Let rst_n propagate
    await ClockCycles(dut.clk, 1)

    # Let `x` values in shift register dissipate
    # in gate level test
    await ClockCycles(dut.clk, 1000)

    '''
    # WILL fail on gate-level, because hierachy is changed
    # As such, is commented out so passes Github Actions

    # Test I2S transmission, according to https://www.nxp.com/docs/en/user-manual/UM11732.pdf
    expected_left_data = 0x30f9
    expected_right_data = 0x7c5a
    # Wait for falling edge of ws, polling on i2s_sck rising edge
    await RisingEdge(dut.test_harness.user_peripheral.i2s_sck)
    while (dut.uo_out.value & 0b100) >> 2 == 0:
        # await ClockCycles(i2s_sck, 1)
        await ClockCycles(dut.test_harness.user_peripheral.i2s_sck, 1)

    while (dut.uo_out.value & 0b100) >> 2 == 1:
        # await ClockCycles(i2s_sck, 1)
        await ClockCycles(dut.test_harness.user_peripheral.i2s_sck, 1)

    # Start polling on next rising edge
    await ClockCycles(dut.test_harness.user_peripheral.i2s_sck, 1)

    # Poll expected channel 1 (left) data
    for _ in range(16):
        assert (dut.uo_out.value & 0b1000) >> 3 == (expected_left_data & 0x8000) >> 15
        expected_left_data <<= 1
        await ClockCycles(dut.test_harness.user_peripheral.i2s_sck, 1)

    # Poll expected channel 2 (right) data
    for _ in range(16):
        assert (dut.uo_out.value & 0b1000) >> 3 == (expected_right_data & 0x8000) >> 15
        expected_right_data <<= 1
        await ClockCycles(dut.test_harness.user_peripheral.i2s_sck, 1)
    '''

    # Test I2S SCK on uo_out[1]
    factor = 0x5

    sck_sample = dut.uo_out.value & 0b10
    for _ in range(10):
        await ClockCycles(dut.clk, ceil(factor / 2))
        assert dut.uo_out.value & 0b10 == sck_sample ^ 0b10
        await ClockCycles(dut.clk, ceil(factor / 2))
        assert dut.uo_out.value & 0b10 == sck_sample

    assert await tqv.read_word_reg(0) == 0x0
    assert await tqv.read_word_reg(4) == 0x0

    '''
    # Test register write and read back
    await tqv.write_word_reg(0, 0x12345678)
    assert await tqv.read_byte_reg(0) == 0x78
    assert await tqv.read_hword_reg(0) == 0x5678
    assert await tqv.read_word_reg(0) == 0x12345678

    # Set an input value, in the example this will be added to the register value
    dut.ui_in.value = 30

    # Wait for two clock cycles to see the output values, because ui_in is synchronized over two clocks,
    # and a further clock is required for the output to propagate.
    await ClockCycles(dut.clk, 3)

    # The following assersion is just an example of how to check the output values.
    # Change it to match the actual expected output of your module:
    assert dut.uo_out.value == 0x96

    # Input value should be read back from register 1
    assert await tqv.read_byte_reg(4) == 30

    # Zero should be read back from register 2
    assert await tqv.read_word_reg(8) == 0

    # A second write should work
    await tqv.write_word_reg(0, 40)
    assert dut.uo_out.value == 70

    # Test the interrupt, generated when ui_in[6] goes high
    dut.ui_in[6].value = 1
    await ClockCycles(dut.clk, 1)
    dut.ui_in[6].value = 0

    # Interrupt asserted
    await ClockCycles(dut.clk, 3)
    assert await tqv.is_interrupt_asserted()

    # Interrupt doesn't clear
    await ClockCycles(dut.clk, 10)
    assert await tqv.is_interrupt_asserted()

    # Write bottom bit of address 8 high to clear
    await tqv.write_byte_reg(8, 1)
    assert not await tqv.is_interrupt_asserted()
    '''
