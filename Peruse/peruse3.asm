;===
; LDOS Model 3 assembly file
; April 9, 1995
;===
	COM	'<Copyright (c) 1997 by Matthew Reed, all rights reserved>'
TRUE	EQU	-1
FALSE	EQU	0
MOD4	EQU	FALSE
MOD3	EQU	TRUE
; Set LDOS and TRSDOS 1.3 equates
	IFDEF	TRSDOS
LDOS	EQU	FALSE
XFILES	EQU	2		; Can be 2 wide
	ELSE
TRSDOS	EQU	FALSE
LDOS	EQU	TRUE
XFILES	EQU	1		; Must be only 1 wide
	ENDIF
; Model 3 specific equates
RVIDEO	EQU	FALSE
XMAX	EQU	64		; 64 wide
YMAX	EQU	16		; 16 deep
LONGHEX	EQU	FALSE
CHKMRK	EQU	'*'		; Check mark
; Keyboard equates
KLEFT	EQU	8
KRIGHT	EQU	9
KUP	EQU	91
KDOWN	EQU	10
KENTER	EQU	13
KSPACE	EQU	32
KBREAK	EQU	1
KSUP	EQU	27
KSDOWN	EQU	26
KCUP	EQU	219
KCDOWN	EQU	138
KCTLV	EQU	22
KCTLC	EQU	3
KCTLS	EQU	19
KCTLR	EQU	18
; Macros
SVC	MACRO	#NUM
	CALL	#NUM
	ENDM
;
RPOP	MACRO	#P1,#P2,#P3,#P4,#P5,#P6
	POP	#P1
	IFGT	%%,1
	POP	#P2
	ENDIF
	IFGT	%%,2
	POP	#P3
	ENDIF
	IFGT	%%,3
	POP	#P4
	ENDIF
	IFGT	%%,4
	POP	#P5
	ENDIF
	IFGT	%%,5
	POP	#P6
	ENDIF
	ENDM
;
RPUSH	MACRO	#P1,#P2,#P3,#P4,#P5,#P6
	PUSH	#P1
	IFGT	%%,1
	PUSH	#P2
	ENDIF
	IFGT	%%,2
	PUSH	#P3
	ENDIF
	IFGT	%%,3
	PUSH	#P4
	ENDIF
	IFGT	%%,4
	PUSH	#P5
	ENDIF
	IFGT	%%,5
	PUSH	#P6
	ENDIF
	ENDM
	ORG	5300H		; Program start
STACK	EQU	5300H		; Allow 1 page of stack
;==
; Function equates
;==
@KBD	EQU	002BH
@OPEN	EQU	4424H
@REMOV	EQU	442CH
@READ	EQU	4436H
@CLS	EQU	01C9H
@DSP	EQU	0033H
;@KEY	EQU	0049H
@ERROR	EQU	4409H
@ABORT	EQU	4030H
@EXIT	EQU	402DH
@CLOSE	EQU	4428H
@FSPEC	EQU	441CH
@INIT	EQU	4420H
@WRITE	EQU	4439H
@BKSP	EQU	4445H
@POSN	EQU	4442H
@REW	EQU	443FH
;==
; Equates specific to LDOS
;==
	IF	LDOS
@DSPLY	EQU	021BH		; Actually TRS-DOS 1.3
@GTDCT	EQU	478FH
@RDSSC	EQU	4B45H
@DIRRD	EQU	4B10H
@DIRWR	EQU	4B1FH
;==
; Routines specific to LDOS
;==
; Check for EOF
@CKEOF:	JP	4458H		; Model 1, 444BH
MR6	EQU	$-2
; 8 bit divide
@DIV8:	LD	A,C
	JP	4B7AH		; Model 1, 4B7BH
MR5	EQU	$-2
; Check for BREAK key (and reset bit)
@CKBRKC:
	PUSH	HL
	LD	HL,429FH	; Model 1, 4423H
MR3	EQU	$-2
	BIT	7,(HL)		; Check BREAK bit
	RES	7,(HL)		; Turn off BREAK
	POP	HL
	RET
; Test drive for disk
@CKDRV:	JP	4209H		; Model 1, 44B8H
MR2	EQU	$-2
;==
; Routines specific to TRS-DOS 1.3
;==
	ELSE
@DSPLY	EQU	4467H		; Actually LDOS
TSBUFF	DS	256		; System buffer (on page boundary)
;--
; Read directory entry
; Entry: B = DEC, C = drive
; Exit: HL = buffer, DE is destroyed
;--
@DIRRD:	CALL	$CALCADD
	PUSH	HL
	LD	D,17
	SVC	@RDSSC
	POP	HL
	RET
;--
; Write directory entry
; Entry: B = DEC, C = drive
; Exit: DE is destroyed
;--
@DIRWR:	CALL	$CALCADD
	PUSH	HL
	LD	D,17		; Directory track
	SVC	@WRSSC		; Write sector
	POP	HL
	RET
; Calculate proper HL
$CALCADD:
	PUSH	BC
	LD	E,B		; DEC value
	LD	C,5
	SVC	@DIV8		; Divide by 5
	POP	BC
	ADD	A,2		; Calculate needed sector
	LD	D,A		; Store (temporarily)
	LD	A,E
	ADD	A,A		; * 2
	ADD	A,A		; * 4
	ADD	A,A		; * 8
	ADD	A,A		; * 16
	LD	E,A
	ADD	A,A		; * 32
	ADD	A,E		; * 48
	LD	L,A		; Low order
	LD	E,D		; Swap bytes
	LD	HL,TSBUFF	; System buffer
	RET
; 8 bit divide
@DIV8:	PUSH	BC
	LD	B,8
	XOR	A
$DE1:	SLA	E
	RLA
	CP	C
	JR	C,$DE2
	SUB	C
	INC	E
$DE2:	DJNZ	$DE1
	LD	C,A
	LD	A,E
	LD	E,C
	POP	BC
	RET
; Check for the end of file
@CKEOF:	RPUSH	HL,DE,IX
	PUSH	DE
	POP	IX
	LD	L,(IX+12)	; ERN
	LD	H,(IX+13)
	LD	E,(IX+10)	; NRN
	LD	D,(IX+11)
	XOR	A
	INC	HL
	SBC	HL,DE
	RPOP	IX,DE,HL
	JR	NZ,$CKZ
	OR	1CH		; Make error
	RET
$CKZ:	XOR	A		; If not same, OK
	RET
; Read system sector
@RDSSC:	LD	D,17		; Track number
	RPUSH	HL,DE,BC
	INC	E		; Correct sector
	CALL	4675H		; Read sector
	RPOP	BC,DE,HL
	RET
; Write system sector
@WRSSC:	LD	D,17		; Directory track
	RPUSH	HL,DE,BC
	INC	E		; Correct sector
	CALL	45F7H		; Write sector
	RPOP	BC,DE,HL
	RET
; Check for BREAK key
@CKBRKC:
	CALL	@KBD		; Poll keyboard
	CP	KBREAK
	JR	Z,$YT78
	XOR	A
	RET
$YT78:	OR	1
	RET
; Check drive for mounted disk
@CKDRV:	JP	4C75H
	ENDIF
;==
; LDOS and TRS-DOS 1.3 emulated routines
;==
; Obtain HIGH$
@HIGH$:	LD	HL,(4411H)	; Model 1, 4049H
MR4	EQU	$-2
	RET
; Multiply 16 bit number
@MUL16:	JP	444EH		; Model 1, 44C1H
MR1	EQU	$-2
;--
; Convert DE to hex ASCII (HEX16)
; Entry: DE = value
;  HL = pointer to 4 character buffer
; Exit: HL points to end of buffer + 1
;--
@HEX16:	LD	A,D		; MSB
	CALL	@HEX8A		; Convert
	LD	A,E
; Falls into @HEX8
;--
; Convert C to hex ASCII (HEX8)
; Entry: C = value
;  HL = pointer to 2 character buffer
; Exit: HL points to end of buffer + 1
;--
@HEX8:	LD	A,C		; Move to A
@HEX8A:	PUSH	AF		; Left 4 bits
	RRA
	RRA
	RRA
	RRA
	CALL	$HDSP		; Display left 4
	POP	AF		; Display right 4
$HDSP:	AND	0FH
	ADD	A,90H
	DAA
	ADC	A,40H
	DAA
	LD	(HL),A
	INC	HL
	RET
;--
; Convert HL to decimal ASCII (HEXDEC)
; Entry: HL = value
;  DE = pointer to 5 character buffer
; Exit: DE points to end of buffer + 1
;--
@HEXDEC:
	LD	B,5		; Maximum length
	LD	A,32		; Space
$HXD1:	LD	(DE),A		; Fill with spaces
	INC	DE
	DJNZ	$HXD1		; Loop until done
	PUSH	DE
	DEC	DE
$HXD2:	LD	A,10		; Divide by 10
	CALL	4451H		; Model 1, 44C4H
MR7	EQU	$-2
	ADD	A,'0'		; Make into ASCII
	LD	(DE),A		; Store
	DEC	DE
	LD	A,H		; Anything left?
	OR	L
	JR	NZ,$HXD2	; Loop if not
	POP	DE
	RET
;--
; See which DOS
; Z if TRS-DOS 1.3
;--
CKDOS:	LD	A,(125H)
	CP	'I'
	RET	NZ		; NZ if Model 1
	LD	A,(4400H)
	CP	0F5H
	RET			; NZ if LDOS
;--
; Convert Model 3 references to Model 1
;--
	IF	LDOS
CMOD1:	LD	A,(125H)	; Model 1 check
	CP	'I'
	RET	Z		; Return if not Model 1
	PUSH	HL
	LD	HL,44C1H	; @MUL16
	LD	(MR1),HL
	LD	HL,44B8H	; @CKDRV
	LD	(MR2),HL
	LD	HL,4423H	; @CKBRKC bits
	LD	(MR3),HL
	LD	HL,4049H	; @HIGH$ pointer
	LD	(MR4),HL
	LD	HL,447BH	; @DIV8
	LD	(MR5),HL
	LD	HL,444BH	; @CKEOF
	LD	(MR6),HL
	LD	HL,44C4H	; @DIV16
	LD	(MR7),HL
	POP	HL
	OR	1
	RET
	ENDIF
;--
; Turn password checking off
;--
PASSOFF:
	RPUSH	HL,DE,BC
; TRS-DOS 1.3 code
	IF	TRSDOS
	LD	A,82H		; Select useless function
	CALL	PRST
	LD	A,18H
	LD	(4ED4H),A
	LD	HL,(5035H)	; Should be LD A,(DE)
	CP	1AH
	JR	NZ,$ZXCASD
	LD	(HL),0AFH	; XOR A (LRL = 256)
	LD	A,11H
	LD	(503FH),A
$ZXCASD:
	ELSE
; LDOS code
	LD	A,8<4.OR.2+2	; Select non-existent function
	CALL	PRST		; Load overlay
	LD	HL,4E00H	; Start of overlay
	LD	BC,51FFH-4E00H	; Length of overlay region
; Search for first byte
$PSSL1:	LD	DE,PCS
	LD	A,(DE)		; "LD HL, nn"
	INC	DE
	CPIR
	JP	PO,$PSEND	; End reached (already disabled?)
; Now search for further bytes
$PSSL0:	LD	A,(DE)		; Next byte
	INC	DE
	OR	A		; If zero, end reached
	JR	Z,$PSSL3
	CPI			; Is this byte?
	JP	PO,$PSEND
	JR	NZ,$PSSL1	; Loop if not equal
	JR	$PSSL0		; Loop if equal
; Matching bytes found
$PSSL3:	DEC	HL
	XOR	A		; Blank out with NOPs
	LD	(HL),A
	DEC	HL
	LD	(HL),A
	ENDIF
$PSEND:	RPOP	BC,DE,HL
	RET
; Segment of code to search for
PCS	LD	HL,113DH	; Blank password
	XOR	A
	SBC	HL,DE
	NOP
PCSL	EQU	$-PCS		; Length of segment
PRST:	RST	28H
DOSM$	DB	'PERUSE version 1.0, (c) 1995 by Matthew Reed',0AH
	IF	TRSDOS
	DB	'This program requires TRS-DOS 1.3!',0DH
	ELSE
	DB	'This program requires LDOS 5.X!',0DH
	ENDIF
;--
; Exit routine
;--
EXIT:	LD	A,'_'		; Underline
OLDCURS	EQU	$-1
	LD	(401DH+5),A	; Restore cursor
	CALL	@CLS
EXIT1:	CALL	@CKBRKC		; Toggle BREAK bit
	LD	HL,0		; No error
	CALL	@EXIT
;--
; Start program
;--
START:	LD	SP,STACK	; New stack
	CALL	CKDOS
	IF	TRSDOS
	JR	Z,DSKIP
	ELSE
	JR	NZ,DSKIP
	ENDIF
	LD	HL,DOSM$	; Display error message
	CALL	@DSPLY
	JP	EXIT1
; Check for Model 1 only if LDOS
DSKIP:
	IF	LDOS
	CALL	CMOD1		; Convert to Model 1
	ENDIF
	LD	A,(401DH+5)	; Cursor character
	LD	(OLDCURS),A	; Store value
	LD	A,'_'		; Underscore
	LD	(401DH+5),A	; Set it to that
*GET PRDIR			; Onto main program
