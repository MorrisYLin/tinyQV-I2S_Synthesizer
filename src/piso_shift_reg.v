/*
 * Copyright (c) 2025 Marcus Alagar
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

/*
 * Parallel-In, Serial-Out 16-Bit Shift Register
 */
module piso_16_shift_reg (
    input         clk,      // Output next data bit on rising edge
    input [15:0]  in,       // Data to fill shift register, MSB will be sent first
    input         pl,       // Synchronous parallel load, active high
    output        sd        // Next data bit
);

    reg [15:0] data;

    always @(posedge clk) begin
        if (pl) begin
            data <= in;
        end else begin
            data <= {data[14:0], 1'b0};
        end
    end

    assign sd = data[15];

endmodule
