module down_sampler #(
    parameter IMG_WIDTH  = 256,
    parameter IMG_HEIGHT = 256
) (
    input logic clk,
    input logic rst_n,
    // AXI4-Stream Slave (入力: YCbCr, 8x8ブロック単位)
    input logic [23:0] s_axis_tdata,  // Y[23:16], Cb[15:8], Cr[7:0]
    input logic s_axis_tvalid,
    output logic s_axis_tready,
    input logic s_axis_tlast,  // 8x8ブロックの最終ピクセルで1
    input logic s_axis_tuser,  // 8x8ブロックの先頭ピクセルで1
    // AXI4-Stream Master (Y: 8x8ピクセル)
    output logic [7:0] y_axis_tdata,
    output logic y_axis_tvalid,
    input logic y_axis_tready,
    output logic y_axis_tlast,  // 8x8ブロックの最終ピクセルで1
    output logic y_axis_tuser,  // 8x8ブロックの先頭ピクセルで1
    // AXI4-Stream Master (Cb: 8x8ピクセル)
    output logic [7:0] cb_axis_tdata,
    output logic cb_axis_tvalid,
    input logic cb_axis_tready,
    output logic cb_axis_tlast,  // 8x8ブロックの最終ピクセルで1
    output logic cb_axis_tuser,  // 8x8ブロックの先頭ピクセルで1
    // AXI4-Stream Master (Cr: 8x8ピクセル)
    output logic [7:0] cr_axis_tdata,
    output logic cr_axis_tvalid,
    input logic cr_axis_tready,
    output logic cr_axis_tlast,  // 8x8ブロックの最終ピクセルで1
    output logic cr_axis_tuser  // 8x8ブロックの先頭ピクセルで1
);

  // モジュールスコープでの変数宣言
  logic [2:0] x_cnt, y_cnt;  // 8x8ブロック内の座標カウンタ (0-7)
  logic [1:0] block_x_cnt, block_y_cnt;  // 16x16内の8x8ブロックカウンタ (0-1)
  logic signed [7:0] cb_buf[15:0][15:0];  // 16x16ピクセルのCbバッファ
  logic signed [7:0] cr_buf[15:0][15:0];  // 16x16ピクセルのCrバッファ
  logic [2:0] cbcr_x_cnt, cbcr_y_cnt;  // 8x8出力の座標カウンタ (0-7)
  logic block_complete;  // 16x16ブロック（4つの8x8ブロック）受信完了フラグ
  logic signed [9:0] cb_sum, cr_sum;  // 2x2ピクセルの平均計算用

  // cb_sum, cr_sumをassignで定義
  assign cb_sum = $signed(
      cb_buf[cbcr_y_cnt*2][cbcr_x_cnt*2] +
                  cb_buf[cbcr_y_cnt*2][cbcr_x_cnt*2+1] +
                  cb_buf[cbcr_y_cnt*2+1][cbcr_x_cnt*2] +
                  cb_buf[cbcr_y_cnt*2+1][cbcr_x_cnt*2+1]
  );
  assign cr_sum = $signed(
      cr_buf[cbcr_y_cnt*2][cbcr_x_cnt*2] +
                  cr_buf[cbcr_y_cnt*2][cbcr_x_cnt*2+1] +
                  cr_buf[cbcr_y_cnt*2+1][cbcr_x_cnt*2] +
                  cr_buf[cbcr_y_cnt*2+1][cbcr_x_cnt*2+1]
  );

  // ステートマシンの状態定義
  typedef enum logic {
    IDLE,        // 待機状態
    OUTPUT_CBCR  // Cb/Cr出力状態
  } state_t;

  state_t state;

  // 入力処理とY出力（ステートマシンとは独立）
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x_cnt <= 0;
      y_cnt <= 0;
      block_x_cnt <= 0;
      block_y_cnt <= 0;
      y_axis_tvalid <= 0;
      block_complete <= 0;
      y_axis_tlast <= 0;
      y_axis_tuser <= 0;
    end else begin
      // 入力処理（8x8ブロックの受信、16x16単位で管理）
      if (s_axis_tready && s_axis_tvalid) begin
        // Yはそのまま出力（8x8単位）
        y_axis_tdata <= s_axis_tdata[23:16];
        y_axis_tvalid <= s_axis_tvalid;
        y_axis_tlast <= s_axis_tlast;
        y_axis_tuser <= s_axis_tuser;

        // Cb/Crを16x16バッファに保存
        cb_buf[block_y_cnt*8+y_cnt][block_x_cnt*8+x_cnt] <= $signed(s_axis_tdata[15:8]);
        cr_buf[block_y_cnt*8+y_cnt][block_x_cnt*8+x_cnt] <= $signed(s_axis_tdata[7:0]);

        // 座標更新（8x8ブロック内）
        if (x_cnt == 7) begin
          x_cnt <= 0;
          if (y_cnt == 7) begin
            y_cnt <= 0;
            // 8x8ブロック完了、16x16内のブロック座標更新
            if (block_x_cnt == 1) begin
              block_x_cnt <= 0;
              if (block_y_cnt == 1) begin
                block_y_cnt <= 0;
                block_complete <= 1;  // 16x16ブロック完了
              end else begin
                block_y_cnt <= block_y_cnt + 1;
              end
            end else begin
              block_x_cnt <= block_x_cnt + 1;
            end
          end else begin
            y_cnt <= y_cnt + 1;
          end
        end else begin
          x_cnt <= x_cnt + 1;
        end
      end
    end
  end

  // Cb/Cr処理用のステートマシン
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cbcr_x_cnt <= 0;
      cbcr_y_cnt <= 0;
      cb_axis_tvalid <= 0;
      cr_axis_tvalid <= 0;
      cb_axis_tlast <= 0;
      cb_axis_tuser <= 0;
      cr_axis_tlast <= 0;
      cr_axis_tuser <= 0;
      cb_axis_tdata <= 0;
      cr_axis_tdata <= 0;
    end else begin
      case (state)
        IDLE: begin
          cb_axis_tvalid <= 0;
          cr_axis_tvalid <= 0;
          cb_axis_tlast  <= 0;
          cb_axis_tuser  <= 0;
          cr_axis_tlast  <= 0;
          cr_axis_tuser  <= 0;
          // 16x16ブロック完了時にステートマシン開始
          if ((x_cnt == 7) && (y_cnt == 7) && (block_x_cnt == 1) && (block_y_cnt == 1) && s_axis_tvalid && s_axis_tready) begin
            state <= OUTPUT_CBCR;
            cbcr_x_cnt <= 0;
            cbcr_y_cnt <= 0;
          end
        end

        OUTPUT_CBCR: begin
          if (cb_axis_tready && cr_axis_tready) begin
            // CbとCrを同時に出力
            cb_axis_tdata  <= $signed(cb_sum) >> 2;  // 2x2ピクセルの平均
            cr_axis_tdata  <= $signed(cr_sum) >> 2;  // 2x2ピクセルの平均
            cb_axis_tvalid <= 1;
            cr_axis_tvalid <= 1;
            cb_axis_tlast  <= (cbcr_x_cnt == 7 && cbcr_y_cnt == 7);
            cb_axis_tuser  <= (cbcr_x_cnt == 0 && cbcr_y_cnt == 0);
            cr_axis_tlast  <= (cbcr_x_cnt == 7 && cbcr_y_cnt == 7);
            cr_axis_tuser  <= (cbcr_x_cnt == 0 && cbcr_y_cnt == 0);

            // 座標更新
            if (cbcr_x_cnt == 7) begin
              cbcr_x_cnt <= 0;
              if (cbcr_y_cnt == 7) begin
                cbcr_y_cnt <= 0;
                state <= IDLE;  // Cb/Cr出力完了、IDLEへ
                block_complete <= 0;  // 次ブロックの準備
              end else begin
                cbcr_y_cnt <= cbcr_y_cnt + 1;
              end
            end else begin
              cbcr_x_cnt <= cbcr_x_cnt + 1;
            end
          end
        end
      endcase
    end
  end

  assign s_axis_tready = y_axis_tready;

endmodule
