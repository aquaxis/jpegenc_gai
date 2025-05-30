// 色空間変換モジュール
module color_space_converter (
    input logic clk,
    input logic rst_n,
    input logic [23:0] s_axis_tdata,  // RGB: R[23:16], G[15:8], B[7:0]
    input logic s_axis_tvalid,
    output logic s_axis_tready,
    input logic s_axis_tlast,
    input logic s_axis_tuser,
    output logic [23:0] m_axis_tdata,  // YCbCr: Y[23:16], Cb[15:8], Cr[7:0]
    output logic m_axis_tvalid,
    input logic m_axis_tready,
    output logic m_axis_tlast,
    output logic m_axis_tuser
);

  logic [7:0] r, g, b;
  logic signed [7:0] y, cb, cr;
  logic tvalid_reg, tlast_reg, tuser_reg;

  // s_axis_treadyはm_axis_treadyを直接出力
  assign s_axis_tready = m_axis_tready;

  // YCbCr変換を組み合わせ論理で計算
  assign y = $signed(
      (76 * $signed({1'b0, r}) + 150 * $signed({1'b0, g}) + 29 * $signed({1'b0, b})) >>> 8
  ) - 128;
  assign cb = ($signed(
      -43 * $signed({1'b0, r}) - 85 * $signed({1'b0, g}) + 128 * $signed({1'b0, b})
  ) >>> 8);
  assign cr = ($signed(
      128 * $signed({1'b0, r}) - 107 * $signed({1'b0, g}) - 21 * $signed({1'b0, b})
  ) >>> 8);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r <= 8'b0;
      g <= 8'b0;
      b <= 8'b0;
      m_axis_tdata <= 24'b0;
      m_axis_tvalid <= 1'b0;
      m_axis_tlast <= 1'b0;
      m_axis_tuser <= 1'b0;
      tvalid_reg <= 1'b0;
      tlast_reg <= 1'b0;
      tuser_reg <= 1'b0;
    end else begin
      if (s_axis_tready) begin
        // 入力データを中間レジスタに保存
        r <= s_axis_tdata[23:16];
        g <= s_axis_tdata[15:8];
        b <= s_axis_tdata[7:0];
        tvalid_reg <= s_axis_tvalid;
        tlast_reg <= s_axis_tlast;
        tuser_reg <= s_axis_tuser;

        // m_axis信号の更新（m_axis_tdataをクロック同期）
        m_axis_tdata <= {y, cb, cr};
        m_axis_tvalid <= tvalid_reg;
        m_axis_tlast <= tlast_reg;
        m_axis_tuser <= tuser_reg;
      end
    end
  end

endmodule
