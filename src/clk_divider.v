module clk_divider (
    input fast_clk,
    input reset,            // Low to reset
    input [26:0] factor,
    output slow_clk
);

    reg [26:0] counter;
    reg out;

    always @(posedge fast_clk) begin
        if (!reset) begin
            counter <= 27'h0;
            out <= 1'h0;
        end else if (counter >= {1'b0, factor[26:1]}) begin
            counter <= 0;
            out <= ~out;
        end else begin
            counter <= counter + 1;
        end
    end

    assign slow_clk = out;

endmodule
