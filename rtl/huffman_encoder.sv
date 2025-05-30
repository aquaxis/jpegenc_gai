module huffman_encoder (
    input logic clk,
    input logic rst_n,
    input logic [15:0] s_axis_tdata,  // ジグザグスキャン済みデータ (16-bit)
    input logic s_axis_tvalid,
    output logic s_axis_tready,
    input logic s_axis_tlast,  // 64番目のデータで1
    input logic s_axis_tuser,  // 1番目のデータで1
    output logic [31:0] m_axis_tdata,  // ハフマン符号 (32-bitパック)
    output logic m_axis_tvalid,
    input logic m_axis_tready,
    output logic m_axis_tlast,
    output logic m_axis_tuser,
    input logic is_luma  // 1: 輝度(Y), 0: 色差(Cb/Cr)
);

  // ビット文字列構造体
  typedef struct packed {
    logic [15:0] value;
    logic [3:0]  length;
  } BitString;

  // メインステート定義（ENCODE_DC_SECONDを追加）
  typedef enum logic [3:0] {
    IDLE,
    LOAD_DC,
    CHECK_DC_DIFF,
    ENCODE_DC,
    ENCODE_DC_SECOND,  // 新しい状態: output_bs[write_ptr+1]の更新用
    LOAD_AC,
    COUNT_ZEROS,
    ENCODE_AC,
    ENCODE_AC_SECOND,  // 新しい状態: gbc_done時の2番目のoutput_bs更新用
    OUTPUT_EOB,
    OUTPUT_BUFFER
  } main_state_t;

  // getBitCode用ステート定義
  typedef enum logic [1:0] {
    GETBITCODE_INIT,
    GETBITCODE_COUNT,
    GETBITCODE_DONE
  } getbitcode_state_t;

  // レジスタ
  main_state_t main_state;
  getbitcode_state_t getbitcode_state;
  logic [15:0] DU[0:63];  // ジグザグスキャン済みデータ
  logic [5:0] data_idx;  // データインデックス
  logic [15:0] prevDC;  // 前回のDC値
  logic [5:0] end_pos;  // 最後の非ゼロ係数の位置
  logic [6:0] ac_idx;  // 現在のAC係数インデックス
  logic [3:0] zero_counts;  // ゼロの連続数
  BitString output_bs[0:127];  // 出力ビット文字列バッファ
  logic [6:0] read_ptr;  // 読み出しポインタ
  logic [6:0] write_ptr;  // 書き込みポインタ
  logic [31:0] bit_buffer;  // 出力ビットバッファ
  logic [5:0] bit_count;  // ビットバッファ内のビット数

  // getBitCode用レジスタ
  logic [15:0] gbc_value;  // 入力値
  logic [15:0] gbc_abs_v;  // 絶対値
  logic [3:0] gbc_length;  // ビット長
  BitString gbc_result;  // 結果
  logic gbc_start;  // getBitCode開始信号
  logic gbc_done;  // getBitCode完了信号

  logic [15:0] dc_diff;

  `include "huffman_encoder_table.svh"

  // EOBとSIXTEEN_ZEROS
  BitString EOB;
  BitString SIXTEEN_ZEROS;

  // EOBとSIXTEEN_ZEROSの初期化
  initial begin
    EOB           = {16'h0000, 4'd2};  // 仮のEOBコード
    SIXTEEN_ZEROS = {16'h0000, 4'd4};  // 仮の16ゼロコード
  end

  // メインステートマシンとgetBitCodeステートマシン
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      main_state <= IDLE;
      getbitcode_state <= GETBITCODE_INIT;
      data_idx <= 0;
      prevDC <= 0;
      end_pos <= 63;
      ac_idx <= 1;
      zero_counts <= 0;
      read_ptr <= 0;
      write_ptr <= 0;
      bit_buffer <= 0;
      bit_count <= 0;
      s_axis_tready <= 1;
      m_axis_tvalid <= 0;
      m_axis_tlast <= 0;
      m_axis_tuser <= 0;
      gbc_value <= 0;
      gbc_abs_v <= 0;
      gbc_length <= 0;
      gbc_result <= '{value: 0, length: 0};
      gbc_start <= 0;
      gbc_done <= 0;
    end else begin
      // getBitCodeステートマシン
      case (getbitcode_state)
        GETBITCODE_INIT: begin
          if (gbc_start) begin
            gbc_abs_v <= (gbc_value[15] == 0) ? gbc_value : -gbc_value;
            gbc_length <= 0;
            getbitcode_state <= GETBITCODE_COUNT;
          end
        end

        GETBITCODE_COUNT: begin
          if (gbc_abs_v != 0) begin
            gbc_abs_v  <= gbc_abs_v >> 1;
            gbc_length <= gbc_length + 1;
          end else begin
            gbc_result.value <= (gbc_value[15] == 0) ? gbc_value : ((1 << gbc_length) + gbc_value - 1);
            gbc_result.length <= gbc_length;
            gbc_done <= 1;
            getbitcode_state <= GETBITCODE_DONE;
          end
        end

        GETBITCODE_DONE: begin
          if (!gbc_start) begin
            gbc_done <= 0;
            getbitcode_state <= GETBITCODE_INIT;
          end
        end

        default: getbitcode_state <= GETBITCODE_INIT;
      endcase

      // メインステートマシン
      case (main_state)
        IDLE: begin
          if (s_axis_tvalid && s_axis_tready) begin
            DU[data_idx] <= s_axis_tdata;
            // 修正: data_idx の複数更新を防ぐ。s_axis_tuser が1なら data_idx <= 0 のみを優先
            if (s_axis_tuser) begin
              data_idx <= 0;  // ブロックの最初でリセット
            end else begin
              data_idx <= data_idx + 1;  // 通常のインクリメント
            end
            if (data_idx == 63) begin
              main_state <= LOAD_DC;
              data_idx <= 0;
              s_axis_tready <= 0;
              read_ptr <= 0;
              write_ptr <= 0;
            end
          end
          m_axis_tvalid <= 0;
          m_axis_tlast  <= 0;
          m_axis_tuser  <= 0;
        end

        LOAD_DC: begin
          dc_diff <= DU[0] - prevDC;
          prevDC <= DU[0];
          main_state <= CHECK_DC_DIFF;
        end

        CHECK_DC_DIFF: begin
          if (dc_diff == 0) begin
            output_bs[write_ptr] <= is_luma ? y_dc_table[0] : cbcr_dc_table[0];
            write_ptr <= write_ptr + 1;
            main_state <= LOAD_AC;
          end else begin
            gbc_value  <= dc_diff;
            gbc_start  <= 1;
            main_state <= ENCODE_DC;
          end
        end

        ENCODE_DC: begin
          if (gbc_done) begin
            output_bs[write_ptr] <= is_luma ? y_dc_table[gbc_result.length] : cbcr_dc_table[gbc_result.length];
            write_ptr <= write_ptr + 1;  // 修正: 1つ目の更新後、次の状態で2つ目を処理
            gbc_start <= 0;
            main_state <= ENCODE_DC_SECOND;  // 新しい状態へ
          end
        end

        // 新しい状態: output_bs[write_ptr+1] の更新
        ENCODE_DC_SECOND: begin
          output_bs[write_ptr] <= gbc_result;  // write_ptr は前のサイクルで+1済み
          write_ptr <= write_ptr + 1;
          main_state <= LOAD_AC;
        end

        LOAD_AC: begin
          if (end_pos > 0 && DU[end_pos] == 0) begin
            end_pos <= end_pos - 1;
          end else begin
            main_state <= COUNT_ZEROS;
          end
        end

        COUNT_ZEROS: begin
          if (ac_idx <= end_pos) begin
            if (DU[ac_idx] == 0) begin
              zero_counts <= zero_counts + 1;
              ac_idx <= ac_idx + 1;
              main_state <= COUNT_ZEROS;
            end else begin
              main_state <= ENCODE_AC;
            end
          end else begin
            main_state <= OUTPUT_EOB;
          end
        end

        ENCODE_AC: begin
          // 修正: zero_counts >= 16 と gbc_done の処理を分離
          if (gbc_done) begin
            // gbc_done を優先
            output_bs[write_ptr] <= is_luma ? y_ac_table[(zero_counts << 4) | gbc_result.length] : cbcr_ac_table[(zero_counts << 4) | gbc_result.length];
            write_ptr <= write_ptr + 1;
            gbc_start <= 0;
            main_state <= ENCODE_AC_SECOND;  // 2番目の output_bs 更新へ
          end else if (zero_counts >= 16) begin
            output_bs[write_ptr] <= is_luma ? y_ac_table[8'hF0] : cbcr_ac_table[8'hF0]; // SIXTEEN_ZEROS
            write_ptr <= write_ptr + 1;
            zero_counts <= zero_counts - 16;
            main_state <= ENCODE_AC;  // ゼロが残っていれば継続
          end else begin
            gbc_value  <= DU[ac_idx];
            gbc_start  <= 1;
            main_state <= ENCODE_AC;
          end
        end

        // 新しい状態: gbc_done 時の2番目の output_bs 更新
        ENCODE_AC_SECOND: begin
          output_bs[write_ptr] <= gbc_result;
          write_ptr <= write_ptr + 1;
          ac_idx <= ac_idx + 1;
          main_state <= COUNT_ZEROS;
        end

        OUTPUT_EOB: begin
          if (end_pos != 63) begin
            output_bs[write_ptr] <= is_luma ? y_ac_table[8'h00] : cbcr_ac_table[8'h00];  // EOB
            write_ptr <= write_ptr + 1;
          end
          main_state <= OUTPUT_BUFFER;
        end

        OUTPUT_BUFFER: begin
          if ((read_ptr + 1 == write_ptr) && m_axis_tready) begin
            main_state <= IDLE;
          end
          s_axis_tready <= 1;
          m_axis_tvalid <= (write_ptr > read_ptr);
          m_axis_tdata <= {12'd0, output_bs[read_ptr].length, output_bs[read_ptr].value};
          m_axis_tlast <= (read_ptr + 1 == write_ptr);
          m_axis_tuser <= (read_ptr == 0);
          end_pos <= 63;
          ac_idx <= 1;
          if (m_axis_tready) begin
            read_ptr <= read_ptr + 1;
          end
        end

        default: begin
          main_state <= IDLE;
          m_axis_tvalid <= 0;
        end
      endcase
    end
  end

endmodule
