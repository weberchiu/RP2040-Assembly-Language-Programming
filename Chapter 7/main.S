@ U13157116 邱偉柏
@
@ 透過呼叫函式將字串轉換為全大寫的彙編語言程式
@
@ R0 - 傳遞給 printf 的第一個參數（格式化字串或欲印出字串的位址）
@ R1 - 輸出字串（outstr）的記憶體位址
@ R0 - 輸入字串（instr）的記憶體位址（呼叫 toupper 前作為參數傳入）
@ R5 - 目前正在處理的字元
@

.thumb_func	@ 必要設定：因為 SDK 使用 BLX 指令，需指定為 Thumb 模式
.global main	@ 將程式進入點（main）匯出給連結器（Linker）

main: 	BL	stdio_init_all	@ 初始化 UART 或 USB 標準輸入輸出

repeat:
	LDR	R0, =instr    @ 載入輸入字串（instr）的起始位址至 R0
	LDR	R1, =outstr   @ 載入輸出字串（outstr）的記憶體位址至 R1
	MOV	R4, #12       @ 設定測試用的暫存器 R4
	MOV	R5, #13       @ 設定測試用的暫存器 R5

	BL	toupper       @ 呼叫 toupper 函式進行轉大寫處理

	LDR	R0, =outstr   @ 載入轉換後的輸出字串位址至 R0，作為 printf 的參數
	BL	printf        @ 呼叫 printf 印出結果字串

@ 呼叫巨集（Macro）版本的範例區塊
	BL	mainmacro

@ 呼叫第 6 章的程式碼片段範例
	BL	codesnippets

	B	repeat        @ 無窮迴圈（重複執行，避免程式終止）
	
.data
instr:  .asciz  "This is our Test String that we will convert.\n"
                      @ 宣告以 Null 結尾的輸入測試字串
outstr:	.fill	255, 1, 0   @ 預留 255 個 bytes 的輸出緩衝區，初始值填 0