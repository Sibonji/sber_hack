module display_text (
    input wire clk,
    input wire reset,
    input wire pause,
    input wire refresh_tick,
    input wire start_en,
    input wire over_en,
    input wire finish_en,
    input wire [9:0] pix_x,
    input wire [9:0] pix_y,

    output wire text_on,
    output reg [11:0] text_rgb
);

wire [7:0] font_word;

wire font_bit, time_on, start_on, finish_on, over_on;

wire [10:0] time_rom_addr, start_rom_addr, finish_rom_addr, over_rom_addr;

wire [2:0] time_bit_addr, start_bit_addr, finish_bit_addr, over_bit_addr;

reg [10:0] rom_addr;

reg [2:0] bit_addr;


assign font_bit = font_word[~bit_addr];

assign text_on = time_on | (start_on & font_bit) | (over_on & font_bit) |  (finish_on & font_bit);

font my_font (
    .clk(clk),
    .addr(rom_addr),
    .data(font_word)
);

display_text_counter my_time(
  .clk(clk), 
  .reset(reset), 
  .pause(pause),
  .refresh_tick(refresh_tick), 
  .pix_x(pix_x),
  .pix_y(pix_y),
  .time_on(time_on),
  .bit_addr(time_bit_addr),
  .rom_addr(time_rom_addr)
);

draw_start my_start(
  .clk(clk), 
  .enable(start_en),
  .pix_x(pix_x),
  .pix_y(pix_y),
  .start_on(start_on),
  .bit_addr(start_bit_addr),
  .rom_addr(start_rom_addr)
);

draw_gameover my_gameover(
  .clk(clk), 
  .enable(over_en),
  .pix_x(pix_x),
  .pix_y(pix_y),
  .over_on(over_on),
  .bit_addr(over_bit_addr),
  .rom_addr(over_rom_addr)
);

draw_finish my_finish(
  .clk(clk), 
  .enable(finish_en),
  .pix_x(pix_x),
  .pix_y(pix_y),
  .finish_on(finish_on),
  .bit_addr(finish_bit_addr),
  .rom_addr(finish_rom_addr)
);


// game_over crash(clk, crash_en, pix_x, pix_y, crash_on, 
//             crash_bit_addr, crash_rom_addr);


always_latch
begin
  if(time_on) begin
    bit_addr = time_bit_addr;
    rom_addr = time_rom_addr;
    text_rgb = 12'h797;
    if (font_bit) text_rgb = 12'h001;
  end
  if(start_on) begin
    bit_addr = start_bit_addr;
    rom_addr = start_rom_addr;
    text_rgb = 12'h12f;
  end  
  else if(over_on) begin
    bit_addr = over_bit_addr;
    rom_addr = over_rom_addr;
    text_rgb = 12'h00f;
  end
  else if(finish_on) begin
    bit_addr = finish_bit_addr;
    rom_addr = finish_rom_addr;
    text_rgb = 12'h0f0;
  end


end

endmodule
