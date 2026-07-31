@ U13157116 邱偉柏
@ 使用 Raspberry Pi Pico 第二個核心 (Core 1) 進行平行運算的範例程式
@

#include "hardware/regs/addressmap.h"
#include "hardware/regs/m0plus.h"
#include "hardware/regs/sio.h"

.thumb_func		@ 必要設定：因為 SDK 使用 BLX 呼叫此程式
.global main	@ 將進入點（main）匯出給連結器（Linker）

main:	
	BL	stdio_init_all   @ 初始化 Pico SDK 的標準 I/O（UART 或 USB）

	BL	launch_core1     @ 透過 SIO FIFO 啟動第二個核心 (Core 1)

	MOV	R4, #0           @ 迴圈變數 i = 0
	LDR	R5, numNumbers   @ 載入測試資料數量 (5)
	LDR	R6, =numbers     @ 載入數字陣列起始位址
forloop: 
	CMP	R4, R5          @ 檢查是否已處理完所有數字
	BGE	mainloop         @ 若 i >= numNumbers，進入主防禦性迴圈

	LDR	R0, [R6]         @ 讀取陣列中的下一個數字
	BL	fifo_push        @ 將數字推入 SIO FIFO，傳送給 Core 1 計算階乘

	LDR	R0, [R6]         @ 重新載入相同的數字
	BL	fibonacci        @ 由 Core 0 自己計算該數字的費氏數列 (Fibonacci)
	MOV	R2, R0           @ 參數 3：費氏數列計算結果
	LDR	R1, [R6]         @ 參數 2：原始數字 n
	LDR	R0, =fibprintstr @ 參數 1：格式化字串
	BL	printf           @ Core 0 印出費氏數列結果

	ADD	R4, #1           @ i = i + 1
	ADD	R6, #4           @ 指標移動至陣列下一個 32-bit word
	
	B	forloop          @ 繼續處理下一個數字

mainloop:
	B	mainloop         @ Core 0 完成工作後在此無窮迴圈等待

.align 4
numNumbers:	.WORD	5
numbers:	.WORD	3, 5, 7, 10, 12
fibprintstr:	.ASCIZ	"Core 0 n = %d fibonacci = %d\n"
factprintstr: 	.ASCIZ	"Core 1 n = %d factorial = %d\n"

@ =========================================================================
@ Core 1 的程式進入點 (Core 1 Entry Point)
@ =========================================================================
.thumb_func
core1entry:
	PUSH	{LR}
infinite:	
	BL	fifo_pop         @ 阻塞式等待並從 FIFO 讀取 Core 0 傳來的數字
	MOV	R4, R0           @ 將數字 n 備份至 R4 (供後續 printf 使用)
	BL	factorial        @ 計算階乘 (Factorial)
	MOV	R2, R0           @ 參數 3：階乘計算結果
	MOV	R1, R4           @ 參數 2：原始數字 n
	LDR	R0, =factprintstr @ 參數 1：格式化字串
	BL	printf           @ Core 1 印出階乘結果
	B	infinite         @ 無窮迴圈，等待 Core 0 傳來下一個數字
	POP	{PC}             @ 實際上不會執行到此處

@ =========================================================================
@ SIO FIFO 通訊函式庫
@ =========================================================================

fifo_push:
@ 將資料推入 SIO FIFO（不等待迴圈，寫入後發送 SEV 喚醒另一個核心）
	LDR	R1, siobase
	STR	R0, [R1, #SIO_FIFO_WR_OFFSET] @ 將 R0 寫入 FIFO 寫入暫存器
	SEV                          @ 發送 SEV (Send Event) 訊號喚醒處於 WFE 休眠的 Core 1
	BX	LR

fifo_pop:
@ 從 SIO FIFO 讀取資料；若 FIFO 為空則進入 WFE 省電休眠
	LDR	R1, siobase
	LDR	R0, [R1, #SIO_FIFO_ST_OFFSET] @ 讀取 FIFO 狀態暫存器
	MOV	R2, #SIO_FIFO_ST_VLD_BITS     @ 載入 Valid (有效數據) 的 Bitmask
	AND	R0, R2
	BNE	gotone                       @ 若 VLD bit 不為 0，代表 FIFO 有資料，跳轉至 gotone
	WFE                              @ 若 FIFO 無資料，使當前核心進入休眠狀態 (Wait For Event)
	B	fifo_pop                     @ 被喚醒後再次檢查 FIFO 狀態
gotone:	
	LDR	R0, [R1, #SIO_FIFO_RD_OFFSET] @ 從 FIFO 讀取資料至 R0
	BX	LR

fifo_drain:
@ 連續讀取 8 次 FIFO 以確保清空舊殘留數據，並發送 SEV 訊號
	LDR	R1, siobase	
	LDR	R0, [R1, #SIO_FIFO_RD_OFFSET]
	LDR	R0, [R1, #SIO_FIFO_RD_OFFSET]
	LDR	R0, [R1, #SIO_FIFO_RD_OFFSET]
	LDR	R0, [R1, #SIO_FIFO_RD_OFFSET]
	LDR	R0, [R1, #SIO_FIFO_RD_OFFSET]
	LDR	R0, [R1, #SIO_FIFO_RD_OFFSET]
	LDR	R0, [R1, #SIO_FIFO_RD_OFFSET]
	LDR	R0, [R1, #SIO_FIFO_RD_OFFSET]
	SEV
	BX	LR

@ =========================================================================
@ 啟動 Core 1 的關鍵子程式 (Launch Core 1)
@ 遵循 RP2040 Bootrom 規範，依序發送 6 個數值的 Magic Sequence：
@ [0, 0, 1, 向量表位址 (VTOR), 堆疊頂端位址 (Stack), 進入點位址 (Routine)]
@ =========================================================================
launch_core1:
	PUSH	{LR}
	BL	fifo_drain       @ 1. 清空 FIFO 中的殘留資料

	MOV	R0, #0
	BL	fifo_push
	BL	fifo_pop         @ 2. 傳送 Sequence 1: 0 (並等待對向 Core 回應確認)

	MOV	R0, #0
	BL	fifo_push
	BL	fifo_pop         @ 3. 傳送 Sequence 2: 0

	MOV	R0, #1
	BL	fifo_push
	BL	fifo_pop         @ 4. 傳送 Sequence 3: 1

	LDR	R2, ppbbase
	LDR	R1, vtoroffset
	ADD	R2, R1
	LDR	R0, [R2]         @ 取得當前核心的中斷向量表位址 (VTOR)
	BL	fifo_push
	BL	fifo_pop         @ 5. 傳送 Sequence 4: VTOR 位址

	LDR	R0, =stack1_end  @ 取得為 Core 1 獨立分配的堆疊頂端位址
	BL	fifo_push
	BL	fifo_pop         @ 6. 傳送 Sequence 5: Core 1 Stack Pointer

	LDR	R0, =core1entry  @ 取得 Core 1 的進入點函式位址
	BL	fifo_push
	BL	fifo_pop         @ 7. 傳送 Sequence 6: Core 1 Entry Function
	POP	{PC}             @ Core 1 成功啟動並開始執行！

.align 4
siobase:	.WORD	SIO_BASE
ppbbase:	.word	PPB_BASE
vtoroffset:	.word	M0PLUS_VTOR_OFFSET

@ =========================================================================
@ 數學運算子程式
@ =========================================================================

@ 費氏數列計算 (Fibonacci)
@ 輸入：R0 = n
@ 回傳：R0 = fib(n)
fibonacci:
	PUSH	{R4}
	MOV	R4, R0           @ R4 = n
	MOV	R1, #0           @ f0 = 0
	MOV	R2, #1           @ f1 = 1
	MOV	R3, #2           @ i = 2
loop:	
	CMP	R3, R4
	BGT	done
	ADD	R0, R1, R2       @ fib = f0 + f1
	MOV	R1, R2           @ f0 = f1
	MOV	R2, R0           @ f1 = fib
	ADD	R3, #1           @ i++
	B	loop
done:	
	POP	{R4}
	BX	LR               @ 回傳值在 R0

@ 階乘計算 (Factorial)
@ 輸入：R0 = n
@ 回傳：R0 = n!
factorial:
	MOV	R2, R0           @ R2 = n
	MOV	R0, #1           @ factorial = 1
	MOV	R1, #2           @ i = 2
loop2:	
	CMP	R1, R2
	BGT	done2
	MUL	R0, R1           @ factorial *= i
	ADD	R1, #1           @ i++
	B	loop2
done2:	
	BX	LR               @ 回傳值在 R0

.align 4
.data
stack1:		.FILL	0x800, 1, 0 @ 為 Core 1 宣告 2KB (0x800) 的獨立堆疊空間
stack1_end:	.WORD	0          @ 堆疊底端 (由於 ARM 堆疊向下成長，此處即為高位址頂端)