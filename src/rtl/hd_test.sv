module hd_test(
  //--------- Clock & Resets                     --------//
    input  wire           pixel_clk ,  // Pixel clock 25,2 MHz
    input  wire           rst_n     ,  // Active low synchronous reset
  //--------- Buttons                            --------//
//    input  wire           button_c  ,
//    input  wire           button_u  ,
//    input  wire           button_d  ,
//    input  wire           button_r  ,
//    input  wire           button_l  ,
  //--------- Accelerometer                      --------//
//    input  wire  [7:0]    accel_data_x         ,
//    input  wire  [7:0]    accel_data_y         ,
//    output logic [7:0]    accel_x_end_of_frame ,
//    output logic [7:0]    accel_y_end_of_frame ,
  //--------- Pixcels Coordinates                --------//
    input  wire  [10:0]    h_coord   ,
    input  wire  [9:0]     v_coord   ,
  //--------- VGA outputs                        --------//
    output logic  [3:0]    red       ,  // 4-bit color output
    output logic  [3:0]    green     ,  // 4-bit color output
    output logic  [3:0]    blue        // 4-bit color output
  //--------- Switches for background colour     --------//
//    input  wire  [2:0]    SW        ,
  //--------- Regime                             --------//
//    output wire  [1:0]    demo_regime_status
);
    logic state;
    logic [4:0] frame_cnt;
    logic end_of_frame;
    logic h_end, v_end;
    assign end_of_frame = h_end && v_end;
    assign h_end = (h_coord==10'd799);
    assign v_end = (v_coord==10'd599);
    
    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n )
            state <= 1'b0;
        else if ( frame_cnt==5'b11111 && end_of_frame)
            state <= !state;
    end
    
    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n )
            frame_cnt <= '0;
        else if ( end_of_frame )
            frame_cnt <= frame_cnt + 1;
    end

    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n ) begin
            red <= 4'd8;
            green <= '0;
            blue <= '0;
        end
        else if ( state ) begin
            red <= '0;
            green <= '0;
            blue <= 4'd8;
        end
        else begin
            red <= '0;
            green <= 4'd8;
            blue <= '0;
        end
    end
    
endmodule

