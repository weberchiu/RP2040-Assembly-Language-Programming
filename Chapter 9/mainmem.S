@ U13157116 邱偉柏
@ 透過直接寫入暫存器（Registers）控制 Raspberry Pi Pico GPIO 腳位
@ 實現三個 LED 燈依序閃爍的彙編程式
@

#include "hardware/regs/addressmap.h"
#include "hardware/regs/sio.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/pads_bank0.h"

	.EQU LED_PIN1, 18     @ 定義 LED1 連接的 GPIO 腳位為 GP18
	.EQU LED_PIN2, 19     @ 定義 LED2 連接的 GPIO 腳位為 GP19
	.EQU LED_PIN3, 20     @ 定義 LED3 連接的 GPIO 腳位為 GP20

	.EQU sleep_time, 200  @ 定義延遲時間為 200 毫秒 (ms)

.thumb_func
.global main            @ 將程式進入點（main）匯出給連結器（Linker）

	.align  4           @ 進行 4-byte 記憶體對齊（極為重要）
main:
@ 初始化三個 GPIO 腳位並將傳輸方向設為輸出 (Output)
	MOV	R0, #LED_PIN1		
	BL	gpioinit        @ 初始化 GPIO18
	MOV	R0, #LED_PIN2
	BL	gpioinit        @ 初始化 GPIO19
	MOV	R0, #LED_PIN3
	BL	gpioinit        @ 初始化 GPIO20

loop:
@ 依序點亮各腳位、延遲後再熄滅，實現走馬燈效果
	MOV	R0, #LED_PIN1	
	BL	gpio_on         @ 點亮 GPIO18
	LDR	R0, =sleep_time
	BL	sleep_ms        @ 延遲 200ms
	MOV	R0, #LED_PIN1	
	BL	gpio_off        @ 熄滅 GPIO18

	MOV	R0, #LED_PIN2
	BL	gpio_on         @ 點亮 GPIO19
	LDR	R0, =sleep_time
	BL	sleep_ms        @ 延遲 200ms
	MOV	R0, #LED_PIN2
	BL	gpio_off        @ 熄滅 GPIO19

	MOV	R0, #LED_PIN3
	BL	gpio_on         @ 點亮 GPIO20
	LDR	R0, =sleep_time
	BL	sleep_ms        @ 延遲 200ms
	MOV	R0, #LED_PIN3
	BL	gpio_off        @ 熄滅 GPIO20
	
	B   loop            @ 無窮迴圈，持續重複閃爍效果

@ =========================================================================
@ 子程式：gpioinit
@ 功能：將指定的 GPIO 腳位初始化為 SIO (Single-cycle I/O) 模式
@ 參數：R0 = 要初始化的 GPIO 腳位編號 (0-29)
@ =========================================================================
gpioinit:
@ 1. 設定 SIO 輸出控制與初始狀態
	MOV	R3, #1
	LSL	R3, R0          @ 將 1 左移 R0 位元，建立該 Pin 專用的 Bitmask (1 << Pin)
	LDR	R2, gpiobase    @ 載入 SIO 基底位址 (SIO_BASE)
	STR	R3, [R2, #SIO_GPIO_OE_SET_OFFSET]  @ 設定此 Pin 的 Output Enable (致能輸出)
	STR	R3, [R2, #SIO_GPIO_OUT_CLR_OFFSET] @ 將此 Pin 的預設輸出清零 (關閉 LED)

@ 2. 設定 Pad 控制暫存器（致能 Input Buffer，避免讀取混亂）
	LDR	R2, padsbank0   @ 載入 PADS_BANK0 基底位址
	LSL	R3, R0, #2      @ 偏移量算式：Pin * 4（每個 Pin 佔用 4 位元組）
	ADD	R2, R3          @ 計算出該 Pin 專屬的 Pad 暫存器位址
	MOV	R1, #PADS_BANK0_GPIO0_IE_BITS      @ 載入致能輸入 (Input Enable) 的 Bit 遮罩
	LDR	R4, setoffset   @ 載入 Atomic Register Set 位址偏移 (REG_ALIAS_SET_BITS)
	ORR	R2, R4          @ 將位址切換至 Atomic SET 區塊（對此位址寫入可直接置 1）
	STR	R1, [R2, #PADS_BANK0_GPIO0_OFFSET] @ 寫入並開啟 IE (Input Enable)

@ 3. 設定 Pin Function Multiplexer (IO_BANK0，指定為 SIO 功能)
	LSL	R0, #3          @ 偏移量算式：Pin * 8（每個 GPIO 控制區塊佔用 8 位元組）
	LDR	R2, iobank0     @ 載入 IO_BANK0 基底位址
	ADD	R2, R0          @ 計算出該 Pin 的控制暫存器目標位址
	MOV	R1, #IO_BANK0_GPIO3_CTRL_FUNCSEL_VALUE_SIO_3 @ 設定功能選擇為 SIO (Function 5/SIO)
	STR	R1, [R2, #IO_BANK0_GPIO0_CTRL_OFFSET]        @ 寫入 CTRL 暫存器完成功能切換
	BX	LR              @ 返回呼叫者

@ =========================================================================
@ 子程式：gpio_on
@ 功能：將指定的 GPIO 腳位拉高電位 (High / 點亮)
@ 參數：R0 = GPIO 腳位編號
@ =========================================================================
gpio_on:
	MOV	R3, #1
	LSL	R3, R0          @ 產生專屬 Bitmask (1 << Pin)
	LDR	R2, gpiobase    @ 載入 SIO 基底位址
	STR	R3, [R2, #SIO_GPIO_OUT_SET_OFFSET] @ 寫入 OUT_SET 暫存器（將該 Pin 置高電位）
	BX	LR              @ 返回呼叫者

@ =========================================================================
@ 子程式：gpio_off
@ 功能：將指定的 GPIO 腳位拉低電位 (Low / 熄滅)
@ 參數：R0 = GPIO 腳位編號
@ =========================================================================
gpio_off:
	MOV	R3, #1
	LSL	R3, R0          @ 產生專屬 Bitmask (1 << Pin)
	LDR	R2, gpiobase    @ 載入 SIO 基底位址
	STR	R3, [R2, #SIO_GPIO_OUT_CLR_OFFSET] @ 寫入 OUT_CLR 暫存器（將該 Pin 清為低電位）
	BX	LR              @ 返回呼叫者

	.align  4           @ 進行 4-byte 文字池 (Literal Pool) 記憶體對齊
gpiobase:	.word	SIO_BASE        @ 儲存 SIO 暫存器基底位址
iobank0:	.word	IO_BANK0_BASE   @ 儲存 IO_BANK0 暫存器基底位址
padsbank0:	.word	PADS_BANK0_BASE @ 儲存 PADS_BANK0 暫存器基底位址
setoffset:	.word	REG_ALIAS_SET_BITS @ 儲存 RP2040 特有的 Atomic SET 別名偏移量