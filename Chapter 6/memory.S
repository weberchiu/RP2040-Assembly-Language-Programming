@ U13157116 邱偉柏
@ 本檔案包含第 5 章的各種程式碼片段。
@ 確保它們能正常編譯，並提供單步執行（Single Step）偵錯的機會。
@ 程式碼均已加上標籤（Label），你可以直接在感興趣的位置設定中斷點（Breakpoint）。

.thumb_func        @ 必要設定：因為 SDK 使用 BLX 指令，需指定為 Thumb 模式
.global main       @ 將程式進入點（main）匯出給連結器（Linker）

.data
l1: .byte 74, 0112, 0b00101010, 0x4A, 0X4a, 'J', 'H' + 2
                   @ 各種數值進位制的 byte 宣告（十進位、八進位、二進位、十六進位、字元、算術表達式，結果皆為ASCII 'J' / 74）
	.word	0x1234ABCD, -1434
                   @ 宣告 32-bit 字組 (Word)
	.ascii	"Hello World\n"
                   @ 宣告 ASCII 字串（不自動加上結尾符號 \0）

l2:	.byte -0x45, -33, ~0b00111001
                   @ 負數與反相補數（Bitwise NOT）的 byte 宣告

l3:	.fill	10, 4, 0
                   @ 填滿記憶體：重複 10 次，每次填充 4 個 bytes，值為 0

l4:	.rept 3        @ 重複區塊開始：重複執行 3 次
	.byte	0, 1, 2
	.endr          @ 重複區塊結束

.text

main:	BL	stdio_init_all	@ 初始化 UART 或 USB 標準輸入輸出

	BL	toupper        @ 呼叫 toupper 轉大寫常式

	MOV	r2, #0xd0
	LSL	r2, r2, #24    @ 向左位移 24 bits，變為 0xd0000000
	ADD	r2, #0x14      @ 加上 0x14

l5:	LDR	R1, =helloworld
                   @ 使用偽指令（Literal Pool）載入 helloworld 字串的記憶體位址

l6:	LDR	R1, =0x1234ABCDF
                   @ 使用偽指令將 32 位元常數載入 R1

l7:
@ 將 mynumber 的記憶體位址載入至 R1
	LDR	R1, =mynumber
@ 載入儲存在 mynumber 位址的 32 位元字組 (Word) 到 R2
	LDR	R2, [R1]

l8:	LDR	R1, =arr1      @ 載入陣列 arr1 的起始位址

l9:	@ 載入陣列的第一個元素 (index 0)
	LDR	R2, [R1]
	@ 載入第 3 個元素
	@ 陣列索引從 0 開始計算，因此 2 代表第 3 個元素。
	@ 每個 Word 佔用 4 個 bytes，因此需要乘以 4 (即偏移量 8 bytes)
	LDR	R2, [R1, #(2 * 4)]

l10:	@ 第 3 個元素的索引值依然是 2
	MOV	R3, #(2 * 4)   @ 計算偏移量並放入 R3
@ 將 R3 的偏移量與 R1 基底位址相加，來取得目標元素的內容
	LDR	R2, [R1, R3]   @ 基底暫存器 + 暫存器偏移量定址

	LDR	R1, =mydword   @ 載入 mydword 位址
	LDM	R1, {R2, R3}   @ 從 R1 指向的記憶體一次載入資料到 R2 與 R3 (Load Multiple)
	STM	R1, {R2, R3}   @ 將 R2 與 R3 的內容寫回至 R1 指向的記憶體 (Store Multiple)

	@ 與上述作用相同，但加上 ! 表示會在操作後自動更新基底暫存器 R1 的位址 (Writeback)
	LDR	R1, =mydword
	LDM	R1!, {R2, R3}  @ 載入後，R1 位址會自動加 8
	STM	R1!, {R2, R3}  @ 寫入後，R1 位址會自動加 8

.data
helloworld:	.ascii "Hello World!"
mynumber:	.WORD	0x1234ABCD
arr1:	.FILL	10, 4, 0   @ 填充 10 個大小為 4 bytes 的區塊（清零）
@ 撰寫當時 Assembler (AS) 存在一個 Bug，導致下一行指令會跳出 Warning。
@ 你可以忽略警告，並透過 objdump 來確認產生的資料是否正確。
mydword:	.QUAD 0x1234567887654321 @ 宣告 64-bit 雙字組 (Quadword)
mydword2:	.QUAD 0x0