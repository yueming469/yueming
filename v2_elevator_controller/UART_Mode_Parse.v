// UART接收与模式解析模块：实现9600bps串口接收，解析PC端模式控制指令
module UART_Mode_Parse(
    input clk,              // 系统时钟（50MHz）
    input rst_n,            // 复位信号（低电平有效）
    input uart_rx,          // UART接收引脚
    output reg [31:0]mode_cmd, // 解析后的模式指令
    output reg mode_update     // 模式更新标志（高电平脉冲有效）
);

reg [15:0] cnt_baud;
reg [3:0] cnt_bit;
reg [7:0] uart_data;
reg [7:0] cmd_buf0, cmd_buf1, cmd_buf2, cmd_buf3;
reg [2:0] cmd_cnt;
reg uart_rx_sync1, uart_rx_sync2, uart_rx_sync3;
wire uart_rx_neg;
reg recv_flag;

parameter BAUD_CNT = 16'd5207;
parameter BAUD_HALF = 16'd2603;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        uart_rx_sync1 <= 1'b1;
        uart_rx_sync2 <= 1'b1;
        uart_rx_sync3 <= 1'b1;
    end else begin
        uart_rx_sync1 <= uart_rx;
        uart_rx_sync2 <= uart_rx_sync1;
        uart_rx_sync3 <= uart_rx_sync2;
    end
end
assign uart_rx_neg = ~uart_rx_sync2 & uart_rx_sync3;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt_baud <= 16'd0;
        cnt_bit <= 4'd0;
        recv_flag <= 1'b0;
        uart_data <= 8'd0;
    end else begin
        if(uart_rx_neg && cnt_bit == 4'd0) begin
            cnt_baud <= BAUD_HALF;
            cnt_bit <= 4'd1;
        end else if(cnt_bit > 4'd0) begin
            if(cnt_baud == BAUD_CNT) begin
                cnt_baud <= 16'd0;
                cnt_bit <= cnt_bit + 4'd1;
                if(cnt_bit >= 4'd2 && cnt_bit <= 4'd9) begin
                    uart_data[cnt_bit-2] <= uart_rx_sync2;
                end
                if(cnt_bit == 4'd10) begin
                    recv_flag <= 1'b1;
                    cnt_bit <= 4'd0;
                end
            end else begin
                cnt_baud <= cnt_baud + 16'd1;
            end
        end else begin
            recv_flag <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cmd_buf0 <= 8'd0;
        cmd_buf1 <= 8'd0;
        cmd_buf2 <= 8'd0;
        cmd_buf3 <= 8'd0;
        cmd_cnt <= 3'd0;
        mode_cmd <= 32'd0;
        mode_update <= 1'b0;
    end else if(recv_flag) begin
        case(cmd_cnt)
            3'd0: cmd_buf0 <= uart_data;
            3'd1: cmd_buf1 <= uart_data;
            3'd2: cmd_buf2 <= uart_data;
            3'd3: cmd_buf3 <= uart_data;
        endcase
        cmd_cnt <= cmd_cnt + 3'd1;

        if(cmd_cnt == 3'd3) begin
            cmd_cnt <= 3'd0;
            mode_update <= 1'b1;
            if(cmd_buf0 == "A" && cmd_buf1 == "U" && cmd_buf2 == "T" && uart_data == "O")
                mode_cmd <= 32'd0;
            else if(cmd_buf0 == "M" && cmd_buf1 == "A" && cmd_buf2 == "N" && uart_data == "U")
                mode_cmd <= 32'd1;
            else if(cmd_buf0 == "F" && cmd_buf1 == "I" && cmd_buf2 == "R" && uart_data == "E")
                mode_cmd <= 32'd2;
            else if(cmd_buf0 == "C" && cmd_buf1 == "H" && cmd_buf2 == "E" && uart_data == "C")
                mode_cmd <= 32'd3;
            else
                mode_update <= 1'b0;
        end else begin
            mode_update <= 1'b0;
        end
    end else begin
        mode_update <= 1'b0;
    end
end

endmodule
