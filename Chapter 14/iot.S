@ U13157116 邱偉柏
@ 組合語言程式：回應來自伺服器的輪詢 (Poll)，並透過 UART 傳送當前晶片溫度
@

@ 通訊協定狀態機 (State Machine) 狀態定義
.EQU	SOH_State, 1   @ 狀態 1：等待 SOH (Start of Header) 標頭字元
.EQU	ADDR_State, 2  @ 狀態 2：等待終端機位址 (Device Address) Matching
.EQU	ETX_State, 3   @ 狀態 3：等待 ETX (End of Text) 結尾字元

@ 特殊通訊協定控制字元定義 (Control Characters)
.EQU	SOHChar, 1      @ 0x01: SOH (Start of Header)
.EQU	STXChar, 2      @ 0x02: STX (Start of Text)
.EQU	ETXChar, 3      @ 0x03: ETX (End of Text)
.EQU	TermAddrChar, 49 @ 本機位址標籤 (ASCII Code '1' = 49)

.thumb_func
.global main	        @ 匯出 main 給連結器

main:
@ 初始化週邊硬體設備
	BL	initTempSensor  @ 初始化 ADC 模組與內部溫度感測器
	BL	initUART        @ 初始化 UART 通訊埠 (設定波特率、位元數等)

loop:
@ 狀態機重置：初始狀態設為等待 SOH 標頭
	MOV	R7, #SOH_State  @ 將當前狀態 (State) 存放在 R7 暫存器
       
waitforpoll:
	BL	readUART        @ 從 UART 讀取一個輸入字元 (回傳於 R0)

	@ --- 狀態機分歧 switch( state = R7 ) ---
	CMP	R7, #SOH_State  @ 是否處於 SOH_State 狀態？
	BNE	AddrStateCheck  @ 若否，檢查是否為位址狀態 (AddrState)
	CMP	R0, #SOHChar    @ 檢查讀到的字元是否為 SOH (0x01)
	BNE	waitforpoll     @ 若不是 SOH，繼續留在 SOH_State 等待下一個字元
	MOV	R7, #ADDR_State @ 若是 SOH，將狀態切換至 ADDR_State
	B	waitforpoll     @ 讀取下一個字元

AddrStateCheck:	
	CMP	R7, #ADDR_State @ 是否處於 ADDR_State 狀態？
	BNE	EtxStateCheck   @ 若否，檢查是否為 ETX 狀態
	CMP	R0, #TermAddrChar @ 檢查目標位址是否匹配本機位址 ('1')
	BEQ	gotaddr         @ 位址匹配，跳轉至 gotaddr
	MOV	R7, #SOH_State  @ 位址不符 (輪詢其他設備)，狀態倒退回 SOH_State
	B	waitforpoll     @ 讀取下一個字元

gotaddr:
	MOV	R7, #ETX_State  @ 位址匹配成功，將狀態切換至 ETX_State
	B	waitforpoll     @ 讀取下一個字元

EtxStateCheck:
	CMP	R0, #ETXChar    @ 是否讀到封包結尾字元 ETX (0x03)？
	BEQ	gotetx          @ 收到完整的合法封包，跳轉至 gotetx 處理回應
	MOV	R7, #SOH_State  @ 封包格式錯誤，重置回 SOH_State
	B	waitforpoll     @ 讀取下一個字元

gotetx: 
@ 成功接收到針對本機的輪詢要求 (Poll Packet)，發送封包回應伺服器：
@ 回應封包格式：[SOH] + [Address] + [STX] + "Temp:   XX" + [ETX]

	MOV	R0, #SOHChar
	BL	sendUART        @ 傳送 1. SOH 標頭
	MOV	R0, #TermAddrChar
	BL	sendUART        @ 傳送 2. 本機位址 ('1')
	MOV	R0, #STXChar
	BL	sendUART        @ 傳送 3. STX 文字開始符號

	BL	readTemp        @ 呼叫 ADC 讀取溫度感測器 12-bit 原始數值 (回傳於 R0)
	BL	calcTempCelc    @ 將原始數據轉換為攝氏溫度數值 (回傳於 R0)

	LDR	R1, =tempStr    @ 載入字串樣板 "Temp:            " 的記憶體位址
	ADD	R1, #6          @ 將寫入指標偏移 +6 Bytes (移至 "Temp: " 之後的空白處)
	BL	itoa            @ 呼叫 integer-to-ascii (itoa)，將 R0 的溫度數值轉為字串填入 [R1]
	
	LDR	R5, =tempStr    @ R5 指向準備發送的字串頭

@ 透過 UART 將組合完成的訊息字串逐字傳送出去
nextchar:
	LDRB	R0, [R5]    @ 從記憶體讀取一個位元組 (字元)
	CMP	R0, #0          @ 檢查是否遇到字串結束符號 '\0' (Null-terminated)
	BEQ	done            @ 若遇到 '\0'，代表字串發送結束
	BL	sendUART        @ 將字元透過 UART 發送
	ADD	R5, #1          @ 字串指標指向下一個字元
	B	nextchar        @ 繼續迴圈發送

@ 訊息內文發送完畢，補上 ETX 結尾字元結束本次回應
done:
	MOV	R0, #ETXChar
	BL	sendUART        @ 傳送 ETX 結尾字元

@ 本次輪詢回應結束，重新回到主迴圈等待下一次伺服器輪詢
	B	loop            @ 無窮迴圈

.data
@ 溫度訊息字串樣板 (預留足夠空間給 itoa 填入數字)
tempStr:	.asciz   "Temp:            "