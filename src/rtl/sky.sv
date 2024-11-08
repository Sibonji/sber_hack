module sky #(
    parameter H_PIXELS = 800,
    parameter V_PIXELS = 600,
    parameter ROAD_WIDTH = 90,
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
    logic state;
    logic [0:0] frame_cnt;
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
    logic [7:0] cur_type_len;
    logic [10:0] road[V_PIXELS - 1:0];
    
    logic [15:0] random_num;

    // parabola gen: x = 1/a*y^2 + b
    logic [6:0] par_b;
    logic [7:0] par_a;
    logic [10:0] par_a_pulled;
    logic [10:0] par_b_pulled;
    logic [10:0] base_y;
    logic [10:0] base_x;
    logic [15:0] random_par;
    logic  par_part; //0 - y below zero, 1 - y above zero
    assign par_a = {1'b1, random_par[6:0]};
    assign par_b = {1'b1, random_par[12:7]};
    assign par_b_pulled = 11'd100;
    
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
                else if ( &frame_cnt && end_of_frame )
                    road[i] <= road[i - 1];
            end
        end
    endgenerate
    
    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n ) begin
            road[0] <= H_PIXELS / 2 - ROAD_WIDTH / 2;
        end
        else if ( &frame_cnt && end_of_frame) begin
            if ( !road_type[1] )
                road[0] <= direction ? (road[0] + 1) : (road[0] - 1);
            else if ( road_type[1] ) begin
                $display(base_y >> 4, ((base_y >> 4) * (base_y >> 4)), base_x + ((base_y >> 4) * (base_y >> 4)) - par_b_pulled);
                if ( !par_part ) begin
                    road[0] <= direction ? (base_x + ((base_y >> 4) * (base_y >> 4)) - par_b_pulled) : (base_x - ((base_y >> 4) * (base_y >> 4)) + par_b_pulled);
                end
                else if ( par_part )
                    road[0] <= direction ? (base_x - ((base_y >> 4) * (base_y >> 4)) + par_b_pulled) : (base_x + ((base_y >> 4) * (base_y >> 4)) - par_b_pulled);
            end
        end
    end

    // parabola coord generate
    always_ff @(posedge pixel_clk) begin
        if ( !rst_n ) begin
            base_x <=  H_PIXELS / 2 - ROAD_WIDTH / 2;
            base_y <= 11'd160;
            par_part <= '0;
        end
        else if ( cur_type_len == 8'd0 ) begin
            base_x <= road[0];
            base_y <= 11'd160;
            par_part <= '0;
        end
        else if ( &frame_cnt && end_of_frame && road_type[1] ) begin
            if ( base_y == 11'd0 ) begin
                par_part <= '1;
            end
            else if ( par_part )
                base_y <= base_y + 1;
            else
                base_y <= base_y - 1;
        end
    end

    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n )
            // cur_type_len <= {1'b1, random_num[6:0]};
            cur_type_len <= 200;
        else if ( cur_type_len == 8'd0 )
            // cur_type_len <= {1'b1, random_num[6:0]};
            cur_type_len <= 200;
        else if ( &frame_cnt && end_of_frame )
            cur_type_len <= cur_type_len - 1;
    end
    
    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n )
            direction = '1;
        else if ( road[0] <= H_PIXELS / 2 - BORDER_WIDTH)
            direction = '1;
        else if ( road[0] >= H_PIXELS / 2 + BORDER_WIDTH - ROAD_WIDTH)
            direction = '0;
        // else if ( road_type[0] && (cur_type_len == 8'd0) )
        //     direction = '1;
        // else if ( !road_type[0] && (cur_type_len == 8'd0) )
        //     direction = '0;
    end

    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n ) begin
            // road_type <= random_num[9:8];
            road_type[0] <= random_num[9];
            road_type[1] <= 1'b1;
        end
        else if ( road[0] <= H_PIXELS / 2 - BORDER_WIDTH) begin
            road_type[0] <= 1'b1;
            road_type[1] <= 1'b0;
        end
        else if ( road[0] >= H_PIXELS / 2 + BORDER_WIDTH - ROAD_WIDTH) begin
            road_type[0] <= 1'b0;
            road_type[1] <= 1'b0;
        end
        else if ( cur_type_len == 8'd0 ) begin
            // road_type <= random_num[9:8];
            road_type[0] <= random_num[9];
            road_type[1] <= 1'b1;
        end
    end
    
    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n )
            frame_cnt <= '0;
        else if ( end_of_frame )
            frame_cnt <= frame_cnt + 1;
    end

    logic [10:0]curr_road;
    assign curr_road = road[v_coord];
    
    always_ff @( posedge pixel_clk ) begin
        if ( !rst_n ) begin
            red <= '0;
            green <= '0;
            blue <= 4'd8;
        end
        else if ( (h_coord >= road[v_coord]) && (h_coord <= road[v_coord] + ROAD_WIDTH)) begin
            red <= '1;
            green <= '1;
            blue <= '1;
        end
        else begin
            red <= '0;
            green <= '0;
            blue <= 4'd8;
        end
    end
    
endmodule

