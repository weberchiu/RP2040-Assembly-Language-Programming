@ U13157116 邱偉柏
@ RP2040 乘法、硬體除法器 (Hardware Divider) 
@ 以及內插器 (Interpolator) 硬體加速運算範例
@

#include "hardware/regs/addressmap.h"
#include "hardware/regs/sio.h"

.thumb_func		@ 必要設定：因為 SDK 使用 BLX 呼叫此程式
.global main	@ 將進入點（main）匯出給連結器（Linker）

@ 定義巨集：等待硬體除法器計算完成（RP2040 硬體除法需 8 個 Clock Cycles）
.macro	divider_delay
	// 延遲 8 個時脈週期 (Cycles)
	b	1f
1:	b	1f
1:	b	1f
1:	b	1f
1:
.endm

main:	BL	stdio_init_all	@ 初始化 Pico SDK 的標準 I/O（UART 或 USB）

multi:  @ --- 乘法運算範例 ---
	MOV	R2, #25
	MOV	R3, #5
	MUL	R2, R3		@ R2 = 25 * 5 = 125
	NEG	R3, R3		@ R3 = -5 (取補數/變更正負號)
	MUL	R2, R3		@ R2 = 125 * (-5) = -625

divis:  @ --- 有符號硬體除法 (Signed Division) 範例 ---
	MOV	R0, #11     @ 被除數 = 11
	MOV	R1, #3      @ 除數 = 3
	LDR	R3, =SIO_BASE @ 載入 SIO 基底位址
	STR	R0, [R3, #SIO_DIV_SDIVIDEND_OFFSET] @ 寫入有符號被除數 (SDIVIDEND)
	STR	R1, [R3, #SIO_DIV_SDIVISOR_OFFSET]  @ 寫入有符號除數 (SDIVISOR)，觸發硬體計算
	divider_delay   @ 延遲 8 個週期等待硬體除法器計算完畢
	LDR	R1, [R3, #SIO_DIV_REMAINDER_OFFSET] @ 讀取餘數 (Remainder = 2) 至 R1
	LDR	R0, [R3, #SIO_DIV_QUOTIENT_OFFSET]  @ 讀取商數 (Quotient = 3) 至 R0

divis2: @ --- 無符號硬體除法 (Unsigned Division) 範例 ---
	MOV	R0, #100    @ 被除數 = 100
	MOV	R1, #3      @ 除數 = 3
	LDR	R3, =SIO_BASE
	STR	R0, [R3, #SIO_DIV_UDIVIDEND_OFFSET] @ 寫入無符號被除數 (UDIVIDEND)
	STR	R1, [R3, #SIO_DIV_UDIVISOR_OFFSET]  @ 寫入無符號除數 (UDIVISOR)，觸發計算
	divider_delay   @ 延遲 8 個週期
	LDR	R1, [R3, #SIO_DIV_REMAINDER_OFFSET] @ 讀取餘數 (Remainder = 1) 至 R1
	LDR	R0, [R3, #SIO_DIV_QUOTIENT_OFFSET]  @ 讀取商數 (Quotient = 33) 至 R0

@ 簡化內插器暫存器偏移量常數定義
.EQU INTERP0_CTRL_LANE0_OFF, (SIO_INTERP0_CTRL_LANE0_OFFSET-SIO_INTERP0_ACCUM0_OFFSET)
.EQU INTERP0_ACCUM0_OFF, (SIO_INTERP0_ACCUM0_OFFSET-SIO_INTERP0_ACCUM0_OFFSET)
.EQU INTERP0_ACCUM0_ADD_OFF, (SIO_INTERP0_ACCUM0_ADD_OFFSET-SIO_INTERP0_ACCUM0_OFFSET)

@ --- 範例 1：使用內插器進行陣列數值累加 (Accumulation) ---
interp: MOV	R0, #0  @ 累加器 0 (ACCUM0) 初始值 = 0
	MOV	R1, #4	    @ 陣列指標遞增步長 (每筆 word 佔 4 bytes)
	MOV	R2, #1	    @ 迴圈計數器遞減值
	LDR	R3, INTERP_BASE	 @ 載入 Interpolator 0 基底位址
	MOV	R4, #1
	LSL	R4, #SIO_INTERP0_CTRL_LANE0_ADD_RAW_LSB @ 設定 Control 暫存器：開啟 ADD_RAW 模式
	STR	R4, [R3, #INTERP0_CTRL_LANE0_OFF]
	STR	R0, [R3, #INTERP0_ACCUM0_OFF]     @ 清零 ACCUM0
	LDR	R7, numsumdata @ 載入要加總的資料筆數
	LDR	R6, =sumdata	 @ 載入陣列起始位址
nextnum:LDR	R4, [R6]     @ 從陣列讀取數字
	STR	R4, [R3,#INTERP0_ACCUM0_ADD_OFF] @ 寫入 ACCUM0_ADD，硬體自動將 R4 累加至 ACCUM0
	ADD	R6, R1      @ 指標移至下一個數字
	SUB	R7, R2      @ 計數器減 1
	BNE	nextnum     @ 迴圈尚未結束則繼續
	LDR	R0, [R3, #INTERP0_ACCUM0_OFF] @ 讀取最終加總結果至 R0
done:	NOP

@ 定義內插器混合 (Blend) 模式所需暫存器偏移量
.EQU INTERP0_BASE0_OFF, (SIO_INTERP0_BASE0_OFFSET-SIO_INTERP0_ACCUM0_OFFSET)
.EQU INTERP0_BASE1_OFF, (SIO_INTERP0_BASE1_OFFSET-SIO_INTERP0_ACCUM0_OFFSET)
.EQU INTERP0_ACCUM1_OFF, (SIO_INTERP0_ACCUM1_OFFSET-SIO_INTERP0_ACCUM0_OFFSET)
.EQU INTERP0_PEEK1_OFF, (SIO_INTERP0_PEEK_LANE1_OFFSET-SIO_INTERP0_ACCUM0_OFFSET)
.EQU INTERP0_POP1_OFF, (SIO_INTERP0_POP_LANE1_OFFSET-SIO_INTERP0_ACCUM0_OFFSET)
.EQU INTERP0_CTRL_LANE1_OFF, (SIO_INTERP0_CTRL_LANE1_OFFSET-SIO_INTERP0_ACCUM0_OFFSET)

@ --- 範例 2：使用內插器進行線性內插 (Linear Interpolation/Blending) ---
interp2:MOV	R0, #0  @ 累加器 1 (ACCUM1) 初始值 = 0
	MOV	R1, #4	    @ 陣列指標遞增步長
	MOV	R2, #1	    @ 計數器遞減值
	MOV	R3, #63     @ Alpha/內插權重步長
	MOV	R8, R3
	LDR	R3, INTERP_BASE	
	MOV	R4, #1
	LSL	R4, #SIO_INTERP0_CTRL_LANE0_BLEND_LSB @ 開啟 BLEND 混合功能
	MOV	R5, #1
	LSL	R5, #SIO_INTERP0_CTRL_LANE0_ADD_RAW_LSB
	ORR	R4, R5
	STR	R4, [R3, #INTERP0_CTRL_LANE0_OFF]
	MOV	r4, #248	@ 0xf8
	LSL	r4, r4, #7	@ 變更為 0x7c00 (設定內部 Shift/Mask 區間)
	STR	R4, [R3, #INTERP0_CTRL_LANE1_OFF]
	STR	R0, [R3, #INTERP0_ACCUM0_OFF]
	LDR	R7, numsumdata
	LDR	R6, =sumdata	
nextnum2:LDR	R4, [R6]
	STR	R4, [R3,#INTERP0_BASE0_OFF] @ 設定內插起始點 Base 0
	ADD	R6, R1
	LDR	R4, [R6]
	STR	R4, [R3,#INTERP0_BASE1_OFF] @ 設定內插終點 Base 1
	STR	R0, [R3,#INTERP0_ACCUM1_OFF] @ 寫入 Alpha 權重至 ACCUM1
	ADD	R0, R8      @ 遞增權重值
	LDR	R4, [R3,#INTERP0_PEEK1_OFF]  @ Peek 讀取 Lane 1 運算後的內插結果
	STR	R4, [R3,#INTERP0_ACCUM0_ADD_OFF] @ 將內插結果累加至 ACCUM0
	ADD	R6, R1
	SUB	R7, R2
	BNE	nextnum2
	@ 讀取儲存在累加器 0 的最終加總結果
	LDR	R0, [R3, #INTERP0_ACCUM0_OFF]
done2:	NOP

@ 印出結果與無窮迴圈
loop:	MOV	R1, R6		@ 參數 2：R6
	MOV	R2, R7		@ 參數 3：R7
	LDR	R0, =sumstr	@ 載入格式化字串 "The sum is %x %x\n" 位址
	BL	printf		@ 呼叫 printf 印出數值
	B	loop		@ 無窮迴圈（防止 UART 監視器未即時啟動）

.align 4

INTERP_BASE:	.word	SIO_BASE + SIO_INTERP0_ACCUM0_OFFSET @ 內插器 0 基底位址
numsumdata:	.word	4   @ 迴圈次數
sumdata:	.word	1, 100, 56, 66, 1000, 2000, 43, 97 @ 測試數據陣列

.data
	.align  4       @ 記憶體對齊
sumstr: .asciz   "The sum is %x %x\n"