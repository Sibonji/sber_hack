module sber_logo_rom #(
  parameter size_h = 128,
  parameter size_v = 128
) (
  input  wire    [13:0]     addr,
  output wire    [11:0]     word
);

  logic [11:0] rom [(size_h*size_v)];

  assign word = rom[addr];

  initial $readmemh("sber.mem", rom);

endmodule
