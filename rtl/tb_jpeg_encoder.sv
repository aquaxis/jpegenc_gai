`timescale 1ns / 1ps

module tb_jpeg_encoder;

  // パラメータ（変更なし）
  parameter IMG_WIDTH = 640;
  parameter IMG_HEIGHT = 480;
  parameter DATA_WIDTH = 24;  // RGB: 8bit x 3
  parameter CLK_PERIOD = 10;  // 10ns (100MHz)

  // 信号定義（変更なし）
  logic clk;
  logic rst_n;
  logic [DATA_WIDTH-1:0] s_axis_tdata;
  logic s_axis_tvalid;
  logic s_axis_tready;
  logic s_axis_tlast;
  logic s_axis_tuser;
  logic [7:0] m_axis_tdata;
  logic m_axis_tvalid;
  logic m_axis_tready;
  logic m_axis_tlast;
  logic m_axis_tuser;

  // テストデータ（変更なし）
  logic [7:0] bmp_data[0:IMG_WIDTH*IMG_HEIGHT*3-1];  // RGBバッファ
  integer bmp_file, jpg_file;
  integer pixel_count;
  integer output_count;

  // DUTインスタンス（変更なし）
  jpeg_encoder_top #(
      .IMG_WIDTH (IMG_WIDTH),
      .IMG_HEIGHT(IMG_HEIGHT),
      .DATA_WIDTH(DATA_WIDTH)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(s_axis_tdata),
      .s_axis_tvalid(s_axis_tvalid),
      .s_axis_tready(s_axis_tready),
      .s_axis_tlast(s_axis_tlast),
      .s_axis_tuser(s_axis_tuser),
      .m_axis_tdata(m_axis_tdata),
      .m_axis_tvalid(m_axis_tvalid),
      .m_axis_tready(m_axis_tready),
      .m_axis_tlast(m_axis_tlast),
      .m_axis_tuser(m_axis_tuser)
  );

  // クロック生成（変更なし）
  initial begin
    clk = 0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // バイトスワップ関数
  function automatic logic [15:0] swap16(input logic [15:0] data);
    return {data[7:0], data[15:8]};
  endfunction

  function automatic logic [31:0] swap32(input logic [31:0] data);
    return {data[7:0], data[15:8], data[23:16], data[31:24]};
  endfunction

  // BMPファイル読み込みタスク（バイトスワップを追加）
  task read_bmp_file;
    input string filename;
    integer file, bytes_read;
    logic [15:0] bfType;
    logic [31:0] bfSize, bfOffBits;
    logic [31:0] biSize, biWidth, biHeight;
    logic [15:0] biBitCount;
    logic [31:0] biCompression;
    integer i, j;
    logic [7:0] temp_pixel[0:2];
    begin
      file = $fopen(filename, "rb");
      if (file == 0) begin
        $display("Error: Cannot open BMP file %s", filename);
        $finish;
      end

      // BITMAPFILEHEADER
      bytes_read = $fread(bfType, file);
      bfType = swap16(bfType);  // バイトスワップ
      if (bfType != 16'h4D42) begin
        $display("Error: Not a valid BMP file (bfType = 0x%h)", bfType);
        $fclose(file);
        $finish;
      end
      $fseek(file, 2, 0);  // bfTypeを読み込んだ後
      bytes_read = $fread(bfSize, file);
      bfSize = swap32(bfSize);  // バイトスワップ
      $fseek(file, 10, 0);
      bytes_read = $fread(bfOffBits, file);
      bfOffBits  = swap32(bfOffBits);  // バイトスワップ

      // BITMAPINFOHEADER
      $fseek(file, 14, 0);
      bytes_read = $fread(biSize, file);
      biSize = swap32(biSize);  // バイトスワップ
      bytes_read = $fread(biWidth, file);
      biWidth = swap32(biWidth);  // バイトスワップ
      bytes_read = $fread(biHeight, file);
      biHeight = swap32(biHeight);  // バイトスワップ
      $display("%d,%d", biWidth, biHeight);
      $fseek(file, 28, 0);
      bytes_read = $fread(biBitCount, file);
      biBitCount = swap16(biBitCount);  // バイトスワップ
      bytes_read = $fread(biCompression, file);
      biCompression = swap32(biCompression);  // バイトスワップ
      $display("%d,%d", biBitCount, biCompression);

      // ヘッダチェック
      if (biBitCount != 24 || biCompression != 0) begin
        $display("Error: Only 24-bit uncompressed BMP supported");
        $fclose(file);
        $finish;
      end
      if (biWidth != IMG_WIDTH || biHeight != IMG_HEIGHT) begin
        $display("Error: Image size must be %dx%d", IMG_WIDTH, IMG_HEIGHT);
        $fclose(file);
        $finish;
      end

      // ピクセルデータ読み込み
      $fseek(file, bfOffBits, 0);
      for (i = IMG_HEIGHT - 1; i >= 0; i--) begin  // BMPは上下反転
        for (j = 0; j < IMG_WIDTH; j++) begin
          bytes_read = $fread(temp_pixel, file);
          bmp_data[i*IMG_WIDTH*3+j*3+0] = temp_pixel[0];  // B
          bmp_data[i*IMG_WIDTH*3+j*3+1] = temp_pixel[1];  // G
          bmp_data[i*IMG_WIDTH*3+j*3+2] = temp_pixel[2];  // R
        end
      end

      $fclose(file);
      $display("Successfully read BMP file %s", filename);
    end
  endtask

  // RGBデータ送信タスク（変更なし）
  task send_rgb_data;
    integer i, j, block_x, block_y, px, py;
    integer block_count;
    integer global_x, global_y;
    integer idx;
    begin
      pixel_count   = 0;
      s_axis_tvalid = 0;
      s_axis_tuser  = 0;
      s_axis_tlast  = 0;
      @(posedge clk);

      // 2x2ブロック単位で処理 (16x16ピクセル)
      for (block_y = 0; block_y < IMG_HEIGHT; block_y += 16) begin
        for (block_x = 0; block_x < IMG_WIDTH; block_x += 16) begin
          // 2x2ブロック内の4つの8x8ブロックを処理
          for (i = 0; i < 2; i++) begin  // 縦方向（0:上, 1:下）
            for (j = 0; j < 2; j++) begin  // 横方向（0:左, 1:右）
              // 8x8ブロック内のピクセルを送信
              for (py = 0; py < 8; py++) begin
                for (px = 0; px < 8; px++) begin
                  // ピクセル座標計算
                  global_x = block_x + j * 8 + px;
                  global_y = block_y + i * 8 + py;
                  // 画像範囲内かチェック
                  if (global_x < IMG_WIDTH && global_y < IMG_HEIGHT) begin
                    idx = global_y * IMG_WIDTH * 3 + global_x * 3;
                    s_axis_tdata = {bmp_data[idx+2], bmp_data[idx+1], bmp_data[idx+0]};  // R,G,B
                    $display("BITMAP: %3d,%3d: %02x,%02x,%02x", global_x, global_y,
                             bmp_data[idx+2], bmp_data[idx+1], bmp_data[idx+0]);
                    s_axis_tvalid = 1;
                    // tuser: 最初のピクセルのみ1
                    s_axis_tuser  = (pixel_count == 0) ? 1 : 0;
                    // tlast: 最後のピクセルのみ1
                    s_axis_tlast  = (pixel_count == IMG_WIDTH * IMG_HEIGHT - 1) ? 1 : 0;

                    @(posedge clk);
                    while (!s_axis_tready) @(posedge clk);
                    pixel_count = pixel_count + 1;
                  end
                end
              end
            end
          end
        end
      end

      s_axis_tvalid = 0;
      s_axis_tuser  = 0;
      s_axis_tlast  = 0;
      $display("Sent %d pixels", pixel_count);
    end
  endtask

  // JPEGデータ受信タスク（変更なし）
  task receive_jpeg_data;
    begin
      jpg_file = $fopen("output.jpg", "wb");
      if (jpg_file == 0) begin
        $display("Error: Cannot open output file output.jpg");
        $finish;
      end

      output_count  = 0;
      m_axis_tready = 1;
      @(posedge clk);

      while (!(m_axis_tvalid && m_axis_tlast)) begin
        if (m_axis_tvalid && m_axis_tready) begin
          $fwrite(jpg_file, "%c", m_axis_tdata);
          output_count = output_count + 1;
        end
        @(posedge clk);
      end

      if (m_axis_tvalid && m_axis_tready) begin
        $fwrite(jpg_file, "%c", m_axis_tdata);
        output_count = output_count + 1;
      end

      $fclose(jpg_file);
      $display("Received %d bytes, saved to output.jpg", output_count);
    end
  endtask

  // メインシミュレーション（変更なし）
  initial begin
    rst_n = 0;
    s_axis_tvalid = 0;
    s_axis_tdata = 0;
    s_axis_tlast = 0;
    s_axis_tuser = 0;
    m_axis_tready = 0;

    #20 rst_n = 1;
    $display("Reset deasserted");

    read_bmp_file("sample.bmp");

    fork
      send_rgb_data();
      receive_jpeg_data();
    join

    #100;
    $display("Simulation completed");
    $finish;
  end

  // 時間カウンタ
  time current_time;
  time last_dot_time;
endmodule
