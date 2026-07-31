@ U13157116 邱偉柏
@ 透過呼叫巨集（Macro）將字串轉換為全大寫的彙編語言程式
@
@ R0 - 傳遞給 printf 的第一個參數（字串位址）
@ R1 - 輸出字串的記憶體位址
@ R0 - 輸入字串的記憶體位址
@ R5 - 目前正在處理的字元
@

.include "uppermacro.S"      @ 引用包含巨集定義的外部檔案 uppermacro.S

.global mainmacro            @ 將進入點（mainmacro）匯出給連結器（Linker）

mainmacro: PUSH	{LR}          @ 將返回位址（LR）推入堆疊保存

	toupper tststr, buffer    @ 第一次展開巨集：將 tststr 轉為大寫並存入 buffer

	LDR	R0, =buffer       @ 載入 buffer 位址至 R0，作為 printf 的第一個參數
	BL	printf            @ 呼叫 printf 印出第一個轉換後的字串

	toupper tststr2, buffer   @ 第二次展開巨集：將 tststr2 轉為大寫並寫入 buffer

	LDR	R0, =buffer       @ 載入 buffer 位址至 R0，作為 printf 的第一個參數
	BL	printf            @ 呼叫 printf 印出第二個轉換後的字串

	POP	{PC}              @ 從堆疊還原返回位址至 PC，結束 mainmacro 並返回

.data
tststr:  .asciz  "This is our Test String that we will convert.\n"
                          @ 宣告第一個測試用輸入字串（以 Null 結尾）
tststr2: .asciz	 "A second string to upper case!!\n"
                          @ 宣告第二個測試用輸入字串（以 Null 結尾）
buffer:	.fill	255, 1, 0       @ 預留 255 個 bytes 的輸出緩衝區，初始值填 0