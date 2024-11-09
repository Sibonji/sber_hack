module collision_check #(
    parameter H_PIXELS = 800,
    parameter V_PIXELS = 600,
    parameter ROAD_WIDTH = 130,
    parameter BORDER_WIDTH = 250,
    parameter CAR_V = 70,
    parameter CAR_H = 40
) (
    input clk,
    input rst_n,
    output logic collision [V_PIXELS - 1:0],
    input logic [10:0] road[V_PIXELS - 1:0],
    input logic [10:0] object_h_coord,
    input logic [10:0] object_v_coord
);

    genvar i;
    generate
        for (i=0; i < CAR_H; i++) begin
            always_ff @( posedge clk ) begin
                if ( !rst_n )
                    collision[i] <= 1'b0;
                else if ( (object_h_coord <= road[i]) && ((object_h_coord + CAR_H) >= (road[i] + ROAD_WIDTH)) )
                    collision[i] <= 1'b1;
            end
        end
    endgenerate

endmodule
