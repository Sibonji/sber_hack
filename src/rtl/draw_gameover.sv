module draw_gameover (
    input wire clk, 
    input wire enable,
    input wire [9:0] pix_x, 
    input wire [9:0] pix_y,

    output wire over_on,
    output wire [2:0] bit_addr,
    output wire [10:0] rom_addr
);

    wire [3:0] row_addr;
    reg [6:0] char_addr;

    assign row_addr = pix_y[5:2];
    assign bit_addr = pix_x[4:2] - 3'd1;
    assign over_on = (pix_y[9:6] == 3) && (5 <= pix_x[9:5]) && (pix_x[9:5] <= 13) && enable;

    assign rom_addr = {char_addr, row_addr};

    always @*
    case(pix_x[8:5])
      4'h5: char_addr = 7'h47; // G
      4'h6: char_addr = 7'h61; // a
      4'h7: char_addr = 7'h6d; // m
      4'h8: char_addr = 7'h65; // e
      4'h9: char_addr = 7'h00; //
      4'ha: char_addr = 7'h4f; // O
      4'hb: char_addr = 7'h76; // v
      4'hc: char_addr = 7'h65; // e
      default: char_addr = 7'h72; // r
    endcase

endmodule