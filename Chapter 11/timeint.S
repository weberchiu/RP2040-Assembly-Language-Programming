@ U13157116 邱偉柏
@ 使用 Raspberry Pi Pico 硬體定時器中斷 (Timer Interrupt)
@ 來觸發並切換三個 LED 閃爍狀態的彙編程式
@

#include "hardware/regs/addressmap.h"
#include "hardware/regs/sio.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/pads_bank0.h"
#include "hardware/regs/m0plus.h"

	.EQU LED_PIN1, 18           @ 定義 LED1 連接的 GPIO 腳位為 GP18
	.EQU LED_PIN2, 19           @ 定義 LED2 連接的 GPIO 腳位為 GP19
	.EQU LED_PIN3, 20           @ 定義 LED3 連接的 GPIO 腳位為 GP20

	.EQU alarm0_isr_offset, 0x40 @ Alarm 0 在中斷向量表 (VTOR) 中的 Offset 位址

.thumb_func		@ 必要設定：因為 SDK 使用 BX 呼叫此程式
.global main	@ 將程式進入點（main）匯出給連結器（Linker）

	.align	4	@ 進行 4-byte 記憶體對齊
main:
	BL	stdio_init_all      @ 初始化 Pico SDK 的標準 I/O（UART 或 USB）

@ 初始化三個 GPIO 腳位並設為輸出
	MOV	R0, #LED_PIN1		
	BL	gpioinit
	MOV	R0, #LED_PIN2
	BL	gpioinit
	MOV	R0, #LED_PIN3
	BL	gpioinit

	BL	set_alarm0_isr      @ 設定 Alarm 0 的中斷服務程式 (ISR) 與 NVIC
	LDR	R0, alarmtime       @ 載入第一個鬧鐘的間隔時間 (微秒, us)
	BL	set_alarm0          @ 設定並啟動第一個 Alarm 0 鬧鐘

	MOV	R7, #0              @ 初始化計數器 R7 = 0
loop:
	LDR	R0, =printstr       @ 載入格式化字串 "Couting %d\n" 記憶體位址
	MOV	R1, R7              @ 參數 2：將 R7 計數器值傳入
	BL	printf              @ 呼叫 printf 印出計數值（主程式持續背景執行）
	MOV	R0, #1              @ R0 = 1
	ADD	R7, R0              @ R7 計數器加 1
       
	B   loop                @ 無窮迴圈，與定時器中斷平行獨立運行

@ =========================================================================
@ 子程式：set_alarm0
@ 功能：設定下一次 Alarm 0 觸發的時間點並致能定時器中斷
@ 參數：R0 = 觸發間隔時間 (以微秒/us 為單位)
@ =========================================================================
set_alarm0:
	@ 致能 Timer 0 的中斷
	LDR	R2, timerbase
	MOV	R1, #1              @ 0b1 對應 Alarm 0 中斷
	STR	R1, [R2, #TIMER_INTE_OFFSET] @ 寫入 Interrupt Enable 暫存器

	@ 設定 Alarm 的目標時間（當前硬體時間 + 指定間隔 R0）
	LDR	R1, [R2, #TIMER_TIMELR_OFFSET] @ 讀取當前 Timer 64-bit 計數器的低 32 位元 (TIMELR)
	ADD	R1, R0              @ 目標時間 = 當前時間 + 延遲微秒數
	STR	R1, [R2, #TIMER_ALARM0_OFFSET] @ 寫入 ALARM0 暫存器，等待計數器到達該值觸發中斷

	BX	LR                  @ 返回呼叫者

@ =========================================================================
@ 中斷服務程式：alarm_isr (Alarm 0 Interrupt Service Routine)
@ 功能：處理定時器中斷、清除旗標、依照狀態機切換 LED，並重新設定下一次鬧鐘
@ =========================================================================
.thumb_func	@ 中斷處理常式必須加上 .thumb_func 標示
alarm_isr:
	PUSH	{LR}            @ 保存 LR（因為內部會呼叫 gpio_on/off 等子程式）

	@ 1. 清除中斷旗標 (Acknowledge Interrupt)
	LDR	R2, timerbase
	MOV	R1, #1              @ 對應 Alarm 0
	STR	R1, [R2, #TIMER_INTR_OFFSET] @ 寫入 INTR (Raw Interrupt) 暫存器以清除中斷

	@ 2. 狀態機控制 (State Machine)
	LDR	R2, =state          @ 載入狀態變數 state 的記憶體位址
	LDR	R3, [R2]            @ 讀取當前狀態值 R3
	MOV	R0, #1
	ADD	R3, R0              @ 狀態值加 1
	STR	R3, [R2]            @ 更新並寫回 state 變數

step1:
	MOV	R1, #1              @ 判斷 state == 1
	CMP	R3, R1
	BNE	step2               @ 若不等於 1，跳轉檢查 step2
	MOV	R0, #LED_PIN1	
	BL	gpio_on             @ 點亮 LED1
	MOV	R0, #LED_PIN2
	BL	gpio_off            @ 熄滅 LED2
	MOV	R0, #LED_PIN3
	BL	gpio_off            @ 熄滅 LED3
	B	finish

step2:
	MOV	R1, #2              @ 判斷 state == 2
	CMP	R3, R1
	BNE	step3               @ 若不等於 2，跳轉至 step3 (case else)
	MOV	R0, #LED_PIN1	
	BL	gpio_off            @ 熄滅 LED1
	MOV	R0, #LED_PIN2
	BL	gpio_on             @ 點亮 LED2
	MOV	R0, #LED_PIN3
	BL	gpio_off            @ 熄滅 LED3
	B	finish

step3:                       @ Case Else (state == 3)
	MOV	R0, #LED_PIN1	
	BL	gpio_off            @ 熄滅 LED1
	MOV	R0, #LED_PIN2
	BL	gpio_off            @ 熄滅 LED2
	MOV	R0, #LED_PIN3
	BL	gpio_on             @ 點亮 LED3
	MOV	R3, #0              @ 將狀態值重置為 0
	LDR	R2, =state          @ 載入 state 位址
	STR	R3, [R2]            @ 將 state 清零重新循環

finish:
	@ 3. 設定下一次中斷並結束 ISR
	LDR	R0, alarmtime       @ 載入鬧鐘間隔時間 (200,000 us = 0.2 秒)
	BL	set_alarm0          @ 重新設定下一次定時觸發
	POP	{PC}                @ 還原 LR 到 PC，恢復被中斷的主程式繼續執行

@ =========================================================================
@ 子程式：set_alarm0_isr
@ 功能：在 ARM Cortex-M0+ 向量表 (VTOR) 中註冊 ISR，並啟用 NVIC 控制器的 IRQ0
@ =========================================================================
set_alarm0_isr:
	@ 1. 取得向量表 (VTOR) 位址並填入 alarm_isr 進入點
	LDR	R2, ppbbase         @ 載入 Cortex-M0+ PPB (Private Peripheral Bus) 基底位址
	LDR	R1, vtoroffset      @ 載入 VTOR (Vector Table Offset Register) 偏移量
	ADD	R2, R1              @ R2 = PPB + VTOR 位址
	LDR	R1, [R2]            @ 讀取當前向量表的記憶體起始位址
	MOV	R2, #alarm0_isr_offset @ Alarm 0 在向量表中的 Slot 偏移量 (0x40)
	ADD	R2, R1              @ 計算出 Alarm 0 ISR 指標在向量表中的精確位址
	LDR	R0, =alarm_isr      @ 取得 alarm_isr 函式的入口位址
	STR	R0, [R2]            @ 將 alarm_isr 位址寫入向量表該 Slot 中

	@ 2. 在 NVIC 中開啓 Alarm 0 中斷 (Alarm 0 在 RP2040 中為 IRQ 0)
	MOV	R0, #1              @ IRQ 0 對應 Bitmask (1 << 0)
	LDR	R2, ppbbase         @ 載入 PPB 基底位址
	LDR	R1, clearint        @ 載入 NVIC ICPR (Interrupt Clear Pending Register) 偏移
	ADD	R1, R2
	STR	R0, [R1]            @ 先清除之前可能殘留的待處理中斷狀態 (Pending status)
	LDR	R1, setint          @ 載入 NVIC ISER (Interrupt Set Enable Register) 偏移
	ADD	R1, R2
	STR	R0, [R1]            @ 致能/開啟 IRQ 0 中斷
	
	BX	LR                  @ 返回呼叫者

@ =========================================================================
@ GPIO 初始化與控制子程式 (直接操作 SIO / IO_BANK0 / PADS 暫存器)
@ =========================================================================
gpioinit:
	MOV	R3, #1
	LSL	R3, R0	
	LDR	R2, gpiobase	
	STR	R3, [R2, #SIO_GPIO_OE_SET_OFFSET]
	STR	R3, [R2, #SIO_GPIO_OUT_CLR_OFFSET]

	LDR	R2, padsbank0
	LSL	R3, R0, #2	
	ADD	R2, R3		
	MOV	R1, #PADS_BANK0_GPIO0_IE_BITS
	LDR	R4, setoffset
	ORR	R2, R4
	STR	R1, [R2, #PADS_BANK0_GPIO0_OFFSET]

	LSL	R0, #3		
	LDR	R2, iobank0	
	ADD	R2, R0		
	MOV	R1, #IO_BANK0_GPIO3_CTRL_FUNCSEL_VALUE_SIO_3
	STR	R1, [R2, #IO_BANK0_GPIO0_CTRL_OFFSET]
	BX	LR

gpio_on:
	MOV	R3, #1
	LSL	R3, R0	
	LDR	R2, gpiobase	
	STR	R3, [R2, #SIO_GPIO_OUT_SET_OFFSET]
	BX	LR

gpio_off:
	MOV	R3, #1
	LSL	R3, R0	
	LDR	R2, gpiobase	
	STR	R3, [R2, #SIO_GPIO_OUT_CLR_OFFSET]
	BX	LR

	.align	4               @ 文字池 (Literal Pool) 記憶體對齊
gpiobase:	.word	SIO_BASE
iobank0:	.word	IO_BANK0_BASE
padsbank0:	.word	PADS_BANK0_BASE
setoffset:	.word	REG_ALIAS_SET_BITS
timerbase:	.word	TIMER_BASE
ppbbase:	.word	PPB_BASE
vtoroffset:	.word	M0PLUS_VTOR_OFFSET
clearint:	.word	M0PLUS_NVIC_ICPR_OFFSET
setint:		.word	M0PLUS_NVIC_ISER_OFFSET
alarmtime:	.word	200000        @ 鬧鐘觸發間隔時間：200,000 微秒 (即 0.2 秒)
printstr:	.asciz	"Couting %d\n" @ 主程式計數用格式化字串

.data
state:		.word	0             @ 全域狀態機變數（0, 1, 2 循環切換）