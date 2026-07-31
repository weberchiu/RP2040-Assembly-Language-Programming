@ U13157116 邱偉柏
@ RP2040 ADC 控制器與內建類比溫度感測器 (Analog Temperature Sensor) 介面模組
@

#include "hardware/regs/addressmap.h"
#include "hardware/regs/adc.h"

.EQU	TEMPADC, 4   @ 晶片內部溫度感測器連接至 ADC 通道 4 (AINSEL = 4)

.thumb_func
.global calcTempCelc, initTempSensor, readTemp

@ =========================================================================
@ 函式：calcTempCelc
@ 功能：將 12-bit ADC 原始數值轉換為攝氏溫度 (Degrees Celsius)
@ 算式：T = 437 - (100 * R0) / 215
@
@ 暫存器說明：
@ 輸入：R0 - 12-bit ADC 原始讀取值
@ 輸出：R0 - 攝氏溫度估算值 (°C)
@ 暫存器：R1 - 用於乘法與除法的暫存器
@ =========================================================================
calcTempCelc:
	PUSH	{LR}		    @ 儲存 LR，因為內部會呼叫 intDivide 子程式
	MOV	R1, #100
	MUL	R0, R1		    @ R0 = R0 * 100
	MOV	R1, #215
	BL	intDivide	    @ 呼叫除法函式：R0 = R0 / 215
	LDR	R1, tempcalcoff @ 載入公式常數偏移量 (437)
	SUB	R0, R1, R0	    @ R0 = 437 - R0
	POP	{PC}		    @ 恢復 LR 並返回

@ =========================================================================
@ 函式：initTempSensor
@ 功能：初始化 ADC 硬體模組與晶片內建溫度感測器
@ 輸入：無
@ 輸出：無
@ 使用暫存器：R1, R2, R3
@ =========================================================================
initTempSensor:
@ 開啟 ADC 模組與內部溫度感測器
@ 我們需要設定以下控制位元：
@ 1. AINSEL: 選擇類比通道 4 (TEMPADC)
@ 2. TS_EN:  啟用內部溫度感測器 (Temperature Sensor Enable)
@ 3. EN:     啟用 ADC 硬體模組 (ADC Enable)
	MOV	R1, #TEMPADC
	LSL	R1, #ADC_CS_AINSEL_LSB                 @ 將通道號碼 4 左移至 AINSEL 欄位位址
	ADD	R1, #(ADC_CS_TS_EN_BITS+ADC_CS_EN_BITS) @ 結合 TS_EN 與 EN 致能位元
	LDR	R2, adcbase
	STR	R1, [R2, #ADC_CS_OFFSET]              @ 寫入 ADC 控制與狀態暫存器 (ADC_CS)

@ 類比電路與感測器啟動需要數個 Clock Cycles，因此自旋等待 READY 位元變為 1
notReady2:
	LDR	R1, [R2, #ADC_CS_OFFSET]   @ 讀取當前 ADC_CS 狀態
	MOV	R3, #1
	LSL	R3, #ADC_CS_READY_LSB      @ 建立 READY 位元遮罩 (Bitmask)
	AND	R1, R3                     @ 檢查 READY 位元
	BEQ	notReady2	               @ 若 READY == 0，繼續等待
	BX	LR

@ =========================================================================
@ 函式：readTemp
@ 功能：觸發一次 ADC 採樣並讀取溫度感測器的原始數值
@ 輸入：無
@ 輸出：R0 - 12-bit ADC 採樣結果 (0 ~ 4095)
@ =========================================================================
readTemp:
	LDR	R2, adcbase
	LDR	R1, [R2, #ADC_CS_OFFSET]    @ 讀取當前 ADC_CS 控制暫存器
	ADD	R1, #ADC_CS_START_ONCE_BITS @ 設定 START_ONCE 位元，發起一次性轉換需求
	STR	R1, [R2, #ADC_CS_OFFSET]    @ 寫入暫存器，硬體開始轉換
notReady:
	LDR	R1, [R2, #ADC_CS_OFFSET]    @ 輪詢等待轉換完成
	MOV	R3, #1
	LSL	R3, #ADC_CS_READY_LSB	    @ 檢測 READY 位元
	AND	R1, R3
	BEQ	notReady                    @ 若尚未完成 (READY == 0)，繼續輪詢等待
	LDR	R0, [R2, #ADC_RESULT_OFFSET] @ 從 ADC_RESULT 暫存器讀取 12-bit 轉換結果至 R0
	BX	LR			                 @ 返回數值

		.align	4
adcbase:	.word	ADC_BASE	    @ ADC 週邊基底位址 (0x4004c000)
tempcalcoff:	.word	437             @ 溫度公式整數擬合常數 (27°C - (V - 0.706)/0.001721 的縮放結果)