module clk_divider (
    input fast_clk,
    input [26:0] factor,
    output slow_clk
);
    
    reg [26:0] counter = 0;
    reg out = 0;
    
    always @ (posedge fast_clk) begin
        if (counter >= {1'b0, factor[26:1]}) begin
            counter <= 0;
            out <= ~out;
        end else begin
            counter <= counter + 1;
        end
    end
    
    assign slow_clk = out;
    
endmodule