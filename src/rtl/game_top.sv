module game_top (
  //--------- Clock & Resets                     --------//
    input  wire           pixel_clk ,  // Pixel clock 36 MHz
    input  wire           rst_n     ,  // Active low synchronous reset
  //--------- Buttons                            --------//
    input  wire           button_c  ,
    input  wire           button_u  ,
    input  wire           button_d  ,
    input  wire           button_r  ,
    input  wire           button_l  ,
  //--------- Accelerometer                      --------//
    input  wire  [7:0]    accel_data_x         ,
    input  wire  [7:0]    accel_data_y         ,
    output logic [7:0]    accel_x_end_of_frame ,
    output logic [7:0]    accel_y_end_of_frame ,
  //--------- Pixcels Coordinates                --------//
    input  wire  [10:0]   h_coord   ,
    input  wire  [ 9:0]   v_coord   ,
  //--------- VGA outputs                        --------//
    output wire  [3:0]    red       ,  // 4-bit color output
    output wire  [3:0]    green     ,  // 4-bit color output
    output wire  [3:0]    blue      ,  // 4-bit color output
  //--------- Switches for background colour     --------//
    input  wire  [2:0]    SW        ,
  //--------- Regime                             --------//
    output wire  [1:0]    demo_regime_status
);

//------------------------- Variables                    ----------------------------//
  //----------------------- Regime control               --------------------------//
    wire              change_regime ;
    reg       [1:0]   regime_store  ;         // Two demonstration regimes
  //----------------------- Counters                     --------------------------//
    parameter         FRAMES_PER_ACTION = 2;  // Action delay
    logic     [31:0]  frames_cntr ;
    logic             end_of_frame;           // End of frame's active zone
  //----------------------- Accelerometr                 --------------------------//
    parameter     ACCEL_X_CORR = 8'd3;        // Accelerometer x correction
    parameter     ACCEL_Y_CORR = 8'd1;        // Accelerometer y correction
    wire   [7:0]  accel_data_x_corr  ;        // Accelerometer x corrected data
    wire   [7:0]  accel_data_y_corr  ;        // Accelerometer y corrected data
  //----------------------- Object (Stick)               --------------------------//
    //   0 1         X
    //  +------------->
    // 0|
    // 1|  P.<v,h>-> width
    //  |   |
    // Y|   |
    //  |   V heigh
    //  |
    //  V
    parameter     logo_size_v   = 50 ;
    parameter     logo_size_h   = 61 ;
    parameter     object_width  = 8  ;         // Horizontal width
    parameter     object_height = 20 ;         // Vertical height
    logic         object_draw        ;         // Is Sber Logo or demo object coordinate (with width and height)?
    logic [9:0]   object_h_coord     ;         // Object Point(P) horizontal coodrinate
    logic [9:0]   object_v_coord     ;         // Object Point(P) vertical coordinate
    logic [9:0]   object_h_speed     ;         // Horizontal Object movement speed
    logic [9:0]   object_v_speed     ;         // Vertical Object movement speed
  //----------------------- Sber logo timer              --------------------------//
    logic [31:0]  plane_logo_counter     ;      // Counter is counting how long showing Sber logo
    wire          plane_logo_active      ;      // Demonstrating Sber logo
    // Read only memory (ROM) for sber logo file
    wire  [11:0]  plane_logo_rom_out     ;
    wire  [11:0]  plane_logo_read_address;
//------------------------- End of Frame                 ----------------------------//
  // We recount game object once at the end of display counter //
  always_ff @( posedge pixel_clk ) begin
    if ( !rst_n )
      end_of_frame <= 1'b0;
    else
      end_of_frame <= (h_coord[9:0]==10'd799) && (v_coord==10'd599); // 799 x 599
  end
  always_ff @( posedge pixel_clk ) begin
    if ( !rst_n )
      frames_cntr <= 0;
    else if ( frames_cntr == FRAMES_PER_ACTION )
      frames_cntr <= 0;
    else if (end_of_frame)
      frames_cntr <= frames_cntr + 1;
  end

//------------------------- Regime control               ----------------------------//
  always @ ( posedge pixel_clk ) begin //Right now there are 2 regimes
    if ( !rst_n ) begin
      regime_store <= 2'b11;
    end
    else if (change_regime && (regime_store == 2'b10)) begin
      regime_store <= 2'b11;
    end
    else if ( change_regime ) begin
      regime_store <= regime_store - 1'b1;
    end
  end
  assign change_regime      = button_c    ;
  assign demo_regime_status = regime_store;

//------------------------- Accelerometr at the end of frame-------------------------//
  always @ ( posedge pixel_clk ) begin
    if ( !rst_n ) begin
      accel_x_end_of_frame <= 8'h0000000;
      accel_y_end_of_frame <= 8'h0000000;
    end
    else if ( end_of_frame && (frames_cntr == 0) ) begin
      accel_x_end_of_frame <= accel_data_x_corr;
      accel_y_end_of_frame <= accel_data_y_corr;
    end
  end
  // Accelerometr corrections
  assign accel_data_x_corr = accel_data_x + ACCEL_X_CORR;
  assign accel_data_y_corr = accel_data_y + ACCEL_Y_CORR;
//------------------------- Object movement in 2 regimes  ----------------------------//
  assign object_v_speed = 10'd1;
  assign object_h_speed = 10'd1;
  always @ ( posedge pixel_clk ) begin
    if ( !rst_n ) begin // Put object in the center
      object_h_coord <= 399;
      object_v_coord <= 299;
    end
    else if ( end_of_frame && (frames_cntr == 0) ) begin
      if (regime_store == 2'b11) begin  // Buttons regime
        if ( button_l ) begin           // Moving left
          if ( object_h_coord < object_h_speed)
            object_h_coord <= 0;
          else
            object_h_coord <= object_h_coord - object_h_speed;
        end
        else if ( button_r ) begin
          if ( object_h_coord + object_h_speed + object_width >= 10'd799 )
            object_h_coord <= 10'd799 - object_width;
          else
            object_h_coord <= object_h_coord + object_h_speed;
        end
        //
        if      ( button_u ) begin
          if ( object_v_coord < object_v_speed )
            object_v_coord <= 0;
          else
            object_v_coord <= object_v_coord - object_v_speed;
        end
        else if ( button_d  ) begin
          if ( object_v_coord + object_v_speed + object_height >= 10'd599 )
            object_v_coord <= 10'd599 - object_height;
          else
            object_v_coord <= object_v_coord + object_v_speed;
        end
      end
      else if (regime_store == 2'b10) begin  // Accelerometer regime
        if      ( !accel_data_y_corr[7] && ( accel_data_y_corr != 8'h00 )) begin
          if ( object_h_coord < object_h_speed)
            object_h_coord <= 0;
          else
            object_h_coord <= object_h_coord - object_h_speed;
        end
        else if ( accel_data_y_corr[7] && ( accel_data_y_corr != 8'h00 ) ) begin
          if ( object_h_coord + object_h_speed + object_width >= 10'd799 )
            object_h_coord <= 10'd799 - object_width;
          else
            object_h_coord <= object_h_coord + object_h_speed;
        end
        //
        if      ( accel_data_x_corr[7] && ( accel_data_x_corr != 8'h00 ) ) begin
          if ( object_v_coord < object_v_speed )
            object_v_coord <= 0;
          else
            object_v_coord <= object_v_coord - object_v_speed;
        end
        else if (!accel_data_x_corr[7] && ( accel_data_x_corr != 8'h00 ) )  begin
          if ( object_v_coord + object_v_speed + object_height >= 10'd599 )
            object_v_coord <= 10'd599 - object_height;
          else
            object_v_coord <= object_v_coord + object_v_speed;
        end
      end
    end
  end

//------------- Sber logo on reset                               -------------//
  //----------- How long to show Sber logo                       -----------//
    always @ ( posedge pixel_clk ) begin
      if      ( !rst_n )
        plane_logo_counter <= 32'b0;
      else if ( plane_logo_counter <= 32'h5ff_ffff )
        plane_logo_counter <= plane_logo_counter + 1'b1;
    end
    assign plane_logo_active = ( plane_logo_counter < 32'h5ff_ffff );
  //----------- SBER logo ROM                                    -----------//
    // Screen resoulution is 800x600, the logo size is 128x128. We need to put the logo in the center.
    // Logo offset = (800-128)/2=336 from the left edge; Logo v coord = (600-128)/2 = 236
    // Cause we need 1 clock for reading, we start erlier
    
    logic [11:0] logo_offset_h_init = (800-logo_size_h)/2 - 1;
    logic [11:0] logo_offset_v_init = (600-logo_size_v)/2 - 1;
    logic [11:0] logo_offset_h;
    logic [11:0] logo_offset_v;
    
    always_comb begin
      if (plane_logo_active) begin
        logo_offset_h = logo_offset_h_init;
        logo_offset_v = logo_offset_v_init;
      end
      else begin
        logo_offset_h = {2'b0, object_h_coord};
        logo_offset_v = {2'b0, object_v_coord};
      end
    end

    assign plane_logo_read_address = {1'b0, h_coord} - logo_offset_h + ({2'b0, v_coord} - logo_offset_v)*logo_size_h;

    //for picture with size 128x128 we need 16384 pixel information
    plane_logo_rom #(
      .size_h (logo_size_h),
      .size_v (logo_size_v)
    ) plane_logo_rom (
      .addr ( plane_logo_read_address ),
      .word ( plane_logo_rom_out      ) 
    );
//____________________________________________________________________________//

//------------- RGB MUX outputs                                  -------------//

  assign object_draw = (h_coord[9:0] >= logo_offset_h[9:0]) & (h_coord[9:0] < (logo_offset_h[9:0] + logo_size_h)) & (v_coord >= logo_offset_v[9:0]) & (v_coord < (logo_offset_v[9:0] + logo_size_v)) & ~(plane_logo_rom_out[11:0]==12'h000) ;
  // always_comb begin
  //   if ( plane_logo_active ) begin
  //     object_draw = (h_coord[9:0] >= logo_offset_h[9:0]) & (h_coord[9:0] < (logo_offset_h[9:0] + logo_size_h)) & (v_coord >= logo_offset_v[9:0]) & (v_coord < (logo_offset_v[9:0] + logo_size_v)) & ~(plane_logo_rom_out[11:0]==12'h000) ; // Logo size is 128x128 Pixcels
  //   end
  //   else begin
  //     object_draw = ( h_coord[9:0] >= object_h_coord ) & ( h_coord[9:0] <= (object_h_coord + object_width  )) &
  //                   ( v_coord >= object_v_coord ) & ( v_coord <= (object_v_coord + object_height ));
  //   end
  // end

//TODO

  // assign  red     = object_draw ? ( ~plane_logo_active ? 4'hf : plane_logo_rom_out[3:0]  ) : (SW[0] ? 4'h8 : 4'h0);
  // assign  green   = object_draw ? ( ~plane_logo_active ? 4'hf : plane_logo_rom_out[7:4]  ) : (SW[1] ? 4'h8 : 4'h0);
  // assign  blue    = object_draw ? ( ~plane_logo_active ? 4'hf : plane_logo_rom_out[11:8] ) : (SW[2] ? 4'h8 : 4'h0);
//____________________________________________________________________________//

reg [11:0] road_rgb;

  sky #(
    .H_PIXELS(800),
    .V_PIXELS(600),
    .ROAD_WIDTH(90),
    .BORDER_WIDTH(250)
  ) sky_inst (
    //--------- Clock & Resets                     --------//
      .pixel_clk(pixel_clk),
      .rst_n(rst_n),
      .h_coord(h_coord),
      .v_coord(v_coord),
    //--------- VGA outputs                        --------//
      .red(road_rgb[3:0]),  // 4-bit color output
      .green(road_rgb[7:4]),  // 4-bit color output
      .blue(road_rgb[11:8])  // 4-bit color output
  );

//-- MY GAME --//
reg [1:0] state;
reg refresh_tick;
reg text_on;
reg start_en, finish_en, over_en;
reg [11:0] text_rgb;

initial begin
  start_en = 1'b0;
  finish_en = 1'b0;
  over_en = 1'b1;
end
always @(posedge pixel_clk)
case(state)
    0:  if((v_coord == 481) && (h_coord == 0)) begin
            refresh_tick <= 1'b1;
            state <= 2'b1;
        end
    1:  begin 
            refresh_tick <= 1'b0; 
            state <= 2'b10; 
        end
    2: state <= 2'b11;
    3: state <= 2'b00;
endcase

// Add display text    
  display_text my_text (
    .clk(pixel_clk),
    .reset(~rst_n),
    .pause(0),
    .refresh_tick(refresh_tick),
    .start_en(start_en),
    .over_en(over_en),
    .finish_en(finish_en),
    .pix_x(h_coord),
    .pix_y(v_coord),

    .text_on(text_on),
    .text_rgb(text_rgb)
  );


// wire [11:0] plane_rgb = plane_logo_rom_out;

reg road_on, plane_on;
reg video_on;

reg [11:0] rgb_out;

initial begin
  road_on = 1'b1;
  // plane_on = 1'b1;
  video_on = 1'b1;
end

always_comb begin
  if (object_draw) plane_on = 1'b1;
  else plane_on = 1'b0;
end

always_comb begin
    if (~video_on)
        rgb_out = 12'b0; // blank
    else if(text_on)
        rgb_out = text_rgb;
    else if (road_on)
        rgb_out = road_rgb;
    else if (plane_on)
        // rgb_out = plane_rgb;
        rgb_out = plane_logo_rom_out;

    else
        rgb_out = 12'h0e0; //  background
end


assign  red     = rgb_out[3:0]; // : (SW[0] ? 4'h8 : 4'h0);
assign  green   = rgb_out[7:4]; //object_draw ? ( ~plane_logo_active ? 4'hf : plane_logo_rom_out[7:4]  ) : (SW[1] ? 4'h8 : 4'h0);
assign  blue    = rgb_out[11:8]; //object_draw ? ( ~plane_logo_active ? 4'hf : plane_logo_rom_out[11:8] ) : (SW[2] ? 4'h8 : 4'h0);


endmodule
