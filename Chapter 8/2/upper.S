@ U13157116 邱偉柏
@ 將字串轉換為全大寫的彙編語言函式（自定義函式名稱：mytoupper）
@
@ R1 - 輸出字串（outstr）的記憶體位址
@ R0 - 輸入字串（instr）的記憶體位址
@ R4 - 記錄原始輸出字串位址（用於計算長度）
@ R5 - 目前正在處理的字元
@

.global mytoupper   @ 將 mytoupper 函式匯出，允許其他檔案呼叫此常式

mytoupper:	PUSH	{R4-R5} @ 保護/保存我們將會使用的 Callee-saved 暫存器
	MOV	R4, R1      @ 將原始輸出字串指標 (R1) 複製備份至 R4
@ 迴圈執行，直到 R0 所指向的字元為 0（Null 結尾符號）為止
loop:	LDRB	R5, [R0]    @ 從輸入字串位址 [R0] 載入單字元（Byte）至 R5
	ADD	R0, #1      @ 將輸入字串指標 R0 加 1（指向下一個字元）
@ 若 R5 > 'z'，則跳躍至 cont（非小寫字母，不需轉換）
	CMP	R5, #'z'    @ 檢查字元是否大於 'z'？
	BGT	cont
@ 若 R5 < 'a'，則跳躍至 cont（非小寫字母，不需轉換）
	CMP	R5, #'a'    @ 檢查字元是否小於 'a'？
	BLT	cont        @ 跳躍至 end if
@ 若程式執行到此，代表字元為小寫字母 ('a'-'z')，進行大寫轉換
	SUB	R5, #('a'-'A') @ 減去 32 ('a'-'A') 將 ASCII 小寫轉為大寫
cont:	@ end if
	STRB	R5, [R1]    @ 將處理後的字元寫入輸出字串位址 [R1]
	ADD	R1, #1      @ 將輸出字串指標 R1 加 1
	CMP	R5, #0      @ 檢查是否遇到字串結尾符號 '\0' (Null character)
	BNE	loop        @ 若字元不為 Null，則繼續迴圈處理下一個字元

	SUB	R0, R1, R4  @ 透過「目前輸出指標 (R1) - 原始輸出位址 (R4)」計算字串長度，並存入 R0 做為函式回傳值
	POP	{R4-R5}     @ 還原先前保存的暫存器 R4-R5
	BX	LR          @ 使用 Branch and Exchange 返回呼叫者 (Caller)