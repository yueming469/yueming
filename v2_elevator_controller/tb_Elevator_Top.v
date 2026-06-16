`timescale 1ns / 1ps

module tb_Elevator_Top;

// 信号声明
reg clk;
reg rst_n;
reg [7:0] key_raw;
reg [5:0] floor_sensor;
reg uart_rx;
wire [5:0] floor_led;
wire [1:0] dir_led;
wire [3:0] mode_led;
wire buzzer;
wire door_open;

// UART模块信号
wire [31:0] mode_cmd;
wire mode_update;

// 按键有效信号（直接取反原始按键，绕过消抖模块）
wire [7:0] key_valid = ~key_raw;

// UART解析模块
UART_Mode_Parse u_uart(
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx(uart_rx),
    .mode_cmd(mode_cmd),
    .mode_update(mode_update)
);

// 电梯核心模块
Elevator_Core u_core(
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

// 时钟生成（50MHz）
initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

// 波形输出
initial begin
    $dumpfile("E:\\zhongduan\\elevator.vcd");
    $dumpvars(0, tb_Elevator_Top);
end

// 测试序列
initial begin
    rst_n = 0;
    key_raw = 8'hFF;
    floor_sensor = 6'b000001;
    uart_rx = 1;

    #100;
    rst_n = 1;
    #100;

    // ========== Test 1: 按键控制（自动模式）==========
    $display("");
    $display("========================================");
    $display("=== Test 1: Key Control (Auto Mode) ===");
    $display("========================================");

    $display("Time=%0t: Press floor 4 button", $time);
    key_raw = 8'hF7; // key_raw[3] = 0 -> key_valid[3] = 1
    #1000;
    key_raw = 8'hFF;
    #5000;
    #10000;

    // ========== Test 2: 串口消防模式 ==========
    $display("");
    $display("==========================================");
    $display("=== Test 2: UART Command (Fire Mode) ===");
    $display("==========================================");
    $display("Time=%0t: Send FIRE command", $time);
    send_uart_byte(8'h46); // 'F'
    send_uart_byte(8'h49); // 'I'
    send_uart_byte(8'h52); // 'R'
    send_uart_byte(8'h45); // 'E'
    #500000;

    // ========== Test 3: 楼层传感器变化 ==========
    $display("");
    $display("==========================================");
    $display("=== Test 3: Floor Sensor Change ===");
    $display("==========================================");
    floor_sensor = 6'b000010;
    #500000;
    $display("Time=%0t: Floor 2", $time);
    floor_sensor = 6'b000100;
    #500000;
    $display("Time=%0t: Floor 3", $time);
    floor_sensor = 6'b001000;
    #500000;
    $display("Time=%0t: Floor 4", $time);

    // ========== Test 4: 手动模式 ==========
    $display("");
    $display("==========================================");
    $display("=== Test 4: Manual Mode Test ===");
    $display("==========================================");
    $display("Time=%0t: Send MANU command", $time);
    send_uart_byte(8'h4D); // 'M'
    send_uart_byte(8'h41); // 'A'
    send_uart_byte(8'h4E); // 'N'
    send_uart_byte(8'h55); // 'U'
    #500000;

    $display("Time=%0t: Press open door button", $time);
    key_raw = 8'hBF; // key_raw[6] = 0 -> key_valid[6] = 1
    #1000;
    key_raw = 8'hFF;
    #200000;

    $display("Time=%0t: Press close door button", $time);
    key_raw = 8'h7F; // key_raw[7] = 0 -> key_valid[7] = 1
    #1000;
    key_raw = 8'hFF;
    #200000;

    $display("");
    $display("================================");
    $display("=== Simulation Complete ===");
    $display("================================");
    $finish;
end

// UART发送任务
task send_uart_byte;
    input [7:0] data;
    integer i;
    begin
        uart_rx = 0;
        #104160;
        for(i = 0; i < 8; i = i + 1) begin
            uart_rx = data[i];
            #104160;
        end
        uart_rx = 1;
        #104160;
    end
endtask

// 信号监控
always @(posedge clk) begin
    if(u_core.current_state != u_core.next_state) begin
        case(u_core.next_state)
            3'd0: $display("Time=%0t: [STATE] -> IDLE", $time);
            3'd1: $display("Time=%0t: [STATE] -> UP (floor %0d -> %0d)", $time,
                     u_core.current_floor+1, u_core.target_floor+1);
            3'd2: $display("Time=%0t: [STATE] -> DOWN (floor %0d -> %0d)", $time,
                     u_core.current_floor+1, u_core.target_floor+1);
            3'd3: $display("Time=%0t: [STATE] -> OPEN_DOOR", $time);
            3'd4: $display("Time=%0t: [STATE] -> CLOSE_DOOR", $time);
            3'd5: $display("Time=%0t: [STATE] -> PROMPT", $time);
        endcase
    end
    if(u_core.mode_update) begin
        case(u_core.mode_cmd[1:0])
            2'd0: $display("Time=%0t: [MODE] -> AUTO", $time);
            2'd1: $display("Time=%0t: [MODE] -> MANUAL", $time);
            2'd2: $display("Time=%0t: [MODE] -> FIRE", $time);
            2'd3: $display("Time=%0t: [MODE] -> CHECK", $time);
        endcase
    end
    if(u_core.call_register != 6'd0)
        $display("Time=%0t: [CALL] register=%b", $time, u_core.call_register);
end

endmodule
