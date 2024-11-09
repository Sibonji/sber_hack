module plane_logo_rom #(
  parameter size_h = 32,
  parameter size_v = 32
) (
  input  wire    [10:0]     addr,
  output wire    [11:0]     word
);

  logic [11:0] rom [(size_h*size_v)];

  assign word = rom[addr];

  initial $readmemh("plane.mem", rom);

endmodule
