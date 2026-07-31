@ U13157116 邱偉柏
@ RP2040 數值運算輔助常式模組：
@   1. 利用 SIO 硬體協同處理器 (Coprocessor) 進行兩整數相除
@   2. 將 32 位元整數轉換為十進位 ASCII 字串 (itoa)
@

#include "hardware/regs/addressmap.h"
#include "hardware/regs/sio.h"

.thumb_func
.global intDivide, itoa

@ 巨集：延遲 8 個時脈週期 (Clock Cycles)
@ RP2040 硬體除法器從寫入除數到產出結果剛好需要 8 個 Cycles
.macro	divider_delay
	// 延遲 8 個週期
	b	1f
1:	b	1f
1:	b	1f
1:	b	1f
1:
.endm

@ =========================================================================
@ 函式：intDivide
@ 功能：進行 32 位元有符號整數除法 (Signed 32-bit Integer Division)
@
@ 暫存器說明：
@ 輸入：R0 = 被除數 (Dividend)
@       R1 = 除數 (Divisor)
@ 輸出：R0 = 商數 (Quotient)
@       R1 = 餘數 (Remainder)
@ =========================================================================
intDivide:
	LDR	R3, =SIO_BASE
	STR	R0, [R3, #SIO_DIV_SDIVIDEND_OFFSET]	@ 寫入有符號被除數
	STR	R1, [R3, #SIO_DIV_SDIVISOR_OFFSET]	@ 寫入有符號除數，硬體開始計算
	divider_delay                           @ 等待 8 個週期
	LDR	R1, [R3, #SIO_DIV_REMAINDER_OFFSET] @ 讀取計算完畢的餘數
	LDR	R0, [R3, #SIO_DIV_QUOTIENT_OFFSET]  @ 讀取計算完畢的商數
	BX	LR

@ =========================================================================
@ 函式：itoa
@ 功能：將 32 位元有符號整數轉換為十進位 ASCII 字串 (Null-terminated)
@
@ 暫存器說明：
@ 輸入：R0 = 待轉換的整數值
@       R1 = 存放輸出字串的記憶體緩衝區指標 (Buffer Pointer)
@ 輸出：R1 = 轉換後的字串位址 (R6/R1)
@
@ 區域暫存器分工：
@ R7 - 正負號標記 (0 = 正數, 1 = 負數)
@ R6 - 保存原始緩衝區起始位址 (原始指標)
@ R4 - 呼叫 intDivide 前後用於暫存與保護 R1 緩衝區指標
@ R2, R3 - 字串反轉 (Reverse) 時使用的臨時暫存器
@
@ 演算法說明：
@ 1. 先處理正負號，若為負數則取絕對值（NEG），並標記 R7=1。
@ 2. 反向建構字串：不斷除以 10（呼叫 intDivide），取得個位數餘數並轉為 ASCII 存入 Buffer。
@ 3. 處理負號 '-' 與補上字串結束符號 '\0'。
@ 4. 雙指標法原地反轉 (In-place Reverse) 字串，以獲得正確的十進位順序。
@ =========================================================================
itoa:
	PUSH	{R4, R6, R7, LR}
	MOV	R6, R1	    @ 備份原始緩衝區起始位址至 R6
	MOV	R7, #0	    @ 預設假設數值為正數 (R7 = 0)
	CMP	R0, #0	    @ 檢查 R0 是否為正數
	BPL	convertdigits @ 若 R0 >= 0，跳轉至數字轉換段落
	MOV	R7, #1	    @ 若為負數，設定負號標記 (R7 = 1)
	NEG	R0, R0	    @ R0 = -R0，將負數轉為正數處理

convertdigits:
	MOV	R4, R1	    @ 保護 R1 (緩衝區指標)，因為 BL intDivide 會覆寫 R1
	MOV	R1, #10     @ 除數設定為 10，準備提取最低有效位數 (Least Significant Digit)
	BL	intDivide   @ 計算：R0 = R0 / 10 (商數), R1 = R0 % 10 (餘數)
	ADD	R1, #'0'    @ 將餘數 (0~9) 加上 ASCII '0' (0x30) 轉換為數字字元
	STRB	R1, [R4]    @ 將 ASCII 字元寫入當前緩衝區記憶體位址 [R4]
	MOV	R1, R4	    @ 還原 R1 緩衝區指標
	ADD	R1, #1	    @ 指標前移 +1 Byte，準備寫入下一個字元
	CMP	R0, #0	    @ 檢查商數是否已被除盡 (R0 == 0)？
	BEQ	finish	    @ 若已無剩餘位數，跳轉至 finish 處理結尾
	B	convertdigits @ 若還有剩餘位數，繼續迴圈拆解下一個位數
	
finish:
	CMP	R7, #0		@ 檢查原始數值是否為負數
	BEQ	plus
	MOV	R0, #'-'	@ 若為負數，補上負號 ASCII '-'
	STRB	R0, [R1]	@ 寫入負號
	ADD	R1, #1		@ 指標前移 +1
plus:	
	MOV	R0, #0		@ ASCII '\0' (Null-terminator)
	STRB	R0, [R1]	@ 寫入字串結束符號
	SUB	R1, #1		@ 將末端指標往回移一格，使其指向最後一個有效字元 (用於反轉)

	@ --- 雙指標字串反轉 (Reverse Buffer) ---
	@ 目前緩衝區內容為顛倒順序 (例如 123 會存成 "321")
	SUB	R2, R1, R6	@ 計算字串長度 - 1 (字串尾 R1 - 字串頭 R6)
revloop:	
	LDRB	R0, [R1]    @ 從尾端讀取字元
	LDRB	R3, [R6]	@ 從頭端讀取字元
	STRB	R0, [R6]	@ 將尾端字元寫入頭端
	STRB	R3, [R1]    @ 將頭端字元寫入尾端
	SUB	R1, #1		@ 尾端指標左移 (-1)
	ADD	R6, #1		@ 頭端指標右移 (+1)
	SUB	R2, #2		@ 未交換的字元距離減少 2
	BPL	revloop		@ 若長度差 >= 0，繼續反轉迴圈
	
	POP	{R4, R6, R7, PC} @ 恢復暫存器並返回