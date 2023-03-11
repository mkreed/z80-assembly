;===
; UUDECODE, version 1.0
; copyright (c) 1997, by Matthew Reed
; all rights reserved
;===
*GET EQUATES
	COM	'<Copyright (c) 1997 by Matthew Reed, all rights reserved>'
	ORG	3100H
; Set stack and check for BREAK key
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
; Open file to read
	LD	DE,FCB1		; FCB
	LD	HL,BUFF1	; Disk buffer
	LD	B,0		; LRL = 256
; Signal open only read-only
	SVC	@FLAGS$
	SET	0,(IY+'S'-'A')
	SVC	@OPEN		; Open file
	JP	NZ,DERR		; Ahead if error
	LD	A,1
	LD	(_FILNUM),A	; Signal first file open
; Display decoding message
	LD	HL,DECODE$
	SVC	@DSPLY
; Register percentage
	LD	A,(FCB1+12)	; MSB
	DEC	A
	LD	H,A
	LD	A,(FCB1+8)	; Byte offset
	LD	L,A
	CALL	RPERC		; Register percent
	LD	HL,0
	EXX			; Start percentage at zero
;--
; Main loop
;--
; Read file until "begin" found
_M1:	LD	HL,EBUFF	; Point to buffer
	CALL	READLN		; Read line into buffer
	LD	DE,BEGIN$
	CALL	STRCMP		; Compare the two strings
	JR	NZ,_M1		; Loop if not the same
	LD	A,1
	LD	(_BBLOCK),A	; Show that "begin" line found
; Locate filename
;  Locate access code
	LD	HL,EBUFF+6	; Go to access code
_M2:	LD	A,(HL)
	INC	HL
	CP	0DH		; End of line?
	JP	Z,IFBEGIN
	CP	32		; Skip past if present
	JR	Z,_M2		; Loop until gone
	DEC	HL
;  Now go past access code
_M3:	LD	A,(HL)
	INC	HL
	CP	0DH
	JP	Z,IFBEGIN
	CP	32
	JR	NZ,_M3		; Loop until numbers gone
;  Now skip spaces before filename
_M4:	LD	A,(HL)
	INC	HL
	CP	0DH
	JP	Z,IFBEGIN
	CP	32
	JR	Z,_M4
	DEC	HL
; Now process filename
	LD	DE,WRTFIL$
	CALL	CFLDOS
	LD	HL,WRTFIL$
	LD	DE,FCB2
	SVC	@FSPEC
	JR	Z,_LH1
_LH0:	CALL	NEWFILE
	LD	HL,WRTFIL$
	LD	DE,FCB2
	SVC	@FSPEC
	JR	NZ,_LH0
; Create second file
_LH1:	LD	DE,FCB2		; FCB
	LD	HL,BUFF2	; Disk buffer
	LD	B,0		; LRL = 256
	SVC	@INIT		; Create file
	JR	Z,_LH2
	CP	19
	JR	Z,_LH0
	CP	32
	JR	Z,_LH0
	JP	DERR
; Display message
_LH2:	LD	HL,WRT$
	SVC	@DSPLY
	LD	HL,DECODE$
	SVC	@DSPLY
	EXX
	CALL	DPERC		; Display percent again
	EXX
; Main processing loop
; Read line
_LO0:	LD	HL,EBUFF
	CALL	READLN		; Read into buffer
; See if end of file
	LD	DE,END$
	CALL	STRCMP		; Is it the end?
	JR	Z,CLOSE		; File successfully ended
; Not end, process normally
;  Load length byte
	LD	A,(HL)
	INC	HL
	SUB	32		; Is it too low?
	JP	C,IUUE
	CP	64		; Is it too high?
	JP	NC,IUUE
	LD	B,A		; Store length in B
; Read rest of line
	INC	B		; Is length already 0?
	DEC	B
	JR	Z,_LO0
; Read byte #1
_LO1:	CALL	GTBYTE
	SUB	32		; Subtract offset
	RLCA			; Rotate into place
	RLCA
	AND	11111100B	; Mask out suspicious bits
	LD	C,A		; Set aside
; Read byte #2
	CALL	GTBYTE
	SUB	32		; Subtract offset
	RLCA			; Rotate into place
	RLCA
	RLCA
	RLCA
	PUSH	AF
	AND	00000011B
	OR	C		; Complete byte
	CALL	PUT		; Save byte #1
	POP	AF
	DEC	B		; Is length 0?
	JR	Z,_LO0
	AND	11110000B	; Mask out bits
	LD	C,A		; Set aside for later
; Read byte #3
	CALL	GTBYTE
	SUB	32		; Subtract offset
	RRCA			; Rotate into place
	RRCA
	PUSH	AF
	AND	00001111B
	OR	C
	CALL	PUT		; Save byte #2
	POP	AF
	DEC	B		; Is length 0?
	JR	Z,_LO0
	AND	11000000B
	LD	C,A		; Put aside for later
; Read byte #4
	CALL	GTBYTE
	SUB	32		; Subtract offset
	OR	C		; Merge together
	CALL	PUT		; Save byte #3
	DEC	B		; Is length 0?
	JR	Z,_LO0
; Loop until line is over
	JR	_LO1
;--
; Get byte at HL, return space if end of line encountered
;--
GTBYTE:	LD	A,(HL)		; Load first byte
	INC	HL
	CP	0DH		; Is it ENTER?
	RET	NZ
	LD	A,32		; Force space if so
	RET
;===
; Close open file
CLOSE:	LD	DE,FCB2
	SVC	@CLOSE
	CALL	DDPERC		; Display done message
	JP	EXIT
; Display BREAK message
BRKENDD:
	LD	DE,FCB2
	SVC	@REMOV
	LD	HL,BREAK0$
	SVC	@DSPLY
BRKEND:	LD	HL,BREAK$
	SVC	@DSPLY
	JR	EXIT
; Display syntax message
SYNTAX:	LD	HL,SYNTAX$
	SVC	@DSPLY
	RET
; Display end or begin errors
NFEITHER:
	LD	A,0
_BBLOCK	EQU	$-1
	OR	A
	LD	HL,NFBEG$	; Never found begin
	JR	Z,_NF1
; CLOSE open file
	LD	DE,FCB2
	SVC	@CLOSE
	LD	HL,NFEND$	; Never found end
_NF1:	SVC	@DSPLY
	JP	EXIT
; Display illegal UUENCODE file message
IUUE:	LD	DE,FCB2
	SVC	@REMOV		; Remove partially completed file
	LD	HL,IUUE$
	SVC	@DSPLY
	JP	EXIT
; Too many bytes on line
TMBOL:	LD	DE,FCB2
	SVC	@REMOV
	LD	HL,TMBOL$
	SVC	@DSPLY
	JP	EXIT
; Display illegal filename in begin block
IFBEGIN:
	LD	HL,IFBEG$
	SVC	@DSPLY
	JP	EXIT
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
	SVC	@DSPLY
	JP	EXIT
_DZ0:	SVC	@DSPLY
; Display syntax
SYN:	CALL	SYNTAX		; Display syntax message
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
	LD	HL,NFEITHER
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
; Compare two strings
; Entry: HL = string in buffer
;  DE = null terminated string
;--
STRCMP:	RPUSH	HL,DE
_ST0:	LD	A,(DE)		; Is it end?
	OR	A
	JR	Z,_ST1		; It does match
	CP	(HL)		; Does it match
	JR	NZ,_ST1
	INC	HL
	INC	DE
	JR	_ST0		; Loop until end of match
_ST1:	RPOP	DE,HL
	RET
;--
; Prompt for new filename
;--
NEWFILE:
	RPUSH	HL,DE,BC,AF
	LD	HL,NEWF$
	SVC	@DSPLY
; ((( Not sure ))
	LD	HL,WRTFIL$
	LD	B,14
	LD	C,32
	SVC	@KEYIN
	JP	C,BRKEND	; End if BREAK key pressed
; (( Should check BREAK key ))
	LD	C,15
	SVC	@DSP
	RPOP	AF,BC,DE,HL
	RET
NEWF$	DB	29,'Output filename is illegal',0AH
	DB	14,'Type in a new filename: ',3
;--
; Convert UNIX filename to LS-DOS
; Entry: DE = FCB, HL = start of filename
;--
CFLDOS:	PUSH	DE
	PUSH	HL
_C1:	LD	A,(HL)
	INC	HL
; ((
; Should uppercase (or lowercase?)
; ))
	CP	'.'		; Delimitter?
	JR	Z,_C3
	CP	32		; End of filename?
	JR	C,_C2
_C10:	LD	(DE),A		; Otherwise, store it
	INC	DE
	JR	_C1		; Loop until done
; End of filename
_C2:	LD	A,0DH
	LD	(DE),A		; End of UNIX filename
	POP	HL
	POP	DE
	RET
; Extension delimiter
_C3:	LD	A,'/'		; Change to slash
	JR	_C10
;--
; Read line from disk
; Entry: HL = buffer
;--
READLN:
	RPUSH	HL,BC
; Skip possible CR, LF, etc.
_R0:	CALL	GET
	JP	NZ,_R80		; Empty line
	CP	0DH+1
	JR	C,_R0		; Loop until gone
; Load into buffer
	LD	B,EBLEN
_R1:	LD	(HL),A		; Store in memory
	INC	HL
	CP	0DH		; If CR, end
	JR	Z,_R9
	CP	0AH		; If LF, end
	JR	Z,_R8
	CALL	GET		; Get new byte
	JR	NZ,_R80		; End of line
	DJNZ	_R1
; Too many bytes on line
	JP	TMBOL
; End of line
_R8:	DEC	HL
_R80:	LD	(HL),0DH	; Make it CR in memory
_R9:	RPOP	BC,HL
	RET
;==
; Data area
;==
PBUFF	DB	'00000%',03H
DONE$	DB	'Done',0DH
OPEN$	DB	15,'UUDECODE 1.0',0AH
	DB	' copyright (c) 1997 by Matthew Reed',0AH
	DB	' all rights reserved',0AH,0DH
BREAK$	DB	29,'Terminated due to BREAK key',0DH
BREAK0$	DB	'terminated',0DH
TMBOL$	DB	29,'Too many bytes on line',0DH
FNF$	DB	'Input file not found',0DH
ILIN$	DB	'Illegal input filename',0DH
ILOUT$	DB	29,'Illegal output filename',0DH
NFBEG$	DB	29,'"begin" block not found!',0DH
NFEND$	DB	29,'"end" block not found!',0DH
IUUE$	DB	29,'Improperly constructed UUENCODE file!',0DH
IFBEG$	DB	29,'Illegal filename in begin block!',0DH
SYNTAX$	DB	'Syntax: UUDECODE <input file>',0DH
DECODE$	DB	'Decoding: ',03H
BEGIN$	DB	'begin ',0
END$	DB	'end',0
WRT$	DB	29,'Writing: '
WRTFIL$	DB	0DH
	DS	60
FCB1	DS	32
FCB2	DS	32
BUFF2	DS	256
BUFF1	DS	256
EBLEN	EQU	128
EBUFF	DS	EBLEN
	END	START
