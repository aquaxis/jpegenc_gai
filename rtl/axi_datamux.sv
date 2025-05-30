module axi_datamux #(
    parameter DATA_WIDTH = 32  // tdataの幅を32ビットに変更
) (
    input logic clk,
    input logic rst_n,

    // Input AXI-Stream (y)
    input  logic [DATA_WIDTH-1:0] s_axis_y_tdata,
    input  logic                  s_axis_y_tvalid,
    output logic                  s_axis_y_tready,
    input  logic                  s_axis_y_tlast,
    input  logic                  s_axis_y_tuser,

    // Input AXI-Stream (cb)
    input  logic [DATA_WIDTH-1:0] s_axis_cb_tdata,
    input  logic                  s_axis_cb_tvalid,
    output logic                  s_axis_cb_tready,
    input  logic                  s_axis_cb_tlast,
    input  logic                  s_axis_cb_tuser,

    // Input AXI-Stream (cr)
    input  logic [DATA_WIDTH-1:0] s_axis_cr_tdata,
    input  logic                  s_axis_cr_tvalid,
    output logic                  s_axis_cr_tready,
    input  logic                  s_axis_cr_tlast,
    input  logic                  s_axis_cr_tuser,

    // Output AXI-Stream
    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready,
    output logic                  m_axis_tlast,
    output logic                  m_axis_tuser
);

  // 内部信号
  logic [DATA_WIDTH-1:0] y_buffer[0:3][0:1023];  // yの4ブロック分
  logic [DATA_WIDTH-1:0] cb_buffer[0:1023];  // cbの1ブロック分
  logic [DATA_WIDTH-1:0] cr_buffer[0:1023];  // crの1ブロック分
  logic [9:0] y_count[0:3];  // 各yブロックのデータカウンタ
  logic [9:0] cb_count;  // cbブロックのデータカウンタ
  logic [9:0] cr_count;  // crブロックのデータカウンタ
  logic [1:0] y_block_count;  // yブロック数カウンタ
  logic y_complete;  // yの4ブロック受信完了フラグ
  logic cb_complete;  // cbの1ブロック受信完了フラグ
  logic cr_complete;  // crの1ブロック受信完了フラグ
  logic [9:0] out_count;  // 出力データカウンタ
  logic [2:0] out_state;  // 出力状態（0:アイドル, 1:y出力, 2:cb出力, 3:cr出力）
  logic [1:0] out_y_block;  // 出力中のyブロック番号

  // 状態マシン用定数
  localparam IDLE = 3'd0, OUT_Y = 3'd1, OUT_CB = 3'd2, OUT_CR = 3'd3;

  // リセットと入力処理
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_axis_y_tready <= 1'b1;
      s_axis_cb_tready <= 1'b1;
      s_axis_cr_tready <= 1'b1;
      y_block_count <= 2'd0;
      y_count[0] <= 10'd0;
      y_count[1] <= 10'd0;
      y_count[2] <= 10'd0;
      y_count[3] <= 10'd0;
      cb_count <= 10'd0;
      cr_count <= 10'd0;
      y_complete <= 1'b0;
      cb_complete <= 1'b0;
      cr_complete <= 1'b0;
      out_count <= 10'd0;
      out_state <= IDLE;
      out_y_block <= 2'd0;
      m_axis_tvalid <= 1'b0;
      m_axis_tuser <= 1'b0;
      m_axis_tlast <= 1'b0;
    end else begin
      // y入力処理
      if (out_state != IDLE) begin
        y_complete <= 1'b0;
      end else if (s_axis_y_tvalid && s_axis_y_tready) begin
        y_buffer[y_block_count][y_count[y_block_count]] <= s_axis_y_tdata;
        y_count[y_block_count] <= y_count[y_block_count] + 1;

        if (s_axis_y_tlast) begin
          y_block_count <= y_block_count + 1;
          y_count[y_block_count+1] <= 10'd0;
          if (y_block_count == 2'd3) begin
            y_complete <= 1'b1;
            s_axis_y_tready <= 1'b0;
          end
        end
      end

      // cb入力処理
      if (out_state != IDLE) begin
        cb_complete <= 1'b0;
      end else if (s_axis_cb_tvalid && s_axis_cb_tready) begin
        cb_buffer[cb_count] <= s_axis_cb_tdata;
        cb_count <= cb_count + 1;

        if (s_axis_cb_tlast) begin
          cb_complete <= 1'b1;
          s_axis_cb_tready <= 1'b0;
        end
      end

      // cr入力処理
      if (out_state != IDLE) begin
        cr_complete <= 1'b0;
      end else if (s_axis_cr_tvalid && s_axis_cr_tready) begin
        cr_buffer[cr_count] <= s_axis_cr_tdata;
        cr_count <= cr_count + 1;

        if (s_axis_cr_tlast) begin
          cr_complete <= 1'b1;
          s_axis_cr_tready <= 1'b0;
        end
      end

      // 出力処理
      case (out_state)
        IDLE: begin
          if (y_complete && cb_complete && cr_complete && m_axis_tready) begin
            out_state <= OUT_Y;
            m_axis_tvalid <= 1'b1;
            m_axis_tuser <= 1'b1;  // OUT_Yの最初でtuser有効
            m_axis_tdata <= y_buffer[0][0];
            out_count <= 10'd1;
          end
        end

        OUT_Y: begin
          if (m_axis_tready) begin
            m_axis_tuser <= 1'b0;  // OUT_Yの2データ目以降はtuser無効
            m_axis_tlast <= 1'b0;  // OUT_Yではtlast無効

            if (out_count < y_count[out_y_block]) begin
              m_axis_tdata <= y_buffer[out_y_block][out_count];
              out_count <= out_count + 1;
            end

            if (out_count == y_count[out_y_block]) begin
              out_count <= 10'd0;
              if (out_y_block == 2'd3) begin
                out_state <= OUT_CB;
                m_axis_tdata <= cb_buffer[0];
                out_count <= 10'd1;
              end else begin
                out_y_block <= out_y_block + 1;
                m_axis_tdata <= y_buffer[out_y_block+1][0];
                out_count <= 10'd1;
              end
            end
          end
        end

        OUT_CB: begin
          if (m_axis_tready) begin
            m_axis_tuser <= 1'b0;  // OUT_CBではtuser無効
            m_axis_tlast <= 1'b0;  // OUT_CBではtlast無効

            if (out_count < cb_count) begin
              m_axis_tdata <= cb_buffer[out_count];
              out_count <= out_count + 1;
            end

            if (out_count == cb_count) begin
              out_state <= OUT_CR;
              m_axis_tdata <= cr_buffer[0];
              out_count <= 10'd1;
            end
          end
        end

        OUT_CR: begin
          if (m_axis_tready) begin
            m_axis_tuser <= 1'b0;  // OUT_CRではtuser無効
            if (out_count == cr_count - 1) begin
              m_axis_tlast <= 1'b1;  // OUT_CRの最後のデータでtlast有効
            end else begin
              m_axis_tlast <= 1'b0;
            end

            if (out_count < cr_count) begin
              m_axis_tdata <= cr_buffer[out_count];
              out_count <= out_count + 1;
            end

            if (m_axis_tlast) begin
              m_axis_tlast <= 1'b0;
              out_state <= IDLE;
              m_axis_tvalid <= 1'b0;
              // リセット（完了フラグは入力処理で管理）
              y_block_count <= 2'd0;
              y_count[0] <= 10'd0;
              y_count[1] <= 10'd0;
              y_count[2] <= 10'd0;
              y_count[3] <= 10'd0;
              cb_count <= 10'd0;
              cr_count <= 10'd0;
              s_axis_y_tready <= 1'b1;
              s_axis_cb_tready <= 1'b1;
              s_axis_cr_tready <= 1'b1;
              out_y_block <= 2'd0;
            end
          end
        end
      endcase
    end
  end

endmodule
