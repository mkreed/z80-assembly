*LIST OFF
;===
; Main program routine
; March 23, 1995
;===
; Miscellaneous equates and data
YFILES	EQU	YMAX-5
	IF	TRSDOS
SELEN	EQU	32		; TRSDOS 1.3
SELEN1	EQU	30
	ELSE
SELEN	EQU	40		; Screen entry length
	IF	LDOS
SELEN1	EQU	41		; LDOS (1 greater)
	ELSE
SELEN1	EQU	40		; LS-DOS (the same)
	ENDIF
	ENDIF
DELEN	EQU	23		; Directory entry length
;--
; Startup code
;--
; Initialize display
	CALL	DSP_INIT
; See if graphics board installed
	CALL	GCHK
	JR	Z,$VFR		; Skip if installed
	PUSH	HL
	LD	HL,HEXSTART
	LD	(ZLOADER),HL	; Overwrite if not
	POP	HL
; Stuff correct HIGH$ values
;
$VFR:	PUSH	HL
	LD	HL,0		; Get HIGH$
	LD	B,L
	PUSH	DE
	SVC	@HIGH$		; Get upper boundary
	POP	DE
; Corrected code
	DEC	HL
	LD	A,H
	DEC	A		; Go back one page (for good measure)
	LD	(ZHIMEM),A	; Store in routines
	LD	(ZHIMEM2),A
	LD	(ZHIMEM3),A
	SUB	.HIGH.FBUFF	; Subtract start of buffer
	LD	(ZHIMEM4),A
	POP	HL
; Stuff drive number of default in program
	EX	DE,HL
	LD	BC,6
	ADD	HL,BC
	LD	A,(HL)		; Drive number
	LD	(DRIVE),A	; Store
	EX	DE,HL
; See if colon
	LD	A,(HL)
	CP	':'
	JR	NZ,DNVAL	; Not valid drive
	INC	HL
	LD	A,(HL)		; Drive number
	CALL	CNB
	JR	NZ,DNVAL	; Not valid
; Store directory
	LD	C,A
	CALL	DIR_STORE1	; Get directory of drive
	JR	Z,DIR_KEY	; If no error, skip
; Store directory
DNVAL:	CALL	DIR_STORE	; Do valid directory
;--
; Directory display key handler
;--
DIR_KEY:
; Restore stack
DNVAL1:	LD	SP,STACK
	SVC	@CKBRKC		; Eliminate possible BREAK
	CALL	DSP_CLR		; Clear screen
	CALL	DSP_RVON	; Turn reverse on
	CALL	DIR_PAINT	; Display on screen
	JR	NZ,$DDLP1
; Ask for new drive
$DDZK1:	CALL	KEY_DRIVE	; Get new drive number
	JP	C,EXIT
	JR	Z,$DDZK1
	JR	DNVAL1		; Loop if good
; Normal loop
$DDLP1:	CALL	DIR_HFNUM	; Reverse highlight
	LD	A,(FNUM)	; Number
	LD	B,A
	CALL	KBD_GET		; Get key
; Compare various keys
;**
	CP	KBREAK		; Is it BREAK?
	JP	Z,EXIT
	CP	KCTLC		; Complement all marks?
	JP	Z,DIR_RMARK
	CP	KCTLS		; Mark all files?
	JP	Z,DIR_MALL
	CP	KCTLR		; Reset all marks?
	JP	Z,DIR_CALL
	CP	KLEFT		; Left?
	JP	Z,DIR_CLEFT
	CP	KRIGHT		; Right?
	JP	Z,DIR_CRIGHT
	CP	KDOWN		; Down?
	JP	Z,DIR_CDOWN
	CP	KUP		; Up?
	JP	Z,DIR_CUP
	CP	KSPACE		; Space?
	JP	Z,DIR_CSPACE
	CP	KENTER
	JP	Z,VIEWER
; See if number key
	CP	'0'
	JR	C,$_O1		; Skip if below
	CP	'7'+1
	JR	NC,$_O1
	SUB	'0'		; Make into correct number
	CALL	KEY_DRIVEA	; Change drive
	JR	DIR_KEY		; Redisplay screen
; Check the menu options
$_O1:	LD	HL,MENU		; Menu data
	CALL	MNU_KEY		; See if key
	JR	NZ,DIR_KEY	; Redisplay screen if found
DIR_LOOP:
	LD	A,B		; Highlight number
	LD	(FNUM),A
DIR_LON:
	CALL	DIR_HFNUM
	CALL	DSP_PAINT	; Display screen
	JR	$DDLP1
;-
; Left
;-
DIR_CLEFT:
	LD	A,B
	SUB	1
	JR	$DRCU5
;-
; Up
;-
DIR_CUP:
	LD	A,B		; Go back two
	SUB	XFILES
$DRCU5:	JR	C,$DRSC		; Scroll
	LD	B,A
	JR	DIR_LOOP
; Scroll?
$DRSC:	ADD	A,XFILES	; Add on width
	LD	B,A		; Store in B
	LD	A,(SFNUM)	; Is it 0?
	OR	A
	JR	Z,DIR_LON	; Loop if 0 (and don't store)
; Scroll up
	SUB	XFILES		; Subtract from X
	LD	(SFNUM),A	; Store
	RPUSH	HL,DE,BC
	LD	DE,YFILES+2*XMAX+SCREEN
	LD	HL,YFILES+1*XMAX+SCREEN
	LD	BC,YFILES-1*XMAX+1
	LDDR
	RPOP	BC,DE,HL
; Display top line
	PUSH	BC
	LD	A,(FNUM)
	CALL	DIR_PLINE
	POP	BC
	JP	DIR_LOOP
;-
; Right
;-
DIR_CRIGHT:
	LD	A,B
	INC	A		; Move ahead by 1
	JR	$DRCC2
;-
; Down
;-
DIR_CDOWN:
	LD	A,B
	ADD	A,XFILES	; Move ahead by 2
$DRCC2:	LD	B,A		; Store in B
; See if past end
	LD	A,(SFNUM)	; Starting number
	ADD	A,B
	LD	C,A
	LD	A,(EFNUM)
	CP	C
	JR	C,DIR_LON	; Loop if within range
	JR	Z,DIR_LON	; Loop if equal
; See if scroll necessary
	LD	A,B		; Current value
	CP	YFILES*XFILES	; Maximum
	JR	C,DIR_LOOP
; Correct FNUM
	SUB	XFILES
	LD	(FNUM),A
; Scroll down
	LD	A,(SFNUM)
	ADD	A,XFILES	; Add on fields
	LD	(SFNUM),A	; Store
; Memory scroll
	RPUSH	HL,DE,BC
	LD	HL,XMAX*3+SCREEN
	LD	DE,SCREEN+XMAX+XMAX
	LD	BC,YFILES-1*XMAX
	LDIR
; Clear bottom line
	LD	HL,YFILES+1*XMAX+SCREEN
	LD	DE,YFILES+1*XMAX+SCREEN+1
	LD	(HL),32
	LD	BC,XMAX-1
	LDIR
	RPOP	BC,DE,HL
; Display new bottom line
	LD	A,(FNUM)	; File number
	CALL	DIR_PLINE	; Display line
	JP	DIR_LON
;-
; Space
;-
DIR_CSPACE:
	PUSH	HL
	LD	A,(FNUM)
	CALL	DIR_FDE		; Find address
	LD	A,(HL)
	XOR	10000000B
	LD	(HL),A
	POP	HL
	LD	A,(FNUM)	; Line number
	CALL	DIR_PLINE	; Display line
	JP	DIR_LOOP	; Loop
;-
; Reverse all marked files
;-
DIR_RMARK:
	PUSH	HL
	XOR	A		; The first
$DRM9:	PUSH	AF
	CALL	DIR_FDES
	LD	A,(HL)
	XOR	10000000B	; Reverse it
	LD	(HL),A
	POP	AF
	LD	C,A
	LD	A,(EFNUM)
	DEC	A
	CP	C
	LD	A,C
	JR	Z,$DRM8
	INC	A
	JR	NZ,$DRM9
$DRM8:	POP	HL
	JP	DIR_KEY
;-
; Mark all files
;-
DIR_MALL:
	PUSH	HL
	XOR	A		; The first
$MAM9:	PUSH	AF
	CALL	DIR_FDES
	LD	(HL),10000000B	; Mark it
	POP	AF
	LD	C,A
	LD	A,(EFNUM)
	DEC	A
	CP	C
	LD	A,C
	JR	Z,$MAM8
	INC	A
	JR	NZ,$MAM9
$MAM8:	POP	HL
	JP	DIR_KEY
;-
; Clear all files
;-
DIR_CALL:
	PUSH	HL
	XOR	A		; The first
$CAM9:	PUSH	AF
	CALL	DIR_FDES
	LD	(HL),0
	POP	AF
	LD	C,A
	LD	A,(EFNUM)
	DEC	A
	CP	C
	LD	A,C
	JR	Z,$CAM8
	INC	A
	JR	NZ,$CAM9
$CAM8:	POP	HL
	JP	DIR_KEY
;--
; Paint line
; Entry: A = file number
;--
DIR_PLINE:
	RPUSH	HL,DE,BC
; Only for XFILES = 2
	IFEQ	XFILES,2
	AND	11111110B	; Mask out odd
	ENDIF
	PUSH	AF
	CALL	DIR_FDE		; Load HL with address
	EX	DE,HL		; Move to DE
	POP	AF
; Only for XFILES = 2
	IFEQ	XFILES,2
	SRL	A		; Divide by 2
	ENDIF
	LD	B,A
	INC	B		; Correct for 2 lines
	INC	B
	LD	C,0
	CALL	DSP_CXY		; Calculate screen line
	CALL	DIR_DLINE	; Display line
	RPOP	BC,DE,HL
	RET
;--
; Find directory entry
; Entry: A = FNUM value
; Exit: HL = address
;--
DIR_FDES:
	RPUSH	BC,DE
	JR	$RCX7
DIR_FDE:
	RPUSH	BC,DE
	LD	C,A
	LD	A,(SFNUM)
	ADD	A,C		; Combined value
$RCX7:	LD	C,A
	LD	HL,DELEN	; Directory entry length
	SVC	@MUL16
	LD	H,L
	LD	L,A
	LD	DE,BUFFER
	ADD	HL,DE
	RPOP	DE,BC
	RET
;--
; Highlight FNUM
;--
DIR_HFNUM:
	RPUSH	BC,DE,HL
	LD	A,(FNUM)	; File number (on screen)
	LD	C,A
; XFILES specific
	IFEQ	XFILES,2
	LD	HL,SELEN	; Screen entry
	ELSE
	LD	HL,XMAX		; Screen width
	ENDIF
	SVC	@MUL16		; Multiply
	LD	H,L		; Convert
	LD	L,A
	LD	DE,XMAX*2+SCREEN
	ADD	HL,DE		; Add it screen start
	IFEQ	XFILES,1
	LD	DE,SELEN/2-8
	ADD	HL,DE
	ENDIF
; RVIDEO specific
	IF	RVIDEO
	LD	B,SELEN		; Screen entry
$DHNZ1:	LD	A,(HL)
	XOR	10000000B	; Reverse the reverse
	LD	(HL),A
	INC	HL
	DJNZ	$DHNZ1		; Loop
	ELSE
	LD	A,(HL)		; Reverse it
	XOR	151		; Inside graphic
	LD	(HL),A
	LD	C,SELEN1	; Entry length
	LD	B,0
	ADD	HL,BC
	LD	A,(HL)		; Reverse it
	XOR	155		; Outside graphic
	LD	(HL),A
	ENDIF
	RPOP	HL,DE,BC
	RET
;--
; Display directory on screen (according to buffer)
; All registers destroyed
;--
DIR_PAINT:
	CALL	STATUS		; Display status line
; See if any files
	LD	A,(EFNUM)
	OR	A
	JR	Z,$DP_0
	XOR	A		; Start of screen
	CALL	DIR_FDE		; Calculate
	EX	DE,HL		; Move to DE
	LD	HL,XMAX*2+SCREEN
	LD	B,YFILES	; Start of screen
;
$DP0:	PUSH	BC
	CALL	DIR_DLINE	; Display line
	POP	BC
	JR	Z,$DP1
	DJNZ	$DP0
;
$DP1:	CALL	DIR_HFNUM	; Highlight number
	CALL	DSP_PAINT	; Display the screen
	OR	1		; Make NZ
	RET
; No files on disk
$DP_0:	RPUSH	HL,DE,BC
	LD	DE,XMAX*2+SCREEN
	LD	HL,NOFILE$
	LD	BC,NOFILEL
	LDIR
	RPOP	BC,DE,HL
	XOR	A
	RET
NOFILE$	DB	'No files found'
NOFILEL	EQU	$-NOFILE$
;--
; Display directory line
; Entry: DE = buffer, HL = start of line
; Exit: Z if end of line
;--
DIR_DLINE:
	PUSH	HL
	IFEQ	XFILES,1
	PUSH	BC
	LD	BC,XMAX-SELEN/2
	ADD	HL,BC
	POP	BC
	ENDIF
	CALL	DIR_DENTRY	; Display entry
	POP	HL
; XFILES specific
	IFEQ	XFILES,2
	LD	BC,SELEN	; Entry length
	ELSE
	LD	BC,XMAX		; Screen width
	ENDIF
	PUSH	AF
	ADD	HL,BC		; Add on offset
	POP	AF
; Only for XFILES = 2
	IFEQ	XFILES,2
	RET	Z
	PUSH	HL
	CALL	DIR_DENTRY	; Display entry
	POP	HL
	LD	BC,XMAX/2	; Second offset
	PUSH	AF
	ADD	HL,BC
	POP	AF
	ENDIF
	RET
;--
; Display directory entry
; Entry: DE = buffer
;  HL = screen
; Exit: Z if end of file
;--
DIR_DENTRY:
; Only if XFILES = 1
	IFEQ	RVIDEO,FALSE
	INC	HL
	ENDIF
	LD	A,(DE)		; Check mark
	CP	0FFH		; End of files?
	RET	Z
	INC	DE
	BIT	7,A		; Check mark?
	LD	A,32		; Space
	JR	Z,$DDC1
	LD	A,CHKMRK	; The check mark
;THECHECK	EQU	$-1
$DDC1:	LD	(HL),A
	INC	HL
	INC	DE		; Skip past DEC
	LD	BC,8+3+1+1	; "FILENAME" + "EXT" + "/" + MOD
; Store filename/ext
$DDF1:	EX	DE,HL
	LDIR			; Transfer
	EX	DE,HL
; Display size
	LD	BC,7		; Go ahead 7 spaces
	ADD	HL,BC
	PUSH	HL
	PUSH	HL
	EX	DE,HL
	LD	C,(HL)		; lowest LSB
	INC	HL
	LD	E,(HL)		; LSB
	INC	HL
	LD	D,(HL)		; MSB
	INC	HL
	EX	(SP),HL
	CALL	CDEC24		; Display 24 bit number
	POP	DE
	POP	HL
	INC	HL
	INC	HL
; Display date
	INC	DE		; Go to day
	INC	DE
; No day display for TRSDOS 1.3
	IFNE	TRSDOS,TRUE
	LD	A,(DE)		; Get day
	OR	A
	JR	Z,$TM98		; Skip date display
	CALL	DSPNUM		; Display it
	LD	A,'-'
	LD	(HL),A		; Display dash
	INC	HL
	ENDIF
	DEC	DE
	LD	A,(DE)		; Get month
	CALL	DSPMTH		; Display it
	LD	A,'-'		; Display dash
	LD	(HL),A
	INC	HL
	DEC	DE
	LD	A,(DE)		; Get year
	ADD	A,80		; Correct year
	CALL	DSPNUM		; Display it
	INC	HL
; Display time
	INC	DE		; Go to hour
	INC	DE
	IFNE	TRSDOS,TRUE
	INC	DE
	LD	A,'a'		; Signify AM
	LD	(TLTR),A	; Store it
	LD	A,(DE)		; Get hour
	OR	A
	JR	Z,$TM9
	DEC	A		; Correct for shift
	CP	12		; Is it PM?
	JR	C,$TM1		; If not, ahead
	SUB	12		; Correct for PM
	LD	B,A		; Store hour
	LD	A,'p'		; Signify PM
	LD	(TLTR),A	; Store it
	LD	A,B		; Restore hour
$TM1:	OR	A		; Is it zero?
	JR	NZ,$TM2
	LD	A,12		; Make 12 o'clock
$TM2:	CALL	DSPNUM		; Display hour
	LD	A,':'		; Colon to separate
	LD	(HL),A
	INC	HL
	INC	DE		; Go to minute
	LD	A,(DE)		; Get minute
	INC	DE
	CALL	DSPNUM		; Display minute
	LD	A,0		; "a" or "p"
TLTR	EQU	$-1
	LD	(HL),A
	INC	HL
	OR	A		; Signal NZ
	RET
	ENDIF
; Advance past day, month, year
$TM98:	INC	DE
; Advance past hour, minute
$TM9:	INC	A
	INC	DE
	INC	DE
	RET
;--
; Displays number in A
; Entry: A = number, HL = address
; Exit: HL = after number
;--
DSPNUM:	PUSH	BC		; Save BC
	LD	C,0		; Zero counter
; Make sure not above 100
	CP	100
	JR	C,DSPN1
	SUB	100
DSPN1:	INC	C		; Tens counter
	SUB	10		; Back ten
	JR	NC,DSPN1	; Loop until done
	ADD	A,11		; Ahead ten plus one
	LD	B,A		; Store ones
	LD	A,C		; Tens place
	ADD	A,'0'-1		; Make into number
	LD	(HL),A
	INC	HL
	LD	A,B		; Ones place
	ADD	A,'0'-1		; Make into number
	LD	(HL),A
	INC	HL
	POP	BC		; Restore BC
	RET
;--
; Displays 3 byte month in A
; Entry: A = month number, HL = address
; Exit: HL = after address
;--
DSPMTH:	PUSH	BC		; Save BC and DE
	PUSH	DE
	DEC	A		; Correct for month
	LD	B,A		; Store A
	SLA	A		; Multiply by two
	ADD	A,B		; by three
	LD	DE,MNTH$	; Month string
	ADD	A,E		; Find address
	LD	E,A
	LD	B,3		; Three bytes
$DSM1:	LD	A,(DE)		; Get byte
	INC	DE		; Next one
	LD	(HL),A
	INC	HL
	DJNZ	$DSM1		; Loop
	POP	DE		; Restore BC and DE
	POP	BC
	RET
; Directory storage routines
;---
; Store encoded directory in buffer
; Entry: C = drive number
; Exit: BUFFER = encoded data
;  NZ if error
;   all registers destroyed
;---
DIR_STORE:
	CALL	D_STORE		; Call routine
	RET	Z		; No error
	CALL	ERROR		; Display error
	RET
DIR_STORE1:
	CALL	D_STORE1	; Call routine
	RET	Z
	CALL	ERROR		; Display error
	RET
D_STORE:
	LD	C,0		; Drive number
DRIVE	EQU	$-1
D_STORE1:
	SVC	@CKDRV		; Check the drive
	LD	A,32		; Illegal drive number
	RET	NZ
	LD	A,C
	LD	(DRIVE),A	; Proper drive
; Zero data
	XOR	A		; Ending file = 0
	LD	(EFNUM),A
	LD	(SFNUM),A	; Starting file = 0
	LD	(FNUM),A	; File number = 0
	LD	(SSBUFF),A	; Buffer sector = 0
; Find directory track
	IF	TRSDOS
	ELSE
	SVC	@GTDCT		; Get the correct DCT
	ENDIF
; Read GAT table
	CALL	RDGAT
	RET	NZ
	CALL	DIRD		; Load D with DIR
; Read HIT table
	LD	HL,SBUF1
	LD	E,1		; HIT table
	SVC	@RDSSC		; Read it
	RET	NZ		; Return if error
	LD	DE,BUFFER	; Start of name buffer
	LD	B,0		; DEC 0
	LD	L,B
; Read only entries that exist
$DRLP:	LD	B,L
	LD	A,(HL)		; Byte of HIT
	OR	A		; Is it zero?
	PUSH	HL		; Save HL
	PUSH	BC		; Save BC
; Store this entry
	JR	Z,$DRZZ1	; Skip if not active
	CALL	$DIRPRS		; Store entry
$DRZZ1:	POP	BC		; Restore BC
	POP	HL		; Restore HL
; Find correct DEC
	LD	A,L		; DEC
; Different for TRS-DOS 1.3
	IF	TRSDOS
	INC	A
	LD	L,A
	CP	81H		; Final slot
	JR	NZ,$DRLP	; Loop if not at end
				; Fall into $DRZE
	ELSE
	ADD	A,20H		; Move to next
	LD	L,A
	JR	NC,$DRLP	; Loop
	CP	1FH		; At end?
	JR	Z,$DRZE
	INC	L		; Next byte
	JR	$DRLP		; Loop
	ENDIF
; Signal end of table
$DRZE:	LD	A,0FFH		; End of table byte
	LD	(DE),A		; Store it
; Store # of files in status
	LD	A,(EFNUM)	; Final #
	LD	HL,FILEN$
	CALL	CBYTE		; Convert
	CALL	SORT		; Sort filenames
	XOR	A		; No error
	RET
;--
; Store byte long number
; Entry: HL = start, A = number
; Exit: nothing
;--
CBYTE:	RPUSH	HL,DE,BC
	LD	C,A		; Store in C
	LD	DE,0		; High bytes
; Blank out area
	LD	A,32		; Space
	LD	(HL),A
	INC	HL
	LD	(HL),A
	INC	HL
	CALL	CDEC24		; Store number
	RPOP	BC,DE,HL
	RET
;--
; Read directory entry (substitute for @DIRRD)
; Entry: B = DEC, C = drive
; Exit: HL <= buffer, DE is destroyed
;--
DIRRD:
	IF	TRSDOS
; Calculate proper HL
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
	LD	H,.HIGH.SBUFF
	ELSE
; Calculate proper HL
	LD	A,B		; Record start
	AND	0E0H
	LD	L,A		; Offset
	LD	H,.HIGH.SBUFF	; MSB of buffer
	XOR	B
	ADD	A,2		; Calculate needed sector
	LD	E,A		; Needed sector
	ENDIF
; Now see if in buffer
	LD	A,(SSBUFF)	; Sector number
	CP	E
	RET	Z		; Return if same
; Otherwise, must load
	PUSH	HL
	LD	L,0
	CALL	DIRD		; Load D with DIR
	LD	A,E
	LD	(SSBUFF),A	; Store sector number
	SVC	@RDSSC		; Read sector
	POP	HL
	RET
;--
; Read directory entry and store
; Entry: B = DEC, C = drive
;  DE = buffer to store at
; Exit:
;--
$DIRPRS:
	PUSH	DE
	CALL	DIRRD		; Read DEC entry
	POP	DE
	RET	NZ		; Return if error
	LD	A,00010000B	; Is it active?
	AND	(HL)		; Make sure it is
	RET	Z		; Return if not
	LD	A,11001000B	; Is it SYS or INV
	AND	(HL)		; or FXDE?
	RET	NZ		; Return if so
	PUSH	HL		; Put SBUF1
	POP	IX		; in IX
	XOR	A
	LD	(DE),A		; Store no check
	INC	DE
	LD	A,B		; DEC
	LD	(DE),A
	INC	DE
; Increment file counter
	LD	A,(EFNUM)
	INC	A
	LD	(EFNUM),A
; Store filename
	LD	A,L		; Position to filename
	ADD	A,5
	LD	L,A
;-
; HL = directory
; DE = buffer
;-
; Transfer filename without spaces
	LD	BC,0808H	; "FILENAME" length
$R676:	LD	A,(HL)		; Get byte
	INC	HL
	CP	32		; Is it space?
	JR	Z,$R677
	LD	(DE),A
	INC	DE
	DEC	C		; Increase count
$R677:	DJNZ	$R676
; Slash
	LD	A,(HL)		; No slash if space
	CP	32
	JR	Z,$R6778
	LD	A,'/'
$R6778:	LD	(DE),A		; Store
	INC	DE
; Transfer extension
	PUSH	BC
	LD	BC,3		; "EXT" length
	LDIR
	POP	BC
; Add on extra spaces
	INC	C		; Is it nothing?
$R678:	DEC	C		; Decrement count
	JR	Z,$R679
	LD	A,32		; Space
	LD	(DE),A
	INC	DE
	JR	$R678
; Store MOD flag byte
$R679:	LD	A,32		; Space (no MOD)
	IFNE	TRSDOS,TRUE
	BIT	6,(IX+1)
	JR	Z,$R680
	LD	A,'+'
	ENDIF
$R680:	LD	(DE),A
	INC	DE
; Calculate file length
	RPUSH	HL,BC
	LD	L,(IX+20)	; ERN
	LD	H,(IX+21)
	IF	TRSDOS
	INC	HL
	ENDIF
;()()()()()
; Check for empty file
	LD	A,H		; Is there anything in the file?
	OR	L
	JR	Z,$R6Z9		; Go with zero
; Check for full sector
	LD	A,(IX+3)	; Is it set to zero?
	OR	A
	JR	Z,$R6Z8		; No decrement if so
	DEC	HL		; Eliminate difference
$R6Z8:	LD	A,(IX+3)	; Offset
$R6Z9:	LD	(DE),A		; Store LSB
	INC	DE
	LD	A,L
	LD	(DE),A		; Store NSB
	INC	DE
	LD	A,H
	LD	(DE),A		; Store MSB
	INC	DE
	RPOP	BC,HL
;()()()()()()
; See if there is a date
	LD	A,(IX+1)	; Month byte
	AND	00001111B	; Mask out everything
	JR	Z,NODATE	; There is no date!!
; Determine dating scheme
	LD	A,$-$
NDATE	EQU	$-1
	IFNE	TRSDOS,TRUE
	OR	A
	JR	Z,$NEWDATE
	ENDIF
;-
; Old style dating
;-
; YEAR
	LD	A,(IX+2)	; Year byte
	IF	TRSDOS
	SUB	80		; Add on offset
	ELSE
	AND	00000111B	; Mask out rest
	ENDIF
	LD	(DE),A		; Store it
	INC	DE
; MONTH
	LD	A,(IX+1)	; Month byte
	AND	00001111B	; Mask out flags
	LD	(DE),A		; Store it
	INC	DE
; DAY
	IF	TRSDOS
	LD	A,1
	ELSE
	LD	A,(IX+2)	; Day byte
	AND	11111000B	; Mask out year
	RRCA			; Rotate to 0
	RRCA
	RRCA
	ENDIF
	LD	(DE),A		; Store it
	INC	DE
; Hour and minute
$NDAT	XOR	A
	LD	(DE),A
	INC	DE
	LD	(DE),A
	INC	DE
	RET
;--
; There is no date!
;--
NODATE:	XOR	A		; Wipe out date
	LD	(DE),A
	INC	DE
	CALL	$NDAT		; 3 bytes
	JR	$NDAT		; 5 bytes
;-
; Store new dating
;-
	IFNE	TRSDOS,TRUE
$NEWDATE:
; YEAR
	LD	A,(IX+19)	; Year byte
	AND	00011111B	; Mask out minute
	LD	(DE),A		; Store it
	INC	DE
; MONTH
	LD	A,(IX+1)	; Month byte
	AND	00001111B	; Mask out flags
	LD	(DE),A		; Store it
	INC	DE
; DAY
	LD	A,(IX+2)	; Day byte
	AND	11111000B	; Mask out year
	RRCA			; Rotate to 0
	RRCA
	RRCA
	LD	(DE),A		; Store it
	INC	DE
; HOUR
	LD	A,(IX+18)	; Hour byte
	PUSH	AF		; Store minutes
	AND	11111000B	; Mask out minutes
	RRCA			; Rotate to 0
	RRCA
	RRCA
	INC	A		; Up one
	LD	(DE),A		; Store it
	INC	DE
; MINUTES
	POP	AF		; A = minutes MSB
	AND	00000111B	; Mask out hours
	RLCA			; Rotate to 3
	RLCA
	RLCA
	LD	B,A		; Store in B
	LD	A,(IX+19)	; Minutes LSB
	AND	11100000B	; Mask out year
	RLCA			; Rotate to 0
	RLCA
	RLCA
	OR	B		; Add other half
	LD	(DE),A		; Store it
	INC	DE
	RET
	ENDIF
;--
; Binary multiply
; Entry: BC = factor 1
;  DE = factor 2
; Exit: DE = result
;--
BMULT	PUSH	HL		; Save address
	LD	HL,0		; Reset counter
	LD	A,16		; Count down
BMLT1	RR	D		; Divide by 2
	RR	E
	JR	NC,BMLT2	; Ahead if nothing
	ADD	HL,BC		; Add on
BMLT2	SLA	C		; BC = BC * 2
	RL	B
	DEC	A		; Count down
	JR	NZ,BMLT1
	EX	DE,HL		; Move to DE
	POP	HL		; Restore address
	RET
;--
; Convert 24 bit register to a right-justified number
; Entry: DEC = number
;  HL = end of buffer
; Exit: HL = start of buffer
;--
CDEC24:
	CALL	DIV24
	ADD	A,'0'		; Make decimal
	LD	(HL),A		; Store
	DEC	HL
	LD	A,C		; Is it over?
	OR	D
	OR	E
	RET	Z
	JR	CDEC24		; Loop
;--
; 24 bit divide by 10
; Entry: DEC = dividend
; Exit: DEC = result
;  A = remainder
;--
DIV24:	PUSH	HL
	LD	B,24		; 24 bits
	XOR	A
	LD	H,A
	LD	L,A
;-
; HLA = result
; DEC = remainder count
; B = bit count
;-
$D24A:	OR	A
	RL	C		; DEC * 2
	RL	E
	RL	D
	RL	A		; and HLA * 2 (with carry
	RL	L		;  from DEC)
	RL	H
	JR	C,$D24A2	; If carry, skip compare
; See if HLA is greater than 10
	PUSH	BC		; Save A (but not flags)
	LD	C,A
	LD	A,H		; Is it zero?
	OR	L
	LD	A,C		; Restore A (but not flags)
	POP	BC
	JR	NZ,$D24A1	; Cannot be below 10
	CP	10		; Is it below 10?
	JR	C,$D24A2	; Skip if below 10
; Not below 10 (must subtract)
$D24A1:	SUB	10		; Subtract from A
	JR	NC,$DZ1		; Skip if no carry
	DEC	HL		; Decrement if carry
$DZ1:	SET	0,C		; Set low order bit
$D24A2:	DJNZ	$D24A		; Loop until done
	POP	HL
	RET
	RET
;--
; Binary divide
; Entry: DE = dividend
;  BC = divisor
; Exit: DE = result
;  BC = remainder
;--
BDIV	PUSH	HL		; Save
	LD	A,16		; 16 bits
	EX	DE,HL		; Move to HL
	LD	DE,0		; Remainder
BDIV1	ADD	HL,HL		; Rotate dividend
	RL	E		; & subtract divisor if
	RL	D		; carry into bit 16
	JR	C,BDIV2
	OR	A
	EX	DE,HL
	PUSH	HL		; Compare them
	SBC	HL,BC
	POP	HL
	EX	DE,HL
	JR	C,BDIV3
BDIV2	EX	DE,HL		; Switch the two
	OR	A
	SBC	HL,BC		; Subtract them
	EX	DE,HL
	INC	L		; Set low order bit
BDIV3	DEC	A		; Count down one bit
	JR	NZ,BDIV1	; Loop until done
	EX	DE,HL		; Move result to DE
	LD	B,H
	LD	C,L		; Move remainder to BC
	POP	HL		; Restore
	RET
;--
; Read GAT and store information
;--
RDGATE:	RPOP	HL,BC		; Error condition
	RET
RDGAT:
	RPUSH	BC,HL
	LD	HL,BGAT		; GAT buffer
	CALL	DIRD		; Load D with DIR
	LD	E,0		; GAT sector
	SVC	@RDSSC		; Read system sector
	JR	NZ,RDGATE
; Calculate free space
	LD	DE,0		; Granule count
	LD	L,0CCH		; Position to GAT + CC
	LD	A,(HL)		; Excess cylinder
	ADD	A,35
	IF	TRSDOS
	LD	A,40
	ENDIF
	LD	B,A		; Set loop counter
	LD	L,E		; GAT + 0
	PUSH	BC		; Save counter
; Loop
$FS1:	LD	A,(HL)		; Read byte
	IF	TRSDOS
	OR	11000000B	; Mark high bits in use
	ENDIF
$FS2:	SCF			; Set carry
	RRA			; Granule in use?
	JR	C,$FS3		; Don't increment if in use
	INC	DE		; Increase free count
$FS3:	CP	0FFH		; Finished with GAT byte?
	JR	NZ,$FS2		; Loop until done
	INC	L		; Finished with GAT byte
	DJNZ	$FS1
	POP	BC		; Restore counter
$ND:	IF	TRSDOS
;()()
	LD	A,2
	ELSE
	LD	A,(IY+8)
	ENDIF
	AND	1FH		; Strip out sectors per granule
	INC	A		; Change for zero offset
; Calculate # of free sectors
	EX	DE,HL
	LD	C,A
	SVC	@MUL16		; Multiply
; Divide by 4 (free K)
	LD	E,L
	LD	C,A
; Calculate fraction
	LD	A,C
	AND	00000011B	; Mask out bits
	SRL	E
	RR	C
	SRL	E
	RR	C
	LD	D,0
; Store number of free bytes
	LD	HL,FREE$	; Free space buffer
	PUSH	AF
	LD	A,5
$IUY:	LD	(HL),32		; Space out
	INC	HL
	DEC	A
	JR	NZ,$IUY
	POP	AF
	PUSH	AF
	CALL	CDEC24		; Convert 24 bit number
	POP	AF
; Store fractional part
	LD	C,A		; * 1
	ADD	A,A		; * 2
	ADD	A,A		; * 4
	ADD	A,C		; * 5
	LD	C,A
	ADD	A,A		; * 10
	ADD	A,A		; * 20
	ADD	A,C		; * 25
	LD	HL,FRAC$
	CALL	DSPNUM		; Convert number
; Determine disk type
	IFEQ	TRSDOS,FALSE
	LD	A,(BGAT+0CDH)	; Disk type byte
	BIT	3,A
	LD	A,0FFH		; New style
	JR	Z,$R55
	ENDIF
	XOR	A
$R55:	LD	(NDATE),A
; Store disk name
	LD	HL,BGAT+0D0H	; Start of name
	LD	DE,NAME$
	LD	BC,8
	LDIR			; Transfer 8 bytes
; Calculate disk date
; Month
	CALL	CNUM		; Calculate number
	JR	NZ,$REND
	CP	13
	JR	NC,$REND
	OR	A
	JR	Z,$REND
	PUSH	HL
	LD	HL,MONTH$
	CALL	DSPMTH		; Display month
	POP	HL
; Day
	INC	HL
	CALL	CNUM		; Calculate number
	JR	NZ,$REND
	PUSH	HL
	LD	HL,DAY$
	CALL	DSPNUM		; Display number
	POP	HL
; Year
	INC	HL
	CALL	CNUM		; Calculate number
	JR	NZ,$REND
	LD	HL,YEAR$
	CALL	DSPNUM		; Display number
	XOR	A
	RPOP	HL,BC
	RET
; Error condition (display no date)
$REND:	XOR	A
	LD	(DEND$),A	; Store it
	RPOP	HL,BC
	RET
; Loads D with directory track
DIRD:
	IF	TRSDOS
	LD	D,17
	ELSE
	LD	D,(IY+9)	; Directory
	ENDIF
	RET
;--
; Convert a number
; Entry: HL = address of number
; Exit: if Z, A = hex
;  if NZ, not a valid number
;--
CNUM:	LD	A,(HL)
	INC	HL
	CALL	CNB
	RET	NZ		; Return if not valid
	PUSH	BC
	LD	C,A		; Calculate A * 10
	ADD	A,A		; * 2
	ADD	A,A		; * 4
	ADD	A,C		; * 5
	ADD	A,A		; * 10
	POP	BC
	LD	($RZZZ),A	; Store for later
	LD	A,(HL)		; Second number
	INC	HL
	CALL	CNB		; Convert
	RET	NZ		; Return if not valid
	ADD	A,0		; Add on previous
$RZZZ	EQU	$-1
	CP	A		; Make Z
	RET
;--
; Convert number byte
; Entry: A = ASCII number
; Exit: if Z, A = hex
;  if NZ, not a valid number
;--
CNB:	SUB	'0'
	RET	C		; If error
	CP	'9'-'0'		; See if two high
	RET	NC
	CP	A		; Make zero
	RET
;--
; Display status at top of screen
; Display equal signs on line 2
; Display equal signs on line YMAX-3
; Display menu bar on bottom line
; Copyright message on second to last line
;--
STATUS:	RPUSH	HL,DE,BC
; Change file number message
	LD	A,(EFNUM)	; Final #
	LD	HL,FILEN$
	CALL	CBYTE		; Convert
; Display status line
	LD	HL,XMAX-64/2+SCREEN
	LD	DE,STAT$
	CALL	DSP_PRINT	; PRINT
; Menu bar on bottom line
	LD	HL,YMAX-1*XMAX+SCREEN
	LD	DE,MENU$	; Menu bar string
	CALL	DSP_PRINT
; Dashes on line 2
	LD	HL,XMAX*1+SCREEN
	LD	DE,XMAX*1+SCREEN+1
	LD	(HL),'='
	LD	BC,XMAX-1
	LDIR
; Dashes on line YMAX-3
	LD	HL,YMAX-3*XMAX+SCREEN
	LD	DE,YMAX-3*XMAX+SCREEN+1
	LD	(HL),'='
	LD	BC,XMAX-1
	LDIR
; Copyright message (line 1)
	LD	HL,YMAX-3*XMAX+SCREEN+C1L
	LD	DE,COPYRIGHT1$
	CALL	DSP_PRINT
; Copyright message (line 2)
	LD	HL,YMAX-2*XMAX+SCREEN+C2L
	LD	DE,COPYRIGHT2$
	CALL	DSP_PRINT
	RPOP	BC,DE,HL
	RET
	IF	MOD4
MENU$	DB	'Sort  Copy  Delete  Move  Rename  Quit       ^C ^R ^S',0
	ELSE
MENU$	DB	'Sort  Copy  Delete  Move  Quit       ^C ^R ^S',0
	ENDIF
COPYRIGHT1$
	IF	LDOS
	DB	' PERUSE for LDOS, version 1.1 '
	ENDIF
	IF	MOD4
	DB	' PERUSE for the Model 4, version 1.1 '
	ENDIF
	IF	TRSDOS
	DB	' PERUSE for TRS-DOS 1.3, version 1.1 '
	ENDIF
C1L	EQU	XMAX-$+COPYRIGHT1$/2
	DB	0		; Could be space (patch letter previous)
	DB	0		; Extra zero needed
COPYRIGHT2$
	DB	'copyright (c) 1997 by Matthew Reed,'
	DB	' all rights reserved'
C2L	EQU	XMAX-$+COPYRIGHT2$/2
	DB	0
SORT$	DB	'Filename  Extension  Date  Size  None',0
STAT$	DB	'Name: '
NAME$	DB	'nnnnnnnn  '
FILEN$	DB	'    file(s)   '
	DB	'Free: '
FREE$	DB	'     ',0
FRAC$	EQU	$+1
	DB	'.  K   Date: '
DEND$	EQU	$
DAY$	DB	'dd-'
MONTH$	DB	'mmm-'
YEAR$	DB	'yy',0
MENU	DB	'S'
	DW	KEY_SORT
	DB	'D'
	DW	KEY_KILL
	DB	'C'
	DW	KEY_COPY
	DB	'M'
	DW	KEY_MOVE
	IF	MOD4
	DB	'R'
	DW	KEY_RENAME
	ENDIF
	DB	'Q'
	DW	EXIT
	DB	0
;***
; Screen routines
;***
;--
; Wait for key
; Entry: nothing
; Exit: A = key
;--
KBD_GET:
; Model 4 version
	IF	MOD4
	PUSH	DE
KBDG1:	SVC	@KBD
	JR	NZ,KBDG1
	POP	DE
	RET
	ELSE
; Model 3 version
	PUSH	DE
KBDG1:	SVC	@KBD
	JR	Z,KBDG1
; Special Model 1 check
	OR	A
	JR	Z,KBDG1
	POP	DE
	CALL	TSTCLR		; Is CLEAR pressed?
	RET	Z
; CLEAR is pressed
	CP	KUP		; Is it up?
	JR	Z,$RT9Z
	CP	KDOWN		; Is it down?
	RET	NZ
; DOWN key is pressed
	LD	A,KCDOWN	; CLEAR DOWN
	RET
$RT9Z:	LD	A,KCUP		; CLEAR UP
	RET
TSTCLR:	PUSH	BC
	LD	B,A
	LD	A,(3840H)	; CLEAR key
	BIT	1,A
	LD	A,B
	POP	BC
	RET
	ENDIF
;--
; Initialize screen
; Exit: A is destroyed
;--
DSP_INIT:
	CALL	DSP_RVON	; Turn on reverse video
	CALL	DSP_COFF	; Turn off cursor
	CALL	DSP_CLS		; Clear screen
	RET
;--
; Turn reverse video on
;--
DSP_RVON:
; Only if reverse video
	IF	RVIDEO
	RPUSH	DE,BC
	LD	C,16		; Turn on
	SVC	@DSP
	LD	C,17		; Turn off
	SVC	@DSP
	RPOP	BC,DE
	ENDIF
	RET
;--
; Turn reverse video off
;--
DSP_RVOFF:
; Only if reverse video
	IF	RVIDEO
	RPUSH	DE,BC
	LD	C,17		; Turn off
	SVC	@DSP
	RPOP	BC,DE
	SVC	@CLS		; Clear the screen
	ENDIF
	RET
;--
; Calculate X, Y from address
; Entry: HL = address
; Exit: B = Y,  C = X
;--
DSP_CADD:
	RPUSH	DE,HL
	LD	DE,SCREEN	; Subtract out screen
$DCAZ:	LD	BC,0		; Zero BC
	OR	A
	SBC	HL,DE
	LD	DE,XMAX		; Width of screen
DSPC1:	INC	B
	OR	A
	SBC	HL,DE
	JR	NC,DSPC1	; Loop
	DEC	B		; Correct Y
	ADD	HL,DE
	LD	C,L		; Transfer X
	RPOP	HL,DE
	RET
;--
; Calculate address from X, Y
; Entry: B = Y,  C = X
; Exit: HL = address
;--
DSP_CXY:
	RPUSH	DE,BC
	LD	L,B		; Y in HL
	LD	H,0
	ADD	HL,HL		; *2
	ADD	HL,HL		; *4
	ADD	HL,HL		; *8
	ADD	HL,HL		; *16
; Only if XMAX = 80
	IFEQ	XMAX,80
	LD	D,H
	LD	E,L
	ENDIF
	ADD	HL,HL		; *32
	ADD	HL,HL		; *64
; Only if XMAX = 80
	IFEQ	XMAX,80
	ADD	HL,DE		; *80 (64+16)
	ENDIF
	LD	B,0		; MSB = 0
	ADD	HL,BC		; Find address
	LD	BC,SCREEN
	ADD	HL,BC		; Add on SCREEN
	RPOP	BC,DE
	RET
;--
; PRINT@
; Entry: BC = Y, X
;  DE = string + 0
; Exit: A is destroyed
;--
DSP_PRINTAT:
	PUSH	HL		; Save HL
	CALL	DSP_CXY		; Locate
	CALL	DSP_PRINT	; Print on screen
	POP	HL
	RET
;--
; Print to screen
; Entry: HL = screen address
;  DE = string + 0
; Exit: A is destroyed
;--
DSP_PRINT:
	LD	A,(DE)		; Get string byte
	INC	DE
	OR	A		; See if end
	RET	Z
	LD	(HL),A		; Store on screen
	INC	HL
	JR	DSP_PRINT	; Loop until done
;--
; Clear the buffer and screen
; Exit: A is destroyed
;--
DSP_CLS:
	CALL	DSP_CLR		; Clear buffer
	CALL	DSP_PAINT	; Display on screen
	RET
;--
; Clear screen buffer
; Exit: A is destroyed
;--
DSP_CLR:
	RPUSH	HL,DE,BC
	LD	HL,SCREEN
	LD	BC,XMAX*YMAX-1	; Length
$DSZ1:	LD	D,H
	LD	E,L
	INC	DE
	LD	(HL),32
	LDIR
	RPOP	BC,DE,HL
	RET
;--
; Clear bottom line
;--
DSP_CBL:
	RPUSH	HL,DE,BC
	LD	HL,YMAX-1*XMAX+SCREEN
	LD	BC,XMAX-1
	JR	$DSZ1		; Jump into routine
;--
; Display screen buffer
; Exit: A is destroyed
;--
DSP_PAINT:
	RPUSH	DE,BC,HL,AF	; Save
; Model 4 version
	IF	MOD4
	LD	B,5		; Buffer to video
	LD	HL,SCREEN
	SVC	@VDCTL
	ELSE
; Model 3 version
	LD	HL,SCREEN
	LD	DE,3C00H	; Video display
	LD	BC,XMAX*YMAX
	LDIR			; Move it
	ENDIF
	RPOP	AF,HL,BC,DE	; Restore
	RET
;--
; Save screen to buffer
;--
;DSP_SAVE:
;	RPUSH	DE,BC,HL,AF
;	LD	HL,SCREEN
;	LD	DE,SCREEN1
;	LD	BC,XMAX*YMAX
;	LDIR
;	RPOP	AF,HL,BC,DE
;	RET
;--
; Restore screen from buffer
;--
;DSP_RESTORE:
;	RPUSH	DE,BC,HL,AF
;	LD	HL,SCREEN1
;	LD	DE,SCREEN
;	LD	BC,XMAX*YMAX
;	LDIR
;	RPOP	AF,HL,BC,DE
;	RET
;--
; Turn cursor on
;--
DSP_CON:
	LD	A,14
	CALL	DSP_DSP
	RET
;--
; Turn cursor off
;--
DSP_COFF:
	LD	A,15
	CALL	DSP_DSP
	RET
;--
; Display character
; Entry: A = character
;--
DSP_DSP:
	RPUSH	DE,BC,AF
; Only with Model 4
	IF	MOD4
	LD	C,A
	ENDIF
	SVC	@DSP
	RPOP	AF,BC,DE
	RET
;--
; Set cursor position
; Entry: HL = address
; Exit: nothing
;--
DSP_SADD:
	RPUSH	HL,DE,BC,AF
; Model 4 version
	IF	MOD4
	CALL	DSP_CADD
	LD	H,B		; Move to HL
	LD	L,C
	LD	B,3
	SVC	@VDCTL
	ELSE
; Model 3 version
	LD	BC,SCREEN	; Find difference
	OR	A
	SBC	HL,BC
	LD	BC,3C00H
	ADD	HL,BC
	LD	(4020H),HL	; Store cursor position
	ENDIF
	RPOP	AF,BC,DE,HL
	RET
;--
; Error handling routine
; Entry: A = error
;--
ERROR:
	RPUSH	DE,BC,AF	; Save registers
; Model 4 version
	IF	MOD4
	PUSH	AF
	SVC	@FLAGS$
	SET	7,(IY+'C'-'A')	; Return error message
	CALL	DSP_CBL		; Clear the bottom line
	POP	AF
	OR	11000000B	; Return and short error
	LD	C,A		; Error code
	LD	DE,YMAX-1*XMAX+SCREEN
	SVC	@ERROR		; Display error
	ELSE
; Model 3 version
	PUSH	AF
	CALL	DSP_CBL		; Clear bottom line
; Replace display driver
	LD	HL,(401DH+1)	; Store *DO driver address
	LD	(SDO),HL
	LD	HL,RDO		; Replacement driver
	LD	(401DH+1),HL
; Display error
	LD	HL,YMAX-1*XMAX+SCREEN
	LD	(RDO1),HL	; Error display point
	POP	AF
	OR	11000000B	; Return and short error
	SVC	@ERROR		; Display error
; Replace old driver
	LD	HL,$-$		; Old driver
SDO	EQU	$-2
	LD	(401DH+1),HL
	ENDIF
; Put in exclamation later
	LD	DE,YMAX-1*XMAX+SCREEN
$DS1E:	LD	A,(DE)		; See if CR
	INC	DE
	CP	13
	JR	NZ,$DS1E	; Back if not
	DEC	DE
	LD	A,32		; Replace CR with space
	LD	(DE),A
	DEC	DE
	LD	A,'!'		; Replace space with "!"
	LD	(DE),A
	CALL	DSP_PAINT	; Display screen
	CALL	KBD_GET		; Wait for key
	RPOP	AF,BC,DE
	RET
; Replacement display driver
; Needed only for Model 3
	IF	MOD3
RDO:	RPUSH	AF,HL		; Save
	LD	HL,$-$		; Screen address
RDO1	EQU	$-2
	LD	(HL),C		; Store it
	INC	HL
	LD	(RDO1),HL	; Restore value
	RPOP	HL,AF
	RET
	ENDIF
;--
; Check to see if graphics board
; is installed
; Exit: Z if installed
;--
GCHK:	PUSH	BC		; Save BC
	LD	A,11000000B	; Turn off board features
	OUT	(GCTL),A
	LD	A,20		; Go to 20,20
	OUT	(GX),A		; Set X
	OUT	(GY),A		; Set Y
	IN	A,(GRW)		; Read from board
	CPL			; Make the opposite
	OUT	(GRW),A		; Store in board
	LD	B,A		; Store value
	IN	A,(GRW)		; Get value again
	CP	B		; Is it same?
	POP	BC		; Restore BC
	PUSH	AF
	CPL
	OUT	(GRW),A		; Restore to original
	POP	AF
	RET
;===
; Specific routines
;===
*GET PRFILE
*GET PRVIEW
*LIST ON
;===
; Data area
;===
	IF	TRSDOS
FCB	DS	50
FCB2	DS	50
	ELSE
FCB	DS	32
FCB2	DS	32
	ENDIF
SCREEN	DS	YMAX+1*XMAX
;sCREEN1	DS	YMAX+1*XMAX
SSBUFF	DB	0
SFNUM	DB	0		; Start of screen file number
EFNUM	DB	0		; Ending file number
FNUM	DB	0		; Highlighted file number
	ORG	$+36<-8+1<8-36
MNTH$	DB	'JanFebMarAprMayJunJulAugSepOctNovDec'
SBUFF	DS	256
BGAT	DS	256
SBUF1	DS	256
BUFFER	DS	256*DELEN
BEND	EQU	$
	DS	256-.LOW.$
FBUFF	EQU	$
	END	START
