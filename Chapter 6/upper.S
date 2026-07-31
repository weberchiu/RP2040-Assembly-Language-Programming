@ U13157116 邱偉柏
@ 將字串中的所有小寫字母轉換為大寫字母的彙編程式
@
@ R0-R2 - 傳遞給 Linux 系統呼叫服務的參數（或 printf 參數）
@ R3    - 輸出字串（target string）的記憶體位址
@ R4    - 輸入字串（source string）的記憶體位址
@ R5    - 目前正在處理的字元
@ R7    - Linux 系統呼叫編號
@

.global toupper           @ 將程式進入點（toupper）匯出給連結器（Linker）

toupper: PUSH	{LR}        @ 將返回位址（LR）推入堆疊保存

	LDR	R4, =instr    @ 載入輸入字串（instr）的起始位址
	LDR	R3, =outstr   @ 載入輸出字串（outstr）的記憶體位址
@ 迴圈執行，直到 R4 所指向的字元為 0（Null 結尾符號）為止
loop:	LDRB	R5, [R4]    @ 載入單一位元組字元（Byte）至 R5
	ADD	R4, #1        @ 將輸入字串指標加 1（指向下一個字元）
@ 若 R5 > 'z'，則跳躍至 cont（非小寫字母，不需轉換）
	CMP	R5, #'z'      @ 檢查字元是否大於 'z'？
	BGT	cont
@ 若 R5 < 'a'，則跳躍至 cont（非小寫字母，不需轉換）
	CMP	R5, #'a'      @ 檢查字元是否小於 'a'？
	BLT	cont          @ 跳躍至 end if
@ 若程式執行到此，代表字元為小寫字母 ('a'-'z')，進行大寫轉換
	SUB	R5, #('a'-'A') @ 減去 32 ('a'-'A') 將小寫 ASCII 碼轉為大寫 ASCII 碼
cont:	@ end if
	STRB	R5, [R3]    @ 將處理好的字元存入輸出字串記憶體 [R3]
	ADD	R3, #1        @ 將輸出字串指標加 1
	CMP	R5, #0        @ 檢查是否遇到字串結尾符號 '\0' (Null character)
	BNE	loop          @ 若字元不為 Null，則繼續迴圈處理下一個字元

@ 設定參數並呼叫 printf 來印出轉換後的結果字串
	LDR	R0, =outstr   @ 將轉好的大寫字串位址放入 R0，作為 printf 的第一個參數
	BL	printf        @ 呼叫 printf 印出結果

	POP	{PC}          @ 將保存在堆疊中的返回位址彈出至 PC，結束函式並返回

.data
instr:  .asciz  "This is our Test String that we will convert.\n"
                      @ 宣告以 Null 結尾的測試輸入字串
outstr:	.fill	255, 1, 0   @ 預留 255 個 bytes 的輸出緩衝區，初始值填 0