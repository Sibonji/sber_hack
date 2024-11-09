module sky #(
    parameter H_PIXELS = 800,
    parameter V_PIXELS = 600,
    parameter ROAD_WIDTH = 130,
    parameter BORDER_WIDTH = 250
) (
//--------- Clock & Resets                     --------//
    input  wire           pixel_clk ,  // Pixel clock 25,2 MHz
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
    input  wire  [10:0]    h_coord   ,
    input  wire  [9:0]     v_coord   ,
  //--------- VGA outputs                        --------//
    output logic  [3:0]    red       ,  // 4-bit color output
    output logic  [3:0]    green     ,  // 4-bit color output
    output logic  [3:0]    blue      ,  // 4-bit color output
  //--------- Switches for background colour     --------//
//    input  wire  [2:0]    SW        ,
  //--------- Regime                             --------//
    output wire  [1:0]    regime_status
);
    logic [1:0] demo_regime_status;
    logic state;
    logic [5:0] frames_cntr;
    logic [4:0] ch_dir;
    logic end_of_frame;
    logic h_end, v_end;
    
    assign end_of_frame = h_end && v_end;
    assign h_end = (h_coord==(H_PIXELS - 1));
    assign v_end = (v_coord==(V_PIXELS - 1));
    
    logic direction;
    // [0] defines direction: 0 - -1, 1 - +1
    // [1] defines type: 0 - line, 1 - parabola
    logic [1:0] road_type;
    logic [8:0] cur_type_len;
    logic [10:0] road[V_PIXELS - 1:0];
    
    logic [15:0] random_num;

    // parabola gen: x = 1/a*y^2 + b
    logic [6:0] par_b;
    logic [7:0] par_a;
    logic [10:0] par_a_pulled;
    logic [10:0] par_b_pulled;
    logic [15:0] base_y;
    logic [15:0] mult_res;
    logic [10:0] base_x;
    logic [15:0] random_par;
    logic  par_part; //0 - y below zero, 1 - y above zero
    assign par_a = {1'b1, random_par[6:0]};
    assign par_b = {1'b1, random_par[12:7]};
    assign par_b_pulled = 11'd100;
    assign mult_res = (base_y * base_y) >> 8;

    // car gen 50*90
    parameter CAR_V = 70;
    parameter CAR_H = 40;
    parameter CAR_START_V = V_PIXELS - 150;
    parameter CAR_START_H = H_PIXELS / 2 - CAR_H / 2;
    logic [V_PIXELS - 1:0] collision;
    logic stop;
    assign stop = |collision;

    reg       [1:0]   regime_store  ;         // Two demonstration regimes
    wire              change_regime ;
    //----------------------- Counters                     --------------------------//
    parameter         FRAMES_PER_ACTION = 2;  // Action delay
    parameter MAX_FRAMES_PER_ACTION = 16;
    logic [5:0] frames_per_act;
    //----------------------- Accelerometr                 --------------------------//
    parameter     ACCEL_X_CORR = 8'd3;        // Accelerometer x correction
    parameter     ACCEL_Y_CORR = 8'd1;        // Accelerometer y correction
    wire   [7:0]  accel_data_x_corr  ;        // Accelerometer x corrected data
    wire   [7:0]  accel_data_y_corr  ;        // Accelerometer y corrected data

    logic [10:0]   object_h_coord     ;         // Object Point(P) horizontal coodrinate
    logic [10:0]   object_v_coord     ;         // Object Point(P) vertical coordinate
    logic [10:0]   object_h_speed     ;         // Horizontal Object movement speed

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
    assign regime_status = regime_store;

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
    assign object_h_speed = 11'd1;
    always @ ( posedge pixel_clk ) begin
        if ( !rst_n ) begin // Put object in the center
            object_h_coord <= H_PIXELS / 2 - CAR_H / 2;
            // object_h_coord <= 150 - CAR_H / 2;
            object_v_coord <= V_PIXELS - 150;
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
                    if ( object_h_coord + object_h_speed + CAR_H >= 10'd799 )
                        object_h_coord <= 10'd799 - CAR_H;
                    else
                        object_h_coord <= object_h_coord + object_h_speed;
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
                    if ( object_h_coord + object_h_speed + CAR_H >= 10'd799 )
                        object_h_coord <= 10'd799 - CAR_H;
                    else
                        object_h_coord <= object_h_coord + object_h_speed;
                end
            end
        end
    end

    // road speed change
    always @ ( posedge pixel_clk ) begin
        if ( !rst_n ) begin 
            frames_per_act <= FRAMES_PER_ACTION;
        end
        else if ( end_of_frame && (frames_cntr == 0) ) begin
            if ( button_u ) begin
              if ( frames_per_act >= 1 )
                frames_per_act <= frames_per_act - 1;
            end
            else if ( button_d  ) begin
              if ( frames_per_act != MAX_FRAMES_PER_ACTION )
                frames_per_act <= frames_per_act + 1;
            end
        end
      end
    
    random random_inst(
        .clk    ( pixel_clk  ),
        .rst_n  ( rst_n      ),
        .random ( random_num )
    );

    random random_par_gen (
        .clk    ( pixel_clk  ),
        .rst_n  ( rst_n      ),
        .random ( random_par )
    );
    
    genvar i;
    generate
        for (i=1; i < V_PIXELS; i++) begin
            always_ff @( posedge pixel_clk ) begin
                if ( !rst_n )
                    road[i] <= H_PIXELS / 2 - ROAD_WIDTH / 2;
                else if ( (frames_cntr == 0) && end_of_frame )
                    road[i] <= road[i - 1];
            end
        end
    endgenerate
    
    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n ) begin
            road[0] <= H_PIXELS / 2 - ROAD_WIDTH / 2;
        end
        else if ( (frames_cntr == 0) && end_of_frame) begin
            $display(road[0], base_x, mult_res[10:0], base_x + mult_res[10:0] - par_b_pulled);
            $display("Part: ", par_part, ", direction: ", direction, ", Road type: ", road_type[1], road_type[0], ", v len: ", cur_type_len);
            $display("Stop: ", stop, " obj coord: ", object_h_coord, " road: ", road[V_PIXELS - 160], " object_h_coord + CAR_H ", object_h_coord + CAR_H, " road[i] + ROAD_WIDTH ", road[V_PIXELS - 160] + ROAD_WIDTH);
            if ( !road_type[1] )
                road[0] <= direction ? (road[0] + 1) : (road[0] - 1);
            else if ( road_type[1] ) begin
                if ( !par_part ) begin
                    road[0] <= direction ? (base_x + mult_res[10:0] - par_b_pulled) : (base_x - mult_res[10:0] + par_b_pulled);
                end
                else if ( par_part )
                    road[0] <= direction ? (base_x - mult_res[10:0] - par_b_pulled) : (base_x + mult_res[10:0] + par_b_pulled);
            end
        end
    end

    // parabola coord generate
    always_ff @(posedge pixel_clk) begin
        if ( !rst_n ) begin
            base_x <=  H_PIXELS / 2 - ROAD_WIDTH / 2;
            base_y <= 16'd160;
            par_part <= '0;
        end
        else if ( cur_type_len == 9'd0 ) begin
            base_x <= road[0];
            base_y <= 16'd160;
            par_part <= '0;
        end
        else if ( (frames_cntr == 0) && end_of_frame && road_type[1] ) begin
            if ( base_y == 16'd0 ) begin
                par_part <= '1;
                base_y <= base_y + 1;
            end
            else if ( par_part )
                base_y <= base_y + 1;
            else
                base_y <= base_y - 1;
        end
    end

    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n )
            cur_type_len <= random_num[8:0];
            // cur_type_len <= 200;
        else if ( cur_type_len == 9'd0 )
            cur_type_len <= random_num[8:0];
            // cur_type_len <= 200;
        else if ( (frames_cntr == 0) && end_of_frame )
            cur_type_len <= cur_type_len - 1;
    end
    
    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n )
            direction = '1;
        else if ( road[0] <= H_PIXELS / 2 - BORDER_WIDTH)
            direction = '1;
        else if ( road[0] >= H_PIXELS / 2 + BORDER_WIDTH - ROAD_WIDTH)
            direction = '0;
        else
            direction = road_type[0];
        // else if ( road_type[0] && (cur_type_len == 8'd0) )
        //     direction = '1;
        // else if ( !road_type[0] && (cur_type_len == 8'd0) )
        //     direction = '0;
    end

    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n ) begin
            road_type <= random_num[9:8];
            // road_type[0] <= random_num[9];
            // road_type[1] <= 1'b1;
        end
        else if ( road[0] <= H_PIXELS / 2 - BORDER_WIDTH) begin
            road_type[0] <= 1'b1;
            road_type[1] <= 1'b0;
        end
        else if ( road[0] >= H_PIXELS / 2 + BORDER_WIDTH - ROAD_WIDTH) begin
            road_type[0] <= 1'b0;
            road_type[1] <= 1'b0;
        end
        else if ( cur_type_len == 9'd0 ) begin
            road_type <= random_num[9:8];
            // road_type[0] <= random_num[9];
            // road_type[1] <= 1'b1;
        end
    end
    
    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n )
            frames_cntr <= '0;
        else if ( stop ) begin
            frames_cntr <= 1;
        end
        else if ( frames_cntr == frames_per_act )
            frames_cntr <= 0;   
        else if ( end_of_frame )
            frames_cntr <= frames_cntr + 1;
    end
    
    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n ) begin
            red <= '1;
            green <= '1;
            blue <= '1;
        end
        else if ( (v_coord >= CAR_START_V) && (v_coord <= CAR_START_V + CAR_V) ) begin
            if ( (h_coord >= object_h_coord) && (h_coord <= object_h_coord + CAR_H) ) begin
                red <= 4'd8;
                green <= '0;
                blue <= '0;
            end
            else if ( (h_coord >= road[v_coord]) && (h_coord <= road[v_coord] + ROAD_WIDTH)) begin
                red <= '0;
                green <= '0;
                blue <= 4'd8;
            end
            else begin
                red <= '1;
                green <= '1;
                blue <= '1;
            end
        end
        else if ( (h_coord >= road[v_coord]) && (h_coord <= road[v_coord] + ROAD_WIDTH)) begin
            red <= '0;
            green <= '0;
            blue <= 4'd8;
        end
        else begin
            red <= '1;
            green <= '1;
            blue <= '1;
        end
    end

    collision_check road_collision_check (
        .clk ( pixel_clk ),
        .rst_n ( rst_n ),
        .collision ( collision ),
        .road ( road ),
        .object_h_coord ( object_h_coord ),
        .object_v_coord ( object_v_coord )
    );
    
endmodule

