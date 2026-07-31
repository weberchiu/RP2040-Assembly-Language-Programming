@ U13157116 邱偉柏
@ 將字串轉換為全大寫的彙編巨集（Macro）
@
@ R1 - 輸出字串（outstr）的記憶體位址
@ R0 - 輸入字串（instr）的記憶體位址
@ R2 - 記錄原始輸出字串位址（用於計算長度）
@ R3 - 目前正在處理的字元
@

@ 標籤 1 = 迴圈開始 (loop)
@ 標籤 2 = 條件分支跳轉 (cont)

.MACRO	toupper	instr, outstr
	LDR	R0, =\instr  @ 載入輸入字串 (\instr) 的位址至 R0
	LDR	R1, =\outstr @ 載入輸出字串 (\outstr) 的位址至 R1
	MOV	R2, R1       @ 將原始輸出字串指標 (R1) 複製備份至 R2
@ 迴圈執行，直到 R0 所指向的字元為 0（Null 結尾符號）為止
1:	LDRB	R3, [R0]     @ 從輸入字串位址 [R0] 載入單字元（Byte）至 R3
	ADD	R0, #1       @ 將輸入字串指標 R0 加 1（指向下一個字元）
@ 若 R3 > 'z'，則跳轉至前方標籤 2（2f：Forward to 2）
	CMP	R3, #'z'     @ 檢查字元是否大於 'z'？
	BGT	2f
@ 若 R3 < 'a'，則跳轉至前方標籤 2（2f：Forward to 2）
	CMP	R3, #'a'     @ 檢查字元是否小於 'a'？
	BLT	2f           @ 跳轉至 end if
@ 若程式執行到此，代表字元為小寫字母 ('a'-'z')，進行大寫轉換
	SUB	R3, #('a'-'A') @ 減去 32 ('a'-'A') 將 ASCII 小寫轉為大寫
2:	@ end if
	STRB	R3, [R1]     @ 將處理後的字元寫入輸出字串位址 [R1]
	ADD	R1, #1       @ 將輸出字串指標 R1 加 1
	CMP	R3, #0       @ 檢查是否遇到字串結尾符號 '\0' (Null character)
	BNE	1b           @ 若字元不為 Null，跳轉回後方標籤 1（1b：Backward to 1）繼續執行
	SUB	R0, R1, R2   @ 透過「目前輸出指標 (R1) - 原始輸出位址 (R2)」計算字串長度，並存入 R0 做為回傳值
.ENDM