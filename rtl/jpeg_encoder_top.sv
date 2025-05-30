// トップモジュール
module jpeg_encoder_top #(
    parameter IMG_WIDTH  = 256,
    parameter IMG_HEIGHT = 256,
    parameter DATA_WIDTH = 24    // RGB: 8bit x 3
) (
    input logic clk,
    input logic rst_n,
    // AXI4-Stream Slave (Input: RGB)
    input logic [DATA_WIDTH-1:0] s_axis_tdata,
    input logic s_axis_tvalid,
    output logic s_axis_tready,
    input logic s_axis_tlast,
    input logic s_axis_tuser,
    // AXI4-Stream Master (Output: JPEG bitstream)
    output logic [7:0] m_axis_tdata,
    output logic m_axis_tvalid,
    input logic m_axis_tready,
    output logic m_axis_tlast,
    output logic m_axis_tuser
);

  // Internal AXI4-Stream signals
  logic [23:0] ycbcr_tdata;
  logic ycbcr_tvalid, ycbcr_tready, ycbcr_tlast, ycbcr_tuser;
  logic [7:0] y_ds_tdata, cb_ds_tdata, cr_ds_tdata;
  logic y_ds_tvalid, cb_ds_tvalid, cr_ds_tvalid;
  logic y_ds_tready, cb_ds_tready, cr_ds_tready;
  logic y_ds_tlast, cb_ds_tlast, cr_ds_tlast;
  logic y_ds_tuser, cb_ds_tuser, cr_ds_tuser;
  logic [15:0] y_dct_tdata, cb_dct_tdata, cr_dct_tdata;
  logic y_dct_tvalid, cb_dct_tvalid, cr_dct_tvalid;
  logic y_dct_tready, cb_dct_tready, cr_dct_tready;
  logic y_dct_tlast, cb_dct_tlast, cr_dct_tlast;
  logic y_dct_tuser, cb_dct_tuser, cr_dct_tuser;
  logic [15:0] y_quant_tdata, cb_quant_tdata, cr_quant_tdata;
  logic y_quant_tvalid, cb_quant_tvalid, cr_quant_tvalid;
  logic y_quant_tready, cb_quant_tready, cr_quant_tready;
  logic y_quant_tlast, cb_quant_tlast, cr_quant_tlast;
  logic y_quant_tuser, cb_quant_tuser, cr_quant_tuser;
  logic [15:0] y_zigzag_tdata, cb_zigzag_tdata, cr_zigzag_tdata;
  logic y_zigzag_tvalid, cb_zigzag_tvalid, cr_zigzag_tvalid;
  logic y_zigzag_tready, cb_zigzag_tready, cr_zigzag_tready;
  logic y_zigzag_tlast, cb_zigzag_tlast, cr_zigzag_tlast;
  logic y_zigzag_tuser, cb_zigzag_tuser, cr_zigzag_tuser;
  logic [31:0] y_huff_tdata, cb_huff_tdata, cr_huff_tdata;
  logic y_huff_tvalid, cb_huff_tvalid, cr_huff_tvalid;
  logic y_huff_tready, cb_huff_tready, cr_huff_tready;
  logic y_huff_tlast, cb_huff_tlast, cr_huff_tlast;
  logic y_huff_tuser, cb_huff_tuser, cr_huff_tuser;
  logic [23:0] axi_muxdata_tdata;
  logic axi_muxdata_tvalid, axi_muxdata_tready, axi_muxdata_tlast, axi_muxdata_tuser;
  logic [23:0] write_tdata;
  logic write_tvalid, write_tready, write_tlast, write_tuser;

  // モジュールインスタンス
  color_space_converter csc (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(s_axis_tdata),
      .s_axis_tvalid(s_axis_tvalid),
      .s_axis_tready(s_axis_tready),
      .s_axis_tlast(s_axis_tlast),
      .s_axis_tuser(s_axis_tuser),
      .m_axis_tdata(ycbcr_tdata),
      .m_axis_tvalid(ycbcr_tvalid),
      .m_axis_tready(ycbcr_tready),
      .m_axis_tlast(ycbcr_tlast),
      .m_axis_tuser(ycbcr_tuser)
  );

  down_sampler ds (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(ycbcr_tdata),
      .s_axis_tvalid(ycbcr_tvalid),
      .s_axis_tready(ycbcr_tready),
      .s_axis_tlast(ycbcr_tlast),
      .s_axis_tuser(ycbcr_tuser),
      .y_axis_tdata(y_ds_tdata),
      .y_axis_tvalid(y_ds_tvalid),
      .y_axis_tready(y_ds_tready),
      .y_axis_tlast(y_ds_tlast),
      .y_axis_tuser(y_ds_tuser),
      .cb_axis_tdata(cb_ds_tdata),
      .cb_axis_tvalid(cb_ds_tvalid),
      .cb_axis_tready(cb_ds_tready),
      .cb_axis_tlast(cb_ds_tlast),
      .cb_axis_tuser(cb_ds_tuser),
      .cr_axis_tdata(cr_ds_tdata),
      .cr_axis_tvalid(cr_ds_tvalid),
      .cr_axis_tready(cr_ds_tready),
      .cr_axis_tlast(cr_ds_tlast),
      .cr_axis_tuser(cr_ds_tuser)
  );

  dct y_dct (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(y_ds_tdata),
      .s_axis_tvalid(y_ds_tvalid),
      .s_axis_tready(y_ds_tready),
      .s_axis_tlast(y_ds_tlast),
      .s_axis_tuser(y_ds_tuser),
      .m_axis_tdata(y_dct_tdata),
      .m_axis_tvalid(y_dct_tvalid),
      .m_axis_tready(y_dct_tready),
      .m_axis_tlast(y_dct_tlast),
      .m_axis_tuser(y_dct_tuser)
  );

  dct cb_dct (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(cb_ds_tdata),
      .s_axis_tvalid(cb_ds_tvalid),
      .s_axis_tready(cb_ds_tready),
      .s_axis_tlast(cb_ds_tlast),
      .s_axis_tuser(cb_ds_tuser),
      .m_axis_tdata(cb_dct_tdata),
      .m_axis_tvalid(cb_dct_tvalid),
      .m_axis_tready(cb_dct_tready),
      .m_axis_tlast(cb_dct_tlast),
      .m_axis_tuser(cb_dct_tuser)
  );

  dct cr_dct (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(cr_ds_tdata),
      .s_axis_tvalid(cr_ds_tvalid),
      .s_axis_tready(cr_ds_tready),
      .s_axis_tlast(cr_ds_tlast),
      .s_axis_tuser(cr_ds_tuser),
      .m_axis_tdata(cr_dct_tdata),
      .m_axis_tvalid(cr_dct_tvalid),
      .m_axis_tready(cr_dct_tready),
      .m_axis_tlast(cr_dct_tlast),
      .m_axis_tuser(cr_dct_tuser)
  );

  quantizer y_quant (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(y_dct_tdata),
      .s_axis_tvalid(y_dct_tvalid),
      .s_axis_tready(y_dct_tready),
      .s_axis_tlast(y_dct_tlast),
      .s_axis_tuser(y_dct_tuser),
      .m_axis_tdata(y_quant_tdata),
      .m_axis_tvalid(y_quant_tvalid),
      .m_axis_tready(y_quant_tready),
      .m_axis_tlast(y_quant_tlast),
      .m_axis_tuser(y_quant_tuser),
      .is_luma(1'b1)
  );

  quantizer cb_quant (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(cb_dct_tdata),
      .s_axis_tvalid(cb_dct_tvalid),
      .s_axis_tready(cb_dct_tready),
      .s_axis_tlast(cb_dct_tlast),
      .s_axis_tuser(cb_dct_tuser),
      .m_axis_tdata(cb_quant_tdata),
      .m_axis_tvalid(cb_quant_tvalid),
      .m_axis_tready(cb_quant_tready),
      .m_axis_tlast(cb_quant_tlast),
      .m_axis_tuser(cb_quant_tuser),
      .is_luma(1'b0)
  );

  quantizer cr_quant (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(cr_dct_tdata),
      .s_axis_tvalid(cr_dct_tvalid),
      .s_axis_tready(cr_dct_tready),
      .s_axis_tlast(cr_dct_tlast),
      .s_axis_tuser(cr_dct_tuser),
      .m_axis_tdata(cr_quant_tdata),
      .m_axis_tvalid(cr_quant_tvalid),
      .m_axis_tready(cr_quant_tready),
      .m_axis_tlast(cr_quant_tlast),
      .m_axis_tuser(cr_quant_tuser),
      .is_luma(1'b0)
  );

  zigzag_scanner y_zigzag (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(y_quant_tdata),
      .s_axis_tvalid(y_quant_tvalid),
      .s_axis_tready(y_quant_tready),
      .s_axis_tlast(y_quant_tlast),
      .s_axis_tuser(y_quant_tuser),
      .m_axis_tdata(y_zigzag_tdata),
      .m_axis_tvalid(y_zigzag_tvalid),
      .m_axis_tready(y_zigzag_tready),
      .m_axis_tlast(y_zigzag_tlast),
      .m_axis_tuser(y_zigzag_tuser)
  );

  zigzag_scanner cb_zigzag (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(cb_quant_tdata),
      .s_axis_tvalid(cb_quant_tvalid),
      .s_axis_tready(cb_quant_tready),
      .s_axis_tlast(cb_quant_tlast),
      .s_axis_tuser(cb_quant_tuser),
      .m_axis_tdata(cb_zigzag_tdata),
      .m_axis_tvalid(cb_zigzag_tvalid),
      .m_axis_tready(cb_zigzag_tready),
      .m_axis_tlast(cb_zigzag_tlast),
      .m_axis_tuser(cb_zigzag_tuser)
  );

  zigzag_scanner cr_zigzag (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(cr_quant_tdata),
      .s_axis_tvalid(cr_quant_tvalid),
      .s_axis_tready(cr_quant_tready),
      .s_axis_tlast(cr_quant_tlast),
      .s_axis_tuser(cr_quant_tuser),
      .m_axis_tdata(cr_zigzag_tdata),
      .m_axis_tvalid(cr_zigzag_tvalid),
      .m_axis_tready(cr_zigzag_tready),
      .m_axis_tlast(cr_zigzag_tlast),
      .m_axis_tuser(cr_zigzag_tuser)
  );

  huffman_encoder y_huff (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(y_zigzag_tdata),
      .s_axis_tvalid(y_zigzag_tvalid),
      .s_axis_tready(y_zigzag_tready),
      .s_axis_tlast(y_zigzag_tlast),
      .s_axis_tuser(y_zigzag_tuser),
      .m_axis_tdata(y_huff_tdata),
      .m_axis_tvalid(y_huff_tvalid),
      .m_axis_tready(y_huff_tready),
      .m_axis_tlast(y_huff_tlast),
      .m_axis_tuser(y_huff_tuser),
      .is_luma(1'b1)
  );

  huffman_encoder cb_huff (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(cb_zigzag_tdata),
      .s_axis_tvalid(cb_zigzag_tvalid),
      .s_axis_tready(cb_zigzag_tready),
      .s_axis_tlast(cb_zigzag_tlast),
      .s_axis_tuser(cb_zigzag_tuser),
      .m_axis_tdata(cb_huff_tdata),
      .m_axis_tvalid(cb_huff_tvalid),
      .m_axis_tready(cb_huff_tready),
      .m_axis_tlast(cb_huff_tlast),
      .m_axis_tuser(cb_huff_tuser),
      .is_luma(1'b0)
  );

  huffman_encoder cr_huff (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(cr_zigzag_tdata),
      .s_axis_tvalid(cr_zigzag_tvalid),
      .s_axis_tready(cr_zigzag_tready),
      .s_axis_tlast(cr_zigzag_tlast),
      .s_axis_tuser(cr_zigzag_tuser),
      .m_axis_tdata(cr_huff_tdata),
      .m_axis_tvalid(cr_huff_tvalid),
      .m_axis_tready(cr_huff_tready),
      .m_axis_tlast(cr_huff_tlast),
      .m_axis_tuser(cr_huff_tuser),
      .is_luma(1'b0)
  );


  axi_datamux axi_datamux (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_y_tdata(y_huff_tdata),
      .s_axis_y_tvalid(y_huff_tvalid),
      .s_axis_y_tready(y_huff_tready),
      .s_axis_y_tlast(y_huff_tlast),
      .s_axis_y_tuser(y_huff_tuser),
      .s_axis_cb_tdata(cb_huff_tdata),
      .s_axis_cb_tvalid(cb_huff_tvalid),
      .s_axis_cb_tready(cb_huff_tready),
      .s_axis_cb_tlast(cb_huff_tlast),
      .s_axis_cb_tuser(cb_huff_tuser),
      .s_axis_cr_tdata(cr_huff_tdata),
      .s_axis_cr_tvalid(cr_huff_tvalid),
      .s_axis_cr_tready(cr_huff_tready),
      .s_axis_cr_tlast(cr_huff_tlast),
      .s_axis_cr_tuser(cr_huff_tuser),
      .m_axis_tdata(axi_muxdata_tdata),
      .m_axis_tvalid(axi_muxdata_tvalid),
      .m_axis_tready(axi_muxdata_tready),
      .m_axis_tlast(axi_muxdata_tlast),
      .m_axis_tuser(axi_muxdata_tuser)
  );

  write_bitstring write_bitstring (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(axi_muxdata_tdata),
      .s_axis_tvalid(axi_muxdata_tvalid),
      .s_axis_tready(axi_muxdata_tready),
      .s_axis_tlast(axi_muxdata_tlast),
      .s_axis_tuser(axi_muxdata_tuser),
      .m_axis_tdata(write_tdata),
      .m_axis_tvalid(write_tvalid),
      .m_axis_tready(write_tready),
      .m_axis_tlast(write_tlast),
      .m_axis_tuser(write_tuser)
  );

  file_generator fg (
      .clk(clk),
      .rst_n(rst_n),
      .s_axis_tdata(write_tdata),
      .s_axis_tvalid(write_tvalid),
      .s_axis_tready(write_tready),
      .s_axis_tlast(s_axis_tlast),
      .s_axis_tuser(write_tuser),
      .m_axis_tdata(m_axis_tdata),
      .m_axis_tvalid(m_axis_tvalid),
      .m_axis_tready(m_axis_tready),
      .m_axis_tlast(m_axis_tlast),
      .m_axis_tuser(m_axis_tuser)
  );

endmodule
