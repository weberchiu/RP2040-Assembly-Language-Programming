@ U13157116 邱偉柏
@ 使用 Pico SDK 印出 "Hello World" 的彙編程式
@
@ R0 - 傳遞給 printf 的第一個參數（字串位址）
@ R1 - 傳遞給 printf 的第二個參數（計數器數值）
@ R7 - 迴圈計數器
@

.thumb_func        @ 必要設定：因為 SDK 使用 BLX 指令，需指定為 Thumb 模式
.global main       @ 將程式進入點（main）匯出給連結器（Linker）

main:
	MOV	R7, #0          @ 將計數器初始化為 0
	BL	stdio_init_all  @ 初始化 UART 或 USB 標準輸入輸出
loop:
	LDR	R0, =helloworld @ 載入 helloworld 字串的記憶體位址
	ADD	R7, #1          @ 計數器加 1
	MOV	R1, R7          @ 將計數器數值放入 R1，作為第二個參數
	BL	printf          @ 呼叫 printf 印出字串
	B	loop            @ 無窮迴圈，重複執行
		
.data
	.align 4            @ 記憶體對齊 4 位元組（必要設定）
helloworld: .asciz   "Hello World %d\n"