/*
JPEG Encoder No.0
C++からCに変換したソースコード
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define PI 3.1415926f

// 構造体定義
typedef struct {
    int length;
    int value;
} BitString;

typedef struct {
    int width;
    int height;
    unsigned char* rgbBuffer;
    unsigned char YTable[64];
    unsigned char CbCrTable[64];
    BitString Y_DC_Huffman_Table[12];
    BitString Y_AC_Huffman_Table[256];
    BitString CbCr_DC_Huffman_Table[12];
    BitString CbCr_AC_Huffman_Table[256];
} JpegEncoder;

// 定数テーブル
static const unsigned char Luminance_Quantization_Table[64] = {
    16, 11, 10, 16, 24, 40, 51, 61,
    12, 12, 14, 19, 26, 58, 60, 55,
    14, 13, 16, 24, 40, 57, 69, 56,
    14, 17, 22, 29, 51, 87, 80, 62,
    18, 22, 37, 56, 68, 109, 103, 77,
    24, 35, 55, 64, 81, 104, 113, 92,
    49, 64, 78, 87, 103, 121, 120, 101,
    72, 92, 95, 98, 112, 100, 103, 99
};

static const unsigned char Chrominance_Quantization_Table[64] = {
    17, 18, 24, 47, 99, 99, 99, 99,
    18, 21, 26, 66, 99, 99, 99, 99,
    24, 26, 56, 99, 99, 99, 99, 99,
    47, 66, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99
};

static const char ZigZag[64] = {
    0, 1, 5, 6, 14, 15, 27, 28,
    2, 4, 7, 13, 16, 26, 29, 42,
    3, 8, 12, 17, 25, 30, 41, 43,
    9, 11, 18, 24, 31, 40, 44, 53,
    10, 19, 23, 32, 39, 45, 52, 54,
    20, 22, 33, 38, 46, 51, 55, 60,
    21, 34, 37, 47, 50, 56, 59, 61,
    35, 36, 48, 49, 57, 58, 62, 63
};

static const char Standard_DC_Luminance_NRCodes[] = { 0, 0, 7, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0 };
static const unsigned char Standard_DC_Luminance_Values[] = { 4, 5, 3, 2, 6, 1, 0, 7, 8, 9, 10, 11 };

static const char Standard_DC_Chrominance_NRCodes[] = { 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0 };
static const unsigned char Standard_DC_Chrominance_Values[] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 };

static const char Standard_AC_Luminance_NRCodes[] = { 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d };
static const unsigned char Standard_AC_Luminance_Values[] = {
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
    0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08, 0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0,
    0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28,
    0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
    0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
    0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
    0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
    0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5,
    0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2,
    0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
    0xf9, 0xfa
};

static const char Standard_AC_Chrominance_NRCodes[] = { 0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77 };
static const unsigned char Standard_AC_Chrominance_Values[] = {
    0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71,
    0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0,
    0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34, 0xe1, 0x25, 0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26,
    0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
    0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
    0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
    0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5,
    0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3,
    0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda,
    0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
    0xf9, 0xfa
};

// 関数プロトタイプ
void JpegEncoder_init(JpegEncoder* encoder);
void JpegEncoder_clean(JpegEncoder* encoder);
int JpegEncoder_readFromBMP(JpegEncoder* encoder, const char* fileName);
int JpegEncoder_encodeToJPG(JpegEncoder* encoder, const char* fileName, int quality_scale);
void JpegEncoder_initHuffmanTables(JpegEncoder* encoder);
void JpegEncoder_initQualityTables(JpegEncoder* encoder, int quality_scale);
void JpegEncoder_computeHuffmanTable(const char* nr_codes, const unsigned char* std_table, BitString* huffman_table);
BitString JpegEncoder_getBitCode(int value);
void JpegEncoder_write_byte(unsigned char value, FILE* fp);
void JpegEncoder_write_word(unsigned short value, FILE* fp);
void JpegEncoder_write(const void* p, int byteSize, FILE* fp);
void JpegEncoder_doHuffmanEncoding(const short* DU, short* prevDC, const BitString* HTDC, const BitString* HTAC, BitString* outputBitString, int* bitStringCounts);
void JpegEncoder_write_bitstring(const BitString* bs, int counts, int* newByte, int* newBytePos, FILE* fp);
void JpegEncoder_convertColorSpace(const unsigned char* rgbBuffer, char* yData, char* cbData, char* crData, int width);
void JpegEncoder_foword_FDC(const char* channel_data, short* fdc_data, const unsigned char* quant_table);
void JpegEncoder_write_jpeg_header(JpegEncoder* encoder, FILE* fp);

// JpegEncoderの初期化
void JpegEncoder_init(JpegEncoder* encoder) {
    encoder->width = 0;
    encoder->height = 0;
    encoder->rgbBuffer = NULL;
    memset(encoder->YTable, 0, sizeof(encoder->YTable));
    memset(encoder->CbCrTable, 0, sizeof(encoder->CbCrTable));
    memset(encoder->Y_DC_Huffman_Table, 0, sizeof(encoder->Y_DC_Huffman_Table));
    memset(encoder->Y_AC_Huffman_Table, 0, sizeof(encoder->Y_AC_Huffman_Table));
    memset(encoder->CbCr_DC_Huffman_Table, 0, sizeof(encoder->CbCr_DC_Huffman_Table));
    memset(encoder->CbCr_AC_Huffman_Table, 0, sizeof(encoder->CbCr_AC_Huffman_Table));
    JpegEncoder_initHuffmanTables(encoder);
}

// JpegEncoderのクリーンアップ
void JpegEncoder_clean(JpegEncoder* encoder) {
    if (encoder->rgbBuffer) {
        free(encoder->rgbBuffer);
        encoder->rgbBuffer = NULL;
    }
    encoder->width = 0;
    encoder->height = 0;
}

// BMPファイルの読み込み
int JpegEncoder_readFromBMP(JpegEncoder* encoder, const char* fileName) {
    JpegEncoder_clean(encoder);

    // BMPファイルヘッダ構造体
    #pragma pack(push, 2)
    typedef struct {
        unsigned short bfType;
        unsigned int bfSize;
        unsigned short bfReserved1;
        unsigned short bfReserved2;
        unsigned int bfOffBits;
    } BITMAPFILEHEADER;

    typedef struct {
        unsigned int biSize;
        int biWidth;
        int biHeight;
        unsigned short biPlanes;
        unsigned short biBitCount;
        unsigned int biCompression;
        unsigned int biSizeImage;
        int biXPelsPerMeter;
        int biYPelsPerMeter;
        unsigned int biClrUsed;
        unsigned int biClrImportant;
    } BITMAPINFOHEADER;
    #pragma pack(pop)

    FILE* fp = fopen(fileName, "rb");
    if (!fp) {
        fprintf(stderr, "Error: Cannot open file %s\n", fileName);
        return 0;
    }

    BITMAPFILEHEADER fileHeader;
    BITMAPINFOHEADER infoHeader;
    int success = 0;

    do {
        if (fread(&fileHeader, sizeof(fileHeader), 1, fp) != 1) break;
        if (fileHeader.bfType != 0x4D42) break;

        if (fread(&infoHeader, sizeof(infoHeader), 1, fp) != 1) break;
        if (infoHeader.biBitCount != 24 || infoHeader.biCompression != 0) break;

        int width = infoHeader.biWidth;
        int height = infoHeader.biHeight < 0 ? (-infoHeader.biHeight) : infoHeader.biHeight;
        if ((width & 7) != 0 || (height & 7) != 0) break; // 8の倍数である必要がある

        int bmpSize = width * height * 3;
        unsigned char* buffer = (unsigned char*)malloc(bmpSize);
        if (!buffer) break;

        fseek(fp, fileHeader.bfOffBits, SEEK_SET);

        if (infoHeader.biHeight > 0) {
            for (int i = 0; i < height; i++) {
                if (fread(buffer + (height - 1 - i) * width * 3, 3, width, fp) != width) {
                    free(buffer);
                    break;
                }
            }
        } else {
            if (fread(buffer, 3, width * height, fp) != width * height) {
                free(buffer);
                break;
            }
        }

        encoder->rgbBuffer = buffer;
        encoder->width = width;
        encoder->height = height;
        success = 1;
    } while (0);

    fclose(fp);
    return success;
}

// JPEGエンコーディング
int JpegEncoder_encodeToJPG(JpegEncoder* encoder, const char* fileName, int quality_scale) {
    if (!encoder->rgbBuffer || encoder->width == 0 || encoder->height == 0) {
        fprintf(stderr, "Error: No image data to encode\n");
        return 0;
    }

    FILE* fp = fopen(fileName, "wb");
    if (!fp) {
        fprintf(stderr, "Error: Cannot open output file %s\n", fileName);
        return 0;
    }

    JpegEncoder_initQualityTables(encoder, quality_scale);
    JpegEncoder_write_jpeg_header(encoder, fp);

    short prev_DC_Y = 0, prev_DC_Cb = 0, prev_DC_Cr = 0;
    int newByte = 0, newBytePos = 7;

    for (int yPos = 0; yPos < encoder->height; yPos += 8) {
        for (int xPos = 0; xPos < encoder->width; xPos += 8) {
            char yData[64], cbData[64], crData[64];
            short yQuant[64], cbQuant[64], crQuant[64];
            unsigned char* rgbBuffer = encoder->rgbBuffer + yPos * encoder->width * 3 + xPos * 3;

            JpegEncoder_convertColorSpace(rgbBuffer, yData, cbData, crData, encoder->width);

            BitString outputBitString[128];
            int bitStringCounts;

            // Yチャンネル
            JpegEncoder_foword_FDC(yData, yQuant, encoder->YTable);
            JpegEncoder_doHuffmanEncoding(yQuant, &prev_DC_Y, encoder->Y_DC_Huffman_Table, encoder->Y_AC_Huffman_Table, outputBitString, &bitStringCounts);
            JpegEncoder_write_bitstring(outputBitString, bitStringCounts, &newByte, &newBytePos, fp);

            // Cbチャンネル
            JpegEncoder_foword_FDC(cbData, cbQuant, encoder->CbCrTable);
            JpegEncoder_doHuffmanEncoding(cbQuant, &prev_DC_Cb, encoder->CbCr_DC_Huffman_Table, encoder->CbCr_AC_Huffman_Table, outputBitString, &bitStringCounts);
            JpegEncoder_write_bitstring(outputBitString, bitStringCounts, &newByte, &newBytePos, fp);

            // Crチャンネル
            JpegEncoder_foword_FDC(crData, crQuant, encoder->CbCrTable);
            JpegEncoder_doHuffmanEncoding(crQuant, &prev_DC_Cr, encoder->CbCr_DC_Huffman_Table, encoder->CbCr_AC_Huffman_Table, outputBitString, &bitStringCounts);
            JpegEncoder_write_bitstring(outputBitString, bitStringCounts, &newByte, &newBytePos, fp);
        }
    }

    if (newBytePos != 7) {
        JpegEncoder_write_byte((unsigned char)newByte, fp);
    }

    JpegEncoder_write_word(0xFFD9, fp); // EOIマーカー
    fclose(fp);
    return 1;
}

// ハフマンテーブルの初期化
void JpegEncoder_initHuffmanTables(JpegEncoder* encoder) {
    memset(encoder->Y_DC_Huffman_Table, 0, sizeof(encoder->Y_DC_Huffman_Table));
    JpegEncoder_computeHuffmanTable(Standard_DC_Luminance_NRCodes, Standard_DC_Luminance_Values, encoder->Y_DC_Huffman_Table);

    memset(encoder->Y_AC_Huffman_Table, 0, sizeof(encoder->Y_AC_Huffman_Table));
    JpegEncoder_computeHuffmanTable(Standard_AC_Luminance_NRCodes, Standard_AC_Luminance_Values, encoder->Y_AC_Huffman_Table);

    memset(encoder->CbCr_DC_Huffman_Table, 0, sizeof(encoder->CbCr_DC_Huffman_Table));
    JpegEncoder_computeHuffmanTable(Standard_DC_Chrominance_NRCodes, Standard_DC_Chrominance_Values, encoder->CbCr_DC_Huffman_Table);

    memset(encoder->CbCr_AC_Huffman_Table, 0, sizeof(encoder->CbCr_AC_Huffman_Table));
    JpegEncoder_computeHuffmanTable(Standard_AC_Chrominance_NRCodes, Standard_AC_Chrominance_Values, encoder->CbCr_AC_Huffman_Table);
}

// 量子化テーブルの初期化
void JpegEncoder_initQualityTables(JpegEncoder* encoder, int quality_scale) {
    if (quality_scale <= 0) quality_scale = 1;
    if (quality_scale >= 100) quality_scale = 99;

    for (int i = 0; i < 64; i++) {
        int temp = ((int)(Luminance_Quantization_Table[i] * quality_scale + 50) / 100);
        if (temp <= 0) temp = 1;
        if (temp > 0xFF) temp = 0xFF;
        encoder->YTable[ZigZag[i]] = (unsigned char)temp;

        temp = ((int)(Chrominance_Quantization_Table[i] * quality_scale + 50) / 100);
        if (temp <= 0) temp = 1;
        if (temp > 0xFF) temp = 0xFF;
        encoder->CbCrTable[ZigZag[i]] = (unsigned char)temp;
    }
  }

// ハフマンテーブルの計算
void JpegEncoder_computeHuffmanTable(const char* nr_codes, const unsigned char* std_table, BitString* huffman_table) {
    unsigned char pos_in_table = 0;
    unsigned short code_value = 0;

    for (int k = 1; k <= 16; k++) {
        for (int j = 1; j <= nr_codes[k - 1]; j++) {
            huffman_table[std_table[pos_in_table]].value = code_value;
            huffman_table[std_table[pos_in_table]].length = k;
            pos_in_table++;
            code_value++;
        }
        code_value <<= 1;
    }
}

// ビットコードの取得
BitString JpegEncoder_getBitCode(int value) {
    BitString ret;
    int v = (value > 0) ? value : -value;
    int length = 0;
    for (length = 0; v; v >>= 1) length++;

    ret.value = value > 0 ? value : ((1 << length) + value - 1);
    ret.length = length;
    return ret;
}

// バイト書き込み
void JpegEncoder_write_byte(unsigned char value, FILE* fp) {
    fwrite(&value, 1, 1, fp);
}

// ワード書き込み
void JpegEncoder_write_word(unsigned short value, FILE* fp) {
    unsigned short _value = ((value >> 8) & 0xFF) | ((value & 0xFF) << 8);
    fwrite(&_value, 2, 1, fp);
}

// 汎用書き込み
void JpegEncoder_write(const void* p, int byteSize, FILE* fp) {
    fwrite(p, 1, byteSize, fp);
}

// ハフマン符号化
void JpegEncoder_doHuffmanEncoding(const short* DU, short* prevDC, const BitString* HTDC, const BitString* HTAC, BitString* outputBitString, int* bitStringCounts) {
    BitString EOB = HTAC[0x00];
    BitString SIXTEEN_ZEROS = HTAC[0xF0];
    int index = 0;

    // DC係数の符号化
    int dcDiff = (int)(DU[0] - *prevDC);
    *prevDC = DU[0];

    if (dcDiff == 0) {
        outputBitString[index++] = HTDC[0];
    } else {
        BitString bs = JpegEncoder_getBitCode(dcDiff);
        outputBitString[index++] = HTDC[bs.length];
        outputBitString[index++] = bs;
    }

    // AC係数の符号化
    int endPos = 63;
    while (endPos > 0 && DU[endPos] == 0) endPos--;

    for (int i = 1; i <= endPos;) {
        int startPos = i;
        while (DU[i] == 0 && i <= endPos) i++;

        int zeroCounts = i - startPos;
        if (zeroCounts >= 16) {
            for (int j = 1; j <= zeroCounts / 16; j++)
                outputBitString[index++] = SIXTEEN_ZEROS;
            zeroCounts = zeroCounts % 16;
        }

        BitString bs = JpegEncoder_getBitCode(DU[i]);
        outputBitString[index++] = HTAC[(zeroCounts << 4) | bs.length];
        outputBitString[index++] = bs;
        i++;
    }

    if (endPos != 63) {
        outputBitString[index++] = EOB;
    }

    *bitStringCounts = index;
}

// ビットストリーム書き込み
void JpegEncoder_write_bitstring(const BitString* bs, int counts, int* newByte, int* newBytePos, FILE* fp) {
    static const unsigned short mask[] = {1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768};

    for (int i = 0; i < counts; i++) {
        int value = bs[i].value;
        int posval = bs[i].length - 1;

        while (posval >= 0) {
            if ((value & mask[posval]) != 0) {
                *newByte |= mask[*newBytePos];
            }
            posval--;
            (*newBytePos)--;
            if (*newBytePos < 0) {
                JpegEncoder_write_byte((unsigned char)(*newByte), fp);
                if (*newByte == 0xFF) {
                    JpegEncoder_write_byte(0x00, fp);
                }
                *newBytePos = 7;
                *newByte = 0;
            }
        }
    }
}

// 色空間変換
void JpegEncoder_convertColorSpace(const unsigned char* rgbBuffer, char* yData, char* cbData, char* crData, int width) {
    for (int y = 0; y < 8; y++) {
        const unsigned char* p = rgbBuffer + y * width * 3;
        for (int x = 0; x < 8; x++) {
            unsigned char B = *p++;
            unsigned char G = *p++;
            unsigned char R = *p++;

            yData[y * 8 + x] = (char)(0.299f * R + 0.587f * G + 0.114f * B - 128);
            cbData[y * 8 + x] = (char)(-0.1687f * R - 0.3313f * G + 0.5f * B);
            crData[y * 8 + x] = (char)(0.5f * R - 0.4187f * G - 0.0813f * B);
        }
    }
}

// DCTと量子化
void JpegEncoder_foword_FDC(const char* channel_data, short* fdc_data, const unsigned char* quant_table) {
    for (int v = 0; v < 8; v++) {
        for (int u = 0; u < 8; u++) {
            float alpha_u = (u == 0) ? 1.0f / sqrtf(8.0f) : 0.5f;
            float alpha_v = (v == 0) ? 1.0f / sqrtf(8.0f) : 0.5f;

            float temp = 0.0f;
            for (int x = 0; x < 8; x++) {
                for (int y = 0; y < 8; y++) {
                    float data = channel_data[y * 8 + x];
                    data *= cosf((2 * x + 1) * u * PI / 16.0f);
                    data *= cosf((2 * y + 1) * v * PI / 16.0f);
                    temp += data;
                }
            }
            int zigZagIndex = ZigZag[v * 8 + u];
            temp *= alpha_u * alpha_v / quant_table[zigZagIndex];
            fdc_data[zigZagIndex] = (short)((short)(temp + 16384.5) - 16384);
        }
    }
}

// JPEGヘッダ書き込み
void JpegEncoder_write_jpeg_header(JpegEncoder* encoder, FILE* fp) {
    // SOI
    JpegEncoder_write_word(0xFFD8, fp);

    // APP0
    JpegEncoder_write_word(0xFFE0, fp);
    JpegEncoder_write_word(16, fp);
    JpegEncoder_write("JFIF\0", 5, fp);
    JpegEncoder_write_byte(1, fp);
    JpegEncoder_write_byte(1, fp);
    JpegEncoder_write_byte(0, fp);
    JpegEncoder_write_word(1, fp);
    JpegEncoder_write_word(1, fp);
    JpegEncoder_write_byte(0, fp);
    JpegEncoder_write_byte(0, fp);

    // DQT
    JpegEncoder_write_word(0xFFDB, fp);
    JpegEncoder_write_word(132, fp);
    JpegEncoder_write_byte(0, fp);
    JpegEncoder_write(encoder->YTable, 64, fp);
    JpegEncoder_write_byte(1, fp);
    JpegEncoder_write(encoder->CbCrTable, 64, fp);

    // SOF0
    JpegEncoder_write_word(0xFFC0, fp);
    JpegEncoder_write_word(17, fp);
    JpegEncoder_write_byte(8, fp);
    JpegEncoder_write_word(encoder->height & 0xFFFF, fp);
    JpegEncoder_write_word(encoder->width & 0xFFFF, fp);
    JpegEncoder_write_byte(3, fp);
    JpegEncoder_write_byte(1, fp);
    JpegEncoder_write_byte(0x11, fp);
    JpegEncoder_write_byte(0, fp);
    JpegEncoder_write_byte(2, fp);
    JpegEncoder_write_byte(0x11, fp);
    JpegEncoder_write_byte(1, fp);
    JpegEncoder_write_byte(3, fp);
    JpegEncoder_write_byte(0x11, fp);
    JpegEncoder_write_byte(1, fp);

    // DHT
    JpegEncoder_write_word(0xFFC4, fp);
    JpegEncoder_write_word(0x01A2, fp);
    JpegEncoder_write_byte(0, fp);
    JpegEncoder_write(Standard_DC_Luminance_NRCodes, sizeof(Standard_DC_Luminance_NRCodes), fp);
    JpegEncoder_write(Standard_DC_Luminance_Values, sizeof(Standard_DC_Luminance_Values), fp);
    JpegEncoder_write_byte(0x10, fp);
    JpegEncoder_write(Standard_AC_Luminance_NRCodes, sizeof(Standard_AC_Luminance_NRCodes), fp);
    JpegEncoder_write(Standard_AC_Luminance_Values, sizeof(Standard_AC_Luminance_Values), fp);
    JpegEncoder_write_byte(0x01, fp);
    JpegEncoder_write(Standard_DC_Chrominance_NRCodes, sizeof(Standard_DC_Chrominance_NRCodes), fp);
    JpegEncoder_write(Standard_DC_Chrominance_Values, sizeof(Standard_DC_Chrominance_Values), fp);
    JpegEncoder_write_byte(0x11, fp);
    JpegEncoder_write(Standard_AC_Chrominance_NRCodes, sizeof(Standard_AC_Chrominance_NRCodes), fp);
    JpegEncoder_write(Standard_AC_Chrominance_Values, sizeof(Standard_AC_Chrominance_Values), fp);

    // SOS
    JpegEncoder_write_word(0xFFDA, fp);
    JpegEncoder_write_word(12, fp);
    JpegEncoder_write_byte(3, fp);
    JpegEncoder_write_byte(1, fp);
    JpegEncoder_write_byte(0, fp);
    JpegEncoder_write_byte(2, fp);
    JpegEncoder_write_byte(0x11, fp);
    JpegEncoder_write_byte(3, fp);
    JpegEncoder_write_byte(0x11, fp);
    JpegEncoder_write_byte(0, fp);
    JpegEncoder_write_byte(0x3F, fp);
    JpegEncoder_write_byte(0, fp);
}

// メインプログラム
int main(int argc, char* argv[]) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <input.bmp> <output.jpg> <quality_scale>\n", argv[0]);
        return 1;
    }

    JpegEncoder encoder;
    JpegEncoder_init(&encoder);

    if (!JpegEncoder_readFromBMP(&encoder, argv[1])) {
        fprintf(stderr, "Error: Failed to read BMP file %s\n", argv[1]);
        JpegEncoder_clean(&encoder);
        return 1;
    }

    int quality_scale = atoi(argv[3]);
    if (quality_scale < 1 || quality_scale > 100) {
        fprintf(stderr, "Error: Quality scale must be between 1 and 100\n");
        JpegEncoder_clean(&encoder);
        return 1;
    }

    if (!JpegEncoder_encodeToJPG(&encoder, argv[2], quality_scale)) {
        fprintf(stderr, "Error: Failed to encode to JPEG file %s\n", argv[2]);
        JpegEncoder_clean(&encoder);
        return 1;
    }

    printf("Successfully encoded %s to %s\n", argv[1], argv[2]);
    JpegEncoder_clean(&encoder);
    return 0;
}
