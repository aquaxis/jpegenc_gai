// 量子化モジュール
module quantizer (
    input logic clk,
    input logic rst_n,
    input logic [15:0] s_axis_tdata,
    input logic s_axis_tvalid,
    output logic s_axis_tready,
    input logic s_axis_tlast,
    input logic s_axis_tuser,
    output logic [15:0] m_axis_tdata,
    output logic m_axis_tvalid,
    input logic m_axis_tready,
    output logic m_axis_tlast,
    output logic m_axis_tuser,
    input logic is_luma
);

  // 量子化テーブルのインクルード
  `include "quantizer_table.svh"

  // ステート定義
  typedef enum logic [2:0] {
    IDLE,
    LOAD_DATA,
    SET_SCALE,
    CALC_TEMP,
    CALC_QUANT,
    OUTPUT,
    DONE
  } state_t;

  // 内部信号
  state_t state;
  logic signed [15:0] dct_data[0:63];  // DCTデータバッファ
  logic signed [15:0] quant_data[0:63];  // 量子化データバッファ
  logic [5:0] index;  // 処理中のインデックス (0-63)
  logic [2:0] u, v;  // 8x8ブロックの座標
  logic [5:0] load_counter;  // 入力データカウンタ
  logic [5:0] output_counter;  // 出力データカウンタ
  logic signed [63:0] temp_result;  // 中間計算結果（64ビットに変更）
  logic signed [31:0] alpha_u, alpha_v;  // スケーリング係数

  logic [15:0] temp_table;
  assign temp_table = (is_luma ? LUMA_QUANT_TABLE[v*8+u] : CHROMA_QUANT_TABLE[v*8+u]);

  // ステートマシン：状態更新と制御ロジック
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      s_axis_tready <= 1'b0;
      m_axis_tvalid <= 1'b0;
      m_axis_tdata <= 16'h0000;
      m_axis_tlast <= 1'b0;
      m_axis_tuser <= 1'b0;
      load_counter <= 0;
      output_counter <= 0;
      index <= 0;
      u <= 0;
      v <= 0;
      temp_result <= 0;
      alpha_u <= 0;
      alpha_v <= 0;
      for (int i = 0; i < 64; i++) begin
        dct_data[i]   <= 16'h0000;
        quant_data[i] <= 16'h0000;
      end
    end else begin
      case (state)
        IDLE: begin
          s_axis_tready <= 1'b1;
          m_axis_tvalid <= 1'b0;
          m_axis_tlast <= 1'b0;
          m_axis_tuser <= 1'b0;
          output_counter <= 0;
          index <= 0;
          u <= 0;
          v <= 0;
          if (s_axis_tvalid && s_axis_tready) begin
            dct_data[0] <= $signed(s_axis_tdata);
            load_counter <= 1;
            state <= LOAD_DATA;
          end
        end

        LOAD_DATA: begin
          if (s_axis_tvalid && s_axis_tready) begin
            dct_data[load_counter] <= $signed(s_axis_tdata);
            load_counter <= load_counter + 1;
          end
          if (load_counter == 63) begin
            state <= SET_SCALE;
            s_axis_tready <= 1'b0;
          end
        end

        SET_SCALE: begin
          // スケーリング係数の設定
          alpha_u <= (u == 0) ? 32'd5973 : 32'd8192;
          alpha_v <= (v == 0) ? 32'd5973 : 32'd8192;
          temp_result <= dct_data[v*8+u];
          state <= CALC_TEMP;
        end

        CALC_TEMP: begin
          // temp_resultの計算（64ビット）
          temp_result <= $signed(
              temp_result * alpha_u * alpha_v + (1 << (2 * 14 - 1))
          ) >>> (2 * 14);
          state <= CALC_QUANT;
        end

        CALC_QUANT: begin
          // quant_dataへの代入
          quant_data[v*8+u] <= $signed(
              temp_result / (is_luma ? LUMA_QUANT_TABLE[v*8+u] : CHROMA_QUANT_TABLE[v*8+u])
          );

          // インデックス更新
          if (u == 7) begin
            u <= 0;
            v <= v + 1;
          end else begin
            u <= u + 1;
          end
          index <= index + 1;

          if (index == 63) begin
            state <= OUTPUT;
          end else begin
            state <= SET_SCALE;
          end
        end

        OUTPUT: begin
          m_axis_tvalid <= 1'b1;
          m_axis_tdata  <= quant_data[output_counter];
          m_axis_tlast  <= (output_counter == 63);
          m_axis_tuser  <= (output_counter == 0) ? s_axis_tuser : 1'b0;
          if (m_axis_tready) begin
            output_counter <= output_counter + 1;
            if (output_counter == 63) begin
              state <= DONE;
            end
          end
        end

        DONE: begin
          m_axis_tvalid <= 1'b0;
          state <= IDLE;
          s_axis_tready <= 1'b1;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
