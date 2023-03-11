DATE$	EQU	0033H
	ORG	8E00H
; Transfer day of week
START:	LD	A,(DATE$+2)	; Is there month?
	OR	A
	JR	Z,SKIP
	LD	A,(DATE$+4)
	RRCA
	AND	00000111B
	LD	HL,DW$
	LD	DE,ZDW
	CALL	XFER3
	LD	A,','
	LD	(DE),A
	INC	DE
; Transfer month
	LD	A,(DATE$+2)
	LD	HL,MONTH$
	INC	DE
	CALL	XFER3
	INC	DE
	LD	HL,ZDW
; Transfer day
	LD	A,(DATE$+1)
	EX	DE,HL
	CALL	XFERN
; Transfer year
	LD	A,(DATE$+0)
	LD	HL,ZYEAR-1
	LD	(HL),27H
	INC	HL
	CALL	XFERN
; Now move page 8F00H to FF00H
SKIP:	LD	HL,8F00H
	LD	DE,0FF00H
	LD	BC,255
	LDIR
	LD	A,0C3H		; "JP"
	LD	(08BF4H),A
	LD	HL,0FF00H
	LD	(08BF5H),HL	; Store intercept
; Move applicable part of page 9000H to 0100H
	LD	HL,90C0H
	LD	DE,01C0H
	LD	BC,64
	LDIR
	RET
;--
; Entry: A = number
;  HL = address to store
;--
XFERN:	CP	100		; Greater than 100?
	JR	C,XFERNN
	SUB	100		; Correct
XFERNN:	LD	(HL),'0'	; Is zero
XFERN0:	CP	10		; Greater than 10?
	JR	C,XFERN1
	INC	(HL)		; Increase tens
	SUB	10		; Down by 10
	JR	XFERN0
XFERN1:	INC	HL
	ADD	A,'0'		; Make into number
	LD	(HL),A
	RET
XFER3:	DEC	A
	LD	B,A
	ADD	A,A		; * 2
	ADD	A,B		; * 3
	ADD	A,L
	LD	L,A
	LD	BC,3
	LDIR
	RET
ZDW	EQU	1249H		; Location within SU4
ZMONTH	EQU	ZDW+5
ZDAY	EQU	ZMONTH+4
ZYEAR	EQU	ZDAY+4
DW$	DB	'SunMonTueWedThuFriSatSun'
MONTH$	DB	'JanFebMarAprMayJunJulAugSepOctNovDec'
	END	START
