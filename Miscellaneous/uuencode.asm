;===
; UUENCODE, version 1.0
; copyright (c) 1997, by Matthew Reed
; all rights reserved
;===
*GET EQUATES
	COM	'<Copyright (c) 1997 by Matthew Reed, all rights reserved>'
	ORG	3100H
; Set stack and clear BREAK bit
START:	LD	SP,START
	SVC	@CKBRKC
	JP	NZ,BRKEND
; Display opener
	PUSH	HL		; Save HL
	LD	HL,OPEN$
	SVC	@DSPLY
	POP	HL
; See if end of line
	LD	A,(HL)
	CP	0DH
	JP	Z,SYN		; Display syntax message
; Put filespec in read FCB
	LD	DE,FCB1		; FCB
	SVC	@FSPEC		; File to read
	LD	A,13H
	JP	NZ,DERR		; Ahead if error
	CALL	CFUNIX		; Convert file to UNIX format
; Put filespec in write FCB
	LD	A,1		; Signal second file
	LD	(_FILNUM),A
	LD	DE,FCB2		; FCB
	SVC	@FSPEC		; File to write to
	LD	A,13H
	JP	NZ,DERR
; Open file to read
	LD	DE,FCB1		; FCB
	LD	HL,BUFF1	; Disk buffer
	LD	B,0		; LRL = 256
; Signal open only read-only
	SVC	@FLAGS$
	SET	0,(IY+'S'-'A')
	SVC	@OPEN		; Open file
	JP	NZ,DERR		; Ahead if error
; Register percentage
	LD	A,(FCB1+12)	; MSB
	DEC	A
	LD	H,A
	LD	A,(FCB1+8)	; Byte offset
	LD	L,A
	CALL	RPERC		; Register percent
	LD	HL,0
	EXX			; Start percentage at zero
; Create second file
	LD	DE,FCB2		; FCB
	LD	HL,BUFF2	; Disk buffer
	LD	B,0		; LRL = 256
	SVC	@INIT		; Create file
	JP	NZ,DERR
; Display encoding message
	LD	HL,ENCODE$	; Display encoding string
	SVC	@DSPLY
; Write begin-line
	LD	HL,BEGIN$
	CALL	WRITELN
;
_LH00:	SVC	@CKBRKC
	JP	NZ,BRKENDD	; End and delete file
	LD	HL,EBUFF	; Buffer
	LD	B,45		; Maximum of 45 bytes
_LH0:	PUSH	BC
	CALL	GET
	POP	BC
	JR	NZ,_LH01
	LD	(HL),A		; Store in buffer
	INC	HL
	DJNZ	_LH0
; All read in, now write out
_LH01:	LD	A,'M'		; Normal length byte
	SUB	B
	CALL	PUT		; Write it
	LD	A,45
	SUB	B
	LD	B,A
	LD	HL,EBUFF	; Start of buffer
; Save registers
_LH1:	PUSH	BC
; Read in three bytes
	LD	C,(HL)		; First byte
	INC	HL
	LD	D,(HL)		; Second byte
	INC	HL
	LD	E,(HL)		; Third byte
	INC	HL
; Rotate bottom two bits out
	RRC	C
	RRC	C
; Mask out and add 32 to current
	LD	A,C
	AND	00111111B
	ADD	A,32
	CALL	PUT
; Rotate and mask for next
	LD	A,C
	RRC	A		; Rotate two more bits to match
	RRC	A
	AND	00110000B	; Mask out rest
	LD	C,A
; Rotate bottom four bits out
	RRC	D
	RRC	D
	RRC	D
	RRC	D
; Mask out, combine, and add 32
	LD	A,D
	AND	00001111B
	OR	C
	ADD	A,32
	CALL	PUT
; Rotate and mask for next
	LD	A,D
	RRC	A
	RRC	A
	AND	00111100B
	LD	D,A
; Rotate top two bits around
	RLC	E
	RLC	E
; Mask out, combine, and add 32
	LD	A,E
	AND	00000011B
	OR	D
	ADD	A,32
	CALL	PUT
; Do final byte
	RRC	E
	RRC	E
	LD	A,E
	AND	00111111B
	ADD	A,32		; Make it printable
	CALL	PUT
; Restore registers
	POP	BC
	LD	A,B
	SUB	3
	LD	B,A
	JR	Z,_LH2
	JR	NC,_LH1		; Loop until done
_LH2:	CALL	PUTEOL		; Save end of line
	JR	_LH00		; Loop until done
; Write end-line
CLOSE:	LD	HL,END$
	CALL	WRITELN
; Close file and exit
	LD	DE,FCB2
	SVC	@CLOSE
	CALL	DDPERC		; Display done message
	JP	EXIT
; Display syntax message
SYNTAX:	LD	HL,SYNTAX$
	SVC	@DSPLY
	RET
; Display disk error and remove partial file
DERRD:	PUSH	AF
	LD	DE,FCB2
	SVC	@REMOV		; Delete it
	POP	AF
; Display disk errors
DERR:	CP	13H		; Illegal filename?
	JR	Z,_DZ0A
	CP	18H		; "File not found"?
	JR	NZ,_DZ1
	LD	HL,FNF$
	SVC	@DSPLY		; Do not display syntax message
	JR	EXIT
_DZ0A:	LD	HL,ILIN$	; "Illegal input filename"?
	LD	A,0
_FILNUM	EQU	$-1
	OR	A
	JR	Z,_DZ0
	LD	HL,ILOUT$	; "Illegal output filename"?
_DZ0:	SVC	@DSPLY
; Display syntax
SYN:	CALL	SYNTAX		; Display syntax message
	JR	EXIT
; Display BREAK message
BRKENDD:
	LD	DE,FCB2
	SVC	@REMOV
	LD	HL,BREAK0$
	SVC	@DSPLY
BRKEND:	LD	HL,BREAK$
	SVC	@DSPLY
	JR	EXIT
_DZ1:	CALL	DSPERR		; Display error and exit
; Exit from program
EXIT:	SVC	@EXIT
; Display error message
DSPERR:	LD	C,A		; Put in C
	PUSH	BC
	LD	C,29		; Erase line
	SVC	@DSP
	POP	BC
	SET	6,C		; Limited error
	SVC	@ERROR		; Exit the system
	RET
;---
; Get character
; NZ if error
;---
GET:	PUSH	DE		; Save DE
	LD	DE,FCB1		; FCB
	SVC	@GET
	POP	DE
	PUSH	AF
	EXX
	INC	L		; Increase position
	JR	NZ,_P1
	INC	H
	CALL	DPERC		; Display percentage message
_P1:	EXX
	POP	AF
	RET	Z		; Return if no error
; See if end of file
	CP	28		; "End of file encountered"?
	JR	Z,_P2
	CP	29		; "Record number out of range"?
	JP	NZ,DERRD	; Disk error if none of these
_P2:	LD	A,0C3H
	LD	(GET),A
	PUSH	HL
	LD	HL,CLOSE
	LD	(GET+1),HL
	POP	HL
	OR	1		; Force NZ
	RET
;---
; Put character
; NZ if error
;---
PUT:	RPUSH	BC,DE		; Save BC
	LD	C,A		; Put in C
	LD	DE,FCB2		; Second FCB
	SVC	@PUT
	RPOP	DE,BC		; Restore registers
	JP	NZ,DERRD
	RET
;---
; Register percent
; HL => maximum tick value
;---
RPERC	LD	C,100		; Divide by 100
	SVC	@DIV16
	LD	(PDIV),HL	; Store in routine
	RET
;---
; Display percent
; HL => tick value
;---
DPERC:	RPUSH	DE,BC,HL,AF	; Save registers
	LD	DE,$-$		; Divisor value
PDIV	EQU	$-2
	XOR	A		; Zero A
DPLOOP	INC	A
; Reset carry not needed
	SBC	HL,DE		; Subtract divisor
	JP	NC,DPLOOP	; Loop until done
	DEC	A		; Correct value
	PUSH	AF		; Save value
	LD	B,4		; Get cursor position
	SVC	@VDCTL
	POP	AF		; Restore value
	PUSH	HL		; Save cursor
	LD	H,0		; Put A in HL
	LD	L,A
	LD	DE,PBUFF	; Buffer
	SVC	@HEXDEC		; Generate percent
	LD	HL,PBUFF	; Go to third digit
DPL0	INC	HL
	LD	A,(HL)		; See if space
	CP	32
	JP	Z,DPL0		; Loop until done space
	SVC	@DSPLY		; Display string
	POP	HL		; Restore cursor position
	LD	B,3
	SVC	@VDCTL
	RPOP	AF,HL,BC,DE	; Restore registers
	RET
;---
; Display done message
;---
DDPERC	LD	HL,DONE$	; Display done message
	SVC	@DSPLY
	RET
;--
; Convert filename to UNIX format
; Entry: DE = FCB
;--
CFUNIX:	PUSH	DE
	PUSH	HL
	LD	HL,BUNIX	; Beginning of UNIX filename
_C1:	LD	A,(DE)
	INC	DE
	CP	'/'		; Slash?
	JR	Z,_C3
	CP	'.'		; Password?
	JR	Z,_C2
	CP	':'		; Drive specifier?
	JR	Z,_C2
	CP	32		; End of filename?
	JR	C,_C2
;(((
; Should also lowercase filename
;)))
_C10:	LD	(HL),A		; Otherwise, store it
	INC	HL
	JR	_C1		; Loop until done
; End of filename
_C2:	LD	(HL),0		; End of UNIX filename
	POP	HL
	POP	DE
	RET
; Extension delimiter
_C3:	LD	A,'.'		; Change to period
	JR	_C10
;--
; Write line to disk
; Entry: HL = start of string
;--
WRITELN:
	PUSH	HL
_W1:	LD	A,(HL)
	INC	HL
	OR	A
	JR	Z,_W2
	CALL	PUT
	JR	_W1
_W2:	CALL	PUTEOL
	POP	HL
	RET
;--
; Write end of line
;--
PUTEOL	LD	A,0DH
	CALL	PUT
	LD	A,0AH
	CALL	PUT
	RET
;==
; Data area
;==
PBUFF	DB	'00000%',03H
DONE$	DB	'Done',0DH
OPEN$	DB	15,'UUENCODE 1.0',0AH
	DB	' copyright (c) 1997 by Matthew Reed',0AH
	DB	' all rights reserved',0AH,0DH
FNF$	DB	'Input file not found',0DH
ILIN$	DB	'Illegal input filename',0DH
ILOUT$	DB	'Illegal output filename',0DH
BREAK0$	DB	'terminated',0DH
BREAK$	DB	'Premature exit due to BREAK key',0DH
SYNTAX$	DB	'Syntax: UUENCODE <input file> <output file>',0DH
ENCODE$	DB	'Encoding: ',03H
BEGIN$	DB	'begin 666 '
BUNIX	DB	'FILENAME.EXT',0
END$	DB	32,0DH,0AH,'end',0
FCB1	DS	32
FCB2	DS	32
BUFF2	DS	256
BUFF1	DS	256
EBUFF	DS	50
	END	START
