@ U13157116 邱偉柏
@ 使用第二個核心進行處理的範例程式。
@ 利用硬體自旋鎖 (Spinlock) 保護共用記憶體表格 (Memory Table)。
@

#include "hardware/regs/addressmap.h"
#include "hardware/regs/m0plus.h"
#include "hardware/regs/sio.h"

.thumb_func		@ 必要設定：因為 SDK 使用 BLX 呼叫此程式
.global main	@ 將進入點（main）匯出給連結器（Linker）

	@ 常數定義 (表格結構與邏輯設定)
	.EQU	numEntries, 100       @ 表格總項目數 (100 筆)
	.EQU	coreOffset, 0         @ 結構偏移量：核心編號 (Offset = 0)
	.EQU	numOffset, 4          @ 結構偏移量：數字 n (Offset = 4)
	.EQU	numSquaredOffset, 8   @ 結構偏移量：平方值 n*n (Offset = 8)
	.EQU	sizeTabRow, 12        @ 每筆表格大小：12 Bytes (3 個 32-bit word)
	.EQU	emptyRow, 255         @ 未使用的表格列預設初始標記 (255 / 0xFF)

main:	BL	stdio_init_all	@ 初始化 UART 或 USB 標準輸出入介面

	BL	launch_core1    @ 啟動 Core 1，執行相同的進入點

	BL	coremain        @ Core 0 進入主運算邏輯，開始搶佔表格空間

@ 確保所有運算完成 (給予 Core 1 充份時間處理)
	MOV	R0, #255
	BL	sleep_ms

@ 將兩個核心競爭填入的表格內容透過串口印出
	MOV	R4, #0		    @ 迴圈計數器 i = 0
	LDR	R5, =numEntries
	LDR	R6, =table      @ 載入表格起始位址
printtab:
	LDR	R0, =printstr
	LDR	R1, [R6, #coreOffset]        @ 取得搶到此列的核心編號 (Core 0 或 Core 1)
	LDR	R2, [R6, #numOffset]         @ 取得數字 n
	LDR	R3, [R6, #numSquaredOffset]  @ 取得平方值 n*n
	BL	printf
	ADD	R4, #1		    @ i = i + 1
	ADD	R6, #sizeTabRow @ 移至表格下一列 ( +12 Bytes )
	CMP	R4, R5		    @ 是否印完 100 筆資料？
	BLT	printtab

mainloop:
	WFE	                @ 印出完成後進入低功耗休眠狀態
	B	mainloop

.align 4
printstr:	.ASCIZ	"Core %d n = %d n * n = %d\n"
.align 4

@ =========================================================================
@ 核心主要運算邏輯 (Core 0 與 Core 1 皆會執行此段程式碼)
@ =========================================================================
.thumb_func
coremain:
	PUSH	{R4, R5, R6, R7, LR}
	MOV	R4, #0		    @ i = 0
	LDR	R5, =numEntries
	LDR	R6, =table      @ 載入共用表格位址
	MOV	R7, #emptyRow   @ 預設空白標記 (255)
forloop:
	@ --- 進入臨界面積 (Critical Section) ---
	BL	lockSpinLock    @ 獲取硬體自旋鎖，防止另一個核心同時檢查/修改此列
	
	@ 檢查目前表格列是否為空白 (未被任何核心搶佔)
	LDRB	R0, [R6]
	CMP	R0, R7
	BNE 	next        @ 若非空白 (被對方搶先了)，跳轉至 next 解鎖並放棄此列

	@ 當前列為空白：記錄當前核心編號 (0 或 1)
	LDR	R2, =SIO_BASE
	LDR	R2, [R2, #SIO_CPUID_OFFSET]  @ 讀取當前核心 ID (CPUID)
	
	@ 標記當前列已佔用後，即可釋放自旋鎖 (減少鎖定時間)
	BL	unlockSpinLock
	
	@ 填入資料的主體
	STR	R2, [R6, #coreOffset]        @ 寫入 Core ID
	STR	R4, [R6, #numOffset]         @ 寫入數值 i
	MOV	R0, R4
	MUL	R0, R0
	STR	R0, [R6, #numSquaredOffset]  @ 寫入平方值 i * i

@ 執行額外延遲 (NOP)，否則 Core 1 速度過快會搶走所有表格欄位
	.REPT	10
	NOP
	.ENDR

	B	cont            @ 跳轉至下一次迴圈步進

next:	
	@ 若該列已被搶佔，解鎖後直接進入下一列
	BL	unlockSpinLock
cont:	
	ADD	R4, #1		    @ i = i + 1
	ADD	R6, #sizeTabRow @ 移至下一列 ( +12 Bytes )
	CMP	R4, R5
	BLT	forloop
	
	@ 運算結束：檢查是否為 Core 0，若非 Core 0 則進入無限休眠
	LDR	R2, =SIO_BASE
	LDR	R2, [R2, #SIO_CPUID_OFFSET]
	CMP	R2, #0
	BEQ	ret             @ Core 0 返回 main 繼續執行列印操作
sleep:	
	WFE                 @ Core 1 完成後在此休眠
	B	sleep

ret:	POP	{R4, R5, R6, R7, PC}

@ =========================================================================
@ 硬體自旋鎖 (Hardware Spinlock) 控制函式
@ =========================================================================

lockSpinLock:
	LDR	R1, spinbase
repeat:	
	LDR	R0, [R1]        @ 讀取 SIO Spinlock 暫存器 (此動作具備原子性：讀取同時進行扣鎖)
@ 若讀取結果非 0，代表成功取得 Spinlock；若為 0，代表此鎖正被對方核心持有
	CMP	R0, #0
	BEQ	repeat          @ 若未取得鎖，則持續自旋等待 (Busy-Wait)
	BX	LR

unlockSpinLock:
	LDR	R1, spinbase
	@ 釋放 Spinlock：向 Spinlock 暫存器寫入任意數值即可解鎖
	STR	R0, [R1]	
	BX	LR

@ =========================================================================
@ SIO FIFO 通訊與啟動 Core 1 邏輯
@ =========================================================================

fifo_push:
	LDR	R1, siobase
	STR	R0, [R1, #SIO_FIFO_WR_OFFSET]
	SEV		            @ 喚醒處於 WFE 的核心
	BX	LR

fifo_pop:
	LDR	R1, siobase
	LDR	R0, [R1, #SIO_FIFO_ST_OFFSET]
	MOV	R2, #SIO_FIFO_ST_VLD_BITS
	AND	R0, R2
	BNE	gotone
	WFE		            @ 無數據時進入休眠
	B	fifo_pop
gotone:	
	LDR	R0, [R1, #SIO_FIFO_RD_OFFSET]
	BX	LR

fifo_drain:
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

launch_core1:
@ 遵循 RP2040 Bootrom 啟動序列：0, 0, 1, VTOR, Stack, Entry
	PUSH	{LR}
	BL	fifo_drain
	MOV	R0, #0
	BL	fifo_push
	BL	fifo_pop
	MOV	R0, #0
	BL	fifo_push
	BL	fifo_pop
	MOV	R0, #1
	BL	fifo_push
	BL	fifo_pop
	LDR	R2, ppbbase
	LDR	R1, vtoroffset
	ADD	R2, R1
	LDR	R0, [R2]
	BL	fifo_push
	BL	fifo_pop
	LDR	R0, =stack1_end
	BL	fifo_push
	BL	fifo_pop
	LDR	R0, =coremain   @ 傳送進入點位址 coremain
	BL	fifo_push
	BL	fifo_pop
	POP	{PC}

.align 4
siobase:	.WORD	SIO_BASE
ppbbase:	.WORD	PPB_BASE
vtoroffset:	.WORD	M0PLUS_VTOR_OFFSET
@ RP2040 提供 32 個硬體 Spinlock (0~31)
@ 官方推薦 Spinlock 0~23 給 SDK 內部或軟體庫使用，自訂程式建議使用 24~31
spinbase:	.WORD	SIO_BASE + SIO_SPINLOCK24_OFFSET

.align 4
.data
stack1:		.FILL	0x800, 1, 0  @ 為 Core 1 準備 2KB 的獨立 Stack 空間
stack1_end:	.WORD	0
table:		.FILL	numEntries * sizeTabRow, 1, emptyRow @ 預留表格記憶體空間，填滿 255