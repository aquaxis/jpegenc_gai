module zigzag_scanner (
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
    output logic m_axis_tuser
);

  // ジグザグテーブル（変更なし）
  localparam [5:0] ZIGZAG[0:63] = '{
      0,
      1,
      5,
      6,
      14,
      15,
      27,
      28,
      2,
      4,
      7,
      13,
      16,
      26,
      29,
      42,
      3,
      8,
      12,
      17,
      25,
      30,
      41,
      43,
      9,
      11,
      18,
      24,
      31,
      40,
      44,
      53,
      10,
      19,
      23,
      32,
      39,
      45,
      52,
      54,
      20,
      22,
      33,
      38,
      46,
      51,
      55,
      60,
      21,
      34,
      37,
      47,
      50,
      56,
      59,
      61,
      35,
      36,
      48,
      49,
      57,
      58,
      62,
      63
  };

  // ステート定義
  typedef enum logic [1:0] {
    IDLE,   // 入力待ち
    INPUT,  // 入力処理
    OUTPUT  // 出力処理
  } state_t;

  // モジュールスコープでの変数宣言
  logic   [15:0] block                                [63:0];  // 入力データバッファ
  logic   [ 5:0] in_idx;  // 入力インデックス
  logic   [ 5:0] out_idx;  // 出力インデックス
  state_t        state;  // 現在のステート

  // ステートマシンと制御ロジック
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      in_idx <= 0;
      out_idx <= 0;
      m_axis_tvalid <= 0;
      s_axis_tready <= 1;
      m_axis_tlast <= 0;
      m_axis_tuser <= 0;
    end else begin
      case (state)
        IDLE: begin
          m_axis_tvalid <= 0;
          m_axis_tlast <= 0;
          m_axis_tuser <= 0;
          s_axis_tready <= 1;
          in_idx <= 0;
          out_idx <= 0;
          if (s_axis_tvalid) begin
            state <= INPUT;
            block[0] <= s_axis_tdata;
            in_idx <= 1;
          end
        end

        INPUT: begin
          if (s_axis_tvalid && s_axis_tready) begin
            block[in_idx] <= s_axis_tdata;
            in_idx <= in_idx + 1;
            if (in_idx == 63) begin
              state <= OUTPUT;
              s_axis_tready <= 0;
              out_idx <= 0;
            end
          end
        end

        OUTPUT: begin
          if (m_axis_tready) begin
            m_axis_tdata <= block[ZIGZAG[out_idx]];
            m_axis_tvalid <= 1;
            m_axis_tlast <= (out_idx == 63) ? s_axis_tlast : 1'b0;
            m_axis_tuser <= (out_idx == 0) ? s_axis_tuser : 1'b0;
            out_idx <= out_idx + 1;
            if (out_idx == 63) begin
              state <= IDLE;
              s_axis_tready <= 1;
              //              m_axis_tvalid <= 0;
            end
          end
        end

        default: begin
          state <= IDLE;
          m_axis_tvalid <= 0;
          s_axis_tready <= 1;
          m_axis_tlast <= 0;
          m_axis_tuser <= 0;
        end
      endcase
    end
  end

endmodule
