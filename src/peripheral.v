/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 41 and change tqvp_example to your chosen module name.
module tqvp_morris_marcus_i2s_synth (
    input         clk,          // Clock - the TinyQV project clock is normally set to 64MHz.
    input         rst_n,        // Reset_n - low to reset.

    input  [7:0]  ui_in,        // The input PMOD, always available.  Note that ui_in[7] is normally used for UART RX.
                                // The inputs are synchronized to the clock, note this will introduce 2 cycles of delay on the inputs.

    output [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected.
                                // Note that uo_out[0] is normally used for UART TX.

    input [5:0]   address,      // Address within this peripheral's address space
    input [31:0]  data_in,      // Data in to the peripheral, bottom 8, 16 or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input [1:0]   data_write_n, // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    input [1:0]   data_read_n,  // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    
    output [31:0] data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high.
    output        data_ready,

    output        user_interrupt  // Dedicated interrupt request for this peripheral
);  

    wire i2s_sck;
    reg [26:0] i2s_sck_factor;

    // From https:
    // //electronics.stackexchange.com/questions/102588/mclk-in-i2s-audio-protocol
    // SCK frequency of 256 * sample_rate is common
    // However, only sending 16 bit packets, so
    // arbitrarily just multiply sample_rate by 64
    // Given 44.1kHz sampling frequency, aiming for approximately 2.82 MHz
    // So, aiming for around 2.82 MHz,
    // so default factor = 64 MHz / 2.82 MHz = ~22.69 = ~23
    always @(posedge clk) begin
        if (!rst_n) begin
            i2s_sck_factor <= 27'h17;
        end
    end

    clk_divider clk_i2s_sck_divider (
        .fast_clk(clk),
        .reset(rst_n),
        .factor(i2s_sck_factor),
        .slow_clk(i2s_sck)
    );

    wire i2s_ws;
    reg [26:0] i2s_ws_factor;

    // Want one half-period to be
    // 16 i2s_sck periods.
    // With the current (technically
    // bugged) design of clk_divider,
    // i2s_sck has a period of 24 clk periods.
    // Therefore, i2s_ws should have a period
    // of 32 i2s_sck periods or 768 clk periods.
    // To get this, with this bugged
    // clk_divider, set factor to 767.
    always @(posedge clk) begin
        if (!rst_n) begin
            i2s_ws_factor <= 27'h2ff;
        end
    end

    clk_divider clk_i2s_ws_divider (
        .fast_clk(clk),
        .reset(rst_n),
        .factor(i2s_ws_factor),
        .slow_clk(i2s_ws)
    );

    // STRT: 32-bit write register at address 0
    // BUSY: 32-bit read register, bit 0 is status

    reg prev_busy;
    reg busy;

    wire trig_i2s_rst;

    always @(posedge clk) begin
        if (!rst_n) begin
            prev_busy <= 1'b0;
            busy <= 1'b0;
        end else if (address < 6'h4 &&
                     data_write_n != 2'b11) begin
            prev_busy <= prev_busy;
            busy <= 1'b1;
        end else begin
            prev_busy <= busy;
            busy <= busy;
        end
    end

    assign trig_i2s_rst = busy & (!prev_busy);

    reg [15:0] example_left_data;
    reg [15:0] example_right_data;

    always @(posedge clk) begin
        if (!rst_n) begin
            example_left_data <= 16'h30f9;
            example_right_data <= 16'h7c5a;
        end
    end

    // https://vlsifacts.com/how-to-implement-a-finite-state-machine-fsm-in-verilog-practical-examples-and-best-practices/#google_vignette
    parameter INACTIVE      = 2'b00;
    parameter ACTIVE_SCK_HI = 2'b01;
    parameter ACTIVE_SCK_LO = 2'b10;
    reg [1:0] i2s_rst_state, next_i2s_rst_state;

    always @(posedge clk) begin
        if (!rst_n)
            i2s_rst_state <= ACTIVE_SCK_LO;
        else
            state <= next_state;
    end

    // Drop to low to reset, hold to next
    // i2s_sck rising edge
    reg i2s_rst;
    always @(*) begin
        case(i2s_rst_state)
            INACTIVE: begin
                if (!rst_n | trig_i2s_rst) begin
                    next_i2s_rst_state = i2s_sck ?
                        ACTIVE_SCK_HI : ACTIVE_SCK_LO;
                    i2s_rst = 1'b0;
                end else begin
                    next_i2s_rst_state = INACTIVE;
                    i2s_rst = 1'b1;
                end
            end
            ACTIVE_SCK_HI: begin
                if (!i2s_sck) begin
                    next_i2s_rst_state = ACTIVE_SCK_LO;
                    i2s_rst = 1'b0;
                end else begin
                    next_i2s_rst_state = ACTIVE_SCK_HI;
                    i2s_rst = 1'b0;
                end
            end
            ACTIVE_SCK_LO: begin
                if (i2s_sck) begin
                    next_i2s_rst_state = INACTIVE;
                    i2s_rst = 1'b1;
                end else begin
                    next_i2s_rst_state = ACTIVE_SCK_LO;
                    i2s_rst = 1'b0;
                end
            end
            default: begin
                next_i2s_rst_state = ACTIVE;
                i2s_rst = 1'b1;
            end
        endcase
    end

    wire i2s_sd;
    i2s_16_transmitter i2s (
        .sck(i2s_sck),
        .reset(i2s_rst),
        .data_left(example_left_data),
        .data_right(example_right_data),
        .ws(i2s_ws),
        .sd(i2s_sd)
    );

    // All other addresses read 0
    assign data_out = (address == 6'h4) ?
                        {31'h0, busy} : 32'h0;

    // All reads complete in 1 clock
    assign data_ready = 1'b1;

    // Expose
    // SCK on uo_out[1],
    // WS on uo_out[2],
    // SD on uo_out[3],
    // STRT on uo_out[4]
    assign uo_out = {4'h0, i2s_sd, i2s_ws, i2s_sck, 1'h0};

    // List all unused inputs to prevent warnings
    // data_read_n is unused as none of our behaviour depends on whether
    // registers are being read.
    wire _unused = &{ui_in, data_in, data_read_n, 1'b0};

    // Unused outputs
    assign user_interrupt = 1'h0;

    /*
      EXAMPLE PERIPHERAL
    // Implement a 32-bit read/write register at address 0
    reg [31:0] example_data;
    always @(posedge clk) begin
        if (!rst_n) begin
            example_data <= 0;
        end else begin
            if (address == 6'h0) begin
                if (data_write_n != 2'b11)              example_data <= data_in[7:0];
                if (data_write_n[1] != data_write_n[0]) example_data <= data_in[15:8];
                if (data_write_n == 2'b10)              example_data <= data_in[31:16];
            end
        end
    end

    // The bottom 8 bits of the stored data are added to ui_in and output to uo_out.
    assign uo_out = example_data[7:0] + ui_in;

    // User interrupt is generated on rising edge of ui_in[6], and cleared by writing a 1 to the low bit of address 8.
    reg example_interrupt;
    reg last_ui_in_6;

    always @(posedge clk) begin
        if (!rst_n) begin
            example_interrupt <= 0;
        end

        if (ui_in[6] && !last_ui_in_6) begin
            example_interrupt <= 1;
        end else if (address == 6'h8 && data_write_n != 2'b11 && data_in[0]) begin
            example_interrupt <= 0;
        end

        last_ui_in_6 <= ui_in[6];
    end

    assign user_interrupt = example_interrupt;

    // List all unused inputs to prevent warnings
    // data_read_n is unused as none of our behaviour depends on whether
    // registers are being read.
    wire _unused = &{data_read_n, 1'b0};
    */
endmodule
