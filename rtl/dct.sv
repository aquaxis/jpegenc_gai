module dct (
    input logic clk,
    input logic rst_n,
    input logic [7:0] s_axis_tdata,
    input logic s_axis_tvalid,
    output logic s_axis_tready,
    input logic s_axis_tlast,
    input logic s_axis_tuser,
    output logic [15:0] m_axis_tdata,
    output logic m_axis_tvalid,
    input logic m_axis_tready,
    output logic m_axis_tlast,
    output logic m_axis_tuser
);

  // コサインテーブル（修正内容：削除し、`includeで外部ファイル参照）
  // localparam logic signed [15:0] COS_TABLE[8][8] = '... 削除
  `include "dct_table.svh"

  // ステート定義
  typedef enum logic [3:0] {
    IDLE,
    INPUT,
    DCT_CALC_DATA,  // データ取得
    DCT_CALC_U,     // COS_TABLE[u][x]乗算
    DCT_CALC_V,     // COS_TABLE[v][y]乗算
    DCT_CALC_ACC_WRITE,   // temp加算（書き込み）
    DCT_CALC_ACC_READ,    // temp読み込みとdct_out更新
    OUTPUT
  } state_t;

  // 変数宣言
  logic signed [7:0] block[7:0][7:0];  // 8x8ブロックバッファ
  logic [2:0] x_idx, y_idx;  // ブロック内インデックス
  logic signed [15:0] dct_out[7:0][7:0];  // DCT結果
  logic [2:0] u, v;  // DCT周波数インデックス
  logic [2:0] x, y;  // DCT計算用インデックス
  logic signed [63:0] temp;  // DCT計算用一時変数
  logic signed [31:0] data;  // 中間データ保持用
  state_t state;  // 現在のステート
  logic block_complete;  // ブロック完了フラグ

  // ステートマシンとロジック
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      x_idx <= 0;
      y_idx <= 0;
      u <= 0;
      v <= 0;
      x <= 0;
      y <= 0;
      temp <= 0;
      data <= 0;
      s_axis_tready <= 1;
      m_axis_tvalid <= 0;
      m_axis_tlast <= 0;
      m_axis_tuser <= 0;
      block_complete <= 0;
      for (int i = 0; i < 8; i++) begin
        for (int j = 0; j < 8; j++) begin
          block[i][j]   <= 0;
          dct_out[i][j] <= 0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          s_axis_tready <= 1;
          m_axis_tvalid <= 0;
          if (s_axis_tvalid) begin
            state <= INPUT;
            // 修正内容：block[y_idx][x_idx] <= s_axis_tdata; を block[0][0] <= s_axis_tdata; に変更
            block[0][0] <= $signed(s_axis_tdata);
            // 修正内容：x_idx=1, y_idx=0
            x_idx <= 1;
            y_idx <= 0;
          end
        end

        INPUT: begin
          if (s_axis_tvalid && s_axis_tready) begin
            block[y_idx][x_idx] <= $signed(s_axis_tdata);
            x_idx <= x_idx + 1;
            if (x_idx == 7) begin
              x_idx <= 0;
              y_idx <= y_idx + 1;
              if (y_idx == 7) begin
                y_idx <= 0;
                block_complete <= 1;
                state <= DCT_CALC_DATA;
                s_axis_tready <= 0;
              end
            end
          end
        end

        DCT_CALC_DATA: begin
          // データ取得
          data  <= block[y][x];
          state <= DCT_CALC_U;
        end

        DCT_CALC_U: begin
          // COS_TABLE[u][x]乗算とシフト
          data  <= (data * COS_TABLE[x][u] + (1 << (14 - 1))) >> 14;
          state <= DCT_CALC_V;
        end

        DCT_CALC_V: begin
          // COS_TABLE[v][y]乗算とシフト
          data  <= (data * COS_TABLE[y][v] + (1 << (14 - 1))) >> 14;
          state <= DCT_CALC_ACC_WRITE;
        end

        DCT_CALC_ACC_WRITE: begin
          // temp加算（書き込み）
          temp <= temp + data;

          // インデックス更新
          y <= y + 1;
          if (y == 7) begin
            y <= 0;
            x <= x + 1;
            if (x == 7) begin
              x <= 0;
              state <= DCT_CALC_ACC_READ;
            end else begin
              state <= DCT_CALC_DATA;
            end
          end else begin
            state <= DCT_CALC_DATA;
          end
        end

        DCT_CALC_ACC_READ: begin
          // temp読み込みとdct_out更新
          dct_out[v][u] <= temp[15:0];
          temp <= 0;
          u <= u + 1;
          if (u == 7) begin
            u <= 0;
            v <= v + 1;
            if (v == 7) begin
              v <= 0;
            end
          end

          // ステート遷移：y, x, u, vが全て7ならOUTPUT、それ以外はDCT_CALC_DATA
          if (u == 7 && v == 7 && m_axis_tready) begin
            state <= OUTPUT;
            u <= 0;
            v <= 0;
          end else begin
            state <= DCT_CALC_DATA;
          end
        end

        OUTPUT: begin
          if (m_axis_tready) begin
            m_axis_tdata <= dct_out[v][u];
            m_axis_tvalid <= 1;
            m_axis_tlast <= (u == 7 && v == 7) ? s_axis_tlast : 1'b0;
            m_axis_tuser <= (u == 0 && v == 0) ? s_axis_tuser : 1'b0;
            u <= u + 1;
            if (u == 7) begin
              u <= 0;
              v <= v + 1;
              if (v == 7) begin
                v <= 0;
                state <= IDLE;
                block_complete <= 0;
                // 修正内容：IDLEに戻る時にs_axis_tready <= 1; を追加
                s_axis_tready <= 1;
                // m_axis_tvalid <= 0; （コメントアウトされていたのでそのまま）
              end
            end
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
