@ U13157116 邱偉柏
@ 本檔案包含第 6 章的各種程式碼片段。
@ 確保它們能正常編譯，並提供單步執行（Single Step）偵錯的機會。
@ 程式碼均已加上標籤（Label），你可以直接在感興趣的位置設定中斷點（Breakpoint）。

.global codesnippets     @ 將 codesnippets 匯出給連結器（Linker）

codesnippets: 
	PUSH	{R3-R7, LR}     @ 保護呼叫者（Caller）的暫存器與返回位址 (LR)

l1:	PUSH	{r0, r5-r7}     @ 堆疊操作範例：將 r0, r5, r6, r7 推入堆疊
	POP	{r0, r5-r7}     @ 彈出並還原 r0, r5, r6, r7
	PUSH	{r0-r4, r6}     @ 支援連續暫存器範圍 (r0-r4) 與單一暫存器 (r6)
	POP 	{r0-r4, r6}

l2:	BL	myfunc          @ 呼叫子程式 myfunc（自動將下一行位址存入 LR）
	MOV	R1, #4
	B	l3              @ 無條件跳躍至 l3

myfunc:	@ 執行函式內部工作...
	BX	LR              @ 使用 Branch and Exchange 指令返回（從 LR 恢復執行位置）

l3:	BL	myfuncb         @ 呼叫會再呼叫其他函式的子程式 (Nested Function Call)
	MOV	R1, #4
	B 	l4

myfuncb:PUSH {LR}           @ 巢狀呼叫必須先保存自身的 LR，否則再次呼叫 BL 時 LR 會被覆寫
@ 執行函式內部工作 ...
	BL	myfuncb2        @ 呼叫第二層子程式
@ 執行更多工作...
	POP {PC}            @ 直接將堆疊中的 LR 彈出給 PC（實現函式返回）

myfuncb2:	@ 執行最內層工作 ....
	BX LR               @ 葉函式（Leaf function，不再呼叫別人）直接 BX LR 返回

l4:	SUB	SP, #12         @ 在堆疊上保留 12 位元組（3 個 32-bit Word）作為區域變數空間

l5:	STR	R0, [SP]        @ 將變數 a 存入堆疊頂端 [SP + 0]
	STR	R1, [SP, #4]    @ 將變數 b 存入堆疊 [SP + 4]
	STR	R2, [SP, #8]    @ 將變數 c 存入堆疊 [SP + 8]

l6:	ADD	SP, #12         @ 釋放堆疊上的區域變數空間（恢復堆疊指標 SP）

@l7:	MOV	R0, #4          @ （註解掉的 Frame Pointer 範例）
@	SUB	FP, SP, R0      @ 設定 Frame Pointer (FP)
@	SUB	SP, #12

@l8:	STR	R0, [FP]        @ 使用基底 FP 進行區域變數存取
@	STR	R1, [FP, #-4]
@	STR	R2, [FP, #-8]
@	ADD	SP, #12

l9:	BL	SUMFN           @ 呼叫加法函式 SUMFN
	B	l10

@ 一個接受 2 個參數（VAR1 與 VAR2）的簡單函式。
@ 該函式將兩者相加，並將結果存入區域變數 SUM，
@ 最後回傳加總結果 (SUM)。
@ 假設此函式還會進行其他工作（包含呼叫其他函式）。

@ 使用 .EQU 定義區域變數在堆疊上的相對偏移量（Offset）
	.EQU	VAR1, 0
	.EQU	VAR2, 4
	.EQU	SUM,  8

SUMFN:	@ 函式前導程式（Function Prolog）
	PUSH	{R4-R7, LR}     @ 保存Callee-saved暫存器與 LR
	SUB	SP, #12         @ 分配 12 位元組的堆疊空間給區域變數
	STR	R0, [SP, #VAR1] @ 保存傳入的第一個參數 (R0)
	STR	R1, [SP, #VAR2] @ 保存傳入的第二個參數 (R1)

@ 執行其他工作，期間可自由使用 R0-R3，只要不改變 SP

	LDR	R4, [SP, #VAR1] @ 從堆疊讀取 VAR1 到 R4
	LDR	R5, [SP, #VAR2] @ 從堆疊讀取 VAR2 到 R5
	ADD	R6, R4, R5      @ R6 = R4 + R5
	STR	R6, [SP, #SUM]  @ 將結果存入堆疊的 SUM

@ 執行其他工作...

@ 函式尾聲（Function Epilog）
	LDR	R0, [SP, #SUM]  @ 將結果載入 R0 作為回傳值（符合 AAPCS 規範）
	ADD	SP, #12         @ 釋放區域變數的堆疊空間
	POP	{R4-R7, PC}     @ 還原暫存器並將 LR 彈出至 PC（完成返回）

l10: 	
	POP	{R3-R7, PC}     @ 還原主程式進入時保存的暫存器並結束執行