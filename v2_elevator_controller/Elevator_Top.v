// 电梯控制器顶层模块：连接核心控制、按键消抖、UART解析模块
module Elevator_Top(
    input clk,              // 系统时钟（50MHz）
    input rst_n,            // 复位信号（低电平有效，对应GPIO_29）
    
    // 按键输入（对应GPIO_0-GPIO_7）
    input [7:0] key_raw,    // 8个原始按键（上拉电阻，按下为低电平）
    
    // 楼层传感器（对应GPIO_22-GPIO_27）
    input [5:0] floor_sensor, // 6个拨码开关（高电平有效）
    
    // UART接口（对应GPIO_8, GPIO_9）
    input uart_rx,          // UART接收
    
    // LED输出
    output [5:0] floor_led, // 楼层指示LED（GPIO_10-GPIO_15）
    output [1:0] dir_led,   // 方向指示LED（GPIO_16-GPIO_17）
    output [3:0] mode_led,  // 模式指示LED（GPIO_18-GPIO_21）
    
    // 蜂鸣器（对应GPIO_28）
    output buzzer,
    
    // 门状态
    output door_open
);

// 内部连线
wire [7:0] key_valid;
wire [31:0] mode_cmd;
wire mode_update;

// 1. 实例化按键消抖模块
Key_Debounce u_Key_Debounce(
    .clk(clk),
    .rst_n(rst_n),
    .key_in(key_raw),
    .key_valid(key_valid)
);

// 2. 实例化UART模式解析模块
UART_Mode_Parse u_UART_Mode_Parse(
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx(uart_rx),
    .mode_cmd(mode_cmd),
    .mode_update(mode_update)
);

// 3. 实例化电梯核心控制模块
Elevator_Core u_Elevator_Core(
    .clk(clk),
    .rst_n(rst_n),
    .key_valid(key_valid),
    .floor_sensor(floor_sensor),
    .mode_cmd(mode_cmd),
    .mode_update(mode_update),
    .floor_led(floor_led),
    .dir_led(dir_led),
    .mode_led(mode_led),
    .buzzer(buzzer),
    .door_open(door_open)
);

endmodule