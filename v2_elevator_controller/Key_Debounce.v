// 按键消抖模块：对8个按键进行消抖，输出稳定有效信号
module Key_Debounce(
    input clk,
    input rst_n,
    input [7:0] key_in,
    output reg [7:0] key_valid
);

// 消抖参数（仿真用小值）
parameter DEBOUNCE_MAX = 20'd1_000_000; // 20ms @ 50MHz

// 每个按键独立的消抖计数器和状态
reg [19:0] cnt0, cnt1, cnt2, cnt3, cnt4, cnt5, cnt6, cnt7;
reg [7:0] key_sync1, key_sync2;
reg [7:0] key_stable, key_prev;

// 同步
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        key_sync1 <= 8'hff;
        key_sync2 <= 8'hff;
    end else begin
        key_sync1 <= key_in;
        key_sync2 <= key_sync1;
    end
end

// 消抖计数器 - 按键0
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt0 <= 20'd0;
        key_stable[0] <= 1'b1;
    end else if(key_sync2[0] != key_stable[0]) begin
        cnt0 <= 20'd0;
    end else if(cnt0 < DEBOUNCE_MAX) begin
        cnt0 <= cnt0 + 20'd1;
    end else begin
        key_stable[0] <= key_sync2[0];
    end
end

// 消抖计数器 - 按键1
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt1 <= 20'd0;
        key_stable[1] <= 1'b1;
    end else if(key_sync2[1] != key_stable[1]) begin
        cnt1 <= 20'd0;
    end else if(cnt1 < DEBOUNCE_MAX) begin
        cnt1 <= cnt1 + 20'd1;
    end else begin
        key_stable[1] <= key_sync2[1];
    end
end

// 消抖计数器 - 按键2
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt2 <= 20'd0;
        key_stable[2] <= 1'b1;
    end else if(key_sync2[2] != key_stable[2]) begin
        cnt2 <= 20'd0;
    end else if(cnt2 < DEBOUNCE_MAX) begin
        cnt2 <= cnt2 + 20'd1;
    end else begin
        key_stable[2] <= key_sync2[2];
    end
end

// 消抖计数器 - 按键3
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt3 <= 20'd0;
        key_stable[3] <= 1'b1;
    end else if(key_sync2[3] != key_stable[3]) begin
        cnt3 <= 20'd0;
    end else if(cnt3 < DEBOUNCE_MAX) begin
        cnt3 <= cnt3 + 20'd1;
    end else begin
        key_stable[3] <= key_sync2[3];
    end
end

// 消抖计数器 - 按键4
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt4 <= 20'd0;
        key_stable[4] <= 1'b1;
    end else if(key_sync2[4] != key_stable[4]) begin
        cnt4 <= 20'd0;
    end else if(cnt4 < DEBOUNCE_MAX) begin
        cnt4 <= cnt4 + 20'd1;
    end else begin
        key_stable[4] <= key_sync2[4];
    end
end

// 消抖计数器 - 按键5
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt5 <= 20'd0;
        key_stable[5] <= 1'b1;
    end else if(key_sync2[5] != key_stable[5]) begin
        cnt5 <= 20'd0;
    end else if(cnt5 < DEBOUNCE_MAX) begin
        cnt5 <= cnt5 + 20'd1;
    end else begin
        key_stable[5] <= key_sync2[5];
    end
end

// 消抖计数器 - 按键6
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt6 <= 20'd0;
        key_stable[6] <= 1'b1;
    end else if(key_sync2[6] != key_stable[6]) begin
        cnt6 <= 20'd0;
    end else if(cnt6 < DEBOUNCE_MAX) begin
        cnt6 <= cnt6 + 20'd1;
    end else begin
        key_stable[6] <= key_sync2[6];
    end
end

// 消抖计数器 - 按键7
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt7 <= 20'd0;
        key_stable[7] <= 1'b1;
    end else if(key_sync2[7] != key_stable[7]) begin
        cnt7 <= 20'd0;
    end else if(cnt7 < DEBOUNCE_MAX) begin
        cnt7 <= cnt7 + 20'd1;
    end else begin
        key_stable[7] <= key_sync2[7];
    end
end

// 下降沿检测：按键从未按下变为按下时，输出一个时钟周期的高脉冲
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        key_valid <= 8'd0;
        key_prev <= 8'hff;
    end else begin
        key_prev <= key_stable;
        key_valid <= key_prev & (~key_stable);
    end
end

endmodule
