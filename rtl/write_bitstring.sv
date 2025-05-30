// モジュール定義
module write_bitstring (
    input logic clk,
    input logic rst_n,
    // AXI4-Stream Slave Interface
    input logic [31:0] s_axis_tdata,  // {12'd0, length[3:0], value[15:0]}
    input logic s_axis_tvalid,
    input logic s_axis_tuser,  // 最初のデータ
    input logic s_axis_tlast,  // 最後のデータ
    output logic s_axis_tready,
    // AXI4-Stream Master Interface (出力バイト用)
    output logic [7:0] m_axis_tdata,
    output logic m_axis_tvalid,
    output logic m_axis_tuser,  // 最初のバイト
    output logic m_axis_tlast,  // 最後のバイト
    input logic m_axis_tready
);

  // ビット文字列構造体（SystemVerilog形式）
  typedef struct packed {
    logic [15:0] value;
    logic [3:0]  length;
  } BitString;

  // ステート定義
  typedef enum logic [2:0] {
    IDLE,
    LOAD_DATA,
    PROCESS_BIT,
    WRITE_BYTE,
    WRITE_STUFFING
  } state_t;

  // 内部レジスタ
  state_t state;
  BitString bs_buffer[0:127];  // 最大128ワード
  logic [6:0] buf_count;  // バッファ内のデータ数
  logic [6:0] buf_index;  // 現在の処理データインデックス
  logic [3:0] bit_pos;  // 現在のビット位置
  logic [7:0] new_byte;  // 出力バイト
  logic [2:0] new_byte_pos;  // バイト内のビット位置
  logic [15:0] mask[0:15];  // マスク配列
  logic first_byte;  // 最初のバイトフラグ
  logic last_data;  // 最後のデータフラグ

  // マスクの初期化（シミュレーション用）
  initial begin
    mask[0]  = 16'h0001;
    mask[1]  = 16'h0002;
    mask[2]  = 16'h0004;
    mask[3]  = 16'h0008;
    mask[4]  = 16'h0010;
    mask[5]  = 16'h0020;
    mask[6]  = 16'h0040;
    mask[7]  = 16'h0080;
    mask[8]  = 16'h0100;
    mask[9]  = 16'h0200;
    mask[10] = 16'h0400;
    mask[11] = 16'h0800;
    mask[12] = 16'h1000;
    mask[13] = 16'h2000;
    mask[14] = 16'h4000;
    mask[15] = 16'h8000;
  end

  // ステートマシン
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      buf_count <= 0;
      buf_index <= 0;
      bit_pos <= 0;
      new_byte <= 0;
      new_byte_pos <= 7;
      s_axis_tready <= 0;
      m_axis_tvalid <= 0;
      m_axis_tdata <= 0;
      m_axis_tuser <= 0;
      m_axis_tlast <= 0;
      first_byte <= 0;
      last_data <= 0;
    end else begin
      case (state)
        IDLE: begin
          s_axis_tready <= 1;
          m_axis_tvalid <= 0;
          m_axis_tuser <= 0;
          m_axis_tlast <= 0;
          buf_count <= 0;
          buf_index <= 0;
          /*
          // 追加処理: s_axis_tuserが1の場合に初期化
          if (s_axis_tvalid && s_axis_tuser) begin
            new_byte <= 0;
            new_byte_pos <= 7;
            first_byte <= 1;  // 最初のデータを受信
            last_data <= 0;
            bit_pos <= 0;
          end
*/
          // 既存処理: s_axis_tvalidでデータ受信と状態遷移
          if (s_axis_tvalid) begin
            bs_buffer[0].value <= s_axis_tdata[15:0];
            bs_buffer[0].length <= s_axis_tdata[19:16];
            buf_count <= 1;
            if (!s_axis_tuser) begin
              first_byte <= 0;  // s_axis_tuserが0ならfirst_byteをクリア
            end
            state <= LOAD_DATA;
          end
        end

        LOAD_DATA: begin
          if (s_axis_tvalid && s_axis_tready) begin
            bs_buffer[buf_count].value <= s_axis_tdata[15:0];
            bs_buffer[buf_count].length <= s_axis_tdata[19:16];
            buf_count <= buf_count + 1;
            if (s_axis_tlast) begin
              last_data <= 1;  // 最後のデータを受信
            end
            if (s_axis_tlast || buf_count == 127) begin
              s_axis_tready <= 0;
              state <= PROCESS_BIT;
            end
          end
        end

        PROCESS_BIT: begin
          m_axis_tvalid <= 0;
          m_axis_tuser  <= 0;
          m_axis_tlast  <= 0;
          if (bit_pos < bs_buffer[buf_index].length) begin
            if (bs_buffer[buf_index].value & mask[bs_buffer[buf_index].length-bit_pos-1]) begin
              new_byte <= new_byte | (1 << new_byte_pos);
            end
            bit_pos <= bit_pos + 1;
            new_byte_pos <= new_byte_pos - 1;
            if (new_byte_pos == 0) begin
              state <= WRITE_BYTE;
            end
          end else begin
            buf_index <= buf_index + 1;
            bit_pos   <= 0;
            if (buf_index + 1 >= buf_count) begin
              state <= IDLE;
            end
          end
        end

        WRITE_BYTE: begin
          m_axis_tvalid <= 1;
          m_axis_tdata <= new_byte;
          m_axis_tuser <= first_byte;  // 最初のバイトなら1
          m_axis_tlast <= (last_data && buf_index + 1 >= buf_count && bit_pos >= bs_buffer[buf_index].length && new_byte_pos == 0); // 最後のバイトなら1
          if (m_axis_tready) begin
            new_byte <= 0;
            new_byte_pos <= 7;
            first_byte <= 0;  // 最初のバイト出力後はクリア
            if (new_byte == 8'hFF) begin
              state <= WRITE_STUFFING;
            end else begin
              state <= PROCESS_BIT;
            end
          end
        end

        WRITE_STUFFING: begin
          m_axis_tvalid <= 1;
          m_axis_tdata <= 8'h00;
          m_axis_tuser <= 0;  // スタッフィングバイトは最初のバイトではない
          m_axis_tlast <= (last_data && buf_index + 1 >= buf_count && bit_pos >= bs_buffer[buf_index].length); // 最後のバイトなら1
          if (m_axis_tready) begin
            state <= PROCESS_BIT;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
