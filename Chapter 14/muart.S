@ U13157116 邱偉柏
@ RP2040 UART 週邊硬體控制與 GPIO 設定模組
@

#include "hardware/regs/addressmap.h"
#include "hardware/regs/uart.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/pads_bank0.h"

.thumb_func
.global initUART, readUART, sendUART

@ =========================================================================
@ 函式：initUART
@ 功能：初始化 UART0，設定傳輸速率為 115200 baud, 8 bits, 無奇偶校驗 (8N1)
@       並配置 GPIO0 (TX) 與 GPIO1 (RX) 為 UART 多工功能。
@
@ 輸入/輸出：無
@ 使用暫存器：R0, R1 (呼叫 gpioInit 時使用 R0~R4)
@ =========================================================================
initUART:
	PUSH	{LR}
	LDR	R1, uart0base          @ 載入 UART0 的基底位址 (0x40034000)

	@ --- 設定波特率 (Baud Rate) 為 115200 ---
	@ 根據 RP2040 Datasheet 公式，當系統時脈為 125MHz 時：
	@ Baud Rate Divisor = 125,000,000 / (16 * 115200) = 67.8168
	@整數部分 (IBRD) = 67，小數部分 (FBRD) = integer(0.8168 * 64 + 0.5) = 52
	MOV	R0, #67
	STR	R0, [R1, #UART_UARTIBRD_OFFSET] @ 設定整數波特率暫存器 (IBRD)
	MOV	R0, #52
	STR	R0, [R1, #UART_UARTFBRD_OFFSET] @ 設定小數波特率暫存器 (FBRD)

	@ --- 設定資料格式 (Line Control Register) ---
	@ 設定資料長度為 8 bits (WLEN = 3)，致能硬體 FIFO (FEN = 1)，無奇偶校驗
	MOV	R0, #(UART_UARTLCR_H_WLEN_BITS+UART_UARTLCR_H_FEN_BITS)
	STR	R0, [R1, #UART_UARTLCR_H_OFFSET]

	@ --- 致能 UART 收發器 ---
	@ 同時啟動傳輸 (TXE) 與接收 (RXE)，並啟動 UART 模組 (UARTEN)
	MOV	R0, #3		                    @ 設 3 (進位 0b11) 再左移 TXE 欄位位址
	LSL	R0, #UART_UARTCR_TXE_LSB
	ADD	R0, #UART_UARTCR_UARTEN_BITS     @ 結合 UART Enable 位元
	STR	R0, [R1, #UART_UARTCR_OFFSET]    @ 寫入控制暫存器 (UARTCR)

	@ --- 初始化 GPIO 腳位 ---
	MOV	R0, #0                          @ 配置 GPIO0 為 UART0_TX
	BL	gpioInit
	MOV	R0, #1                          @ 配置 GPIO1 為 UART0_RX
	BL	gpioInit
	
	POP	{PC}

@ =========================================================================
@ 函式：readUART
@ 功能：從 UART0 阻塞式讀取一個字元 (Polling 輪詢)
@ 輸入：無
@ 輸出：R0 = 讀取到的 ASCII 字元
@ 使用暫存器：R0, R1, R2
@ =========================================================================
readUART:
	LDR	R1, uart0base	@ UART0 基底位址
@ 輪詢等待：檢查接收 FIFO 是否為空
waitr:	
	LDR	R0, [R1, #UART_UARTFR_OFFSET] @ 讀取 Flag Register (UARTFR)
	MOV	R2, #UART_UARTFR_RXFE_BITS    @ 取得 RXFE (RX FIFO Empty) 位元遮罩
	AND	R0, R2
	BNE	waitr			              @ 若 RXFE == 1 (FIFO 為空)，繼續自旋等待
	
	@ 讀取接收到的資料位元組
	LDR	R0, [R1, #UART_UARTDR_OFFSET] @ 從 Data Register (UARTDR) 讀取字元
	BX	LR

@ =========================================================================
@ 函式：sendUART
@ 功能：透過 UART0 發送一個字元 (Polling 輪詢)
@ 輸入：R0 = 待發送的 ASCII 字元
@ 輸出：無
@ 使用暫存器：R0, R1, R2, R3
@ =========================================================================
sendUART:
	LDR	R1, uart0base
@ 輪詢等待：檢查傳送 FIFO 是否已滿
waitt:	
	LDR	R3, [R1, #UART_UARTFR_OFFSET] @ 讀取 Flag Register
	MOV	R2, #UART_UARTFR_TXFF_BITS    @ 取得 TXFF (TX FIFO Full) 位元遮罩
	AND	R3, R2
	BNE	waitt			              @ 若 TXFF == 1 (FIFO 已滿)，繼續自旋等待
	
	@ 將字元寫入發送 FIFO
	STR	R0, [R1, #UART_UARTDR_OFFSET] @ 寫入 Data Register 進行傳送
	BX	LR

@ =========================================================================
@ 函式：gpioInit
@ 功能：將指定的 GPIO 引腳設定為 UART0 功能並開啟 Pads 輸入致能
@ 輸入：R0 = GPIO 引腳編號 (0 代表 GPIO0, 1 代表 GPIO1)
@ =========================================================================
gpioInit:
@ 致能腳位墊片 (Pads Bank 0) 的輸入緩衝區 (Input Enable, IE)
	LDR	R2, padsbank0
	LSL	R3, R0, #2	        @ 計算 Pad 控制暫存器偏移量 (pin * 4 Bytes)
	ADD	R2, R3		        @ 取得該 GPIO 腳位對應的 Pads 暫存器位址
	MOV	R1, #PADS_BANK0_GPIO0_IE_BITS
	LDR	R4, setoffset       @ 使用 RP2040 的 Atomic Register Alias (SET 位址)
	ORR	R2, R4              @ 將位址轉為原子設定 (Atomic Bit Set) 模式
	STR	R1, [R2, #PADS_BANK0_GPIO0_OFFSET]

@ 設定 IO Bank 0 控制暫存器，將腳位功能切換為 UART (FUNCSEL)
	LSL	R0, #3		        @ 計算 IO 控制暫存器偏移量 (每個 GPIO 佔用 8 Bytes)
	LDR	R2, iobank0	        @ IO Bank 0 基底位址 (0x40014000)
	ADD	R2, R0		        @ 加上特定 GPIO 的暫存器偏移量
	MOV	R1, #IO_BANK0_GPIO0_CTRL_FUNCSEL_VALUE_UART0_TX @ 設定多工選擇值為 UART0 功能 (值為 2)
	STR	R1, [R2, #IO_BANK0_GPIO0_CTRL_OFFSET]
	BX	LR

		.align	4
uart0base:	.word	UART0_BASE            @ UART0 暫存器基底位址 (0x40034000)
gpiobase:	.word	SIO_BASE              @ SIO 基底位址
iobank0:	.word	IO_BANK0_BASE         @ IO Bank 0 控制暫存器基底 (0x40014000)
padsbank0:	.word	PADS_BANK0_BASE       @ Pads Bank 0 控制暫存器基底 (0x4001c000)
setoffset:	.word	REG_ALIAS_SET_BITS    @ 原子暫存器別名 (Atomic Bit Set Alias 0x2000)