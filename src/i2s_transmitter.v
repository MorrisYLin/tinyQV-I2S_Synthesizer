/*
 * Copyright (c) 2025 Marcus Alagar
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

/*
 * Following I2S specification as laid out
 * here: https://www.nxp.com/docs/en/user-manual/UM11732.pdf
 */
module i2s_16_transmitter (
    input         sck,          // Serial Clock - for transmission with I2S board
    input         reset,        // Synchronous reset - low to reset
    input [15:0]  data_left,    // 16-bit data to go to channel 1 (left)
    input [15:0]  data_right,   // 16-bit data to go to channel 2 (right)
    input         ws,           // Word Select - low for left, high for right
    output        sd            // Serial Data - to be transmitted to I2S board,
                                //               polled on rising edge of sck
);

    reg previous_ws;
    reg current_ws;

    wire ws_pl;

    // Parallel load on detected
    // change level change of ws
    always @(posedge sck) begin
        previous_ws <= current_ws;
        current_ws <= ws;
    end

    assign ws_pl = previous_ws ^ current_ws;

    reg [15:0] stored_data;
    reg reset_pl;

    always @(posedge sck) begin
        if (!reset) begin
            stored_data <= 16'h0;
            reset_pl <= 1'b1;
        end else begin
            // Is opposite because on falling edge, will
            // load the old value of stored_data to shift register.
            // So, want to leave behind old value and pre-emptively
            // switch to value for next ws level change
            stored_data <= current_ws ? data_left : data_right;
            reset_pl <= 1'b0;
        end
    end

    wire [15:0] data;
    assign data = stored_data;

    // Use ws_pl normally (on WS level change),
    // then reset_pl to force loads into the shift register
    // Theoretically means will sucessfully load the default value
    // on the first falling edge of sck after a reset
    wire pl;
    assign pl = ws_pl | reset_pl;

    piso_16_shift_reg shift_reg(
        .clk(!sck),
        .in(data),
        .pl(pl),
        .sd(sd)
    );

endmodule
