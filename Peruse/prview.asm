;===
; File viewer module
; copyright (c) 1995 by Matthew Reed
;===
;--
; Counts number of checked files
; Exit: A = number
;--
CFILES:	RPUSH	HL,DE,BC
	XOR	A
	LD	(O1FILE),A	; Zero storage
	LD	C,A		; Counter
	LD	DE,DELEN	; Entry length
	LD	HL,BUFFER	; Start of filenames
$CF5:	LD	A,(HL)		; Is it end?
	INC	A
	JR	Z,$CF7		; Ahead if end
	BIT	7,A		; Is it checked?
	JR	Z,$CF51
	INC	C		; Add to check number
$CF51:	ADD	HL,DE		; Go to next
	JR	$CF5		; Loop
$CF7:	LD	A,C		; Counter
	RPOP	BC,DE,HL
	OR	A
	RET
;--
; Find checked file
; Exit: if NZ, FCB contains filename
;  if Z, no more files
;--
FCFILE:
	PUSH	HL
	LD	HL,0		; Signal no error in check
	LD	(CKERR),HL
	POP	HL
	SVC	@CKBRKC		; See if BREAK
	JR	Z,$FCI9
	XOR	A		; Say no more files
	RET
$FCI9:	RPUSH	DE,BC
	LD	A,0		; See if any
O1FILE	EQU	$-1
	OR	A
	JR	Z,$FCI90	; Skip this if any
	DEC	A
	PUSH	AF
	XOR	A
	LD	(O1FILE),A	; Write over it
	POP	AF
	CALL	DIR_FDE		; Find selected file
	JR	$FCF4		; Treat it as marked
$FCI90:	LD	DE,DELEN	; Length
	LD	HL,BUFFER
$FCF3:	LD	A,(HL)		; Is it end?
	INC	A
	JR	Z,$FCF5		; Ahead if end
	BIT	7,A		; Is it checked?
	JR	NZ,$FCF4	; Ahead if checked
	ADD	HL,DE		; Move to next
	JR	$FCF3		; Loop until done
; Found checked file
$FCF4:	RES	7,(HL)		; Eliminate check
	LD	(CKERR),HL
	CALL	RFSPEC		; Move to FCB
	OR	1		; Make NZ
$FCF5:	RPOP	BC,DE
	RET
;--
; Puts filename in FCB
; Entry: HL points to directory entry
; Exit: FCB contains filename with drive #
;--
RFSPEC2:
	PUSH	HL
	CALL	DIR_FDE
	INC	HL
	INC	HL
	JR	$FSPC1
RFSPEC:
	PUSH	HL
	INC	HL
	INC	HL
	LD	DE,FCB
$FSPC1:	LD	A,(HL)		; Get byte
	CP	32		; Is it space?
	JR	Z,$FSPC2
	CP	'+'
	JR	Z,$FSPC2	; Or MOD flag
	LD	(DE),A
	INC	DE
	INC	HL
	JR	$FSPC1		; Loop
$FSPC2:	LD	A,':'		; Colon
	LD	(DE),A		; Store
	INC	DE
	LD	A,(DRIVE)	; Drive number
	ADD	A,'0'		; Make into number
	LD	(DE),A
	INC	DE
	LD	A,0DH		; Terminator
	LD	(DE),A
	POP	HL
	RET
;--
; View file
;--
VIEWER:	XOR	A
	LD	(FORCEV),A
VIEWENT:
; Clear screen and turn reverse off
	SVC	@CLS
	CALL	DSP_RVOFF
	LD	A,(FNUM)	; Put HL to directory entry
	CALL	DIR_FDE
	CALL	RFSPEC		; Move to FCB
; See if HEX forced
	LD	A,0
FORCEV	EQU	$-1
	OR	A		; Anything?
	JR	Z,$XZCV		; Do automatic check
	DEC	A		; Is it text? (1)
	JR	Z,TXTFORCE
	DEC	A		; Is it HR? (2)
	JR	Z,HRFORCE
	DEC	A		; Is it BAS? (3)
	JR	Z,BASFORCE
	DEC	A		; Is it C? (4)
	JR	Z,CFORCE
	JR	HEXFORCE	; Otherwise, force HEX
$XZCV:	INC	HL		; Move past checks, DEC
	INC	HL
; Move past filename
$VR5:	LD	A,(HL)
	INC	HL
	CP	'/'
	JR	NZ,$VR5		; Loop until done
	LD	($REWQ),HL
	LD	DE,EXT$
; Compare the extensions
$VR50:	LD	B,3		; Count down 3
$VR6:	LD	A,(DE)
	CP	(HL)
	INC	HL
	INC	DE
	JR	NZ,$VR7		; Skip if not
	DJNZ	$VR6		; Loop until done
	JR	$VR71		; Jump to routine
; Does not match
$VR7:	INC	DE
	DJNZ	$VR7		; Add on rest
	INC	DE		; Go past
	LD	HL,$-$
$REWQ	EQU	$-2
	LD	A,(DE)		; See if end
	OR	A
	JR	NZ,$VR50	; Loop if not
	INC	DE
; Set up everything
$VR71:	EX	DE,HL
	LD	A,(HL)		; LSB
	INC	HL
	LD	H,(HL)		; MSB
	LD	L,A
; Open file
$VR79:	PUSH	HL		; Save routine address
; Only if Model 4
;  (no equivalent for Model 3)
	IF	MOD4
	SVC	@FLAGS$		; Set IY to FLAGS$
	SET	0,(IY+'S'-'A')	; Set FORCE-TO-READ flag
	ENDIF
;
	LD	HL,FBUFF	; File buffer
	LD	DE,FCB		; FCB for file
	LD	B,0		; LRL = 256 (no blocking)
	CALL	PASSOFF
	SVC	@OPEN		; Open file
	JR	NZ,$ZXERR
	SVC	@CKEOF		; Is it at end already?
	RET	Z		; To routine if no error
	LD	A,(FCB+5)	; Is there any offset?
	OR	A
	RET	NZ		; Jump if not end
	JP	DIR_KEY		; Redisplay
$ZXERR:	CP	24		; Is it file not found?
	JP	Z,DNVAL		; Reload directory if so
	CALL	ERROR		; Otherwise, display error
	JP	DIR_KEY		;  and redisplay
BASFORCE:
	LD	HL,BSTART
	JR	$VR79
HEXFORCE:
	LD	HL,HEXSTART
	JR	$VR79
TXTFORCE:
	LD	HL,TXTSTART
	JR	$VR79
HRFORCE:
	LD	HL,HRSTART
	JR	$VR79
CFORCE:
	LD	HL,CSTART
	JR	$VR79
EXT$	DB	'HR '		; high resolution file
	DW	HRSTART
; Model 4 only (only HR allowed)
	IF	MOD4
	DB	'SHR'		; super-crunched file
	DW	HRSTART
	DB	'CHR'		; crunched file
	DW	HRSTART
	ENDIF
	DB	'CMD'		; program file
	DW	HEXSTART
	DB	'CIM'		; program file
	DW	HEXSTART
	DB	'REL'		; relocatible file
	DW	HEXSTART
	DB	'LIB'		; library file
	DW	HEXSTART
	DB	'IRL'		; library file
	DW	HEXSTART
	DB	'SYS'		; system file
	DW	HEXSTART
	DB	'ARC'		; Archived files
	DW	HEXSTART
	DB	'ZIP'		; Zipped files
	DW	HEXSTART
	DB	'C  '		; Small C file
	DW	CSTART
	DB	'CCC'		; PRO-MC file
	DW	CSTART
	DB	'BAS'		; Model 3 or 4 BASIC file
	DW	BSTART
	DB	0
	DW	TXTSTART	; default to hexadecimal viewer
; Space for more
	DW	TXTSTART
	DB	'   '
	DW	TXTSTART
	DB	'   '
	DW	TXTSTART
	DB	0
	DW	HEXSTART
;--
; Viewer exit routine
;--
VIEW_EXIT:
	SVC	@CLS		; Clear screen
;****
; Only in Model 3 mode
;	IF	MOD3
;	LD	DE,FCB
;	SVC	@CLOSE		; Close the file
; Ignore any errors
;	ENDIF
;
	JP	DIR_KEY		; Restore stack
;---
; Clear graphics screen
;---
GCLS:	LD	A,01000000B	; Graphics off, increment Y
	OUT	(GCTL),A
	LD	HL,0000H	; Start of display
	LD	C,XMAX		; 80 columns to clear
CLOOP0	LD	A,H		; Get column
	OUT	(GX),A
	LD	A,L		; Get row
	OUT	(GY),A
	LD	B,YMAX*2	; 240 rows clear
	XOR	A		; Blank space
CLOOP1	OUT	(GRW),A		; Clear byte
	OUT	(GRW),A
	OUT	(GRW),A
	OUT	(GRW),A
	OUT	(GRW),A
	DJNZ	CLOOP1		; Loop until column done
	DEC	C		; Are all columns done?
	JR	Z,GCEND		; End if so
	INC	H		; Next column
	LD	L,0		; Start of column
	JR	CLOOP0		; Loop until done
GCEND	LD	A,01000001B	; Graphics on, increment Y
	OUT	(GCTL),A
	RET
;====
; /HR, /CHR, and /SHR loader
; copyright (c) 1995, by Matthew Reed
; all rights reserved
;====
GX	EQU	128		; X register
GY	EQU	129		; Y register
GRW	EQU	130		; Read/write data register
GCTL	EQU	131		; Control register
; Initialize
HRSTART:
	JP	$T55		; Dummy jump
ZLOADER	EQU	$-2
$T55:	LD	A,6		; HR force HEX
	LD	(FORCEV),A
	LD	A,255		; Reset end of sectors
	LD	(ENDSECT),A
	LD	(STACK2),SP
; Initialize graphics registers
	XOR	A
	LD	(RSECT),A	; Enable routine
; Set up alternate registers
	EXX
; Model specific
	IF	MOD4
	LD	HL,50F0H	; X = 80, Y = 240
	ELSE
	LD	HL,40A0H	; X = 64, Y = 160
	ENDIF
	EXX
; Initialize file
; Open file
; Enable screen
	CALL	GCLS		; Clear the screen
	XOR	A
	OUT	(GX),A		; Reset X
	OUT	(GY),A		; Reset Y
	LD	A,10110011B	; Enable screen with
	OUT	(GCTL),A	; X increment after writes
; See if /HR, or /CHR and /SHR
	LD	A,(FCB+9)	; LRL (must be 0)
	LD	B,A
	LD	A,(FCB+13)	; MSB of ERN
	OR	B		; Both must be zero
	LD	B,A
	LD	A,(FCB+8)	; EOF offset
	CP	255		; Skip if 255
	JR	NZ,$FFD1
	XOR	A
$FFD1:	OR	B
; Special Model 3 (/CHR and /SHR not allowed)
	IF	MOD3
	JP	NZ,HEXSTART	; /CHR and /SHR not allowed
	ELSE
	JP	NZ,SSTART	; Ahead if not
	ENDIF
	LD	A,(FCB+12)	; LSB of ERN
	IF	TRSDOS
	DEC	A
	ENDIF
	CP	YMAX*XMAX*10/256
				; MUST be 75
; Special Model 3
	IF	MOD3
	JP	NZ,HEXSTART	; /CHR and /SHR not allowed
	ELSE
	JP	NZ,SSTART	; Ahead if not
	ENDIF
; Start to read /HR file
HSTART	CALL	RSECT		; Read sector
	LD	HL,FBUFF	; Start of data
	LD	C,0		; Start of 240 down
HST1	XOR	A		; Set X and Y
	OUT	(GX),A
	LD	A,C
	OUT	(GY),A
	LD	B,XMAX		; 80 across
HST2	LD	A,(HL)		; Get byte
	OUT	(GRW),A		; Send out byte
	INC	L		; Next byte
	CALL	Z,NXTPG		; If past, read sector
	DJNZ	HST2		; Loop until done
	INC	C		; Next line
	LD	A,C
	CP	YMAX*10		; Is it end?
	JP	Z,STOP		; Stop if so
	JR	HST1		; Loop until done
; Model 4 specific
	IF	MOD4
; Start to read /CHR or /SHR file
SSTART	CALL	RSECT		; Read sectors
SSTART1	LD	A,(HL)		; Get byte
	INC	L		; Next byte
	CALL	Z,NXTPG		; Ahead if possible end
	BIT	7,A		; Is it count or repeat?
	JR	NZ,SRPT		; Ahead if repeat
SCOUNT	LD	B,A		; Count in B
SCOUNT1	LD	A,(HL)		; Get byte
	INC	L		; Next byte
	CALL	Z,NXTPG		; Ahead if possible end
	CALL	SBG		; Display byte
	DJNZ	SCOUNT1		; Loop until done
	JR	SSTART1		; Start next sequence
SRPT	AND	01111111B	; Mask out repeat bit
	LD	B,A		; Put in B
	LD	A,(HL)		; Get byte
	INC	L		; Next byte
	CALL	Z,NXTPG		; Ahead if possible end
SRPT1	CALL	SBG		; Display byte
	DJNZ	SRPT1		; Loop until done
	JR	SSTART1		; Start next sequence
	ENDIF
;---
; Go to next page
;---
NXTPG	PUSH	AF		; Save AF
	LD	A,255		; End of file sector
ENDSECT	EQU	$-1
	CP	H		; Is it end?
	JR	Z,STOP		; Stop if so
	INC	H		; Ahead page
	LD	A,9+.HIGH.FBUFF
	CP	H		; Is it end?
	CALL	Z,RSECT		; If so, read sectors
	POP	AF		; Restore A
	RET			; Return
;---
; Read sectors
;---
RSECT:	NOP
	PUSH	BC		; Save BC
	LD	HL,FCB+4	; Disk file pointer (MSB)
	LD	(HL),.HIGH.FBUFF
				; Reset file buffer
	LD	DE,FCB		; FCB for file
	LD	B,9		; Sectors to read
ZHIMEM4	EQU	$-1
RSLOOP	SVC	@READ		; Read a sector
	JR	NZ,DSKERR	; If disk error
	INC	(HL)		; Advance buffer
	DJNZ	RSLOOP		; Loop until done
RRE	LD	HL,FBUFF	; Start of buffer
	POP	BC		; Restore BC
	RET
;---
; Disk error
;---
DSKERR	CP	28		; "End of file encountered"
	JR	Z,DSKE1		; Just ahead if so
	CP	29		; "Record number out of range"
	JR	NZ,DSKF		; Ahead if not
DSKE1	LD	A,0C9H		; Disable read routine
	LD	(RSECT),A
	LD	A,(HL)		; Get last sector
	LD	(ENDSECT),A	; Store value
	JR	RRE		; Loop back
; Fatal disk error
DSKF:	LD	L,A		; Store error in L
	XOR	A
	OUT	(GCTL),A	; Disable screen
	LD	A,L
	OR	A		; Signal error (NZ)
	JP	VIEW_EXIT	; Restore stack anyway
; End the program
STOP:
	CALL	KBD_GET		; Wait for key
	CP	KCTLV		; Is it CONTROL V?
	PUSH	AF
	XOR	A
	OUT	(GCTL),A	; Turn off display
	POP	AF
	LD	SP,$-$
STACK2	EQU	$-2
	JP	NZ,VIEW_EXIT	; Return if not CONTROL V
	JP	VIEWENT		; Other entry if so
;--
; Display graphics byte
; HL' = X, Y
;--
SBG:	EXX			; Switch registers
	OUT	(GRW),A		; Send byte
	DEC	H		; Decrement X count
	EXX			; Switch back
	RET	NZ		; Return if not end
	EXX			; Otherwise, switch back
	EX	AF,AF'		; Store A
	DEC	L		; Decrement Y count
	JR	Z,STOP		; If end, stop
	LD	H,XMAX		; Reset X count
	XOR	A		; Go to X beginning
	OUT	(GX),A
	LD	A,YMAX*10	; Create Y address
	SUB	L
	OUT	(GY),A		; Go to Y address
	EXX			; Switch registers
	EX	AF,AF'		; Restore A
	RET
;====
; Hexadecimal viewer
;====
	IF	LONGHEX
XHEX	EQU	74
	ELSE
XHEX	EQU	61
	ENDIF
; Choose correct viewer
HEX_VIEW:
	LD	A,(FORCEV)	; See if nothing
	OR	A
	JR	Z,HEXENT
	SUB	4		; Make into correct number
$TREW:	LD	(FORCEV),A
	JP	VIEWENT
HEXENT:	LD	A,1		; Force TEXT if no other
	JR	$TREW
HEXSTART:
	IF	LONGHEX
	LD	A,(FNUM)	; Selected filename
	LD	DE,FF$
	CALL	RFSPEC2		; Copy filename
	XOR	A
	LD	(DE),A		; Store terminator
	ENDIF
; Reset file pointer
	LD	HL,FBUFF
	LD	(FCB+3),HL
	JR	HEX_BEGIN	; Go to beginning
; File is already open, read first sector
HEX_READ:
	LD	DE,FCB
	SVC	@READ
	JR	Z,$ZR77		; If OK, skip
	CP	28		; End of file?
	JR	Z,$ZR77
	CP	29
	JP	NZ,HXERROR	; Error trapping
$ZR77:	LD	HL,FBUFF	; File buffer
	CALL	DISP_PAGE	; Display the page
; Interpret keystrokes
HEX_KLOOP:
	CALL	KBD_GET
	CP	';'		; Forward?
	JR	Z,HEX_PLUS
	CP	KUP
	JR	Z,HEX_MINUS
	CP	KDOWN
	JR	Z,HEX_PLUS
	CP	'-'		; Backward?
	JR	Z,HEX_MINUS
	CP	KBREAK
	JP	Z,VIEW_EXIT
	CP	KCTLV		; CONTROL V?
	JR	Z,HEX_VIEW
	OR	00100000B
	CP	'b'		; Beginning?
	JR	Z,HEX_BEGIN
	CP	'e'
	JR	Z,HEX_END	; End?
	JR	HEX_KLOOP
; Error routine
HXERROR:
	CALL	ERROR		; Display error
	JP	DIR_KEY
;--
; Move forward one sector
;--
HEX_PLUS:
	LD	HL,(FCB+10)	; See if too far
	LD	DE,(FCB+12)
	INC	DE
	OR	A
	SBC	HL,DE
	JR	Z,HEX_KLOOP	; Don't bother if at end
; Already is forward
	JR	HEX_READ	; Read the sector
;--
; Move back one sector
;--
HEX_MINUS:
	LD	HL,(FCB+10)	; At beginning?
	DEC	HL
	LD	A,H
	OR	L
	JR	Z,HEX_KLOOP	; Can't move before beginning
; Move backwards
	LD	DE,FCB
	SVC	@BKSP		; Move back sector
	JR	NZ,HXERROR
	SVC	@BKSP
	JR	NZ,HXERROR
	JR	HEX_READ	; Read new sector
;--
; Move to beginning
;--
HEX_BEGIN:
	LD	HL,(FCB+10)	; At beginning?
	DEC	HL
	LD	A,H
	OR	L
	JR	Z,HEX_KLOOP	; Don't bother if zero
	LD	DE,FCB
	SVC	@REW		; Move to beginning
	JR	NZ,HXERROR
	JR	HEX_READ
;--
; Move to end
;--
HEX_END:
	LD	HL,(FCB+10)	; See if too far
	LD	DE,(FCB+12)
	OR	A
	SBC	HL,DE
	JR	Z,HEX_KLOOP	; Don't bother if at end
; Go to end
	LD	B,D
	LD	C,E
	IFEQ	TRSDOS,FALSE
	DEC	BC
	ENDIF
	LD	DE,FCB
	SVC	@POSN		; Position to end
	JP	Z,HEX_READ
	CP	28		; EOF encountered
	JP	Z,HEX_READ
	CP	29		; End of file
	JR	NZ,HXERROR
	JP	HEX_READ
;---
; Display data page
;---
DISP_PAGE:
	RPUSH	HL,DE,BC
	LD	HL,FBUFF	; File buffer
	CALL	DSP_CLR		; Clear screen
	LD	DE,SCREEN	; Screen buffer
	IF	LONGHEX
	LD	A,188		; Extra large
	CALL	DISP_DASH
	ENDIF
	LD	B,16		; 16 lines
DP1:	RPUSH	BC,DE
	CALL	DISP_LINE	; Display line
	POP	DE
	EX	DE,HL
	LD	BC,XMAX
	ADD	HL,BC		; Add it on
	EX	DE,HL
	POP	BC
	DJNZ	DP1		; Loop
	IF	LONGHEX
	LD	A,131
	CALL	DISP_DASH
	ENDIF
; Convert record # to ASCII
	LD	DE,RECN$
	LD	HL,(FCB+10)	; Record number
	PUSH	HL
	DEC	HL		; Convert for display
	SVC	@HEXDEC		; Convert to decimal
; See if at last record
	POP	DE
	LD	HL,(FCB+12)	; Last record number
;()()()
	IF	TRSDOS
	INC	HL
	ENDIF
	OR	A
	SBC	HL,DE		; Compare
	JR	NZ,$NOEOF	; Skip if not same
; Display EOF number
	LD	A,(FCB+8)	; EOF #
	DEC	A		; Correct value
	LD	HL,EOFN$
	CALL	CBYTE		; Convert to number
	IF	LONGHEX
; Long display version
	LD	HL,18*XMAX+35+SCREEN
	LD	DE,EOF$
	CALL	DSP_PRINT	; Display a line
	ELSE
; Short display version
	LD	HL,XMAX*12+XHEX+SCREEN+1
	LD	BC,XMAX-1
	LD	DE,EOFN$
	LD	A,3		; Loop 3 bytes
$DE5:	PUSH	AF		; Save A
	LD	A,(DE)		; Get byte
	INC	DE
	LD	(HL),A		; Store
	INC	HL
	LD	(HL),170	; Vertical bar
	ADD	HL,BC
	POP	AF
	DEC	A
	JR	NZ,$DE5
; Display box
	LD	HL,XMAX*11+XHEX+SCREEN
	LD	A,131		; Horizontal bar (upper)
	LD	(HL),A		; Two bytes worth
	INC	HL
	LD	(HL),A
	INC	HL
	LD	(HL),171	; Corner piece
	LD	HL,XMAX*15+SCREEN+XHEX
	LD	A,176		; Horizontal bar (lower)
	LD	(HL),A		; Two bytes worth
	INC	HL
	LD	(HL),A
	INC	HL
	LD	(HL),186	; Corner piece
	LD	DE,XMAX*10+SCREEN+XHEX
	LD	HL,EOFM$
	LD	BC,3
	LDIR			; Move to display
	ENDIF
	IF	LONGHEX
; Long display version
$NOEOF:	LD	HL,18*XMAX+59+SCREEN
	LD	DE,RECORD$
	CALL	DSP_PRINT
	LD	HL,18*XMAX+1+SCREEN
	LD	DE,FIL$
	CALL	DSP_PRINT
	ELSE
; Short display version
$NOEOF:	LD	HL,XHEX+1+SCREEN+XMAX
	LD	BC,XMAX-1
	LD	DE,RECN$
	LD	A,5		; Loop 5 bytes
$DP5:	PUSH	AF		; Save A
	LD	A,(DE)		; Get byte
	INC	DE
	LD	(HL),A		; Store
	INC	HL
	LD	(HL),170	; Vertical bar
	ADD	HL,BC
	POP	AF
	DEC	A
	JR	NZ,$DP5
; Display box
	LD	HL,XHEX+SCREEN
	LD	A,131		; Horizontal bar (upper)
	LD	(HL),A		; Two bytes worth
	INC	HL
	LD	(HL),A
	INC	HL
	LD	(HL),171	; Corner piece
	LD	HL,XMAX*6+SCREEN+XHEX
	LD	A,176		; Horizontal bar (lower)
	LD	(HL),A		; Two bytes worth
	INC	HL
	LD	(HL),A
	INC	HL
	LD	(HL),186	; Corner piece
	LD	DE,XMAX*7+SCREEN+XHEX
	LD	HL,REC$
	LD	BC,3
	LDIR			; Move to display
	ENDIF
;
	CALL	DSP_PAINT	; Display screen
	RPOP	BC,DE,HL
	RET
EOF$	DB	'EOF offset: '
EOFN$	DB	'000',0
RECORD$	DB	'Record: '
RECN$	DB	'00001',0
FIL$	DB	'Filename: '
FF$	DB	'filename/ext:0 ',0
REC$	DB	'REC'
EOFM$	DB	'EOF'
;---
; Display character
; Entry: DE => buffer, A = character
;---
; Only used with LONGHEX
	IF	LONGHEX
DISP_DASH:
	EX	DE,HL
	PUSH	BC
	PUSH	HL
	LD	B,XHEX		; Width of display
DD1:	LD	(HL),A
	INC	HL
	DJNZ	DD1		; Loop until done
	POP	HL
	LD	BC,XMAX
	ADD	HL,BC
	EX	DE,HL
	POP	BC
	RET
	ENDIF
;---
; Display line
; HL => address
; DE => screen
;---
DISP_LINE:
	PUSH	BC
	LD	A,149
	LD	(DE),A
	INC	DE
	CALL	DL_CHAR		; Display characters
	CALL	DL_ADD		; Display address
	CALL	DL_NUMS		; Display numbers
	LD	A,170
	LD	(DE),A
	POP	BC
	RET
;---
; Display numbers
; HL => address
; DE => numbers
;---
DL_NUMS:
	PUSH	BC
	EX	DE,HL		; Switch
	LD	B,8		; Half of 16
DLN1:	LD	A,(DE)		; Get byte
	INC	DE
	LD	C,A
	SVC	@HEX8		; Convert
; Only if long display
	IF	LONGHEX
	INC	HL
	ENDIF
; Second byte
	LD	A,(DE)
	INC	DE
	LD	C,A
	SVC	@HEX8
	INC	HL
	DJNZ	DLN1		; Loop until done
	IF	LONGHEX
	ELSE
	DEC	HL		; Back the space
	ENDIF
	EX	DE,HL
	POP	BC
	RET
;---
; Display characters
; HL => address
; DE => screen
;---
DL_CHAR:
	RPUSH	HL,BC		; Save address
	LD	BC,16		; Transfer
	LDIR
	RPOP	BC,HL		; Restore address
	RET
;---
; Display address
; HL => address
; DE => screen
;---
DL_ADD:
	PUSH	BC
	EX	DE,HL		; Switch
	IF	LONGHEX
	INC	HL
	ENDIF
	LD	(HL),149	; Barrier
	INC	HL
	IF	LONGHEX
	INC	HL
	ENDIF
	LD	C,E		; LSB
	SVC	@HEX8		; Convert
	IF	LONGHEX
	INC	HL
	ENDIF
	LD	(HL),170	; Other barrier
	INC	HL
	IF	LONGHEX
	INC	HL
	ENDIF
	EX	DE,HL
	POP	BC
	RET
;===
; Basic loader
; Uses TXT_BGN, TXT_END, VMM_INIT
;===
BSTART:
; Just in case text needed
	LD	A,4		; Tabs = 4
	LD	(TABSTOP),A
	LD	A,5		; TEXT force HEX
	LD	(FORCEV),A
; Initialization
	XOR	A		; Turn on down arrow
	LD	($HGFD),A
	CALL	DSP_CLS
	CALL	VMM_INIT	; Initialize memory
; See if BASIC file
	LD	A,(DE)		; Is it FFH?
	INC	A
	JP	NZ,$Y78		; Go if not
	LD	(DE),A		; Makes things easier
; See if Model 3 file
	INC	DE		; Go to LSB
	INC	DE		; At MSB
	LD	A,(DE)		; MSB of program start
	CP	7EH		; Is it less than 7E?
	JP	NC,HEXSTART	; Go if Model 4
; Proper Model 3 file
	LD	A,7		; BAS force HEX
	LD	(FORCEV),A
	DEC	DE
	DEC	DE
; Display screen
$ZQWE0:	CALL	DSP_CLR		; Clear screen
	LD	HL,SCREEN	; Start of screen
	LD	C,YMAX		; Depth of screen
	LD	B,XMAX
$ZQWE:	CALL	BAS_DLINE
	JR	Z,NOMORE	; End of screen reached
	DEC	C
	JR	NZ,$ZQWE
; Store BASIC position (DE), screen position (HL), character count (B)
	LD	(BASPOS),DE
	LD	(SCRNPOS),HL
	LD	A,B
	LD	(CHARCNT),A
; Display screen and wait for key
$QWER:	CALL	DSP_PAINT
$QWEER:	CALL	KBD_GET
; Process keys
	CP	KBREAK
	JP	Z,VIEW_EXIT	; Exit the viewer
	CP	KCTLV		; Is it CONTROL V?
	JP	Z,VIEWENT	; Other viewer entry
	LD	B,A
	LD	A,0
$HGFD	EQU	$-1
	OR	A
	JR	NZ,$QWEER	; Loop if not allowed
	LD	A,B
	CP	KDOWN
	JR	Z,BAS_DOWN	; Move down by one
	JR	$QWEER
; Move down
BAS_DOWN:
; Scroll entire screen up
	LD	HL,SCREEN+XMAX
	LD	DE,SCREEN
	LD	BC,YMAX+1*XMAX
	LDIR
; Reset pointers
	LD	DE,$-$
BASPOS	EQU	$-2
	LD	HL,$-$
SCRNPOS	EQU	$-2
	LD	BC,XMAX
	OR	A
	SBC	HL,BC		; Move back one
	LD	B,0
CHARCNT	EQU	$-1
; Clear to end of screen
	RPUSH	HL,BC
$HJKL1:	LD	(HL),32
	INC	HL
	DJNZ	$HJKL1
	RPOP	BC,HL
	LD	C,1		; Only 1 line
	JR	$ZQWE
; No more down arrows allowed
NOMORE:	LD	A,1
	LD	($HGFD),A
	JR	$QWER
;==
; Convert 16 bit line number to left justified number
; Entry: DE = number
;  HL = screen
;==
CDEC16:
	EX	DE,HL
	PUSH	DE		; Save screen address
	LD	DE,R16BYT
	SVC	@HEXDEC		; Convert
	POP	HL		; Restore screen address
	LD	DE,R16BYT	; Buffer
	LD	B,XMAX		; Screen width
$OPOPO:	LD	A,(DE)		; Load byte
	INC	DE
	OR	A
	JR	Z,$OPI1		; Is at end
	CP	32		; Is it space?
	JR	Z,$OPOPO	; Loop if so
	LD	(HL),A		; Store on screen
	DEC	B
	INC	HL
	JR	$OPOPO		; Loop until done
$OPI1:	LD	(HL),32		; Extra space
	DEC	B
	INC	HL
	RET
R16BYT	DB	'12345',0
;==
; Handle quoted string
;==
$QUOTES:
	LD	A,(DE)		; Is it end?
	OR	A
	JP	Z,BAS_LENT
	LD	A,(DE)		; Load byte
	CALL	INCDE
	CP	0AH
	JP	Z,BAS_LENT	; ENTER if 0AH
	CP	'"'		; Or end quote?
	JR	NZ,$T5679
; Turn off quotes
	XOR	A
	LD	(ZQUOT),A
	LD	A,'"'		; Display quote
	JR	$T5679
;==
; Display BASIC line
; Entry: DE = codes
;  HL = screen
; Exit: one screen line displayed
;  Z if end of file
;==
BAS_DLINE:
	LD	A,(DE)		; See if at start of line
	OR	A
	JR	NZ,$DLL8
; Make sure not overflow from line
	LD	A,B
	CP	XMAX		; Is it it?
	JP	NZ,BAS_LENT	; Move to next line if not
; Display line number and such
	XOR	A
	LD	(ZQUOT),A	; Reset quote status
	CALL	INCDE		; Go past end of line token
	RET	Z
	CALL	INCDE		; Go past pointers
	RET	Z
	LD	A,(DE)		; See if MSB = 0
	OR	A
	RET	Z		; End if so
	CALL	INCDE
	RET	Z
	EX	DE,HL		; Swap
	LD	A,(HL)		; Move line number to DE
	CALL	INCHL
	PUSH	DE
	LD	D,(HL)
	LD	E,A
	EX	(SP),HL		; Bring screen from stack
	CALL	CDEC16		; Convert to decimal
	POP	DE		; Restore address
	CALL	INCDE
; Display line
$DLL8:	LD	A,0		; Is it in quotes?
ZQUOT	EQU	$-1
	CP	'"'
	JR	Z,$QUOTES
	LD	A,(DE)		; See if token
	OR	A		; Is it end?
	JR	Z,BAS_LENT
	CALL	INCDE
	RET	Z		; Return if at end
	CP	0AH		; Is it end of line?
	JR	Z,BAS_LENT
	BIT	7,A
	JR	NZ,$DLL9	; Go to token routine
	LD	(ZQUOT),A
; Check for "'" and "ELSE"
	CP	':'
	JR	NZ,$T5679	; Ahead if not
	LD	A,(DE)
	CP	93H		; "REM"
	JR	NZ,$BELSE	; Skip if not
	CALL	INCDE
	JR	Z,$RE45		; If error, treat as ":REM"
	LD	A,(DE)		; FBH
	CP	0FBH
	LD	A,27H		; "'"
	PUSH	AF
	CALL	INCDE		; Ignore any errors
	POP	AF
	JR	Z,$T5679	; Go if so
; Not a "'"
	DEC	DE
$RE45:	DEC	DE
	JR	$T5678		; Print colon
; Check for ELSE
$BELSE:	CP	149		; Is it "ELSE"?
	JR	Z,$DLL8		; Skip colon if so
$T5678:	LD	A,':'		; Print colon
$T5679:	LD	(HL),A		; Store on screen
	INC	HL
	DEC	B		; Decrease count
	JR	Z,BAS_LEND	; End of line
	JR	$DLL8		; Loop
; Display token
$DLL9:	PUSH	DE
	EX	DE,HL
	LD	HL,RMOD3	; Normal tokens
; Same for both
	RES	7,A		; Eliminate bit 7
	CALL	DTOK		; Display token
	EX	DE,HL
	POP	DE
	LD	A,B		; See if overflow
	OR	A
	JR	Z,BAS_LEND	; Only if exact match
	CP	XMAX		; See if overflow
	JR	C,$DLL8		; Loop if no overflow
;==
; Line end
; Exit with NZ
;==
BAS_LEND:
	LD	A,XMAX
	ADD	A,B		; Find correct count
	LD	B,A
	OR	H		; Ensure not zero
	RET
;==
; ENTER routine
; Exit with NZ
;==
BAS_LENT:
	PUSH	BC
	LD	C,B		; Store in C
	LD	B,0
	ADD	HL,BC		; Move to next line
	POP	BC
	LD	B,XMAX		; No overflow of line
	OR	H		; Make NZ
	RET
;==
; Move HL forward one byte
;==
INCHL:	EX	DE,HL
	CALL	INCDE
	EX	DE,HL
	RET
;==
; Move DE forward one byte
; Entry: DE = pointer
; Exit: NZ, DE = pointer
;  Z = no more text
;==
INCDE:	INC	DE
	PUSH	HL
	LD	HL,(XHIGH)	; Highest address
	OR	A
	SBC	HL,DE
	POP	HL
	RET	NZ
	PUSH	BC
	LD	B,A		; Save A
	CALL	TXT_END		; Load more if possible
	LD	A,B
	POP	BC
	RET
;==
; Display tokens
; Entry: HL = table
;  A = token
;  B = character count
;  DE = buffer to store
; Exit: DE = displayed token
;  B = new count (could be 81-255)
;==
DTOK:	INC	A		; Allow for 0
$DTOK1:	DEC	A		; Is it there?
	JR	Z,$DTDISP	; Display if so
; Move to next token
$MNOP:	BIT	7,(HL)		; Is it there?
	INC	HL
	JR	Z,$MNOP		; Loop until done
	JR	$DTOK1		; Jump back
; Display token
$DTDISP:
	DEC	B		; Decrease character count
	LD	A,(HL)		; Byte
	RES	7,A
	LD	(DE),A		; Store at DE
	BIT	7,(HL)		; See if end
	INC	DE
	INC	HL
	JR	Z,$DTDISP	; Loop until done
	RET
;==
; Initialize virtual memory
; Exit: DE points to start
;==
VMM_INIT:
	XOR	A
	LD	(XREOF),A
	LD	HL,0
	LD	(XLREC),HL	; Lowest record
	LD	(XHREC),HL	; For good measure
	LD	(ZOFFSET),HL	; Blank out
	LD	A,.HIGH.FBUFF	; Page to load into
	LD	(XMTEXT),A
; Read in 8 sectors (one screen page)
	CALL	RD8SEC
; At beginning of file
; Final page not end of file
; No EOF offset
	LD	DE,FBUFF
	RET
;==
; Alter DE if needed
;==
VMM_UDE:
	PUSH	AF
	PUSH	HL
	LD	HL,$-$		; Offset needed
ZOFFSET	EQU	$-2
	ADD	HL,DE
	EX	DE,HL		; Move to DE
	LD	HL,0
	LD	(ZOFFSET),HL	; Blank it out
	POP	HL
	POP	AF
	RET
;==
; Reset DE offset
;==
VMM_RDE:
	PUSH	HL
	LD	HL,0
	LD	(ZOFFSET),HL
	POP	HL
	RET
;===
; Text viewer
;===
CSTART:	LD	A,8
	LD	(FORCEV),A	; C force HEX
	LD	A,4		; Tabs = 4
	JR	$TYR
TXTSTART:
	LD	A,5		; TEXT force HEX
	LD	(FORCEV),A
	LD	A,8		; Tabs = 8
$TYR:	LD	(TABSTOP),A
; Initialize everything
	CALL	VMM_INIT
	LD	A,(DE)		; See if BAS
	INC	A
	JP	Z,BSTART
$Y78:	CALL	VMM_RDE
	PUSH	DE
	CALL	TXT_PAINT
	POP	DE
	CALL	VMM_UDE		; Update DE
	CALL	DSP_PAINT
;
	CALL	KBD_GET
	CP	KBREAK
	JP	Z,VIEW_EXIT	; Exit the viewer
	CP	KCTLV		; Is it CONTROL V?
	JP	Z,VIEWENT	; Other viewer entry
	CP	KDOWN
	JR	Z,TXT_DOWN
	CP	KUP
	JP	Z,TXT_UP
	CP	KSDOWN
	JR	Z,TXT_SD
	CP	KSUP
	JR	Z,TXT_SU
	CP	KCDOWN		; CLEAR DOWN?
	JR	Z,TXT_CD
	CP	KCUP		; CLEAR UP?
	JR	Z,TXT_CU
	JR	$Y78
;--
; Move to beginning of file
;--
TXT_CU:
	DEC	E		; Compare it
	INC	E
	CALL	Z,TXT_BGN	; At beginning?
	JR	Z,$Y78		; End if so
	DEC	DE
	JR	TXT_CU		; Loop until done
;--
; Move to end of file
;--
TXT_CD:
	CALL	INCDE		; Move to next
	JR	NZ,TXT_CD	; Loop until done
	JP	TXT_SU		; Move up screen
;--
; Move text down one screen
;--
TXT_SD:
	CALL	TXT_CSD		; Go down
	JR	$Y78		; and loop
TXT_CSD:
	LD	B,YMAX-1
$TXSD:	PUSH	BC
	CALL	TCL_DOWN	; Move down
	POP	BC
	DJNZ	$TXSD		; Loop until done
	RET
;--
; Move text down one screen
;--
TXT_SU:
	LD	B,YMAX-1
$TXSU:	PUSH	BC
	CALL	TCL_UP		; Move up
	POP	BC
	DJNZ	$TXSU		; Loop until done
	JR	$Y78
;--
; Move text down one line
; Entry: DE = start of screen
; Exit: DE = new start
;--
TXT_DOWN:
	CALL	TCL_DOWN
	JR	$Y78
TCL_DOWN:
	LD	HL,SCREEN	; Scratch buffer
	CALL	TXT_DLINE	; Move to next line
	RET
;===
; At beginning of text?
; Entry: DE = pointer (E = 0)
;  HL might be altered
; Exit: DE = adjusted value
;  HL = adjusted value
;  Z if at beginning
;===
TXT_BGN:
	LD	A,D		; See if MSB
	CP	.HIGH.FBUFF	; Compare MSB with FBUFF
	RET	NZ		; Return if normal
	LD	DE,FBUFF	; Load with start
; See if at beginning
	PUSH	HL
	LD	HL,(XLREC)	; Is it at beginning?
	LD	A,H		; Record start
	OR	L
	POP	HL
	RET	Z		; Return if beginning
	RPUSH	HL,DE,BC
; Move everything up in memory
; HL = end of file - 8*256
; DE = end of file
; BC = end of file - (beginning + 8*256)
; Find difference
	LD	HL,(XHREC)
	LD	BC,(XLREC)
	OR	A
	SBC	HL,BC
	LD	A,L		; This is the difference
; Add on FBUFF (for DE)
	ADD	A,.HIGH.FBUFF
	LD	(XMTEXT),A	; Store for later
	LD	D,A
	LD	E,0
	DEC	DE
; Put in BC
	LD	A,L
	SUB	8		; Go down 8
	LD	B,A
	LD	C,0
; Add on FBUFF (for HL)
	ADD	A,.HIGH.FBUFF
	LD	H,A
	LD	L,0
	DEC	HL
	LD	A,B
	OR	C
	JR	Z,$ROPZ
;
	LD	(XHIGH),DE	; Reset XHIGH
	LDDR
; Position and read sectors
$ROPZ:	LD	HL,(XHREC)	; Highest record start
	LD	BC,8
	OR	A
	SBC	HL,BC		; Subtract
	LD	(XHREC),HL
	LD	HL,(XLREC)	; Lowest record start
	OR	A
	SBC	HL,BC		; Subtract
	LD	(XLREC),HL	; Store
; Position to record
	LD	B,H		; Move to BC
	LD	C,L
	LD	DE,FCB
	SVC	@POSN		; Position to record
	JP	NZ,TXT_ERROR
; Memory to lead text
	LD	A,.HIGH.FBUFF	; File buffer
	LD	(FCB+4),A
	LD	B,8		; 8 to load
$RX8:	PUSH	BC
	LD	DE,FCB		; Read a sector
	SVC	@READ
	JP	NZ,TXT_ERROR	; Ahead if error encountered
	LD	A,(FCB+4)	; Fast file technique
	INC	A
	LD	(FCB+4),A
	POP	BC
	DJNZ	$RX8
; Reset everything
	XOR	A
	LD	(XREOF),A	; Not reached end of file
	RPOP	BC,DE,HL
	PUSH	BC
	LD	BC,8*256
	ADD	HL,BC
	POP	BC
	LD	DE,8*256+FBUFF+1
	OR	1		; Make it non-zero
	RET
;--
; Move text up one line
; Assume start of line after 256 characters
; Entry: DE = start of screen
; Exit: DE = new start
;--
TXT_UP:	CALL	TCL_UP
	JP	$Y78
TCL_UP:	LD	B,240		; Count
	LD	H,D
	LD	L,E
	DEC	E		; Compare it
	INC	E
	CALL	Z,TXT_BGN
	JR	Z,$TZZZ
	DEC	DE
$TZXC:	DEC	B		; Count used up?
	JR	Z,$TZZZ		; If used up, go there
	DEC	E		; Go to previous ENTER
	INC	E
	CALL	Z,TXT_BGN	; Go if beginning
	JR	NZ,$U789	; Jump past if not beginning
	JR	$TZZZ		; Jump into routine
$U789:	DEC	DE
	LD	A,(DE)
	CP	0DH
	JR	NZ,$TZXC
; ENTER found!!
	INC	DE		; Skip ENTER
; See if at start of screen
$TZZZ:	PUSH	HL
	OR	A
	SBC	HL,DE
	POP	HL
	RET	Z		; If at start, return
; Format screen line until there
$TZXE:	PUSH	HL		; Save start of screen
	LD	(USEAH),DE	; Store for later
	LD	HL,SCREEN	; Scratch buffer
	CALL	TXT_DLINE	; Advance line
	POP	HL
; See if reached start of screen
	PUSH	HL
	OR	A
	SBC	HL,DE
	POP	HL
	JR	Z,$ZR79		; Skip
	JR	NC,$TZXE	; Loop if not there yet
; Start of screen reached
; Now use previous start
$ZR79:	LD	DE,$-$		; New start of screen
USEAH	EQU	$-2
	RET			; Return
;--
; Display entire screen
; Entry: DE = data
;--
TXT_PAINT:
	CALL	DSP_CLR		; Clear screen
	LD	HL,SCREEN	; Start of screen
	LD	B,YMAX-1
$TXP1:	CALL	TXT_DLINE
	RET	Z
	DJNZ	$TXP1		; Loop until done
;--
; Display one line
; Entry: DE = data, HL = screen
; Exit: DE = data start of new line
;  HL = screen start of new line
;  Z if end of screen
;--
TXT_DLINE:
	PUSH	BC
	LD	B,0		; Start of line
TXT_DLP:
	PUSH	HL
	LD	HL,$-$		; Highest address
XHIGH	EQU	$-2
	OR	A
	SBC	HL,DE
	POP	HL
	CALL	Z,TXT_END
	JR	Z,TXT_AEND
	LD	A,(DE)		; Read byte
	INC	DE
	CP	0DH		; End of line
	JR	Z,TXT_ENT
	CP	9		; Tab
	JP	Z,TXT_TAB
$ZR67:	LD	(HL),A		; Merely store
	INC	HL
	INC	B		; Increase counter
TXT_EL:	LD	A,B
	CP	XMAX		; See if at end
	JR	NZ,TXT_DLP	; Loop if not end
; Reached end of line
; Could word-wrap here
	OR	H
	POP	BC
	RET
;--
; End of file reached
;--
TXT_AEND:
	POP	BC
	XOR	A
	RET
;-
; ENTER encountered
;-
TXT_ENT:
	LD	A,XMAX		; X width
	SUB	B
	LD	C,A		; Store in C
	LD	B,0
	ADD	HL,BC		; Move to next line
	OR	H		; Make NZ
	POP	BC
	RET
;===
; End of text data?
; Entry: DE matches (XHIGH)
; Exit: DE = adjusted value
;  HL is not adjusted
; Z if end of file reached
;===
TXT_END:
	LD	A,(XREOF)	; At end of file?
	OR	A
	JR	Z,$XDOIT	; Read sectors if so
; End of file
	XOR	A		; Make zero
	RET
; Compare to see if more can be loaded
$XDOIT:	PUSH	BC
	LD	A,(XMTEXT)
	ADD	A,8		; Loaded sectors
	LD	B,A
;**
	CP	10H		; See if past end of memory
	JR	C,$XDONT	; Carry will fall through
;**
	LD	A,(XMHIGH)	; Highest page
	CP	B
$XDONT:	POP	BC		; Jumped to with carry set
; if C, not enough memory, will have to move it down
;
	JR	NC,$XDO		; Load normally
; Set up for block move
; HL = FBUFF+8*256
; DE = FBUFF
; BC = end of file - HL
	RPUSH	HL,BC
	LD	H,D		; Move end of HL
	LD	L,E
	LD	BC,8*256+FBUFF
	OR	A
	SBC	HL,BC
	LD	B,H		; Put length in BC
	LD	C,L
	INC	BC		; Move count up
	LD	HL,8*256+FBUFF
	LD	DE,FBUFF
	LDIR			; Move it all
	DEC	DE		; Move DE down
	LD	A,(XMTEXT)	; Subtract 8 from it
	SUB	8
	LD	(XMTEXT),A
	LD	HL,(XLREC)	; Low record
	LD	BC,8
	ADD	HL,BC
	LD	(XLREC),HL	; Store it
	LD	HL,-2048	; Store negative offset
	LD	(ZOFFSET),HL
	RPOP	BC,HL
; Read in 8 sectors (one screen page)
$XDO:	RPUSH	BC,HL,DE
	CALL	RD8SEC
	RPOP	DE,HL,BC
	OR	1		; Ensure not zero
	RET
;--
; Read in 8 sectors at top of memory
;--
RD8SEC:
	LD	BC,(XHREC)	; Highest record start
	LD	DE,FCB
	SVC	@POSN		; Position to record
	JP	NZ,TXT_ERROR
; Memory to lead text
	LD	A,(XMTEXT)
	LD	(FCB+4),A
	LD	B,8		; 8 to load
$RZ8:	PUSH	BC
	LD	DE,FCB		; Read a sector
	SVC	@READ
	JR	NZ,$RZERR	; Ahead if error encountered
	LD	A,(FCB+4)	; Fast file technique
	INC	A
	LD	(FCB+4),A
	POP	BC
	DJNZ	$RZ8
; See if end of file
	LD	DE,FCB
	SVC	@CKEOF		; Check for it
	JR	Z,$RYZZ		; Skip if OK
	CP	28		; End of file error
	JR	Z,$RZER1	; If end of file, treat as such
	CP	29		; End of file error
	JR	Z,$RZER1
$RYZZ:	LD	A,(FCB+4)
	LD	(XMTEXT),A
	LD	HL,(FCB+3)	; Highest address
	LD	(XHIGH),HL
	LD	HL,(FCB+10)	; NRN
	LD	(XHREC),HL	; Store record number
	RET
; Error encountered
$RZERR:	POP	BC
	CP	28		; End of file
	JR	Z,$RZER1
	CP	29		; Record out of range
	RET	NZ		; If error, return
; End of file reached
$RZER1:	LD	(XREOF),A	; Signal end of file
;
	LD	HL,(XHREC)
	LD	BC,8
	ADD	HL,BC
	LD	(XHREC),HL
;
	LD	HL,(FCB+3)	; Load address
	DEC	H
	LD	A,(FCB+8)	; EOF offset
	LD	L,A
	LD	(XHIGH),HL	; Store it
	XOR	A		; No error (so to speak)
	RET
;==
; Data area
;==
XREOF	DB	0		; Non-zero means end of file reached
XLREC	DW	0		; Lowest record start
XHREC	DW	0		; Highest record start
XMTEXT	DB	.HIGH.FBUFF	; MSB to load text
XMHIGH	DB	0EAH		; MSB of highest page that can be used
ZHIMEM3	EQU	$-1
;-
; Tab stop
;-
TXT_TAB:
	PUSH	DE
	PUSH	BC
	LD	C,8		; Tab stops of 8
TABSTOP	EQU	$-1
	LD	E,B		; Value
	SVC	@DIV8		; Find remainder
; Calculate correct tab stop value
	LD	A,(TABSTOP)	; Maximum
	SUB	E
	LD	E,A		; Store in E
	POP	BC		; Restore
	LD	A,B
	ADD	A,E		; Character counter
	CP	XMAX
	JR	C,$MKE		; Skip if OK
; Otherwise, recalculate tab
	SUB	B		; Make it equal
	LD	E,A
	LD	A,XMAX		; Reached the end
$MKE:	LD	B,A		; Store in B
; Add tab to HL
	LD	D,0
	ADD	HL,DE		; Add it on
	POP	DE
	JP	TXT_EL		; Loop, and end line if needed
;--
; Error routine
;--
TXT_ERROR:
	CALL	ERROR		; Display the error
	JP	VIEW_EXIT	; Restore the stack
;===
; Model 3 reserved word table
;===
RMOD3	DB	'EN','D'!80H
	DB	'FO','R'!80H
	DB	'RESE','T'!80H
	DB	'SE','T'!80H
	DB	'CL','S'!80H
	DB	'CM','D'!80H
	DB	'RANDO','M'!80H
	DB	'NEX','T'!80H
	DB	'DAT','A'!80H
	DB	'INPU','T'!80H
	DB	'DI','M'!80H
	DB	'REA','D'!80H
	DB	'LE','T'!80H
	DB	'GOT','O'!80H
	DB	'RU','N'!80H
	DB	'I','F'!80H
	DB	'RESTOR','E'!80H
	DB	'GOSU','B'!80H
	DB	'RETUR','N'!80H
	DB	'RE','M'!80H
	DB	'STO','P'!80H
	DB	'ELS','E'!80H
	DB	'TRO','N'!80H
	DB	'TROF','F'!80H
	DB	'DEFST','R'!80H
	DB	'DEFIN','T'!80H
	DB	'DEFSN','G'!80H
	DB	'DEFDB','L'!80H
	DB	'LIN','E'!80H
	DB	'EDI','T'!80H
	DB	'ERRO','R'!80H
	DB	'RESUM','E'!80H
	DB	'OU','T'!80H
	DB	'O','N'!80H
	DB	'OPE','N'!80H
	DB	'FIEL','D'!80H
	DB	'GE','T'!80H
	DB	'PU','T'!80H
	DB	'CLOS','E'!80H
	DB	'LOA','D'!80H
	DB	'MERG','E'!80H
	DB	'NAM','E'!80H
	DB	'KIL','L'!80H
	DB	'LSE','T'!80H
	DB	'RSE','T'!80H
	DB	'SAV','E'!80H
	DB	'SYSTE','M'!80H
	DB	'LPRIN','T'!80H
	DB	'DE','F'!80H
	DB	'POK','E'!80H
	DB	'PRIN','T'!80H
	DB	'CON','T'!80H
	DB	'LIS','T'!80H
	DB	'LLIS','T'!80H
	DB	'DELET','E'!80H
	DB	'AUT','O'!80H
	DB	'CLEA','R'!80H
	DB	'CLOA','D'!80H
	DB	'CSAV','E'!80H
	DB	'NE','W'!80H
	DB	'TAB','('!80H
	DB	'T','O'!80H
	DB	'F','N'!80H
	DB	'USIN','G'!80H
	DB	'VARPT','R'!80H
	DB	'US','R'!80H
	DB	'ER','L'!80H
	DB	'ER','R'!80H
	DB	'STRING','$'!80H
	DB	'INST','R'!80H
	DB	'POIN','T'!80H
	DB	'TIME','$'!80H
	DB	'ME','M'!80H
	DB	'INKEY','$'!80H
	DB	'THE','N'!80H
	DB	'NO','T'!80H
	DB	'STE','P'!80H
	DB	'+'!80H
	DB	'-'!80H
	DB	'*'!80H
	DB	'/'!80H
	DB	'['!80H
	DB	'AN','D'!80H
	DB	'O','R'!80H
	DB	'>'!80H
	DB	'='!80H
	DB	'<'!80H
	DB	'SG','N'!80H
	DB	'IN','T'!80H
	DB	'AB','S'!80H
	DB	'FR','E'!80H
	DB	'IN','P'!80H
	DB	'PO','S'!80H
	DB	'SQ','R'!80H
	DB	'RN','D'!80H
	DB	'LO','G'!80H
	DB	'EX','P'!80H
	DB	'CO','S'!80H
	DB	'SI','N'!80H
	DB	'TA','N'!80H
	DB	'AT','N'!80H
	DB	'PEE','K'!80H
	DB	'CV','I'!80H
	DB	'CV','S'!80H
	DB	'CV','D'!80H
	DB	'EO','F'!80H
	DB	'LO','C'!80H
	DB	'LO','F'!80H
	DB	'MKI','$'!80H
	DB	'MKS','$'!80H
	DB	'MKD','$'!80H
	DB	'CIN','T'!80H
	DB	'CSN','G'!80H
	DB	'CDB','L'!80H
	DB	'FI','X'!80H
	DB	'LE','N'!80H
	DB	'STR','$'!80H
	DB	'VA','L'!80H
	DB	'AS','C'!80H
	DB	'CHR','$'!80H
	DB	'LEFT','$'!80H
	DB	'RIGHT','$'!80H
	DB	'MID','$'!80H
; Fill up rest
	DB	32!80H
	DB	32!80H
	DB	32!80H
	DB	32!80H
	DB	32!80H
	DB	32!80H
