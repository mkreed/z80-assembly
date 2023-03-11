;-----------------------------------------
; MMOUSE - Model 4 mouse driver for a 
; Microsoft compatible mouse, version 1.0
; copyright (c) 1990, by Matthew Reed
;-----------------------------------------
@DSPLY	EQU	10
@LOGOT	EQU	12
@PARAM	EQU	17
@GTMOD	EQU	83
@MUL16	EQU	91
@DIV16	EQU	94
@HIGH$	EQU	100
@FLAGS$	EQU	101
@CKBRKC	EQU	106
@MOUSE	EQU	120
STR	EQU	20H
ABR	EQU	10H
SVC	MACRO	#NUM
	LD	A,#NUM
	RST	28H
	ENDM
;-----------------------
; Start of installation
;-----------------------
	ORG	3000H
BEGIN	LD	(STACK),SP	; Save stack
	LD	SP,BEGIN	; Make new stack
	SVC	@CKBRKC		; Abort if break pressed
	JP	NZ,ABORT
	PUSH	HL		; Save command line
	LD	HL,TITLE$	; Display title
	SVC	@DSPLY
	POP	HL		; Restore command line
;---------------------
; Test for parameters
;---------------------
	SVC	@FLAGS$		; Set IY
	LD	A,(IY+26)	; SVC table MSB
	LD	(SVCA1),A	; Stuff in program
	LD	(SVCA2),A
	LD	DE,PARM$	; Parameter table
	SVC	@PARAM		; Parse parameters
	JP	NZ,PARME	; Abort if error
	LD	BC,0		; REMOVE = OFF
REMOVE	EQU	$-2
	LD	A,B		; Is it ON?
	OR	C
	JP	NZ,RMV		; REMOVE if ON
;----------------
; Install $MOUSE
;----------------
	LD	DE,MOUSE$	; "$MOUSE"
	SVC	@GTMOD		; Is it in high memory?
	JR	Z,LINK		; Install if so
;---------------
; Get old HIGH$
;---------------
	LD	HL,0		; Get current HIGH$
	LD	B,L
	SVC	@HIGH$
	JP	NZ,NOMEM$	; No high memory
	LD	(OLDHI),HL	; Put in module
;---------------------
; Relocate references
;---------------------
	LD	IX,RELTAB	; Relocation table
	LD	DE,MODEND	; Module end
	OR	A
	SBC	HL,DE		; Difference to add
	LD	B,H		; BC = difference
	LD	C,L
RLOOP	LD	L,(IX+0)	; Get address to change
	LD	H,(IX+1)
	LD	A,H		; Is it end?
	OR	L
	JR	Z,MOVH		; If so, move to high
	LD	E,(HL)		; Get address
	INC	HL
	LD	D,(HL)
	EX	DE,HL
	ADD	HL,BC		; Add difference
	EX	DE,HL
	LD	(HL),D		; Put it back
	DEC	HL
	LD	(HL),E
	INC	IX		; Advance to next entry
	INC	IX
	JR	RLOOP		; Loop until finished
;-----------------------
; Move into high memory
;-----------------------
MOVH	LD	DE,(OLDHI)	; Destination
	LD	HL,MODEND	; Last byte of module
	LD	BC,LENGTH	; Length of module
	LDDR			; Move into high memory
	EX	DE,HL		; HL = HIGH$
	SVC	@HIGH$		; Set it
	JP	NZ,NOMEM	; Abort if error
	INC	HL		; Ahead one
;-----------------
; Install SVC 120
;-----------------
LINK	LD	BC,SVC120-MOUSE	; Find SVC address
	ADD	HL,BC
	LD	(01F0H),HL	; Put in SVC table
SVCA1	EQU	$-1
;------------------------
; Initialize RS-232 port
;------------------------
	OUT	(0E8H),A	; Reset UART
	LD	A,77H		; 1200 baud
	OUT	(0E9H),A	; Set it
	LD	A,01101100B	; UART settings
	OUT	(0EAH),A	; Set it
;----------------------------------
; Install RS-232 receive interrupt
;----------------------------------
	DI			; Find interrupt address	
	LD	BC,INTTASK-SVC120
	ADD	HL,BC
	LD	(0048H),HL	; Put in interrupt table
	SET	5,(IY+'W'-'A')	; Enable receive interrupt
	LD	A,(IY+'W'-'A')	; Get byte
	OUT	(0E0H),A	; Out to port
	EI
	LD	HL,80		; Set maximum values
	LD	DE,24
	LD	BC,0403H	; Sensitivity
	SVC	@MOUSE
;---------------
; Success, exit
;---------------
	LD	HL,SCC$		; Installation success
	DB	0DDH
RSCC	LD	HL,RSCC$	; Remove success
	SVC	@DSPLY
EXIT	LD	HL,0		; No error
	DB	0DDH
ABORT	LD	HL,-1		; Error
	LD	SP,$-$		; Restore stack
STACK	EQU	$-2
	RET
;---------------------
; Remove mouse driver
;---------------------
RMV	LD	DE,MOUSE$	; Module name
	SVC	@GTMOD		; Look in high memory
	JP	NZ,NTINST	; Abort if not found
	PUSH	HL		; Save address
	LD	HL,1AF4H	; SVC error
	LD	(01F0H),HL	; Put in table
SVCA2	EQU	$-1
	DI
	LD	HL,1C48H	; No interrupt
	LD	(0048H),HL	; Put in table
	RES	5,(IY+'W'-'A')	; Remove interrupt
	LD	A,(IY+'W'-'A')	; Get byte
	OUT	(0E0H),A	; Out to port
	EI
	LD	HL,0		; Get HIGH$
	LD	B,H
	SVC	@HIGH$
	JP	NZ,NOMEM	; Abort if error
	EX	DE,HL		; DE = HIGH$
	POP	HL		; HL = module address
	DEC	HL		; Back one
	OR	A		; Compare
	SBC	HL,DE
	JP	NZ,CNTRMV	; Abort if error
	EX	DE,HL		; Switch to HL
	INC	HL		; Go to OLDHI
	INC	HL
	INC	HL
	LD	A,(HL)
	INC	HL
	LD	H,(HL)
	LD	L,A		; HL = (OLDHI)
	LD	B,0		; Set new HIGH$
	SVC	@HIGH$
	JR	Z,RSCC		; Go if success
;----------------
; Error routines
;----------------
NOMEM	LD	HL,NOMEM$	; No memory
	DB	0DDH
PARME	LD	HL,PARME$	; Parameter error
	DB	0DDH
NTINST	LD	HL,NTINST$	; Driver not installed
	DB	0DDH
CNTRMV	LD	HL,CNTRMV$	; Can't remove
	SVC	@LOGOT
	JR	ABORT
;----------
; Messages
;----------
TITLE$	DB	'MMOUSE - Model 4 mouse driver for a'
	DB	' Microsoft compatible mouse,',0AH
	DB	'  version 1.0,'
	DB	' copyright (c) 1990 by Matthew Reed',0AH
	DB	'  all rights reserved',0AH,0DH
SCC$	DB	'Mouse driver successfully installed',0DH
RSCC$	DB	'Mouse driver turned off and memory reclaimed',0DH
NOMEM$	DB	'High memory address can''t be changed!',0DH
PARME$	DB	'Parameter error!',0DH
NTINST$	DB	'Mouse driver is not installed!',0DH
CNTRMV$	DB	'Mouse driver turned off but memory can''t be reclaimed',0DH
MOUSE$	DB	'$MOUSE',03H
;-----------------
; Parameter table
;-----------------
PARM$	DB	80H
	DB	STR.OR.ABR.OR.6
	DB	'REMOVE'
RRSP	DB	0
	DW	REMOVE
	DB	0
;----------------------------------
; Resident portion of mouse driver
;----------------------------------
MOUSE	JR	SVC120
OLDHI	DW	$-$		; Old HIGH$
	DB	MODDCB-MOUSE-5
	DB	'$MOUSE'
MODDCB	DW	$-$
	DW	0
;-----------------
; SVC 120 handler
;-----------------
SVC120	DEC	B		; Go if function 1
	JR	Z,FUNCT1
	DEC	B		; Go if function 2
	JR	Z,FUNCT2
	DEC	B		; Go if function 3
	JR	Z,FUNCT3
	DEC	B		; Go if function 4
	JR	Z,FUNCT4
	DEC	B		; Return if not function 5
	LD	A,43		; SVC error
	RET	NZ
FUNCT5	XOR	A		; 2 button mouse
	RET
;-----------------------------
; Return X, Y, and buttons
; A = buttons, HL = X, DE = Y
;-----------------------------
FUNCT1	LD	HL,$-$		; Y value
YVAL	EQU	$-2
	LD	C,21		; Amount to divide
YDIV	EQU	$-1
	SVC	@DIV16		; Divide
	EX	DE,HL		; Put Y in DE
	LD	HL,$-$		; X value
XVAL	EQU	$-2
	LD	C,9		; Amount to divide
XDIV	EQU	$-1
	SVC	@DIV16		; Divide
	LD	A,07H		; Get button value
BUTTONS	EQU	$-1
	LD	B,00000111B	; No buttons pressed
	AND	00110000B	; Mask out rest
	JR	Z,F3		; If no buttons, ahead
	CP	00110000B	; If both buttons,
	JR	NZ,F1
	LD	B,00000101B	; signal middle
F1	CP	00100000B	; If left button,
	JR	NZ,F2
	LD	B,00000011B	; signal left
F2	CP	00010000B	; If right button,
	JR	NZ,F3
	LD	B,00000110B	; signal right
F3	LD	A,B		; Put in A
	RET
;------------------------
; Set X, Y value
; Entry: HL = X, DE = Y
; Success, Z flag set
;------------------------
FUNCT2	PUSH	DE		; Save Y
	PUSH	HL		; Save X
	LD	BC,80		; X maximum
XMAX	EQU	$-2
	OR	A		; Reset carry
	SBC	HL,BC		; Is it over maximum?
	JR	NC,FERR		; Go if error
	POP	HL		; Restore X
	LD	A,(XDIV)	; Get X divisor
RX01	EQU	$-2
	CALL	MULT		; Multiply
RX02	EQU	$-2
	LD	(XVAL),HL	; Put in XVAL
RX03	EQU	$-2
	POP	HL		; Restore Y
	PUSH	HL		; Save Y
	LD	BC,24		; Y maximum
YMAX	EQU	$-2
	OR	A		; Reset carry
	SBC	HL,BC		; Is it over maximum?
	JR	NC,FERR1	; Go if error
	POP	HL		; Restore Y
	LD	A,(YDIV)	; Get Y divisor
RX04	EQU	$-2
	CALL	MULT		; Multiply
RX05	EQU	$-2
	LD	(YVAL),HL	; Put in YVAL
RX06	EQU	$-2
	XOR	A		; Zero for no error
	RET
MULT	LD	C,A		; Put in C
	SVC	@MUL16		; Multiply
	LD	H,L		; Correct byte
	LD	L,A
	RET
FERR	POP	DE		; Clear stack
FERR1	POP	DE
	INC	A		; Signal error
	RET
;---------------------------------------
; Get sensitivity, X and Y maximums
; Exit: A = sensitivity, HL = X maximum
;	DE = Y maximum
;---------------------------------------
FUNCT3	LD	A,3		; Sensitivity
SENS	EQU	$-1
	LD	HL,(YMAX)	; Y maximum
RX07	EQU	$-2
	EX	DE,HL
	LD	HL,(XMAX)	; X maximum
RX08	EQU	$-2
	RET
;----------------------------------------
; Set sensitivity, X and Y maximums
; Entry: A = sensitivity, HL = X maximum
;	 DE = Y maximum
; Success, Z flag set
;----------------------------------------
FUNCT4	CP	4		; If too high, return
	RET	NC
	LD	(SENS),A	; Store sensitivity
RX09	EQU	$-2
	LD	B,C		; Put in counter
	INC	B		; Make non-zero
	LD	A,32		; X tick maximum
	LD	C,16		; Y tick maximum
FNCL	SRL	A		; Divide by 2
	SRL	C		; Divide by 2
	DJNZ	FNCL		; Loop until done
	LD	(TXMAX+1),A	; Store X tick maximum
RX10	EQU	$-2
	LD	A,C
	LD	(TYMAX+1),A	; Store Y tick maximum
RX11	EQU	$-2
	PUSH	HL		; Save X maximum
	PUSH	DE		; Save Y maximum
	CALL	FDIV		; Divide Y maximum by A
RX12	EQU	$-2
	JR	Z,FERR		; If zero, division error
	LD	(YDIV),A	; Store divisor
RX13	EQU	$-2
	LD	A,0FFH		; Get remainder
	SUB	L
	LD	(TYMAX),A	; Store it
RX14	EQU	$-2
	POP	HL		; Restore Y maximum
	LD	(YMAX),HL	; Store
RX15	EQU	$-2
	POP	DE		; Restore X maximum
	PUSH	DE		; Save X maximum
	LD	A,(TXMAX+1)	; Tick maximum
RX16	EQU	$-2
	CALL	FDIV		; Divide the two
RX17	EQU	$-2
	JR	Z,FERR1		; If zero, division error
	LD	(XDIV),A	; Store divisor
RX18	EQU	$-2
	LD	A,0FFH		; Get remainder
	SUB	L
	LD	(TXMAX),A	; Store it
RX19	EQU	$-2
	POP	HL		; Restore X maximum
	LD	(XMAX),HL	; Store
RX20	EQU	$-2
	LD	HL,0		; Zero X and Y
	PUSH	HL
	POP	DE
	JP	FUNCT2		; Exit through function 2
RX21	EQU	$-2
FDIV	LD	H,A		; MSB
	LD	A,D		; Is DE zero?
	OR	E
	RET	Z		; Return if error
	XOR	A		; Zero A
	LD	L,A
	DEC	L		; Back one
FDIV1	SBC	HL,DE		; Subtract
	INC	A		; Add one
	JR	NC,FDIV1	; Loop if more
	ADD	HL,DE		; Find remainder
	DEC	A		; -1
	RET
;------------------------------
; Interrupt task to read mouse
;------------------------------
INTTASK	IN	A,(0EAH)	; Is byte ready?
	AND	80H
	RET	Z		; Return if not
	LD	HL,INTC		; Interrupt counter
RX22	EQU	$-2
	IN	A,(0EBH)	; Read byte
	BIT	6,A		; Go if first byte
	JR	NZ,FBYTE
	AND	00111111B	; Mask out 7 and 6
	RLC	(HL)		; See which routine
	JR	C,SBYTE		; Go if second
TBYTE	OR	00H		; Y increment
YINC	EQU	$-1
	LD	HL,YVAL		; Y value
RX23	EQU	$-2
	LD	BC,01F8H	; Maximum count
TYMAX	EQU	$-2
	JR	TBYTE1		; Jump past
SBYTE	OR	00H		; X increment
XINC	EQU	$-1
	LD	HL,XVAL		; X value
RX24	EQU	$-2
	LD	BC,02D0H	; Maximum count
TXMAX	EQU	$-2
TBYTE1	LD	E,(HL)		; Put (HL) in DE
	INC	HL
	LD	D,(HL)
	JP	M,ADD2		; If minus, subtract
RX25	EQU	$-2
	ADD	A,E		; Add LSB
	LD	E,A		; Put in E
	JR	NC,ADD1		; If no overflow, ahead
	INC	D		; Increment MSB if so
ADD1	EX	DE,HL
	LD	(ADHL),HL	; Save HL
RX26	EQU	$-2
	OR	A
	SBC	HL,BC		; Is it too high?
	LD	HL,$-$		; Restore HL
ADHL	EQU	$-2
	EX	DE,HL
	JR	C,ADD4		; If not, ahead
ADDERR	LD	D,B		; Transfer BC to DE
	LD	E,C
	DEC	DE		; Back one
	JR	ADD4		; Skip subtract
ADD2	ADD	A,E		; Add LSB
	LD	E,A		; Put in E
	JR	C,ADD4		; If no underflow, ahead
	XOR	A		; Zero A
	OR	D		; Is D zero?
	JR	NZ,ADD3		; If not, skip
	LD	DE,0100H	; Allow for subtract
ADD3	DEC	D		; Decrement one
ADD4	LD	(HL),D		; Put DE at (HL)
	DEC	HL
	LD	(HL),E
	RET	
FBYTE	LD	(HL),10101010B	; Reprime counter
	LD	C,A		; Store A
	LD	(BUTTONS),A	; Store buttons
RX27	EQU	$-2
	RLCA			; Rotate Y7 and Y6
	RLCA			; into position
	RLCA
	RLCA
	AND	11000000B	; Mask out rest
	LD	(YINC),A	; Put in memory
RX28	EQU	$-2
	LD	A,C		; Restore first byte
	RRCA			; Rotate X7 and X6
	RRCA			; into position
	AND	11000000B	; Mask out rest
	LD	(XINC),A	; Put in memory
RX29	EQU	$-2
	RET
INTC	DB	10101010B
MODEND	EQU	$-1
LENGTH	EQU	$-MOUSE
RELTAB	DW	RX01,RX02,RX03,RX04,RX05,RX06,RX07,RX08
	DW	RX09,RX10,RX11,RX12,RX13,RX14,RX15,RX16
	DW	RX17,RX18,RX19,RX20,RX21,RX22,RX23,RX24
	DW	RX25,RX26,RX27,RX28,RX29
	DW	0
	END	BEGIN
