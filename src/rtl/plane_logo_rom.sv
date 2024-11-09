module plane_logo_rom #(
  parameter size_h = 61,
  parameter size_v = 50
) (
  input  wire    [11:0]     addr,
  output wire    [11:0]     word
);

  logic [11:0] rom [(size_h*size_v)];

  assign word = rom[addr];

  initial $readmemh("plane.mem", rom);

endmodule
