module random(
    input clk,
    input rst_n,
    output logic [15:0] random
);
    
    always_ff @(posedge clk) begin
        if ( !rst_n )
            random <= 16'hffff;
        else
            random <= {random[14:0], 1'b0} ^ ( random[15] ? 16'h800B : 16'b0);
    end

endmodule
