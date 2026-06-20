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
    output door_open,

    // 数码管（未使用，置为灭灯）
    output [7:0] seg7,       // 7段数据总线（低电平点亮）
    output [3:0] com         // 位选控制（低电平使能）
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

// 3. 上电数码管显示"6666"，2秒后灭灯
// 50MHz时钟，2秒 = 100_000_000个周期
reg [26:0] boot_cnt;           // 上电计数器（27位足够计数1亿）
reg        boot_disp_en;       // 上电显示使能（1=显示6666，0=灭灯）
reg [1:0]  scan_cnt;           // 数码管扫描计数器（4位轮流显示）
reg [17:0] scan_div;           // 扫描分频计数器（50MHz/2^18 ≈ 190Hz，无闪烁）

// 7段译码：显示数字"6"（TREX C1共阳极，低电平点亮）
// TREX C1段码映射：bit7=DP, bit6=a, bit5=b, bit4=c, bit3=d, bit2=e, bit1=f, bit0=g
// 6的段码：a=0,b=1,c=0,d=0,e=0,f=0,g=0 → 8'h67
// 验证：4=0x17, 3=0x19, 2=0x58, 1=0x9f（与文档一致）
parameter SEG_6 = 8'h67;

// 上电2秒计数
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        boot_cnt <= 27'd0;
        boot_disp_en <= 1'b1;
    end else if(boot_cnt < 27'd100_000_000) begin
        boot_cnt <= boot_cnt + 27'd1;
        boot_disp_en <= 1'b1;
    end else begin
        boot_disp_en <= 1'b0;
    end
end

// 数码管扫描分频（约190Hz刷新率，4位轮流显示）
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        scan_div <= 18'd0;
    else
        scan_div <= scan_div + 18'd1;
end

// 扫描计数器（每131072个时钟周期切换一位）
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        scan_cnt <= 2'd0;
    else if(scan_div == 18'd0)
        scan_cnt <= scan_cnt + 2'd1;
end

// 数码管输出控制
reg [7:0] seg7_r;
reg [3:0] com_r;

always @(*) begin
    if(boot_disp_en) begin
        // 上电显示"6666"：4位轮流扫描（DP不亮）
        seg7_r = SEG_6;  // 8'h67，DP=1(灭)，段a-g=显示"6"
        case(scan_cnt)
            2'd0: com_r = 4'b1110;  // 使能第1位（低电平有效）
            2'd1: com_r = 4'b1101;  // 使能第2位
            2'd2: com_r = 4'b1011;  // 使能第3位
            2'd3: com_r = 4'b0111;  // 使能第4位
            default: com_r = 4'b1111;
        endcase
    end else begin
        // 2秒后灭灯
        seg7_r = 8'hFF;   // 所有段熄灭（低电平点亮）
        com_r  = 4'hF;    // 所有位关闭（低电平使能）
    end
end

assign seg7 = seg7_r;
assign com  = com_r;

// 4. 实例化电梯核心控制模块
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