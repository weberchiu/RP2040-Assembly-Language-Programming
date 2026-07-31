@ U13157116 邱偉柏
@ RP2040 Bootrom 浮點數常式（Floating-point Routines）呼叫與運算範例
@

#include "pico/bootrom/sf_table.h"

.thumb_func		@ 必要設定：因為 SDK 使用 BLX 呼叫此程式
.global main	@ 將進入點（main）匯出給連結器（Linker）

	.EQU	datatable, 0x16  @ ROM 查詢表的 Entry Table 位址偏移量
	.EQU	helperfn, 0x18   @ ROM Helper 函式 (`rom_func_lookup`) 的指標偏移量

main:	
	BL	stdio_init_all   @ 初始化 Pico SDK 的標準 I/O（UART 或 USB）

next:	
	MOV	R3, #datatable   @ 載入 ROM 資料表的索引代碼位址
	LDRH	R0, [R3]     @ 讀取單精度浮點數常式表 (SF Table) 在 ROM 中的標記/位址
	LDRH	R1, code     @ 載入 "SF" 字串標籤（代表 Software Float 函式庫）
	MOV	R5, #helperfn    @ 載入 ROM Helper 尋找函式的指標位址
	LDR	R5, [R5]     @ 取得 ROM 函式尋找服務（`rom_func_lookup`）的真實起始位址
	BLX	R5           @ 呼叫 Helper 函式，傳入 R0="SF Table" 與 R1="SF"，尋找浮點數函式表
	MOV	R5, R0       @ 尋找完成，R0 回傳 SF 函式表的基底位址，保存至 R5 供後續使用

	@ --- 進行浮點數加法 (fadd) ---
	LDR	R4, [R5, #SF_TABLE_FADD] @ 從 SF 列表中載入加法常式 `_fadd` 的進入點位址
	LDR	R0, number1  @ 載入第一個浮點數 (12.345) 至 R0 作為第一參數
	LDR	R1, number2  @ 載入第二個浮點數 (23.232) 至 R1 作為第二參數
	BLX	R4           @ 呼叫 Bootrom 的 `_fadd` 函式，計算 R0 = R0 + R1
	MOV	R7, R0       @ 將加法結果（單精度 32-bit 浮點數）備份至 R7 以備後用

	@ --- 將單精度浮點數轉為雙精度 (ftod)，以利傳給 printf("%f") 印出 ---
	LDR	R4, [R5, #SF_TABLE_FLOAT2DOUBLE] @ 載入 `_ftod` (Float-to-Double) 轉譯常式位址
	BLX	R4           @ 呼叫 `_ftod` 將 R0 內的單精度轉換為 64-bit 雙精度浮點數
	MOV	R3, R1       @ 依據 AAPCS 呼叫約定，64-bit 雙精度數值會存放在 R0:R1 (Low:High)
	MOV	R2, R0       @ 將轉換後的雙精度浮點數傳入 R2 與 R3，作為 printf 的第二與第三參數

done:	
	LDR	R0, =sumstr  @ 載入格式化字串 "The sum is %f\n" 記憶體位址至 R0
	BL	printf       @ 呼叫 printf 印出加法運算結果

	@ --- 進行浮點數開平方根 (fsqrt) ---
	MOV	R0, R7       @ 還原之前備份的加法結果（32-bit 單精度浮點數）至 R0
	LDR	R4, [R5, #SF_TABLE_FSQRT] @ 載入平方根常式 `_fsqrt` 位址
	BLX	R4           @ 呼叫 `_fsqrt` 計算 R0 = sqrt(R0)

	@ --- 將平方根結果轉換為雙精度 (ftod) 並印出 ---
	LDR	R4, [R5, #SF_TABLE_FLOAT2DOUBLE] @ 載入 `_ftod` 常式位址
	BLX	R4           @ 轉譯單精度至雙精度 (R0:R1)
	MOV	R3, R1       @ 調整 64-bit 暫存器位置給 printf
	MOV	R2, R0       @ ...
	LDR	R0, =sqrootstr @ 載入格式化字串 "Square root = %f\n" 位址
	BL	printf       @ 呼叫 printf 印出平方根計算結果

loop:	
	B	loop         @ 無窮迴圈，保持程式暫停

.align 4             @ 4-byte 記憶體對齊

number1:	.float	12.345   @ 宣告 32-bit IEEE-754 單精度浮點數
number2:	.float	23.232   @ 宣告 32-bit IEEE-754 單精度浮點數
result:		.float	35.577   @ 預設對照結果
double:		.double 35.577   @ 宣告 64-bit IEEE-754 雙精度浮點數
code:		.ascii	"SF"     @ Bootrom 尋找單精度浮點數函式庫所使用的 2-byte 識別碼

.data
	.align  4        @ 文字池記憶體對齊
sumstr:    .asciz   "The sum is %f\n"
sqrootstr: .asciz   "Square root = %f\n"