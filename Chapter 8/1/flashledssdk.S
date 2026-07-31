@ U13157116 邱偉柏
@ 使用 Pico SDK 控制連接到 Raspberry Pi Pico GPIO 腳位的三個 LED 閃爍的彙編程式
@

	.EQU	LED_PIN1, 18    @ 定義 LED1 連接的 GPIO 腳位為 GP18
	.EQU	LED_PIN2, 19    @ 定義 LED2 連接的 GPIO 腳位為 GP19
	.EQU	LED_PIN3, 20    @ 定義 LED3 連接的 GPIO 腳位為 GP20
	.EQU	GPIO_OUT, 1     @ 定義 GPIO 方向常數：1 代表輸出 (Output)
	.EQU	sleep_time, 200 @ 定義延遲時間為 200 毫秒 (ms)

.thumb_func	@ 必要設定：因為 SDK 使用 BLX 指令，需指定為 Thumb 模式
.global main    @ 將程式進入點（main）匯出給連結器（Linker）

main:
	MOV	R0, #LED_PIN1       @ 將第一個腳位編號 (18) 載入 R0 作為參數
	BL	gpio_init           @ 初始化 GPIO18
	MOV	R0, #LED_PIN1       @ 參數 1：GPIO18
	MOV	R1, #GPIO_OUT       @ 參數 2：方向設為輸出 (1)
	BL	link_gpio_set_dir   @ 設定 GPIO18 的傳輸方向為輸出

	MOV	R0, #LED_PIN2       @ 將第二個腳位編號 (19) 載入 R0 作為參數
	BL	gpio_init           @ 初始化 GPIO19
	MOV	R0, #LED_PIN2       @ 參數 1：GPIO19
	MOV	R1, #GPIO_OUT       @ 參數 2：方向設為輸出 (1)
	BL	link_gpio_set_dir   @ 設定 GPIO19 的傳輸方向為輸出

	MOV	R0, #LED_PIN3       @ 將第三個腳位編號 (20) 載入 R0 作為參數
	BL	gpio_init           @ 初始化 GPIO20
	MOV	R0, #LED_PIN3       @ 參數 1：GPIO20
	MOV	R1, #GPIO_OUT       @ 參數 2：方向設為輸出 (1)
	BL	link_gpio_set_dir   @ 設定 GPIO20 的傳輸方向為輸出

loop:   
	@ --- 點亮並熄滅 LED 1 ---
	MOV	R0, #LED_PIN1       @ 參數 1：GPIO18
	MOV	R1, #1              @ 參數 2：1 (輸出高電位/點亮)
	BL	link_gpio_put       @ 將 GPIO18 拉高電位
	LDR	R0, =sleep_time     @ 載入延遲時間 200ms 至 R0
	BL	sleep_ms            @ 呼叫 SDK 延遲函式 (維持亮燈 200ms)
	MOV	R0, #LED_PIN1       @ 參數 1：GPIO18
	MOV	R1, #0              @ 參數 2：0 (輸出低電位/熄滅)
	BL	link_gpio_put       @ 將 GPIO18 拉低電位

	@ --- 點亮並熄滅 LED 2 ---
	MOV	R0, #LED_PIN2       @ 參數 1：GPIO19
	MOV	R1, #1              @ 參數 2：1 (輸出高電位/點亮)
	BL	link_gpio_put       @ 將 GPIO19 拉高電位
	LDR	R0, =sleep_time     @ 載入延遲時間 200ms 至 R0
	BL	sleep_ms            @ 呼叫 SDK 延遲函式 (維持亮燈 200ms)
	MOV	R0, #LED_PIN2       @ 參數 1：GPIO19
	MOV	R1, #0              @ 參數 2：0 (輸出低電位/熄滅)
	BL	link_gpio_put       @ 將 GPIO19 拉低電位

	@ --- 點亮並熄滅 LED 3 ---
	MOV	R0, #LED_PIN3       @ 參數 1：GPIO20
	MOV	R1, #1              @ 參數 2：1 (輸出高電位/點亮)
	BL	link_gpio_put       @ 將 GPIO20 拉高電位
	LDR	R0, =sleep_time     @ 載入延遲時間 200ms 至 R0
	BL	sleep_ms            @ 呼叫 SDK 延遲函式 (維持亮燈 200ms)
	MOV	R0, #LED_PIN3       @ 參數 1：GPIO20
	MOV	R1, #0              @ 參數 2：0 (輸出低電位/熄滅)
	BL	link_gpio_put       @ 將 GPIO20 拉低電位

	B   loop                @ 無窮迴圈，重複執行 LED 順序閃爍效果