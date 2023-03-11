;===
; Clock setting utility
; For use with TRS-80 Model 4 emulator
;
;===
	COM	'<Copyright (c) 1998 by Matthew Reed, all rights reserved>'
*GET EQUATES
@EXIT3		EQU	402DH		; DOS return entry
@DSPLY3		EQU	4467H		; Display message
@TRSDSPLY	EQU	021BH		; TRS-DOS 1.3 display message
	ORG	5200H
START:
; Determine model and DOS
	LD	IX,MODEL
	LD	(IX+0),0		; Assume Model 1/3
	PUSH	HL
	LD	HL,(0009H)		; Bytes after RST 8H
	XOR	A
	LD	DE,4000H
	SBC	HL,DE			; Is it 4000H?
	JR	Z,$DM0			; If Model 1/3
	INC	(IX+0)
	LD	A,(0000H)		; Is it DOSPLUS 4?
	CP	0C9H
	JR	Z,$DM0			; If DOSPLUS 4
	INC	(IX+0)
	LD	HL,(0009H)		; Is it MULTIDOS 80/64?
	XOR	A
	LD	DE,0BEE3H
	SBC	HL,DE
	JR	Z,$DM0
	INC	(IX+0)			; It is LS-DOS
$DM0:	POP	HL
; Parse parameters
	CALL	PARAM			; Parse parameters
	JP	NZ,PARMERR
	CP	0C9H			; Was it "QUIET"?
	JR	NZ,$CS0
	LD	(DSPLY),A		; Turn off message if QUIET
; Set real-time clock
$CS0:	LD	HL,0
	DB	0EDH,0FEH		; CLOCK instruction
	LD	A,H			; See if anything happened
	OR	L
	JR	Z,$CS1			; Nothing did
	CALL	SETTIME			; Set date and time buffers
	LD	HL,OPENER$		; Success
	CALL	DSPLY
	LD	HL,SUCCESS$
	CALL	DSPLY
	JP	EXIT
$CS1:	LD	HL,OPENER$		; Emulator not running
	CALL	DSPLY1
	LD	HL,FAILURE$
	CALL	DSPLY1
	JP	EXIT
PARMERR:
	LD	HL,OPENER$		; Parameter error
	CALL	DSPLY1
	LD	HL,PARMERR$
	CALL	DSPLY1
	JP	EXIT
; Set date and time buffers
SETTIME:
	LD	A,(IX+0)
	OR	A			; Is it Model 1/3?
	JR	Z,$M13
	DEC	A			; Is it DOSPLUS 4?
	JR	Z,$MD4
	DEC	A			; Is it MULTIDOS 4?
	JR	Z,$MM4
; It is LS-DOS
	LD	(002DH),HL		; Store seconds, minutes
	LD	A,E
	LD	(002FH),A		; Store hours
	LD	A,D
	LD	(0033H),A		; Store year
	LD	(0034H),BC		; Store month, day
	RET
; Model 4 DOSPLUS
$MD4:	LD	(00A4H),HL		; Store seconds, minutes
	LD	(00A6H),DE		; Store hours, year
	LD	(00A8H),BC		; Store month, day
	RET
; Model 1
$M13:	LD	A,(125H)
	CP	'I'
	JR	Z,$MM4			; Go if Model 3
	CALL	YRCORRECT		; Correct year
	LD	(4041H),HL		; Store seconds, minutes
	LD	(4043H),DE		; Store hours, year
	LD	(4045H),BC		; Store month, day
	RET
; Model 4 MULTIDOS and Model 3
$MM4:	CALL	YRCORRECT		; Correct year
	LD	(4217H),HL		; Store seconds, minutes
	LD	(4219H),DE		; Store hours, year
	LD	(421BH),BC		; Store month, day
	RET
; Correct year if over 2000
YRCORRECT:
	LD	A,D			; Is value over 100?
	CP	100
	RET	C			; Return if not
	SUB	100			; Correct if so
	LD	D,A
	RET
;
EXIT:	LD	A,(MODEL)
	CP	3			; LS-DOS
	JR	Z,$E4
	CP	1			; DOSPLUS 4
	JR	Z,$E4
	JP	@EXIT3
$E4:	SVC	@EXIT
;
DSPLY:	NOP
DSPLY1:	LD	A,(MODEL)
	CP	3			; LS-DOS
	JR	Z,$D4
	CP	1			; DOSPLUS 4
	JR	Z,$D4
	CP	2			; MULTIDOS 4
	JR	Z,$D3
	CALL	CKDOS
	JP	Z,@TRSDSPLY
$D3:	JP	@DSPLY3
$D4:	SVC	@DSPLY
	RET
;
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
; PARAM routine
;--
PARAM:	LD	A,(HL)		; Skip past spaces
	INC	HL
	CP	0DH		; Exit if end of line
	RET	Z
	CP	32		; Skip any spaces
	JR	Z,PARAM
	CP	'('		; Is it start of parameters?
	RET	NZ		; Exit if error
	LD	A,(HL)
	AND	0DFH		; Uppercase character
	CP	'Q'		; Is it "Q"?
	RET	NZ		; Error if not
	LD	A,0C9H
	RET
; 0 if Model 1/3, 1 if DOSPLUS 4, 2 if MULTIDOS 80/64, 3 if LS-DOS
MODEL		DB	0
; Messages
OPENER$		DB	'Model 4 emulator clock'
		DB	' setting utility',0AH
		DB	'copyright (c) 1998 by Matthew Reed,'
		DB	' all rights reserved',0AH,0DH
SUCCESS$	DB	'The TRS-80 time is now set to the MS-DOS clock.',0DH
FAILURE$	DB	'The Model 4 emulator is not running!',0DH
PARMERR$	DB	'Parameter error!',0DH
;
	END	START
