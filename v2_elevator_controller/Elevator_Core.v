// 电梯控制器核心模块：实现状态机控制、呼梯调度、模式管理、升降/门控逻辑
module Elevator_Core(
    input clk,              // 系统时钟（50MHz）
    input rst_n,            // 复位信号（低电平有效）
    input [7:0] key_valid,  // 消抖后按键有效信号（bit0-5：1-6楼，bit6：门开，bit7：门关）
    input [5:0] floor_sensor, // 楼层检测信号（bit0-5：1-6楼，高电平有效）
    input [31:0] mode_cmd,  // 串口解析后的模式指令（0：自动，1：手动，2：消防，3：检修）
    input mode_update,      // 模式更新标志（高电平有效）
    output reg [5:0]floor_led, // 楼层指示LED（bit0-5：1-6楼，高电平点亮）
    output reg [1:0]dir_led,   // 方向指示LED（bit0：上行，bit1：下行）
    output reg [3:0]mode_led,  // 模式指示LED（bit0：自动，bit1：手动，bit2：消防，bit3：检修）
    output reg buzzer,          // 蜂鸣器控制（高电平发声）
    output reg door_open        // 门状态（高电平开门，低电平关门）
);

// 内部信号定义
reg [2:0] current_state;    // 当前状态：0-空闲，1-上行，2-下行，3-开门，4-关门，5-提示
reg [2:0] next_state;       // 下一状态
reg [2:0] current_floor;    // 当前楼层（0-5对应1-6楼）
reg [2:0] target_floor;     // 目标楼层（0-5对应1-6楼）
reg [5:0] call_register;    // 呼梯信号寄存器（bit0-5：1-6楼，高电平有效）
reg [1:0] current_mode;     // 当前运行模式（0-自动，1-手动，2-消防，3-检修）
reg [25:0] delay_cnt;       // 延时计数器（50MHz，26位可计数67M）
reg [1:0] dir;              // 运行方向（0-无，1-上行，2-下行）

// 状态参数定义
parameter IDLE = 3'd0;
parameter UP = 3'd1;
parameter DOWN = 3'd2;
parameter OPEN_DOOR = 3'd3;
parameter CLOSE_DOOR= 3'd4;
parameter PROMPT = 3'd5;

// 模式参数定义
parameter AUTO = 2'd0;
parameter MANUAL = 2'd1;
parameter FIRE = 2'd2;
parameter CHECK = 2'd3;

// 1. 运行模式更新逻辑（仅驱动 current_mode 和 mode_led）
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        current_mode <= AUTO;
        mode_led <= 4'b0001;
    end else if(mode_update) begin
        current_mode <= mode_cmd[1:0];
        case(mode_cmd[1:0])
            AUTO:    mode_led <= 4'b0001;
            MANUAL:  mode_led <= 4'b0010;
            FIRE:    mode_led <= 4'b0100;
            CHECK:   mode_led <= 4'b1000;
            default: mode_led <= 4'b0001;
        endcase
    end
end

// 2. 当前楼层检测逻辑
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        current_floor <= 3'd0;
        floor_led <= 6'b000001;
    end else begin
        case(floor_sensor)
            6'b000001: begin current_floor <= 3'd0; floor_led <= 6'b000001; end
            6'b000010: begin current_floor <= 3'd1; floor_led <= 6'b000010; end
            6'b000100: begin current_floor <= 3'd2; floor_led <= 6'b000100; end
            6'b001000: begin current_floor <= 3'd3; floor_led <= 6'b001000; end
            6'b010000: begin current_floor <= 3'd4; floor_led <= 6'b010000; end
            6'b100000: begin current_floor <= 3'd5; floor_led <= 6'b100000; end
            default: ;
        endcase
    end
end

// 3. 呼梯信号登记逻辑（统一驱动 call_register）
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        call_register <= 6'd0;
    end else if(current_mode == FIRE) begin
        // 消防模式：清空所有呼梯
        call_register <= 6'd0;
    end else if(current_mode == AUTO) begin
        // 自动模式：登记呼梯
        if(key_valid[0]) call_register[0] <= 1'b1;
        if(key_valid[1]) call_register[1] <= 1'b1;
        if(key_valid[2]) call_register[2] <= 1'b1;
        if(key_valid[3]) call_register[3] <= 1'b1;
        if(key_valid[4]) call_register[4] <= 1'b1;
        if(key_valid[5]) call_register[5] <= 1'b1;
        // 到达目标楼层后清除对应呼梯
        if(current_floor == target_floor && current_state == PROMPT) begin
            call_register[current_floor] <= 1'b0;
        end
    end
end

// 4. 目标楼层调度逻辑（统一驱动 target_floor 和 dir）
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        target_floor <= 3'd0;
        dir <= 2'd0;
    end else if(current_mode == FIRE) begin
        // 消防模式：强制目标1楼
        target_floor <= 3'd0;
        dir <= (current_floor > 3'd0) ? 2'd2 : 2'd0;
    end else if(current_mode == AUTO && current_state == IDLE) begin
        if(call_register != 6'd0) begin
            // 上行方向优先
            if((current_floor < 3'd5 && call_register[5]) ||
               (current_floor < 3'd4 && call_register[4]) ||
               (current_floor < 3'd3 && call_register[3]) ||
               (current_floor < 3'd2 && call_register[2]) ||
               (current_floor < 3'd1 && call_register[1])) begin
                dir <= 2'd1;
                if     (current_floor < 3'd5 && call_register[5]) target_floor <= 3'd5;
                else if(current_floor < 3'd4 && call_register[4]) target_floor <= 3'd4;
                else if(current_floor < 3'd3 && call_register[3]) target_floor <= 3'd3;
                else if(current_floor < 3'd2 && call_register[2]) target_floor <= 3'd2;
                else if(current_floor < 3'd1 && call_register[1]) target_floor <= 3'd1;
            end else begin
                // 下行
                dir <= 2'd2;
                if     (current_floor > 3'd4 && call_register[4]) target_floor <= 3'd4;
                else if(current_floor > 3'd3 && call_register[3]) target_floor <= 3'd3;
                else if(current_floor > 3'd2 && call_register[2]) target_floor <= 3'd2;
                else if(current_floor > 3'd1 && call_register[1]) target_floor <= 3'd1;
                else if(current_floor > 3'd0 && call_register[0]) target_floor <= 3'd0;
            end
        end else begin
            dir <= 2'd0;
        end
    end
end

// 5. 状态机时序逻辑
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        current_state <= IDLE;
        delay_cnt <= 26'd0;
    end else begin
        current_state <= next_state;
        if(current_state == OPEN_DOOR || current_state == CLOSE_DOOR ||
           current_state == PROMPT) begin
            delay_cnt <= delay_cnt + 26'd1;
        end else begin
            delay_cnt <= 26'd0;
        end
    end
end

// 6. 状态机组合逻辑
always @(*) begin
    next_state = current_state;
    case(current_state)
        IDLE: begin
            if(current_mode == FIRE) begin
                if(current_floor != 3'd0) next_state = DOWN;
                else next_state = OPEN_DOOR;
            end else if(current_mode == AUTO && dir != 2'd0) begin
                next_state = (dir == 2'd1) ? UP : DOWN;
            end else if(current_mode == MANUAL) begin
                if(key_valid[6]) next_state = OPEN_DOOR;
                if(key_valid[7]) next_state = CLOSE_DOOR;
            end
        end
        UP: begin
            if(current_floor == target_floor) next_state = PROMPT;
        end
        DOWN: begin
            if(current_floor == target_floor) next_state = PROMPT;
        end
        PROMPT: begin
            if(delay_cnt >= 26'd50_000_000) next_state = OPEN_DOOR;   // 1秒
        end
        OPEN_DOOR: begin
            if(delay_cnt >= 26'd150_000_000) next_state = CLOSE_DOOR; // 3秒
            if(current_mode == MANUAL && key_valid[7]) next_state = CLOSE_DOOR;
        end
        CLOSE_DOOR: begin
            if(delay_cnt >= 26'd100_000_000) next_state = IDLE;       // 2秒
            if(current_mode == MANUAL && key_valid[6]) next_state = OPEN_DOOR;
        end
    endcase
end

// 7. 输出逻辑
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        dir_led <= 2'd0;
        buzzer <= 1'b0;
        door_open <= 1'b0;
    end else begin
        dir_led <= (dir == 2'd1) ? 2'b01 : (dir == 2'd2) ? 2'b10 : 2'b00;
        buzzer <= (current_state == PROMPT && delay_cnt <= 26'd50_000_000) ? 1'b1 : 1'b0;
        door_open <= (current_state == OPEN_DOOR) ? 1'b1 : (current_state == CLOSE_DOOR) ? 1'b0 : door_open;
    end
end

endmodule
