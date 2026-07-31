@ U13157116 邱偉柏
@ 本檔案包含第 5 章的各種程式碼片段。
@ 確保它們能正常編譯，並提供單步執行（Single Step）偵錯的機會。
@ 程式碼均已加上標籤（Label），你可以直接在感興趣的位置設定中斷點（Breakpoint）。
@
@ 在程式碼片段之後，是將暫存器內容轉換為 ASCII 字串的常式。
@

.thumb_func        @ 必要設定：因為 SDK 使用 BLX 指令，需指定為 Thumb 模式
.global main       @ 將程式進入點（main）匯出給連結器（Linker）

main:	BL	stdio_init_all	@ 初始化 UART 或 USB 標準輸入輸出

@ 若想觀察無窮迴圈，請取消下方兩行的註解
l1:	@ MOV R1, #1
	@ B l1

l2:	CMP R4, #45     @ 比較 R4 是否等於 45
	BEQ l1          @ 若相等（Equal），則跳躍至 l1

l3:	MOV R2, #1      @ R2 代表變數 I，初始化為 1
loop:	@ 迴圈主體放置於此。
	@ 大部分的邏輯判斷放置於迴圈末端
	ADD R2, #1      @ I = I + 1
	CMP R2, #10     @ 比較 I 與 10
	BLE loop        @ 若 I <= 10（Less or Equal），跳躍回 loop 繼續迴圈

l4:	MOV R2, #10     @ R2 代表變數 I，初始化為 10
loop2:	@ 迴圈主體放置於此。
	@ 此處不需要額外的 CMP 指令，因為 SUBS 會直接更新 Flag
	SUB R2, #1      @ I = I - 1
	BNE loop2       @ 若結果不為 0（Not Equal），繼續執行 loop2

l5:	@ R4 代表變數 X，在此進行初始化
	MOV R4, #5
loop3:	CMP R4, #5      @ 比較 R4 與 5
	BGE loopdone    @ 若 R4 >= 5（Greater or Equal），跳出迴圈至 loopdone
	@ … 迴圈主體中的其他敘述 …
	MOV r4, #6
	B loop3         @ 無條件跳躍回 loop3
loopdone:           @ 迴圈結束後繼續執行程式碼

l6:	CMP R5, #10     @ 比較 R5 與 10
	BGE elseclause  @ 若 R5 >= 10，跳躍至 else 分支
	@ … if 區塊的敘述 …
	B endif         @ 執行完 if 區塊後跳過 else 區塊
elseclause:
	@ … else 區塊的敘述 …
endif:              @ if/else 結構結束，繼續往下執行…

l7:	@ 遮罩掉高位元組（High order byte）
	MOV R5, #0xFF
	LSL R5, #24     @ R5 = 0xFF000000
	AND R6, R5      @ 將 R6 與 R5 進行「與」運算（僅保留最高位元組）

l8:	MOV R5, #0xFF
	ORR R6, R5      @ 將 R6 與 R5 進行「或」運算（將最低位元組設為 1）

l9:	BIC R6, R5      @ 位元清除（Bit Clear）：清空 R6 中對應 R5 為 1 的位元

@ 範例：將暫存器內容轉換為 ASCII 碼（Hex 格式）
@
@ R0-R1 - 傳遞給 printf 的參數
@ R1    - 同時作為目前正在寫入的 ASCII 字串位址
@ R4    - 欲印出數值的目標暫存器
@ R5    - 迴圈索引（計數器）
@ R6    - 目前處理的字元/數值
@ R7    - 暫存用暫存器

printexample:
	@ 將 0x12AB 載入至 R4
	MOV	R4, #0x12   @ 欲印出的數值（高位部分）
	LSL	R4, #8
	MOV	R7, #0xAB   @ 欲印出的數值（低位部分）
	ADD	R4, R7      @ R4 現在為 0x000012AB
	LDR	R1, =hexstr @ 載入字串 hexstr 的起始位址
	ADD	R1, #9      @ 將指標移動至最右側（最低有效數字位置）
@ 迴圈結構等同於 FOR R5 = 8 TO 1 STEP -1
	MOV	R5, #8      @ 準備處理 8 個 Hex 數字 (32 bits / 4)
loop4:	MOV	R6, R4
	MOV	R7, #0xf
	AND	R6, R7      @ 取出最低有效數字 (Mask 0xF)
@ 若 R6 >= 10，則跳躍至 letter 處理字母 A-F
	CMP	R6, #10     @ 判斷是數字 0-9 還是字母 A-F
	BGE	letter
@ 否則為數字 0-9，轉換為數字的 ASCII 碼
	ADD	R6, #'0'    @ 加上 '0' 的 ASCII 碼
	B	cont        @ 轉換完成，跳轉至 end if
letter:             @ 處理 10 到 15 (A 到 F) 的情形
	ADD	R6, #('A'-10) @ 加上偏移量轉為 'A'-'F' 的 ASCII 碼
cont:	@ end if
	STRB	R6, [R1]    @ 將轉好的 ASCII 字元存入記憶體 [R1]
	SUB	R1, #1      @ 指標前移一位（準備寫入下一個高位數字）
	LSR	R4, #4      @ 將 R4 向右移 4 bits，丟棄已處理完的數字

	@ 下一次迴圈 (next R5)
	SUB	R5, #1      @ 計數器 R5 減 1
	BNE	loop4       @ 若未完成（不為 0）則繼續執行 loop4

repeat:
	LDR	R0, =printstr @ 第一個參數：格式化字串位址
	LDR	R1, =hexstr   @ 第二個參數：已轉為 ASCII 的 hex 字串位址
	BL	printf        @ 呼叫 printf 印出結果
	B	repeat        @ 重複列印，避免程式結束

.align 4
.data
hexstr:   .asciz  "0x12345678"
printstr: .asciz  "Register = %s\n"