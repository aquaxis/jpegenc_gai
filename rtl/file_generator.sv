// ファイル生成モジュール
module file_generator (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] s_axis_tdata,   // 単一のデータ入力
    input  logic        s_axis_tvalid,  // 単一の有効信号
    output logic        s_axis_tready,  // 単一のレディ信号
    input  logic        s_axis_tlast,   // 単一のラスト信号
    input  logic        s_axis_tuser,   // 単一のユーザー信号
    output logic [ 7:0] m_axis_tdata,   // 出力データ
    output logic        m_axis_tvalid,  // 出力有効
    input  logic        m_axis_tready,  // 出力レディ
    output logic        m_axis_tlast,   // 出力ラスト
    output logic        m_axis_tuser    // 出力ユーザー
);

  // JPEGヘッダ（CコードのJpegEncoder_write_jpeg_headerを参考）
  logic [9:0] header_idx;
  logic header_done;
  logic file_last;

  `include "file_generator_table.svh"

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      header_idx <= 0;
      header_done <= 0;
      file_last <= 0;
      m_axis_tvalid <= 0;
      s_axis_tready <= 1;  // 単一のレディ信号を初期化
      m_axis_tlast <= 0;
    end else begin
      if (!header_done && m_axis_tready) begin
        // ヘッダ送信
        m_axis_tdata <= header[header_idx];
        m_axis_tvalid <= 1;
        header_idx <= header_idx + 1;
        if (header_idx == (`HEADER_SIZE - 1)) header_done <= 1;
      end else if (header_done && m_axis_tready) begin
        // データ送信
        if (s_axis_tvalid) begin
          m_axis_tdata  <= s_axis_tdata[7:0];  // 単一入力データのLSB 8ビットを送信
          m_axis_tvalid <= 1;
          s_axis_tready <= 1;
          m_axis_tlast  <= s_axis_tlast;  // 入力のtlastをそのまま伝播
          m_axis_tuser  <= s_axis_tuser;  // 入力のtuserをそのまま伝播
          if (s_axis_tlast) file_last <= 1;
        end else begin
          m_axis_tvalid <= 0;
          s_axis_tready <= 1;
          m_axis_tlast  <= 0;
        end

        if (s_axis_tlast) file_last <= 1;
        // EOI (End of Image) 送信
        if (file_last) begin
          m_axis_tdata <= 8'hD9;  // EOI: 0xFFD9
          m_axis_tvalid <= 1;
          m_axis_tlast <= 1;
          file_last <= 0;
        end
      end else begin
        m_axis_tvalid <= 0;
        s_axis_tready <= 1;
      end
    end
  end

endmodule
