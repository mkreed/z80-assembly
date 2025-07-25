;=====================================
; DATA-MINDER database manager
; copyright (c) 1995, by Matthew Reed
; all rights reserved
; DMHELP/ASM, help displayer
;=====================================
	ORG	$-1<-8+1<8
FBUFF	DS	256
HUFFTBL	DS	256
DIR	DS	256
XREF	DS	256
;UKEYB	DB	0
;	DS	256
FCBH	DS	32
TMSSG$	DB	'SHIFT F1 - INDEX       '
	DB	'SHIFT F2 - HELP on HELP       '
	DB	'SHIFT F3 - HELP on KEYBOARD'
HKEYB	DB	0
;---
; Display help topic
; A => topic number
;---
DHELP	LD	(HSTACK),SP	; Store stack
	PUSH	AF
	LD	A,(CSTATE)
	LD	(CSTATE1),A
	CALL	SSCRN		; Save screen
	CALL	CBL		; Clear bottom line
	LD	C,15		; Turn cursor off
	SVC	@DSP
	LD	A,(FPFLAG)
	LD	(HSFP),A
	XOR	A
	LD	(FPFLAG),A
	CALL	DINFO		; Display information
	LD	HL,HELP$	; Help message
	CALL	DMB		; Display message bar
	LD	A,0		; See if loaded
$HLPL	EQU	$-1
	OR	A
	JR	NZ,$DHLP1	; Ahead if loaded
	CALL	HLPLD		; Load information
; Do not take out
;	LD	A,1
;	LD	($HLPL),A	; Signal loaded
$DHLP1	POP	AF		; Restore topic
; Main loop
DHELPL	PUSH	AF
	CALL	CSCRN		; Clear screen
	LD	HL,TMSSG$	; Display message
	LD	DE,SCRN
	LD	BC,COL
	LDIR
	LD	HL,SCRN+COL	; Display dashes
	INC	DE
	LD	(HL),'-'
	LD	BC,COL-1
	LDIR
	POP	AF
	LD	HL,XREF		; Initialize
	LD	(XREFP),HL
; Put screen on stack
	LD	HL,COL*2+SCRN
	PUSH	HL
; Position to entry
	LD	HL,DIR		; DIR
	ADD	A,A		; Multiply x 2
	INC	A		; Find MSB
	LD	L,A
	LD	C,(HL)		; Put in BC
	LD	B,0
	LD	DE,FCBH		; FCB
	SVC	@POSN		; Position to record
	JP	NZ,HLPERR
	DEC	HL
	LD	B,(HL)		; Get LSB
	CALL	RSECT		; Read sector
	JP	NZ,HLPERR
	LD	L,B		; Put in LSB
; Read entry
	CALL	GETB		; Get byte
	INC	B		; Increment (8 bits in byte)
	LD	DE,HUFFTBL	; Huffman code table
HDC0	DEC	B
	CALL	Z,GETB		; Get byte if all out
	RL	C		; Rotate bit out
	JP	NC,HDC1		; Ahead if 0
	INC	E		; Next byte
HDC1	LD	A,(DE)		; Get byte
	BIT	7,A		; See if byte or count
	JP	NZ,HDBYTE	; Ahead if byte
	ADD	A,E		; Otherwise, add count
	LD	E,A
	JR	HDC0		; Loop
HDBYTE	RES	7,A
	CP	'\'		; See if end
	JP	Z,HEND		; Exit if end
	CP	']'		; See if ending bracket
	JR	Z,EBRACK
	CP	'['		; See if beginning bracket
	JR	Z,BBRACK
	CP	'{'		; See if braces
	JR	Z,BRACE
	CP	'}'
	JR	Z,BRACE
; Write byte to screen
WBS	EX	(SP),HL		; Get screen
	LD	DE,8		; Tabs of 8
	CP	9
	JR	Z,HDB00		; Ahead if tab
	CP	0DH		; See if CR
	JR	NZ,HDB1
	LD	DE,COL
HDB00	CALL	HMOD		; MOD 80
	JR	HDB2
HDB1	LD	(HL),A
	INC	HL
;$$$$
	LD	A,'}'		; Turned off
BRACEC	EQU	$-1
	CP	'{'		; See if on
	JR	NZ,HDB2		; Ahead if not
	PUSH	HL
	LD	DE,79		; Move to next line
	ADD	HL,DE
	LD	(HL),'-'	; Display dash
	POP	HL
;$$$$
HDB2	EX	(SP),HL		; Save again
	LD	DE,HUFFTBL	; Reset DE
	JP	HDC0		; Loop
GETB	LD	A,(HL)		; Get byte
	INC	L
	CALL	Z,RSECT		; Read sector if needed
	LD	C,A		; Put in C
	LD	B,8		; Initialize B
	RET
; Ending bracket
EBRACK	LD	DE,0700H	; Seven bits
EBR1	DEC	B
	CALL	Z,GETB		; Get byte if all out
	RL	C		; Rotate bit out
	RL	E		; Into E
	DEC	D		; See if end
	JR	NZ,EBR1
; Save byte at XREF
	LD	A,E		; Get byte
	LD	DE,XREF		; Cross-reference
XREFP	EQU	$-2
	LD	(DE),A
	INC	DE
	LD	(XREFP),DE
	LD	A,']'		; Bracket
	JP	WBS		; Write byte to screen
; Beginning bracket
BBRACK	LD	DE,(XREFP)	; Cross-reference
	EX	(SP),HL
	PUSH	BC
	CALL	CADXY		; Convert to X, Y
	EX	DE,HL
	LD	(HL),B
	INC	HL
	LD	(HL),C
	INC	HL
	LD	(XREFP),HL	; Store address
	EX	DE,HL
	POP	BC
	EX	(SP),HL
	LD	A,'['		; Bracket
	JP	WBS		; Write to screen
BRACE	LD	(BRACEC),A	; Store braces
	LD	DE,HUFFTBL	; Reset table
	JP	HDC0
; Display cross-reference links
HEND	POP	HL		; Restore stack
	LD	HL,(XREFP)
	LD	(HL),0FFH
	LD	HL,XREF		; Start of XREF
	LD	(XREFP),HL
HEND1	LD	HL,(XREFP)
	LD	A,(HL)		; See if end
	CP	0FFH
	JR	Z,HEKEY		; To key if so
	CALL	HDCR		; Reverse first option
; Get key
HEKEY	CALL	DSCRN1		; Display screen
HELOOP	CALL	MSKEY		; Get keypress
	PUSH	AF
	LD	HL,(XREFP)
	PUSH	HL
	CALL	HDCR		; Eliminate reverse
	POP	HL
	POP	AF
	LD	HL,(XREFP)
	CP	0DH		; <ENTER>
	JP	Z,HENTER
	CP	128		; <BREAK>
	JP	Z,HBREAK
;;;
	CP	28		; <CONTROL> <?>
	JR	Z,HSF0
	CP	91H		; <SHIFT> <F1>
	JR	Z,HSF1
	CP	92H		; <SHIFT> <F2>
	JR	Z,HSF1
	CP	93H		; <SHIFT> <F3>
	JR	Z,HSF3
	CP	11		; <UP>
	JR	Z,HUARR
	CP	8		; <LEFT>
	JR	Z,HLARR
	CP	27		; <SHIFT> <UP>
	JP	Z,HSUARR
	LD	C,A
	LD	A,(HL)		; Loop if at end
	INC	A
	JR	Z,HELOOP
	LD	A,C
	CP	32		; SPACEBAR
	JR	Z,HRARR
	CP	9		; <RIGHT>
	JR	Z,HRARR
	CP	10		; <DOWN>
	JR	Z,HDARR
	CP	26		; <SHIFT> <DOWN>
	JR	Z,HSDARR
	LD	HL,(XREFP)
	CALL	HDCR
	JR	HELOOP		; Loop until done
HENTER	LD	A,(HL)		; See if end
	INC	A
	JR	Z,HEND1		; Loop if empty
	INC	HL
	INC	HL
	LD	A,(HL)		; Get topic
	JP	DHELPL		; Display help
HSF0	LD	A,(HTOPIC)
	JP	DHELPL
HSF1	SUB	91H		; Determine topic
	JP	DHELPL
; Special F3 handler
HSF3:	LD	A,(HKEYB)	; Special keyboard
	JP	DHELPL
HLARR	LD	A,L		; See if beginning
	OR	A
	JP	Z,HEND1
	DEC	HL		; Go to previous
	DEC	HL
	DEC	HL
	LD	(XREFP),HL
	JP	HEND1
HRARR	INC	HL
	INC	HL
	INC	HL
	LD	A,(HL)		; See if end
	INC	A
	JP	Z,HEND1		; Loop if so
	LD	(XREFP),HL
	JP	HEND1		; Loop
HDARR	LD	B,(HL)		; Get X and Y
	INC	HL
	LD	C,(HL)
HDARR0	INC	HL
	INC	HL
	LD	A,(HL)		; See if last entry
	INC	HL
	CP	0FFH
	JP	Z,HEND1		; Jump back if done
	CP	B
	JR	Z,HDARR0	; Loop if equal
	LD	A,(HL)		; Get X
	CP	C		; See if less
	JR	C,HDARR0	; Loop if less
	DEC	HL
	LD	(XREFP),HL
	JP	HEND1
HUARR	LD	B,(HL)		; Get X and Y
	INC	L
	LD	C,(HL)
	INC	C
HUARR0	DEC	L
	JP	Z,HEND1		; Jump back if beginning
	DEC	HL
	DEC	HL
	DEC	HL
	LD	A,(HL)		; Get Y
	INC	L
	CP	B
	JR	Z,HUARR0	; Loop if equal
	LD	A,(HL)		; Get X
	CP	C		; See if more
	JR	NC,HUARR0	; Loop if more
	DEC	HL
	LD	(XREFP),HL
	JP	HEND1
HSUARR	LD	L,0		; Move to beginning
	LD	(XREFP),HL
	JP	HEND1
HSDARR	INC	HL
	LD	A,(HL)		; See if end
	INC	A
	JR	NZ,HSDARR	; Loop until done
	DEC	HL
	DEC	HL
	DEC	HL
	LD	(XREFP),HL
	JP	HEND1
; Ending conditions
HLPFERR	LD	A,249		; Help file not found
	JR	HLPE1
HLPERR	LD	A,253		; Help error
HLPE1	PUSH	AF
	CALL	RSCRN
	POP	AF
	CALL	DOSERR
HBREAK	LD	A,0
CSTATE1	EQU	$-1		; Cursor state
	CALL	CURS
	CALL	RSCRN		; Restore screen
	LD	A,0
HSFP	EQU	$-1
	LD	(FPFLAG),A
	CALL	DSCRN		; Display screen
	LD	SP,$-$		; Address of stack
HSTACK	EQU	$-2
	RET
; Display cross reference
HDCR:	LD	A,(HL)		; See if at end
	LD	B,A
	INC	A
	RET	Z		; Return if end
	INC	HL
	LD	C,(HL)		; Get X and Y
	CALL	CXY		; Put address in HL
HDCR1	INC	HL		; Go past bracket
	LD	A,(HL)		; See if end
	CP	']'
	RET	Z
	XOR	10000000B	; Reverse the state
	LD	(HL),A
	JR	HDCR1		; Loop until done
;---
HMOD	PUSH	HL		; Save address
	PUSH	DE
	LD	DE,SCRN		; Find distance
	OR	A
	SBC	HL,DE
	POP	DE
	OR	A
HDB0	SBC	HL,DE
	JR	NC,HDB0
	ADD	HL,DE
	EX	DE,HL
	OR	A
	SBC	HL,DE
	EX	DE,HL
	POP	HL
	ADD	HL,DE
	RET
HLPLD	LD	HL,HFILE$	; Help file name
	LD	DE,FCBH		; Help FCB
	SVC	@FSPEC		; Move to FCB
	LD	HL,DIR		; Directory (to begin with)
	LD	B,0		; LRL = 256
	SET	0,(IY+'S'-'A')	; Set FORCE-TO-READ flag
	SVC	@OPEN		; Open file
	JP	NZ,HLPFERR
	CALL	RSECT		; Read sector (DIR)
	LD	A,.HIGH.FBUFF	; Change to file buffer
	LD	(FCBH+4),A
	CALL	RSECT		; Read sector (Huffman table)
; Load Huffman table
	LD	DE,HUFFTBL	; Buffer to store Huffman table
	LD	C,2		; Start at two
HLPL0	LD	A,(HL)		; Get byte
	INC	L
	OR	A		; See if done
	RET	Z		; Return if end
	BIT	7,A		; See if count
	JR	Z,HLP01		; Ahead if so
; One byte
	LD	(DE),A		; Store in table
	INC	E
	DEC	C		; Subtract count
	JR	HLPL0		; Loop until done
; Series of counts
HLP01	LD	B,A		; Store in B
	LD	A,C		; Count
HLPL1	LD	(DE),A		; Store in buffer
	INC	E
	INC	A		; Next count
	DJNZ	HLPL1		; Loop until done
	LD	C,A		; Store new count
	JR	HLPL0		; Jump back
;---
; Read sector
;---
RSECT	RPUSH	AF,BC,DE	; Save registers
	LD	DE,FCBH		; FCB for file
	SVC	@READ		; Read a sector
	JP	NZ,HLPERR
RRE	LD	HL,FBUFF	; Start of buffer
	RPOP	DE,BC,AF	; Restore registers
	RET
