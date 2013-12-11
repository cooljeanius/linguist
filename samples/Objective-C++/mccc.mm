#import <Foundation/Foundation.h>

#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>

#define VERSION "0.7.1"

const char *helpmsg[] = {
	"使い方：mccc [flags] [入力ファイル名 [出力ファイル名]]\n",
	"[flags]は以下の通り\n",
	"-ia : 入力文字コード自動認識\n",
	"-iu : 入力はUTF-8 (デフォールト)\n",
	"-iU : 入力はUTF-16\n",
	"-ie : 入力はEUC-JP\n",
	"-is : 入力はShift-JIS\n",
	"-ij : 入力はJIS(ISO2022-JP)\n",
	"-ou : 出力はUTF-8\n",
	"-oU : 出力ははUTF-16\n",
	"-oe : 出力はEUC-JP (環境変数LANG未設定時のデフォールト)\n",
	"-os : 出力はShift-JIS\n",
	"-oj : 出力はJIS(ISO2022-JP)\n",
	"-t  : スルーモード(文字コード変換なし)\n",
	"-am : 入力改行コード自動認識、出力はCR(Mac)\n",
	"-au : 入力改行コード自動認識、出力はLF(UNIX)\n",
	"-aw : 入力改行コード自動認識、出力はCR+LF(Windows)\n",
	"-mu : 入力はCR(Mac)、出力はLF(UNIX)\n",
	"-mw : 入力はCR(Mac)、出力はCR+LF(Windows)\n",
	"-um : 入力はLF(UNIX)、出力はCR(Mac)\n",
	"-uw : 入力はLF(UNIX)、出力はCR+LF(Windows)\n",
	"-wm : 入力はCR+LF(Windows)、出力はCR(Mac)\n",
	"-wu : 入力はCR+LF(Windows)、出力はLF(UNIX)\n",
	"-lm : 混在したすべての種類の改行コードをCR(Mac)に\n",
	"-lu : 混在したすべての種類の改行コードをLF(UNIX)に\n",
	"-lw : 混在したすべての種類の改行コードをCR+LF(Windows)に\n",
	"-ow : オーバーライト(入力ファイルを出力ファイルとする)\n",
	"-nc : 出力ファイルが存在しても書き込む(元ファイルは壊れる)\n",
	"-fa : 入力改行コードと文字コードを自動認識し表示(変換はしない)\n",
	"-fc : 入力文字コードを自動認識し表示(変換はしない)\n",
	"-fl : 入力改行コードを自動認識し表示(変換はしない)\n",
	"-v  : バージョン表示(他のパラメータはすべて無視)\n",
	"-h  : ヘルプ表示(出力文字/改行コードに従って変換、入出力ファイル名無視)\n",
	"入力ファイル名指定なしあるいはstdin指定で標準入力\n",
	"-owなしかつ出力ファイル名指定なしで標準出力\n",
	"出力文字コードのデフォールトは環境変数LANGに従う\n",
	""
};

#define BUFUNIT  256
#define HANTEI   20000
#define MAXPOINT 2000
#define ESC 0x1b
#define CR  0x0d
#define LF  0x0a

#define JISSC  0
#define SJISSC 1
#define EUCSC  2
#define UTF8SC 3
#define UNISC  4

#define ALLLB   0x100
#define AUTOLB  0x80
#define INLBMAC 0x10
#define INLBUNX 0x20
#define INLBWIN 0x30
#define OTLBMAC 0x01
#define OTLBUNX 0x02
#define OTLBWIN 0x03

NSStringEncoding autodetect(const char *str, int size, int score[], int *tscore)
{
	NSStringEncoding code;
	int i;
	int sjis = score[SJISSC];
	int euc = score[EUCSC];
	int utf8 = score[UTF8SC];
	int jis = score[JISSC];

	const unsigned char *ptr = (const unsigned char *)str;

	code = NSUTF8StringEncoding;
	*tscore = utf8;

	if (size > 1) {
		if ((ptr[0] == 0xfe && ptr[1] == 0xff) ||
			(ptr[0] == 0xff && ptr[1] == 0xfe)) {
			code = NSUnicodeStringEncoding;
			score[UNISC] = HANTEI+1;
			*tscore = HANTEI+1;
			return (code);
		}
	}

	i = 0;
	while (i < size) {
		if (ptr[i] == CR || ptr[i] == LF) i++;
		else if (ptr[i] == ESC && (size - i >= 3)) {
			if ((ptr[i+1] == '$' && ptr[i+2] == 'B')||(ptr[i+1] == '(' && ptr[i+2] == 'B')) {
				code = NSISO2022JPStringEncoding;
				jis += MAXPOINT*2;
				i += 3;
			}
			else if ((ptr[i+1] == '$' && ptr[i+2] == '@')|| (ptr[i+1] == '(' && ptr[i+2] == 'J')) {
				code = NSISO2022JPStringEncoding;
				jis += MAXPOINT*2;
				i += 3;
			}
			else if (ptr[i+1] == '(' && ptr[i+2] == 'I') {
				code = NSISO2022JPStringEncoding;
				jis += 100;
				i += 3;
			}
			else if (ptr[i+1] == ')' && ptr[i+2] == 'I') {
				code = NSISO2022JPStringEncoding;
				jis += 100;
				i += 3;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] == 0x8E && (size - i >= 2)) {
			if ((ptr[i+1] >= 0x40 && ptr[i+1] <= 0x7E)||(ptr[i+1] >= 0x80 && ptr[i+1] <= 0xA0)) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] >= 0xFD && ptr[i+1] <= 0xFE) {
				code = NSJapaneseEUCStringEncoding;  /* half kana */
				euc += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xFC) {
				code = NSShiftJISStringEncoding;
				sjis += 100;
				euc += 70;	/* half kana */
				i += 2;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] == 0x8F && (size - i >= 2)) {
			if ((ptr[i+1] >= 0x40 && ptr[i+1] <= 0x7E)||(ptr[i+1] >= 0x80 && ptr[i+1] <= 0xA0)) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] >= 0xFD && ptr[i+1] <= 0xFE) {
				code = NSJapaneseEUCStringEncoding;  /* half kana */
				euc += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xFC) {
				if (size - i >= 3) {
					if ((ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F)||(ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F)) {
						code = NSShiftJISStringEncoding;
						sjis += MAXPOINT;
						i += 2;
					}
					else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xDF) {
						code = NSShiftJISStringEncoding;
						sjis += 70;
						euc += 70;	/* half kana */
						i += 3;
					}
					else if (ptr[i+2] >= 0xE0 && ptr[i+2] <= 0xEF) {
						code = NSShiftJISStringEncoding;
						sjis += 100;
						euc += 70;	/* half kana */
						i += 2;
					}
					else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 30;
						euc += 70;	/* half kana */
						i += 3;
					}
					else {
						i++;
					}
				}
				else {
					code = NSShiftJISStringEncoding;
					sjis += MAXPOINT;
					i += 2;
				}
			}
			else {
				i++;
			}
		}
		else if ((ptr[i] >= 0x81 && ptr[i] <= 0x9F) && (size - i >= 2)) {
			if ((ptr[i+1] >= 0x40 && ptr[i+1] <= 0x7E)||(ptr[i+1] >= 0x80 && ptr[i+1] <= 0xFC)) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] >= 0xA1 && ptr[i] <= 0xC1 && (size - i >= 2)) {
			if ((ptr[i+1] >= 0x20 && ptr[i+1] <= 0x7F)||(ptr[i+1] >= 0x81 && ptr[i+1] <= 0x9F)) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xDF) {
				code = NSJapaneseEUCStringEncoding;
				euc += 100;
				sjis += 50;
				i += 2;
			}
			else if (ptr[i+1] >= 0xE0 && ptr[i+1] <= 0xEF) {
				code = NSShiftJISStringEncoding;
				euc += 100;
				sjis += 100;
				i += 2;
			}
			else if (ptr[i+1] >= 0xF0 && ptr[i+1] <= 0xFE) {
				code = NSJapaneseEUCStringEncoding;
				euc += 100;
				sjis += 30;
				i += 2;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] >= 0xC2 && ptr[i] <= 0xDF && (size - i >= 2)) {
			if (ptr[i+1] >= 0x20 && ptr[i+1] <= 0x7F) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else if ((ptr[i+1] == 0x80)||(ptr[i+1] == 0xA0)) {
				code = NSUTF8StringEncoding;
				utf8 += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] >= 0x81 && ptr[i+1] <= 0x9F) {
				if (code == NSUTF8StringEncoding) {
					sjis += 25;
					utf8 += 30;
				}
				else {
					code = NSShiftJISStringEncoding;
					sjis += 70;
					utf8 += 30;
				}
				i += 2;
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xBF) {
				if (code == NSUTF8StringEncoding) {
					euc += 25;
					sjis += 15;
					utf8 += 30;
				}
				else {
					code = NSJapaneseEUCStringEncoding;
					euc += 100;
					sjis += 50;
					utf8 += 30;
				}
				i += 2;
			}
			else if (ptr[i+1] >= 0xC0 && ptr[i+1] <= 0xDF) {
				code = NSJapaneseEUCStringEncoding;
				euc += 100;
				sjis += 50;
				i += 2;
			}
			else if (ptr[i+1] >= 0xE0 && ptr[i+1] <= 0xEF) {
				code = NSJapaneseEUCStringEncoding;
				euc += 100;
				sjis += 70;
				i += 2;
			}
			else if (ptr[i+1] >= 0xF0 && ptr[i+1] <= 0xFE) {
				code = NSJapaneseEUCStringEncoding;
				euc += 100;
				sjis += 30;
				i += 2;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] == 0xE0 && (size - i >= 2)) {		// [E0]
			if ((ptr[i+1] >= 0x40 && ptr[i+1] <= 0x7E)||(ptr[i+1] >= 0x80 && ptr[i+1] <= 0x9F)) {	// [E0]{[40-7E],[80-9F]}
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] >= 0xC0 && ptr[i+1] <= 0xFC) {	// [E0][C0-FC]
				code = NSShiftJISStringEncoding;
				sjis += 100;
				euc += 100;
				i += 2;
			}
			else if (ptr[i+1] >= 0xFD && ptr[i+1] <= 0xFE) {
				code = NSJapaneseEUCStringEncoding;
				euc += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] == 0xA0 && (size - i >= 3)) {		// [E0][A0]
				if ((ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F)||(ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xEF)) {
					code = NSShiftJISStringEncoding;
					sjis += MAXPOINT;
					i += 2;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F) {
					utf8 += 100;
					sjis += 100;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF) {
					utf8 += 100;
					sjis += 70;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSShiftJISStringEncoding;
					sjis += 30;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xBF && (size - i >= 3)) {		// [E0][A1-BF]
				if (ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 3;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F) {
					utf8 += 100;
					sjis += 100;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF) {
					sjis += 70;
					euc += 100;
					utf8 += 100;
					if (euc > utf8 && code == NSJapaneseEUCStringEncoding) {
						i += 2;
					}
					else if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xDF) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 70;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xE0 && ptr[i+2] <= 0xEF) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 2;
				}
				else {
					i++;
				}
			}
			else {
				i++;
			}
		}
		else if (ptr[i] >= 0xE1 && ptr[i] <= 0xEC && (size - i >= 2)) {		// [E1-EC]
			if (ptr[i+1] >= 0x40 && ptr[i+1] <= 0x7E) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] >= 0x80 && ptr[i+1] <= 0xA0 && (size - i >= 3)) {		// [E1-EC][80-A0]
				if ((ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F)||(ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xEF)) {
					code = NSShiftJISStringEncoding;
					sjis += MAXPOINT;
					i += 2;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F) {
					utf8 += 100;
					sjis += 100;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF) {
					utf8 += 100;
					sjis += 70;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSShiftJISStringEncoding;
					sjis += 30;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xBF && (size - i >= 3)) {		// [E1-EC][A1-BF]
				if (ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 3;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F) {
					utf8 += 100;
					sjis += 100;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF) {
					sjis += 70;
					euc += 100;
					utf8 += 100;
					if (euc > utf8 && code == NSJapaneseEUCStringEncoding) {
						i += 2;
					}
					else if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xDF) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 70;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xE0 && ptr[i+2] <= 0xEF) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xC0 && ptr[i+1] <= 0xFC) {
				code = NSShiftJISStringEncoding;
				sjis += 100;
				euc += 100;
				i += 2;
			}
			else if (ptr[i+1] >= 0xFD && ptr[i+1] <= 0xFE) {
				code = NSJapaneseEUCStringEncoding;
				euc += MAXPOINT;
				i += 2;
			}
			else if (size - i == 2) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] == 0xED && (size - i >= 2)) {		// [ED]
			if ((ptr[i+1] >= 0x40 && ptr[i+1] <= 0x7E)||(ptr[i+1] == 0xA0)) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] >= 0x80 && ptr[i+1] <= 0x9F && (size - i >= 3)) {		// [ED][80-9F]
				if ((ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F)||(ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xEF)) {
					code = NSShiftJISStringEncoding;
					sjis += MAXPOINT;
					i += 2;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F) {
					utf8 += 100;
					sjis += 100;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF) {
					utf8 += 100;
					sjis += 70;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSShiftJISStringEncoding;
					sjis += 30;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] == 0xA0) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xFC) {
				code = NSShiftJISStringEncoding;
				sjis += 100;
				euc += 100;
				i += 2;
			}
			else if (ptr[i+1] >= 0xFD && ptr[i+1] <= 0xFE) {
				code = NSJapaneseEUCStringEncoding;
				euc += MAXPOINT;
				i += 2;
			}
			else if (size - i == 2) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] == 0xEE && (size - i >= 2)) {		// [EE]
			if (ptr[i+1] >= 0x40 && ptr[i+1] <= 0x7E) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] >= 0x80 && ptr[i+1] <= 0xA0 && (size - i >= 3)) {		// [EE][80-A0]
				if ((ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F)||(ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xEF)) {
					code = NSShiftJISStringEncoding;
					sjis += MAXPOINT;
					i += 2;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F) {
					utf8 += 70;
					sjis += 100;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF) {
					utf8 += 70;
					sjis += 70;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSShiftJISStringEncoding;
					sjis += 30;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xBF && (size - i >= 3)) {		// [EE][A1-BF]
				if (ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 3;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F) {
					utf8 += 70;
					sjis += 100;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF) {
					sjis += 70;
					euc += 100;
					utf8 += 70;
					if (euc > utf8 && code == NSJapaneseEUCStringEncoding) {
						i += 2;
					}
					else if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xDF) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 70;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xE0 && ptr[i+2] <= 0xEF) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xC0 && ptr[i+1] <= 0xFC) {
				code = NSShiftJISStringEncoding;
				sjis += 100;
				euc += 100;
				i += 2;
			}
			else if (ptr[i+1] >= 0xFD && ptr[i+1] <= 0xFE) {
				code = NSJapaneseEUCStringEncoding;
				euc += MAXPOINT;
				i += 2;
			}
			else if (size - i == 2) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] == 0xEF && (size - i >= 2)) {		// [EF]
			if (ptr[i+1] >= 0x40 && ptr[i+1] <= 0x7E) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else if (ptr[i+1] >= 0x80 && ptr[i+1] <= 0xA0 && (size - i >= 3)) {		// [EF][80-A0]
				if ((ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F)||(ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xEF)) {
					code = NSShiftJISStringEncoding;
					sjis += MAXPOINT;
					i += 2;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F) {
					utf8 += 70;
					sjis += 100;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF) {
					utf8 += 70;
					sjis += 70;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSShiftJISStringEncoding;
					sjis += 30;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xA3 && (size - i >= 3)) {		// [EF][A1-A3]
				if (ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 3;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F) {
					utf8 += 70;
					sjis += 100;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF) {
					sjis += 70;
					euc += 100;
					utf8 += 70;
					if (euc > utf8 && code == NSJapaneseEUCStringEncoding) {
						i += 2;
					}
					else if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xDF) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 70;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xE0 && ptr[i+2] <= 0xEF) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xA4 && ptr[i+1] <= 0xBF && (size - i >= 3)) {		// [EF][A4-BF]
				if (ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 3;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F) {
					utf8 += 100;
					sjis += 100;
					if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF) {
					sjis += 70;
					euc += 100;
					utf8 += 100;
					if (euc > utf8 && code == NSJapaneseEUCStringEncoding) {
						i += 2;
					}
					else if (sjis > utf8 && code == NSShiftJISStringEncoding) {
						i += 2;
					}
					else {
						i += 3;
						code = NSUTF8StringEncoding;
					}
				}
				else if (ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xDF) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 70;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xE0 && ptr[i+2] <= 0xEF) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xC0 && ptr[i+1] <= 0xFC) {
				code = NSShiftJISStringEncoding;
				sjis += 100;
				euc += 100;
				i += 2;
			}
			else if (ptr[i+1] >= 0xFD && ptr[i+1] <= 0xFE) {
				code = NSJapaneseEUCStringEncoding;
				euc += MAXPOINT;
				i += 2;
			}
			else if (size - i == 2) {
				code = NSShiftJISStringEncoding;
				sjis += MAXPOINT;
				i += 2;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] == 0xF0 && (size - i >= 2)) {		// [F0]
			if ((ptr[i+1] >= 0x40 && ptr[i+1] <= 0x7E)||(ptr[i+1] >= 0x80 && ptr[i+1] <= 0x8F)) {
				code = NSShiftJISStringEncoding;
				sjis += 30;
				i += 2;
			}
			else if (ptr[i+1] >= 0x90 && ptr[i+1] <= 0xA0 && (size - i >= 3)) {		// [F0][90-A0]
				if ((ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F)||(ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xEF)) {
					code = NSShiftJISStringEncoding;
					sjis += 30;
					i += 2;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F && (size - i >= 4)) {	// [F0][90-A0][81-9F]
					if ((ptr[i+3] >= 0x40 && ptr[i+3] <= 0x7E)||(ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xFC)) {
						code = NSShiftJISStringEncoding;
						sjis += 30;
						i += 2;
					}
					else if (ptr[i+3] >= 0x80 && ptr[i+3] <= 0xBF) {
						utf8 += 100;
						sjis += 30;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF && (size - i >= 4)) {	// [F0][90-A0][A1-BF]
					if ((ptr[i+3] >= 0x20 && ptr[i+3] <= 0x7F)||(ptr[i+3] >= 0xE0 && ptr[i+3] <= 0xEF)) {
						code = NSShiftJISStringEncoding;
						sjis += 20;
						i += 2;
					}
					else if (ptr[i+3] == 0x80 && ptr[i+3] == 0xA0) {
						code = NSUTF8StringEncoding;
						utf8 += MAXPOINT;
						i += 4;
					}
					else if (ptr[i+3] >= 0x81 && ptr[i+3] <= 0x9F) {
						utf8 += 100;
						sjis += 20;
						i += 4;
					}
					else if (ptr[i+3] >= 0xA1 && ptr[i+3] <= 0xBF) {
						utf8 += 100;
						sjis += 15;
						i += 4;
					}
					else if (ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xDF) {
						code = NSShiftJISStringEncoding;
						sjis += 15;
						i += 4;
					}
					else if (ptr[i+3] >= 0xF0 && ptr[i+3] <= 0xFE) {
						code = NSShiftJISStringEncoding;
						sjis += 5;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSShiftJISStringEncoding;
					sjis += 10;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xBF && (size - i >= 3)) {		// [F0][A1-BF]
				if (ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 3;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F && (size - i >= 4)) {	// [F0][A1-BF][81-9F]
					if ((ptr[i+3] >= 0x40 && ptr[i+3] <= 0x7E)||(ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xFC)) {
						code = NSShiftJISStringEncoding;
						sjis += 20;
						i += 2;
					}
					else if (ptr[i+3] >= 0x80 && ptr[i+3] <= 0xBF) {
						utf8 += 100;
						sjis += 20;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF && (size - i >= 4)) {	// [F0][A1-BF][A1-BF]
					if (ptr[i+3] >= 0x20 && ptr[i+3] <= 0x7F) {
						code = NSShiftJISStringEncoding;
						sjis += 15;
						i += 2;
					}
					else if (ptr[i+3] == 0x80 && ptr[i+3] == 0xA0) {
						code = NSUTF8StringEncoding;
						utf8 += MAXPOINT;
						i += 4;
					}
					else if (ptr[i+3] >= 0x81 && ptr[i+3] <= 0x9F) {
						utf8 += 100;
						sjis += 15;
						i += 4;
					}
					else if (ptr[i+3] >= 0xA1 && ptr[i+3] <= 0xBF) {
						if (code == NSUTF8StringEncoding) {
							utf8 += 100;
							sjis += 10;
							euc += 95;
						}
						else {
							code = NSJapaneseEUCStringEncoding;
							utf8 += 100;
							sjis += 10;
							euc += 150;
						}
						i += 4;
					}
					else if (ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xDF) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 15;
						euc += 150;
						i += 4;
					}
					else if (ptr[i+3] >= 0xE0 && ptr[i+3] <= 0xEF) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 20;
						euc += 150;
						i += 4;
					}
					else if (ptr[i+3] >= 0xF0 && ptr[i+3] <= 0xFE) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 5;
						euc += 150;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xDF) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 70;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xE0 && ptr[i+2] <= 0xEF) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xC0 && ptr[i+1] <= 0xFC) {	// [F0][C0-FC]
				code = NSJapaneseEUCStringEncoding;
				sjis += 30;
				euc += 100;
				i += 2;
			}
			else if (ptr[i+1] >= 0xFD && ptr[i+1] <= 0xFE) {	// [F0][FD-FE]
				code = NSJapaneseEUCStringEncoding;
				euc += MAXPOINT;
				i += 2;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] >= 0xF1 && ptr[i] <= 0xF2 && (size - i >= 2)) {		// [F1-F2]
			if (ptr[i+1] >= 0x40 && ptr[i+1] <= 0x7E) {
				code = NSShiftJISStringEncoding;
				sjis += 30;
				i += 2;
			}
			else if (ptr[i+1] >= 0x80 && ptr[i+1] <= 0xA0 && (size - i >= 3)) {		// [F1-F2][80-A0]
				if ((ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F)||(ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xEF)) {
					code = NSShiftJISStringEncoding;
					sjis += 30;
					i += 2;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F && (size - i >= 4)) {	// [F1-F2][90-A0][81-9F]
					if ((ptr[i+3] >= 0x40 && ptr[i+3] <= 0x7E)||(ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xFC)) {
						code = NSShiftJISStringEncoding;
						sjis += 30;
						i += 2;
					}
					else if (ptr[i+3] >= 0x80 && ptr[i+3] <= 0xBF) {
						utf8 += 100;
						sjis += 30;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF && (size - i >= 4)) {	// [F1-F2][90-A0][A1-BF]
					if ((ptr[i+3] >= 0x20 && ptr[i+3] <= 0x7F)||(ptr[i+3] >= 0xE0 && ptr[i+3] <= 0xEF)) {
						code = NSShiftJISStringEncoding;
						sjis += 20;
						i += 2;
					}
					else if (ptr[i+3] == 0x80 && ptr[i+3] == 0xA0) {
						code = NSUTF8StringEncoding;
						utf8 += MAXPOINT;
						i += 4;
					}
					else if (ptr[i+3] >= 0x81 && ptr[i+3] <= 0x9F) {
						utf8 += 100;
						sjis += 20;
						i += 4;
					}
					else if (ptr[i+3] >= 0xA1 && ptr[i+3] <= 0xBF) {
						utf8 += 100;
						sjis += 15;
						i += 4;
					}
					else if (ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xDF) {
						code = NSShiftJISStringEncoding;
						sjis += 15;
						i += 4;
					}
					else if (ptr[i+3] >= 0xF0 && ptr[i+3] <= 0xFE) {
						code = NSShiftJISStringEncoding;
						sjis += 5;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSShiftJISStringEncoding;
					sjis += 10;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xBF && (size - i >= 3)) {		// [F1-F2][A1-BF]
				if (ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 3;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F && (size - i >= 4)) {	// [F1-F2][A1-BF][81-9F]
					if ((ptr[i+3] >= 0x40 && ptr[i+3] <= 0x7E)||(ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xFC)) {
						code = NSShiftJISStringEncoding;
						sjis += 20;
						i += 2;
					}
					else if (ptr[i+3] >= 0x80 && ptr[i+3] <= 0xBF) {
						utf8 += 100;
						sjis += 20;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF && (size - i >= 4)) {	// [F1-F2][A1-BF][A1-BF]
					if (ptr[i+3] >= 0x20 && ptr[i+3] <= 0x7F) {
						code = NSShiftJISStringEncoding;
						sjis += 15;
						i += 2;
					}
					else if (ptr[i+3] == 0x80 && ptr[i+3] == 0xA0) {
						code = NSUTF8StringEncoding;
						utf8 += MAXPOINT;
						i += 4;
					}
					else if (ptr[i+3] >= 0x81 && ptr[i+3] <= 0x9F) {
						utf8 += 100;
						sjis += 15;
						i += 4;
					}
					else if (ptr[i+3] >= 0xA1 && ptr[i+3] <= 0xBF) {
						if (code == NSUTF8StringEncoding) {
							utf8 += 100;
							sjis += 10;
							euc += 95;
						}
						else {
							code = NSJapaneseEUCStringEncoding;
							utf8 += 100;
							sjis += 10;
							euc += 150;
						}
						i += 4;
					}
					else if (ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xDF) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 15;
						euc += 150;
						i += 4;
					}
					else if (ptr[i+3] >= 0xE0 && ptr[i+3] <= 0xEF) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 20;
						euc += 150;
						i += 4;
					}
					else if (ptr[i+3] >= 0xF0 && ptr[i+3] <= 0xFE) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 5;
						euc += 150;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xDF) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 70;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xE0 && ptr[i+2] <= 0xEF) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xC0 && ptr[i+1] <= 0xFC) {	// [F1-F2][C0-FC]
				code = NSJapaneseEUCStringEncoding;
				sjis += 30;
				euc += 100;
				i += 2;
			}
			else if (ptr[i+1] >= 0xFD && ptr[i+1] <= 0xFE) {	// [F1-F2][FD-FE]
				code = NSJapaneseEUCStringEncoding;
				euc += MAXPOINT;
				i += 2;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] == 0xF3 && (size - i >= 2)) {		// [F3]
			if (ptr[i+1] >= 0x40 && ptr[i+1] <= 0x7E) {
				code = NSShiftJISStringEncoding;
				sjis += 30;
				i += 2;
			}
			else if (ptr[i+1] >= 0x80 && ptr[i+1] <= 0xA0 && (size - i >= 3)) {		// [F3][80-A0]
				if ((ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F)||(ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xEF)) {
					code = NSShiftJISStringEncoding;
					sjis += 30;
					i += 2;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F && (size - i >= 4)) {	// [F0][90-A0][81-9F]
					if ((ptr[i+3] >= 0x40 && ptr[i+3] <= 0x7E)||(ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xFC)) {
						code = NSShiftJISStringEncoding;
						sjis += 30;
						i += 2;
					}
					else if (ptr[i+3] >= 0x80 && ptr[i+3] <= 0xBF) {
						utf8 += 100;
						sjis += 30;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF && (size - i >= 4)) {	// [F0][90-A0][A1-BF]
					if ((ptr[i+3] >= 0x20 && ptr[i+3] <= 0x7F)||(ptr[i+3] >= 0xE0 && ptr[i+3] <= 0xEF)) {
						code = NSShiftJISStringEncoding;
						sjis += 20;
						i += 2;
					}
					else if (ptr[i+3] == 0x80 && ptr[i+3] == 0xA0) {
						code = NSUTF8StringEncoding;
						utf8 += MAXPOINT;
						i += 4;
					}
					else if (ptr[i+3] >= 0x81 && ptr[i+3] <= 0x9F) {
						utf8 += 100;
						sjis += 20;
						i += 4;
					}
					else if (ptr[i+3] >= 0xA1 && ptr[i+3] <= 0xBF) {
						utf8 += 100;
						sjis += 15;
						i += 4;
					}
					else if (ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xDF) {
						code = NSShiftJISStringEncoding;
						sjis += 15;
						i += 4;
					}
					else if (ptr[i+3] >= 0xF0 && ptr[i+3] <= 0xFE) {
						code = NSShiftJISStringEncoding;
						sjis += 5;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSShiftJISStringEncoding;
					sjis += 10;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xAF && (size - i >= 3)) {		// [F3][A1-AF]
				if (ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 3;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F && (size - i >= 4)) {	// [F0][A1-BF][81-9F]
					if ((ptr[i+3] >= 0x40 && ptr[i+3] <= 0x7E)||(ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xFC)) {
						code = NSShiftJISStringEncoding;
						sjis += 20;
						i += 2;
					}
					else if (ptr[i+3] >= 0x80 && ptr[i+3] <= 0xBF) {
						utf8 += 100;
						sjis += 20;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF && (size - i >= 4)) {	// [F0][A1-BF][A1-BF]
					if (ptr[i+3] >= 0x20 && ptr[i+3] <= 0x7F) {
						code = NSShiftJISStringEncoding;
						sjis += 15;
						i += 2;
					}
					else if (ptr[i+3] == 0x80 && ptr[i+3] == 0xA0) {
						code = NSUTF8StringEncoding;
						utf8 += MAXPOINT;
						i += 4;
					}
					else if (ptr[i+3] >= 0x81 && ptr[i+3] <= 0x9F) {
						utf8 += 100;
						sjis += 15;
						i += 4;
					}
					else if (ptr[i+3] >= 0xA1 && ptr[i+3] <= 0xBF) {
						if (code == NSUTF8StringEncoding) {
							utf8 += 100;
							sjis += 10;
							euc += 95;
						}
						else {
							code = NSJapaneseEUCStringEncoding;
							utf8 += 100;
							sjis += 10;
							euc += 150;
						}
						i += 4;
					}
					else if (ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xDF) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 15;
						euc += 150;
						i += 4;
					}
					else if (ptr[i+3] >= 0xE0 && ptr[i+3] <= 0xEF) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 20;
						euc += 150;
						i += 4;
					}
					else if (ptr[i+3] >= 0xF0 && ptr[i+3] <= 0xFE) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 5;
						euc += 150;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xDF) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 70;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xE0 && ptr[i+2] <= 0xEF) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xB0 && ptr[i+1] <= 0xBF && (size - i >= 3)) {		// [F3][B0-BF]
				if (ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 3;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F && (size - i >= 4)) {	// [F0][A1-BF][81-9F]
					if ((ptr[i+3] >= 0x40 && ptr[i+3] <= 0x7E)||(ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xFC)) {
						code = NSShiftJISStringEncoding;
						sjis += 20;
						i += 2;
					}
					else if (ptr[i+3] >= 0x80 && ptr[i+3] <= 0xBF) {
						utf8 += 70;
						sjis += 20;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF && (size - i >= 4)) {	// [F0][A1-BF][A1-BF]
					if (ptr[i+3] >= 0x20 && ptr[i+3] <= 0x7F) {
						code = NSShiftJISStringEncoding;
						sjis += 15;
						i += 2;
					}
					else if (ptr[i+3] == 0x80 && ptr[i+3] == 0xA0) {
						code = NSUTF8StringEncoding;
						utf8 += MAXPOINT;
						i += 4;
					}
					else if (ptr[i+3] >= 0x81 && ptr[i+3] <= 0x9F) {
						utf8 += 70;
						sjis += 15;
						i += 4;
					}
					else if (ptr[i+3] >= 0xA1 && ptr[i+3] <= 0xBF) {
						if (code == NSUTF8StringEncoding) {
							utf8 += 70;
							sjis += 10;
							euc += 65;
						}
						else {
							code = NSJapaneseEUCStringEncoding;
							utf8 += 70;
							sjis += 10;
							euc += 150;
						}
						i += 4;
					}
					else if (ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xDF) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 15;
						euc += 150;
						i += 4;
					}
					else if (ptr[i+3] >= 0xE0 && ptr[i+3] <= 0xEF) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 20;
						euc += 150;
						i += 4;
					}
					else if (ptr[i+3] >= 0xF0 && ptr[i+3] <= 0xFE) {
						code = NSJapaneseEUCStringEncoding;
						sjis += 5;
						euc += 150;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xDF) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 70;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xE0 && ptr[i+2] <= 0xEF) {
					code = NSShiftJISStringEncoding;
					sjis += 100;
					euc += 100;
					i += 2;
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSJapaneseEUCStringEncoding;
					sjis += 30;
					euc += 100;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xC0 && ptr[i+1] <= 0xFC) {	// [F3][C0-FC]
				code = NSJapaneseEUCStringEncoding;
				sjis += 30;
				euc += 100;
				i += 2;
			}
			else if (ptr[i+1] >= 0xFD && ptr[i+1] <= 0xFE) {	// [F3][FD-FE]
				code = NSJapaneseEUCStringEncoding;
				euc += MAXPOINT;
				i += 2;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] == 0xF4 && (size - i >= 2)) {		// [F4]
			if ((ptr[i+1] >= 0x40 && ptr[i+1] <= 0x7E)||(ptr[i+1] >= 0x90 && ptr[i+1] <= 0xA0)) {
				code = NSShiftJISStringEncoding;
				sjis += 30;
				i += 2;
			}
			else if (ptr[i+1] >= 0x80 && ptr[i+1] <= 0x8F && (size - i >= 3)) {		// [F4][80-8F]
				if ((ptr[i+2] >= 0x20 && ptr[i+2] <= 0x7F)||(ptr[i+2] >= 0xC0 && ptr[i+2] <= 0xEF)) {
					code = NSShiftJISStringEncoding;
					sjis += 30;
					i += 2;
				}
				else if (ptr[i+2] == 0x80 || ptr[i+2] == 0xA0) {
					code = NSUTF8StringEncoding;
					utf8 += MAXPOINT;
					i += 3;
				}
				else if (ptr[i+2] >= 0x81 && ptr[i+2] <= 0x9F && (size - i >= 4)) {	// [F4][80-8F][81-9F]
					if ((ptr[i+3] >= 0x40 && ptr[i+3] <= 0x7E)||(ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xFC)) {
						code = NSShiftJISStringEncoding;
						sjis += 30;
						i += 2;
					}
					else if (ptr[i+3] >= 0x80 && ptr[i+3] <= 0xBF) {
						utf8 += 70;
						sjis += 30;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xA1 && ptr[i+2] <= 0xBF && (size - i >= 4)) {	// [F4][80-8F][A1-BF]
					if ((ptr[i+3] >= 0x20 && ptr[i+3] <= 0x7F)||(ptr[i+3] >= 0xE0 && ptr[i+3] <= 0xEF)) {
						code = NSShiftJISStringEncoding;
						sjis += 20;
						i += 2;
					}
					else if (ptr[i+3] == 0x80 && ptr[i+3] == 0xA0) {
						code = NSUTF8StringEncoding;
						utf8 += MAXPOINT;
						i += 4;
					}
					else if (ptr[i+3] >= 0x81 && ptr[i+3] <= 0x9F) {
						utf8 += 70;
						sjis += 20;
						i += 4;
					}
					else if (ptr[i+3] >= 0xA1 && ptr[i+3] <= 0xBF) {
						utf8 += 70;
						sjis += 15;
						i += 4;
					}
					else if (ptr[i+3] >= 0xC0 && ptr[i+3] <= 0xDF) {
						code = NSShiftJISStringEncoding;
						sjis += 15;
						i += 4;
					}
					else if (ptr[i+3] >= 0xF0 && ptr[i+3] <= 0xFE) {
						code = NSShiftJISStringEncoding;
						sjis += 5;
						i += 4;
					}
					else {
						i++;
					}
				}
				else if (ptr[i+2] >= 0xF0 && ptr[i+2] <= 0xFE) {
					code = NSShiftJISStringEncoding;
					sjis += 10;
					i += 2;
				}
				else {
					i++;
				}
			}
			else if (ptr[i+1] >= 0xA1 && ptr[i+1] <= 0xFC) {	// [F4][A1-FC]
				code = NSJapaneseEUCStringEncoding;
				sjis += 30;
				euc += 100;
				i += 2;
			}
			else if (ptr[i+1] >= 0xFD && ptr[i+1] <= 0xFE) {	// [F4][FD-FE]
				code = NSJapaneseEUCStringEncoding;
				euc += MAXPOINT;
				i += 2;
			}
			else {
				i++;
			}
		}
		else if (ptr[i] >= 0xF5 && ptr[i] <= 0xFE && (size - i >= 2)) {		// [F5-FE]
			code = NSJapaneseEUCStringEncoding;
			sjis += 30;
			euc += 100;
			i += 2;
		}
		else {
			i++;
		}
		
		if (euc > HANTEI || sjis > HANTEI || utf8 > HANTEI || jis > HANTEI) break;
	}

	score[JISSC] = jis;
	score[SJISSC] = sjis;
	score[EUCSC] = euc;
	score[UTF8SC] = utf8;

// for debug
// printf ("%s\ni = %i\n", &ptr[i], i);
// printf ("size = %i\n", size);
// printf ("utf8=%i, sjis=%i, euc=%i, jis=%i\n", utf8, sjis, euc, jis);

	if (utf8 > sjis) {
		if (utf8 > euc) {
			if (utf8 > jis) {
				code = NSUTF8StringEncoding;
			}
			else if (jis > utf8) {
				code = NSISO2022JPStringEncoding;
			}
		}
		else if (euc > utf8) {
			if (euc > jis) {
				code = NSJapaneseEUCStringEncoding;
			}
			else if (jis > euc) {
				code = NSISO2022JPStringEncoding;
			}
		}
	}
	else if (sjis > utf8) {
		if (sjis > euc) {
			if (sjis > jis) {
				code = NSShiftJISStringEncoding;
			}
			else if (jis > sjis) {
				code = NSISO2022JPStringEncoding;
			}
		}
		else if (euc > sjis) {
			if (euc > jis) {
				code = NSJapaneseEUCStringEncoding;
			}
			else if (jis > euc) {
				code = NSISO2022JPStringEncoding;
			}
		}
	}

	if (code == NSISO2022JPStringEncoding)
		*tscore = jis;
	else if (code == NSJapaneseEUCStringEncoding)
		*tscore = euc;
	else if (code ==  NSShiftJISStringEncoding)
		*tscore = sjis;
	else if (code == NSUTF8StringEncoding)
		*tscore = utf8;
	else
		*tscore = 0;

	return (code);
}

int lbset(int lbf, char *inbuf2) {
	if ((lbf & OTLBWIN) == OTLBWIN) {
		inbuf2[0] = CR;
		inbuf2[1] = LF;
		return (2);
	}
	else if (lbf & OTLBMAC) {
		inbuf2[0] = CR;
		return (1);
	}
	else if (lbf & OTLBUNX) {
		inbuf2[0] = LF;
		return (1);
	}
	else
		return (0);
}

int lbset2(int lbf, char *inbuf2) {
	if ((lbf & OTLBWIN) == OTLBWIN) {
		inbuf2[0] = '\0';
		inbuf2[1] = CR;
		inbuf2[2] = '\0';
		inbuf2[3] = LF;
		return (4);
	}
	else if (lbf & OTLBMAC) {
		inbuf2[0] = '\0';
		inbuf2[1] = CR;
		return (2);
	}
	else if (lbf & OTLBUNX) {
		inbuf2[0] = '\0';
		inbuf2[1] = LF;
		return (2);
	}
	else
		return (0);
}

int lbconv(int lbf, char *inbuf, int itsize, char *inbuf2, int *cf) {
	int pin, pout, inlbf;

	*cf = 0;
	inlbf = lbf & 0xFF0;
	for (pin = pout = 0; pin < itsize; pin++) {
		if (inlbf & AUTOLB) {
			if (inbuf[pin] == CR) {
				if (pin + 1 < itsize) {
					if (inbuf[pin+1] == LF) {
						if ((inlbf & ALLLB) == 0) inlbf = INLBWIN;
						pin++;
						pout += lbset(lbf, &inbuf2[pout]);
					}
					else {
						if ((inlbf & ALLLB) == 0) inlbf = INLBMAC;
						pout += lbset(lbf, &inbuf2[pout]);
					}
				}
				else {
					*cf = 1;
				}
			}
			else if (inbuf[pin] == LF) {
				if ((inlbf & ALLLB) == 0) inlbf = INLBUNX;
				pout += lbset(lbf, &inbuf2[pout]);
			}
			else {
				inbuf2[pout] = inbuf[pin];
				pout++;
			}
		}
		else if (inbuf[pin] == CR) {
			if (inlbf == INLBWIN) {
				if (pin + 1 < itsize) {
					if (inbuf[pin+1] == LF) {
						pin++;
						pout += lbset(lbf, &inbuf2[pout]);
					}
					else {
						inbuf2[pout] = inbuf[pin];
						pout++;
					}
				}
				else {
					*cf = 1;
				}
			}
			else if (inlbf == INLBMAC) {
				pout += lbset(lbf, &inbuf2[pout]);
			}
			else {
				inbuf2[pout] = inbuf[pin];
				pout++;
			}
		}
		else if (inbuf[pin] == LF) {
			if (inlbf == INLBUNX) {
				pout += lbset(lbf, &inbuf2[pout]);
			}
			else {
				inbuf2[pout] = inbuf[pin];
				pout++;
			}
		}
		else {
			inbuf2[pout] = inbuf[pin];
			pout++;
		}
	}

	return (pout);
}

int lbconv2(int lbf, char *inbuf, int itsize, char *inbuf2, int *cf) {
	int pin, pout, inlbf;

	*cf = 0;
	inlbf = lbf & 0xFF0;
	for (pin = pout = 0; pin < itsize; pin += 2) {
		if (inlbf & AUTOLB) {
			if (inbuf[pin] == '\0' && inbuf[pin+1] == CR) {
				if (pin + 3 < itsize) {
					if (inbuf[pin+2] == '\0' && inbuf[pin+3] == LF) {
						if ((inlbf & ALLLB) == 0) inlbf = INLBWIN;
						pin += 2;
						pout += lbset2(lbf, &inbuf2[pout]);
					}
					else {
						if ((inlbf & ALLLB) == 0) inlbf = INLBMAC;
						pout += lbset2(lbf, &inbuf2[pout]);
					}
				}
				else {
					*cf = 2;
				}
			}
			else if (inbuf[pin] == '\0' && inbuf[pin+1] == LF) {
				if ((inlbf & ALLLB) == 0) inlbf = INLBUNX;
				pout += lbset2(lbf, &inbuf2[pout]);
			}
			else {
				inbuf2[pout++] = inbuf[pin];
				inbuf2[pout++] = inbuf[pin+1];
			}
		}
		else if (inbuf[pin] == '\0' && inbuf[pin+1] == CR) {
			if (inlbf == INLBWIN) {
				if (pin + 3 < itsize) {
					if (inbuf[pin+2] == '\0' && inbuf[pin+3] == LF) {
						pin += 2;
						pout += lbset2(lbf, &inbuf2[pout]);
					}
					else {
						inbuf2[pout++] = inbuf[pin];
						inbuf2[pout++] = inbuf[pin+1];
					}
				}
				else {
					*cf = 2;
				}
			}
			else if (inlbf == INLBMAC) {
				pout += lbset2(lbf, &inbuf2[pout]);
			}
			else {
				inbuf2[pout++] = inbuf[pin];
				inbuf2[pout++] = inbuf[pin+1];
			}
		}
		else if (inbuf[pin] == '\0' && inbuf[pin+1] == LF) {
			if (inlbf == INLBUNX) {
				pout += lbset2(lbf, &inbuf2[pout]);
			}
			else {
				inbuf2[pout++] = inbuf[pin];
				inbuf2[pout++] = inbuf[pin+1];
			}
		}
		else {
			inbuf2[pout++] = inbuf[pin];
			inbuf2[pout++] = inbuf[pin+1];
		}
	}

	return (pout);
}

int lbdetect(int lbf, char *inbuf, int itsize) {
	int pin, inlbf;

	inlbf = lbf & 0xF0;
	for (pin = 0; pin < itsize; pin++) {
		if (inbuf[pin] == CR) {
			if (pin + 1 < itsize) {
				if (inbuf[pin+1] == LF) {
					inlbf = INLBWIN;
					pin++;
					break;
				}
				else {
					inlbf = INLBMAC;
					break;
				}
			}
		}
		else if (inbuf[pin] == LF) {
			inlbf = INLBUNX;
			break;
		}
	}

	return (inlbf);
}

int lbdetect2(int lbf, char *inbuf, int itsize) {
	int pin, inlbf;

	inlbf = lbf & 0xF0;
	for (pin = 0; pin < itsize; pin += 2) {
		if (inbuf[pin] == '\0' && inbuf[pin+1] == CR) {
			if (pin + 3 < itsize) {
				if (inbuf[pin+2] == '\0' && inbuf[pin+3] == LF) {
					inlbf = INLBWIN;
					pin += 2;
					break;
				}
				else {
					inlbf = INLBMAC;
					break;
				}
			}
		}
		else if (inbuf[pin] == '\0' && inbuf[pin+1] == LF) {
			inlbf = INLBUNX;
			break;
		}
	}

	return (inlbf);
}

int lbsearch(char *inbuf, int itsize) {
	int i;
	
	for (i = itsize - 1; i >= 0; i--) {
		if (inbuf[i] == CR || inbuf[i] == LF) break;
	}
	return (i);
}

int main(int argc, const char *argv[]) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSStringEncoding  ienc, oenc;
	NSString          *iestring;
	NSData            *ionsdata;
	int i, j, icsize, itsize, lbp, olbp, autof, score[5], tscore;
	int lbf, tf, itsize2, iunif, cf, owf, owbsize, helpflg, fcf, flf, ilb, nock;
	const char *op, *ofname;
	char *inbuf, *inbuf2, *inbuftmp, *outbuf, *owbuf, *owbuftmp;
	char *plang;
	FILE *ofd;
	struct stat statbuf;
	
	ienc = NSUTF8StringEncoding;
	plang = getenv("LANG");
	if (plang == NULL)
		oenc = NSJapaneseEUCStringEncoding;
	else if (strcmp(plang, "ja_JP.eucJP") == 0 || strcmp(plang, "ja_JP.EUC") == 0 ||
			strcmp(plang, "ja_JP.EUC-JP") == 0 || strcmp(plang, "ja_JP.ujis") == 0)
		oenc = NSJapaneseEUCStringEncoding;
	else if (strcmp(plang, "ja_JP.SJIS") == 0)
		oenc = NSShiftJISStringEncoding;
	else if (strcmp(plang, "ja_JP.UTF-8") == 0)
		oenc = NSUTF8StringEncoding;
	else if (strcmp(plang, "ja_JP.ISO-2022-JP") == 0 || strcmp(plang, "ja_JP.JIS") == 0)
		oenc = NSISO2022JPStringEncoding;
	else
		oenc = NSJapaneseEUCStringEncoding;
	autof = 0;
	lbf = 0;
	tf = 0;
	iunif = -1;
	owf = 0;
	helpflg = 0;
	fcf = 0;		/* flag for Character Code check */
	flf = 0;		/* flag for Line Break check */
	nock = 0;		/* flag for overwrite even if output file exists */

	for (argc--,argv++; (argc > 0) && **argv == '-'; argc--, argv++) {
		op = *argv + 1;
		while (*op) {
			switch (*op++) {
			case 'i' :
				switch (*op++) {
				case 'u' :
					ienc = NSUTF8StringEncoding;
					continue;
				case 'e' :
					ienc = NSJapaneseEUCStringEncoding;
					continue;
				case 's' :
					ienc = NSShiftJISStringEncoding;
					continue;
				case 'j' :
					ienc = NSISO2022JPStringEncoding;
					continue;
				case 'U' :
					ienc = NSUnicodeStringEncoding;
					continue;
				case 'a' :
					autof = 1;
					continue;
				case '\0' :
					break;
				default :
					continue;
				}
				continue;
			case 'o' :
				switch (*op++) {
				case 'u' :
					oenc = NSUTF8StringEncoding;
					continue;
				case 'e' :
					oenc = NSJapaneseEUCStringEncoding;
					continue;
				case 's' :
					oenc = NSShiftJISStringEncoding;
					continue;
				case 'j' :
					oenc = NSISO2022JPStringEncoding;
					continue;
				case 'U' :
					oenc = NSUnicodeStringEncoding;
					continue;
				case 'w' :
					owf = 1;
					continue;
				case '\0' :
					break;
				default :
					continue;
				}
				continue;
			case 'm' :
				switch (*op++) {
				case 'u' :
					lbf = INLBMAC | OTLBUNX;
					continue;
				case 'w' :
					lbf = INLBMAC | OTLBWIN;
					continue;
				case '\0' :
					break;
				default :
					continue;
				}
				continue;
			case 'u' :
				switch (*op++) {
				case 'm' :
					lbf = INLBUNX | OTLBMAC;
					continue;
				case 'w' :
					lbf = INLBUNX | OTLBWIN;
					continue;
				case '\0' :
					break;
				default :
					continue;
				}
				continue;
			case 'w' :
				switch (*op++) {
				case 'm' :
					lbf = INLBWIN | OTLBMAC;
					continue;
				case 'u' :
					lbf = INLBWIN | OTLBUNX;
					continue;
				case '\0' :
					break;
				default :
					continue;
				}
				continue;
			case 'a' :
				switch (*op++) {
				case 'm' :
					lbf = AUTOLB | OTLBMAC;
					continue;
				case 'u' :
					lbf = AUTOLB | OTLBUNX;
					continue;
				case 'w' :
					lbf = AUTOLB | OTLBWIN;
					continue;
				case '\0' :
					break;
				default :
					continue;
				}
				continue;
			case 'l' :
				switch (*op++) {
				case 'm' :
					lbf = ALLLB | AUTOLB | OTLBMAC;
					continue;
				case 'u' :
					lbf = ALLLB | AUTOLB | OTLBUNX;
					continue;
				case 'w' :
					lbf = ALLLB | AUTOLB | OTLBWIN;
					continue;
				case '\0' :
					break;
				default :
					continue;
				}
				continue;
			case 't' :
				tf = 1;
				continue;
			case 'f' :
				switch (*op++) {
				case 'a' :
					flf = 1;
					fcf = 1;
					continue;
				case 'c' :
					fcf = 1;
					continue;
				case 'l' :
					flf = 1;
					continue;
				case '\0' :
					break;
				default :
					continue;
				}
				continue;
			case 'n' :
				switch (*op++) {
				case 'c' :
					nock = 1;
					continue;
				case '\0' :
					break;
				default :
					continue;
				}
				continue;
			case 'v' :
				printf("mccc %s by Yan (yan@yansite.jp)\n", VERSION);
				return 0;
			case 'h' :
				helpflg = 1;
				continue;
			default :
				continue;
			}
		}
	}

	if (helpflg) {
		ienc = NSJapaneseEUCStringEncoding;
		autof = 0;
		if (lbf) lbf = INLBUNX | (lbf & 0x0f);
		owf = 0;
		iunif = 0;
	}
	else {
		if (flf || fcf) {
			autof = 1;
			tf = 0;
			lbf = AUTOLB;
			ilb = lbf;
			owf = 0;
			if (fcf == 0) {
				autof = 0;
				tf = 1;
			}
			else if (flf == 0) {
				lbf = 0;
				ilb = 0;
			}
		}
		if (argc > 0) {
			if (strcmp(*argv, "stdin")) {
				if (stat(*argv, &statbuf)) {
					fprintf(stderr, "%s does not exist.\n", *argv);
					return 1;
				}
				if ((statbuf.st_mode & S_IFMT) != S_IFREG) {
					fprintf(stderr, "%s is not a file.\n", *argv);
					return 1;
				}
				if (freopen(*argv, "r", stdin) == NULL) {
					fprintf(stderr, "%s can not be opened.\n", *argv);
					return 1;
				}
			}
			else owf = 0;
			argc--;
			argv++;

			if (argc > 0 && fcf == 0 && flf == 0) {
				if (strcmp(*argv, "stdout")) {
					if (strcmp(*(argv-1), *argv) == 0) {
						owf = 1;
						ofname = *argv;
					}
					else {
						if (stat(*argv, &statbuf)) {
							if (errno == ENOENT) nock = 1;
							else {
								fprintf(stderr, "Output file (%s) error. (Code = %d)\n", *argv, errno);
								return 1;
							}
						}
						else {
							if ((statbuf.st_mode & S_IFMT) != S_IFREG) {
								fprintf(stderr, "%s is not a file.\n", *argv);
								return 1;
							}
						}

						if (nock == 0) {
							fprintf(stderr, "Output file (%s) already exists.\n", *argv);
							return 1;
						}
						if (freopen(*argv, "w", stdout) == NULL) {
							fprintf(stderr, "%s can not be opened.\n", *argv);
							return 1;
						}
						owf = 0;
					}
				}
				else owf = 0;
			}
			else if (owf) {
				ofname = *(argv-1);
			}
		}
		else owf = 0;
	}

	inbuf = NULL;
	itsize = 0;
	tscore = 0;
	owbsize = 0;
	owbuf = NULL;
	for (i = 0; i < 5; i++) score[i] = 0;
	lbp = -1;
	if (helpflg) {
		i = 0;
		do {
			icsize = strlen(helpmsg[i++]);
			itsize += icsize;
		} while (icsize);
		inbuf = (char *)malloc(itsize+2);
		itsize = 0;
		j = 0;
		for (; i > 0; i--) {
			strcpy(inbuf+itsize, helpmsg[j]);
			itsize += strlen(helpmsg[j]);
			j++;
		}
	}
	else {
		do {
			inbuftmp = (char *)realloc(inbuf, BUFUNIT+itsize);
			if (inbuftmp == NULL) break;
			inbuf = inbuftmp;

			icsize = read(fileno(stdin), inbuf+itsize, BUFUNIT);
			if (icsize == -1) {
				fprintf(stderr, "Data can not be read.(errno = %d)\n", errno);
				return 1;
			}
			itsize += icsize;
			if (inbuf != NULL) {
				if (iunif < 0) {
					if (lbf) {
						if (itsize > 1) {
							if (((unsigned char)inbuf[0] == 0xfe && (unsigned char)inbuf[1] == 0xff) ||
								((unsigned char)inbuf[0] == 0xff && (unsigned char)inbuf[1] == 0xfe)) {
								iunif = 1;
							}
							else {
								iunif = 0;
							}
						}
					}
					else iunif = 0;
				}
				olbp = lbp;
				lbp = lbsearch(&inbuf[olbp+1], itsize - (olbp + 1)) + olbp + 1;
				if ((tf == 0) && autof && (lbp != olbp)) {
					ienc = autodetect(&inbuf[olbp+1], lbp - olbp, score, &tscore);
					if (tscore > HANTEI) {
						if (flf && (ilb == AUTOLB)) {
							tf = 1;
							if (lbp != olbp) {
								if (iunif == 0)
									ilb = lbdetect(lbf, inbuf, itsize);
								else if (iunif > 0)
									ilb = lbdetect2(lbf, inbuf, itsize);
								else continue;
								if (ilb != AUTOLB) break;
							}
						}
						else break;
					}
				}
				else if (lbp != olbp) {
					if (flf && (ilb == AUTOLB)) {
						if (iunif == 0)
							ilb = lbdetect(lbf, inbuf, itsize);
						else if (iunif > 0)
							ilb = lbdetect2(lbf, inbuf, itsize);
						else continue;
						if (ilb != AUTOLB) break;
					}
					else break;
				}
			}
		} while(icsize);
	}

	if (fcf) {
		printf("Character Code : ");
		if (ienc == NSISO2022JPStringEncoding)
			printf("%s\n", "JIS(ISO2022-JP)");
		else if (ienc == NSJapaneseEUCStringEncoding)
			printf("%s\n", "EUC-JP");
		else if (ienc ==  NSShiftJISStringEncoding)
			printf("%s\n", "Shift-JIS");
		else if (ienc == NSUTF8StringEncoding)
			printf("%s\n", "UTF-8");
		else if (ienc == NSUnicodeStringEncoding)
			printf("%s\n", "UTF-16");
		else
			printf("%s\n", "Unknown");
		if (flf == 0) {
			if (inbuf != NULL) free(inbuf);
			return 0;
		}
	}
	if (flf) {
		if (ilb == AUTOLB && icsize == 0) {
			if (inbuf != NULL && itsize) {
				if (iunif <= 0)
					ilb = lbdetect(lbf, inbuf, itsize);
				else
					ilb = lbdetect2(lbf, inbuf, itsize);
			}
		}
		printf("Line Break Code : ");
		if (ilb == INLBMAC)
			printf("%s\n", "CR (Mac)");
		else if (ilb == INLBUNX)
			printf("%s\n", "LF (UNIX)");
		else if (ilb == INLBWIN)
			printf("%s\n", "CR+LF (Windows)");
		else 
			printf("%s\n", "Unknown");
		if (inbuf != NULL) free(inbuf);
		return 0;
	}

	if (inbuf != NULL && itsize) {
		if (iunif < 0) iunif = 0;
		if (icsize == 0) {
			if ((tf == 0) && autof && (itsize > lbp+1))
				ienc = autodetect(&inbuf[lbp+1], itsize - (lbp + 1), score, &tscore);
			if (lbf) {
				inbuf2 = (char *)malloc(itsize*2);
				if (iunif == 0) {
					itsize2 = lbconv(lbf, inbuf, itsize, inbuf2, &cf);
				}
				else {
					inbuf2[0] = inbuf[0];
					inbuf2[1] = inbuf[1];
					itsize2 = lbconv2(lbf, &inbuf[2], itsize-2, &inbuf2[2], &cf) + 2;
				}
				ionsdata = [NSData dataWithBytes:inbuf2 length:itsize2];
				free(inbuf2);
			}
			else
				ionsdata = [NSData dataWithBytes:inbuf length:itsize];
		}
		else {
			if (lbf) {
				inbuf2 = (char *)malloc((lbp+1)*2);
				if (iunif == 0) {
					itsize2 = lbconv(lbf, inbuf, (lbp+1), inbuf2, &cf);
					lbp -= cf;
				}
				else {
					inbuf2[0] = inbuf[0];
					inbuf2[1] = inbuf[1];
					itsize2 = lbconv2(lbf, &inbuf[2], (lbp+1)-2, &inbuf2[2], &cf) + 2;
					lbp -= cf;
				}
				ionsdata = [NSData dataWithBytes:inbuf2 length:itsize2];
				free(inbuf2);
			}
			else
				ionsdata = [NSData dataWithBytes:inbuf length:(lbp+1)];
		}

		if (tf == 0) {
			iestring = [[NSString alloc] initWithData:ionsdata encoding:ienc];
			ionsdata = [iestring dataUsingEncoding:oenc allowLossyConversion:YES];
			[iestring release];
		}
		if (owf) {
			owbuftmp = (char *)realloc(owbuf, owbsize+[ionsdata length]);
			if (owbuftmp == NULL) {
				if (owbsize) {
					close(fileno(stdin));
					ofd = fopen(ofname, "w");
					if (ofd == NULL){
						fprintf(stderr, "%s can not be opened.\n", ofname);
						return 1;
					}
					fwrite(owbuf, 1, owbsize, ofd);
					fclose(ofd);
					free(owbuf);
				}
				free(inbuf);
				[pool release];
				return 0;
			}
			owbuf = owbuftmp;
			outbuf = owbuf + owbsize;
			[ionsdata getBytes:outbuf];
			owbsize += [ionsdata length];
		}
		else {
			outbuf = (char *)malloc([ionsdata length]);
			if (outbuf == NULL) {
				free(inbuf);
				[pool release];
				return 0;
			}
			[ionsdata getBytes:outbuf];
			fwrite(outbuf, 1, [ionsdata length], stdout);
			free(outbuf);
		}
		
		if (icsize == 0) {
			if (owf) {
				close(fileno(stdin));
				ofd = fopen(ofname, "w");
				if (ofd == NULL){
					fprintf(stderr, "%s can not be opened.\n", ofname);
					return 1;
				}
				fwrite(owbuf, 1, owbsize, ofd);
				fclose(ofd);
				free(owbuf);
			}
			free(inbuf);
			[pool release];
			return 0;
		}
		
		if (itsize > lbp + 1) {
			itsize = itsize - (lbp + 1);
			inbuftmp = (char *)malloc(itsize);
			if (inbuftmp == NULL) {
				if (owbsize) {
					close(fileno(stdin));
					ofd = fopen(ofname, "w");
					if (ofd == NULL){
						fprintf(stderr, "%s can not be opened.\n", ofname);
						return 1;
					}
					fwrite(owbuf, 1, owbsize, ofd);
					fclose(ofd);
					free(owbuf);
				}
				free(inbuf);
				[pool release];
				return 0;
			}
			memcpy(inbuftmp, &inbuf[lbp+1], itsize);
		}
		else {
			itsize = 0;
			inbuftmp = NULL;
		}
		
		free(inbuf);
		while (icsize) {
			lbp = -1;
			do {
				inbuf = (char *)realloc(inbuftmp, BUFUNIT+itsize);
				if (inbuf == NULL) break;
				inbuftmp = inbuf;
				icsize = read(fileno(stdin), inbuf+itsize, BUFUNIT);
				itsize += icsize;
				if (inbuf != NULL) {
					olbp = lbp;
					lbp = lbsearch(&inbuf[olbp+1], itsize) + olbp + 1;
					if (lbp != olbp) break;
				}
			} while(icsize);

			if (inbuf != NULL && itsize) {
				if (icsize == 0) {
					if (lbf) {
						inbuf2 = (char *)malloc(itsize*2);
						if (iunif == 0)
							itsize2 = lbconv(lbf, inbuf, itsize, inbuf2, &cf);
						else
							itsize2 = lbconv2(lbf, inbuf, itsize, inbuf2, &cf);
						ionsdata = [NSData dataWithBytes:inbuf2 length:itsize2];
						free(inbuf2);
					}
					else
						ionsdata = [NSData dataWithBytes:inbuf length:itsize];
				}
				else {
					if (lbf) {
						inbuf2 = (char *)malloc((lbp+1)*2);
						if (iunif == 0) {
							itsize2 = lbconv(lbf, inbuf, (lbp+1), inbuf2, &cf);
							lbp -= cf;
						}
						else {
							itsize2 = lbconv2(lbf, inbuf, (lbp+1), inbuf2, &cf);
							lbp -= cf;
						}
						ionsdata = [NSData dataWithBytes:inbuf2 length:itsize2];
						free(inbuf2);
					}
					else
						ionsdata = [NSData dataWithBytes:inbuf length:(lbp+1)];
				}

				if (tf == 0) {
					iestring = [[NSString alloc] initWithData:ionsdata encoding:ienc];
					ionsdata = [iestring dataUsingEncoding:oenc allowLossyConversion:YES];
					[iestring release];
				}
				if (owf) {
					owbuftmp = (char *)realloc(owbuf, owbsize+[ionsdata length]);
					if (owbuftmp == NULL) {
						if (owbsize) {
							close(fileno(stdin));
							ofd = fopen(ofname, "w");
							if (ofd == NULL){
								fprintf(stderr, "%s can not be opened.\n", ofname);
								return 1;
							}
							fwrite(owbuf, 1, owbsize, ofd);
							fclose(ofd);
							free(owbuf);
						}
						free(inbuf);
						[pool release];
						return 0;
					}
					owbuf = owbuftmp;
					outbuf = owbuf + owbsize;
					[ionsdata getBytes:outbuf];
					if (oenc != NSUnicodeStringEncoding)
						owbsize += [ionsdata length];
					else {
						for (i = 0; i < [ionsdata length]-2; i++)
							*(outbuf+i) = *(outbuf+i+2);
						owbsize += [ionsdata length] - 2;
					}
				}
				else {
					outbuf = (char *)malloc([ionsdata length]);
					if (outbuf == NULL) {
						free(inbuf);
						[pool release];
						return 0;
					}
					[ionsdata getBytes:outbuf];
					if (oenc != NSUnicodeStringEncoding)
						fwrite(outbuf, 1, [ionsdata length], stdout);
					else
						fwrite(outbuf+2, 1, [ionsdata length]-2, stdout);
					free(outbuf);
				}
		
				if (icsize == 0) {
					if (owf) {
						close(fileno(stdin));
						ofd = fopen(ofname, "w");
						if (ofd == NULL){
							fprintf(stderr, "%s can not be opened.\n", ofname);
							return 1;
						}
						fwrite(owbuf, 1, owbsize, ofd);
						fclose(ofd);
						free(owbuf);
					}
					free(inbuf);
					[pool release];
					return 0;
				}
		
				if (itsize > lbp + 1) {
					itsize = itsize - (lbp + 1);
					inbuftmp = (char *)malloc(itsize);
					if (inbuftmp == NULL) {
						if (owbsize) {
							close(fileno(stdin));
							ofd = fopen(ofname, "w");
							if (ofd == NULL){
								fprintf(stderr, "%s can not be opened.\n", ofname);
								return 1;
							}
							fwrite(owbuf, 1, owbsize, ofd);
							fclose(ofd);
							free(owbuf);
						}
						free(inbuf);
						[pool release];
						return 0;
					}
					memcpy(inbuftmp, &inbuf[lbp+1], itsize);
				}
				else {
					itsize = 0;
					inbuftmp = NULL;
				}
				
				free(inbuf);
			}
		}
	}
	if (owf) {
		close(fileno(stdin));
		ofd = fopen(ofname, "w");
		if (ofd == NULL){
			fprintf(stderr, "%s can not be opened.\n", ofname);
			return 1;
		}
		fwrite(owbuf, 1, owbsize, ofd);
		fclose(ofd);
		free(owbuf);
	}
	[pool release];
	return 0;
}
