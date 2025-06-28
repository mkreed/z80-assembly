;=====================================
; DATA-MINDER database manager
; copyright (c) 1995, by Matthew Reed
; all rights reserved
; DMEDIT/ASM, editing functions
;=====================================
LEDITE	LD	A,4		; Everything
	JR	LEDID1
;=====
; Line editor with disk saving
; BC => block to read (0 if none)
; PVFORM and NXFORM must have proper values
;=====
LEDITD	LD	A,3		; No print or remove
LEDID1	LD	($NUD),A
	LD	A,4
	LD	(HKEYB),A	; Keyboard help
LEDITD1	LD	A,1		; Page 1
	LD	(CPAGE),A	; Desired page
	LD	($LEFB),BC	; Store first block
	CALL	CSCRN		; Clear and save screen
	CALL	SSCRN
; Zero previous and next pages
	LD	HL,0
	LD	(PVPAGE),HL
	LD	(NXPAGE),HL
; Store block number
$LEDV1	LD	($LEDB),BC	; Store block number
	LD	A,B
	OR	C		; See if nothing
	JR	Z,$LNOFRM
; Read in form
	LD	DE,DATA		; Address of data
	LD	A,(CPAGE)	; Desired page
	DEC	A		; See if first page
	JR	Z,$LEFP		; Ahead if first page
; Second page or above
	CALL	DRPAGE		; Read page
	JP	NZ,LEDERR	; Ahead if error
	JR	$LEDD1		; Move ahead
; First page
$LEFP	CALL	DRFORM		; Read form
	JP	NZ,LEDERR	; Ahead if error
	JR	$LEDD1		; Move ahead
; Create blank data (in memory)
$LNOFRM	LD	A,0FFH		; Create blank form
	LD	(DATA),A
	LD	(MODFLAG),A	; Make modified
; Set up screen
$LEDD1	CALL	CSCRN		; Clear screen
; Create "+", "-", or ""
	LD	BC,(PVPAGE)	; Make minus
	LD	A,B
	OR	C
	LD	(PMINUS),A
	LD	BC,(NXPAGE)	; Make plus
	LD	A,B
	OR	C
	LD	(PPLUS),A
	LD	A,(CPAGE)	; Desired page
	LD	B,0		; Loaded page
APAGE	EQU	$-1
	CP	B		; See if same
	JR	Z,$LEDD2	; If same, ahead
	DEC	A
	CALL	DFSF		; Find screen form
	LD	A,B		; See if nothing
	OR	C
	JR	NZ,$LEDD10	; Ahead if value
; Use notes form
$LEDEF	LD	HL,NOTES	; "NOTES:"
	LD	DE,FORM
	LD	BC,NOTESL
	LDIR			; Move
	JR	$LEDD2		; Jump ahead
; Load screen form
$LEDD10	LD	DE,FORM		; Form address
	CALL	DRDATA		; Read screen form
	JP	NZ,LEDERR	; Ahead if error
; Make sure form is not empty
	LD	A,(FORM)	; See if empty
	INC	A
	JR	Z,$LEDEF
; Update loaded page
$LEDD2	LD	A,(CPAGE)
	LD	(APAGE),A
; Turn on display
	LD	A,1		; Turn on display
	LD	(FPFLAG),A
	CALL	DINFO		; Display information line
; Set up registers
	LD	DE,DATA		; Data buffer
	LD	HL,FORM		; Form buffer
; Call line editor
	CALL	LEDIT2		; Line editor
	CP	2
	JR	Z,$CTCZ1
	OR	A
	JR	NZ,$CTC		; Ahead if not <BREAK>
	LD	BC,($LEFB)	; First block
	XOR	A		; Signal <BREAK>
	RET
;==
; <CONTROL> <C>
;==
$CTC:	CALL	$LSPAGE		; Save page
	JP	NZ,LEDERR
$CTCZ1:	LD	A,(WDIRT)	; See if dirty
	OR	A
	CALL	NZ,DWFLUSH	; Flush write buffer
	JP	NZ,LEDERR
	LD	BC,$-$		; First block
$LEFB	EQU	$-2
	LD	A,3
	OR	A
	RET
;==
; <CONTROL> <R>
;==
$LKCNTR	CALL	$LSPAGE		; Save page
	JP	NZ,LEDERR
	LD	A,23
	LD	(HTOPIC),A
	LD	HL,RMVSQ	; Remove question
	CALL	CSCRN		; Clear screen
	CALL	DMENU
	CP	2		; Is it NO?
	JR	Z,$LKCC1	; Exit if not
	CP	1		; Is it YES?
	JR	NZ,$LKCC1
; Remove form
	LD	BC,($LEFB)	; Block number
	CALL	RFORM		; Remove form
$LKCN1	LD	A,(WDIRT)	; See if dirty
	OR	A
	CALL	NZ,DWFLUSH	; Flush write buffer
	JP	NZ,LEDERR
	LD	BC,(CFORM)	; Current form
	LD	A,B
	OR	C
	JR	Z,$LKCR1
	DEC	BC
	LD	(CFORM),BC
$LKCR1	LD	BC,($LEFB)	; First block
	LD	A,3
	OR	A
	RET
$LKCC1:	LD	BC,($LEFB)
	LD	A,2
	OR	A
	RET
;==
; <CONTROL> <O>
;==
$LKCNTO	CALL	$LSPAGE		; Save page
	JP	NZ,LEDERR
	LD	A,(WDIRT)	; See if dirty
	OR	A
	CALL	NZ,DWFLUSH	; Flush write buffer
	JP	NZ,LEDERR
	LD	BC,(CFORM)	; Current form
	PUSH	BC
	LD	BC,($LEFB)	; Get it
	PUSH	BC
	CALL	CPRINT		; Get options
	LD	HL,PRINT$
	CALL	DMB
	CALL	PCLS
	LD	A,0C9H		; "RET"
	LD	(POEND),A
	POP	BC
	LD	($LEFB),BC
	POP	BC
	LD	(CFORM),BC	; Store it
	LD	BC,($LEFB)	; Actual block number
	CALL	FPRINTA		; Actual print
; Wait for key if preview
	LD	A,(PRVIEW)	; See if preview
	OR	A
	JR	Z,$RRZ
	LD	A,(PPBP)	; Skip if pause between pages
	CP	'Y'
	JR	Z,$RRZ
$RRZX	CALL	MSKEY
	INC	A
	JR	Z,$RRZX
$RRZ	CALL	PCLOS		; Close file
	XOR	A
	LD	(DSCRN),A	; Turn off preview
	LD	(POEND),A
	LD	BC,($LEFB)
	LD	A,3
	OR	A
	RET
;==
; <CONTROL> <P>
;==
$LKCNTP	LD	A,(CPAGE)	; See if beginning
	DEC	A
	JP	Z,$LLOOP	; Loop if at beginning
	CALL	$LSPAGE		; Save page
	JP	NZ,LEDERR
; Alter page structure
	LD	BC,(PVPAGE)	; Previous page
	LD	A,(CPAGE)
	DEC	A
	LD	(CPAGE),A
	POP	HL
	JP	$LEDV1
;==
; <CONTROL> <N>
;==
$LKCNTN	LD	A,(CPAGE)	; See how high
	CP	32
	JP	Z,$LLOOP	; Go back if too high
	CALL	$LSPAGE		; Save page
	JP	NZ,LEDERR
; Alter page structure
	LD	(PVPAGE),BC	; Put in previous page
	LD	BC,(NXPAGE)	; Next page
	LD	HL,0
	LD	(NXPAGE),HL
	LD	A,(CPAGE)
	INC	A
	LD	(CPAGE),A
	POP	HL
	JP	$LEDV1
;---
; Save page of form
;---
$LSPAGE	CALL	SSCRN		; Save screen
	LD	DE,DATA
	LD	(DSTART),DE	; Store start
	CALL	CSDATA		; Convert screen to data
	LD	(DEND),DE	; Store end of data
; See if old or new
	LD	BC,$-$
$LEDB	EQU	$-2
	LD	A,B
	OR	C
	JR	Z,$LKCNN	; Ahead if new
; Old blocks
	LD	A,(MODFLAG)	; See if modified
	OR	A
	RET	Z		; Return if no modifications
	PUSH	BC
	CALL	$LFSO		; Save old form
	POP	BC
	RET
; New blocks
$LKCNN	CALL	DFREE		; Find free block
	RET	NZ
	PUSH	BC	 	; Save block
	CALL	$LFSN		; Save new form
	POP	BC		; Restore block
	RET	NZ
; Make next page of previous page correct (if page > 1)
	LD	A,(APAGE)	; See if first
	DEC	A
	JR	NZ,$LKCNN1
	LD	($LEFB),BC	; Store block number
	RET			; Return if first
$LKCNN1	PUSH	BC		; Save block number
	LD	BC,(PVPAGE)	; Block of previous page
	CALL	DRBLKW		; Read block
	POP	BC		; Restore block
	RET	NZ
	INC	L		; Go to next block
	INC	L
	INC	L
	INC	L
	LD	(HL),C
	INC	L
	LD	(HL),B
	XOR	A
	RET
;---
; Save form (new)
;---
$LFSN	LD	A,(CPAGE)	; See if first page
	DEC	A
	JR	NZ,$LFSN1	; Ahead if not
	CALL	DWFORM		; Write new form to disk
	RET
$LFSN1	CALL	DWPAGE		; Write new page to disk
	RET
;---
; Save form (old)
;---
$LFSO	LD	A,(CPAGE)	; See if first page
	DEC	A
	JR	NZ,$LFSO1	; Ahead if not
	CALL	DWFORMO		; Write form to disk
	RET
$LFSO1	CALL	DWPAGEO		; Write page to disk
	RET
;---
; LEDIT error handler
;---
LEDERR	PUSH	AF
	CALL	RSCRN		; Restore screen
	POP	AF
	CALL	DOSERR		; Display DOS error
	JP	$LEDD2		; Loop
;---
; LEDIT mouse handler
;---
;LEMS	LD	B,1		; Get mouse position
;	SVC	@MOUSE
;	LD	A,E
;	CP	20
;	JP	NC,$LLOOP	; Loop if too high
;	LD	H,E
;	PUSH	HL
;	EXX
;	LD	(LEMS1),BC
;	POP	BC
;	EXX
;	CALL	$LFCF		; Find correct field
;	LD	BC,$-$
;LEMS1	EQU	$-2
;	EXX
;	JP	$LLOOP		; Loop if not correct
;=====
; Line editor without <UP> and <DOWN>
;=====
LEDITO	LD	A,3
	LD	(HKEYB),A
	LD	A,1
	JR	LEDIT1
;=====
; Line editor
; HL => form
; DE => data
;=====
LEDIT:	LD	A,6
	LD	(HKEYB),A
	LD	A,2		; No page keys or print and remove
LEDIT1	LD	($NUD),A
LEDIT2	LD	($LHL),HL	; Store address
	LD	A,1		; Start out at one
	LD	($LFNV),A
	DEC	A
	LD	(MODFLAG),A	; Signal not modified
	CALL	DFRMD		; Display form and data
$LFLP	CALL	$LRSET		; Set up registers
$LFLP1	CALL	DSCRN		; Display screen
	CALL	CURSON		; Turn cursor on
;===
; Alternate registers:
;  BC' = current (X, Y)
;  DE' = end (X, Y)
;  HL' = beginning (X, Y)
;===
; Main loop
$LLOOP	EXX			; Switch back
$LLO1	PUSH	BC		; Move BC
	EXX
	POP	HL		; to HL
	LD	B,3		; Set cursor
	SVC	@VDCTL
	CALL	MSKEY		; Wait for key
;	OR	A		; Ahead if button pressed
;	JP	Z,LEMS
	CP	80H
	JR	NZ,$LKEY
	CALL	CURSOFF		; Turn cursor off
	XOR	A		; Signal <BREAK>
	RET
;---
; Key handler
;---
; Movement keys
$LKEY	CP	136		; <CLEAR> <LEFT>
	JP	Z,$LKCL
	BIT	7,A		; Is it above 127?
	JR	NZ,$LLOOP	; Skip it if so
	CP	32		; Is it above space?
	JR	NC,$LKEYO	; Skip ahead if so
	CP	3		; <CONTROL> <C>
	JR	NZ,$LKEY1
	CALL	CURSOFF
	RET
;===
; Control key combinations
;===
$LKEY1	LD	B,0		; Up or down
$NUD	EQU	$-1
; 1 = no up and down arrows or page keys or print and remove
; 2 = no page keys or print and remove
; 3 = no print and remove
; 4 = everything
	DEC	B		; See if only one
	JR	Z,$LKEY2	; Ahead if only one
	DEC	B
	JR	Z,$LKEY21	; Ahead if two
	DEC	B
	JR	Z,$LKEY20	; Ahead if three
	CP	15		; <CONTROL> <O>
	JP	Z,$LKCNTO
	CP	18		; <CONTROL> <R>
	JP	Z,$LKCNTR
$LKEY20
	CP	14		; <CONTROL> <N>
	JP	Z,$LKCNTN
	CP	16		; <CONTROL> <P>
	JP	Z,$LKCNTP
$LKEY21	CP	10		; <DOWN>
	JP	Z,$LKD
	CP	11		; <UP>
	JP	Z,$LKU
	CP	26		; <SHIFT> <DOWN>
	JP	Z,$LKSD
	CP	27		; <SHIFT> <UP>
	JP	Z,$LKSU
$LKEY2	CP	24		; <SHIFT> <LEFT>
	JP	Z,$LKSL
	CP	25		; <SHIFT> <RIGHT>
	JP	Z,$LKSR
	CP	8		; <LEFT>
	JP	Z,$LKL
	CP	9		; <RIGHT>
	JP	Z,$LKR
	CP	13		; <ENTER>
	JP	Z,$LKENT
	CP	4		; <CONTROL> <D>
	JP	Z,$LKCNTD
	CP	31		; <SHIFT> <CLEAR>
	JP	Z,$LKSC
; Invalid key
	JP	$LLOOP		; Loop
;===
; Ordinary keys
;===
$LKEYO	LD	C,A		; Save key
	LD	(MODFLAG),A	; Signal record is modified
	LD	A,(INSM)	; State of insert mode
	OR	A
	JR	Z,$LOVER	; If overtype, ahead
; Insert key
	PUSH	BC
	EXX
	PUSH	DE		; Save maximum
	EXX
	POP	BC
	CALL	CXY		; Convert to address
	LD	DE,(RMAXV)	; Right maximum
	OR	A
	SBC	HL,DE		; See if same
	POP	BC		; Restore
	JP	Z,$LLOOP	; Loop if same
	PUSH	BC		; Save again
	EXX
	PUSH	BC
	EXX
	POP	BC
	CALL	CXY		; Find address
	EX	DE,HL		; Switch current to DE
	LD	HL,(RMAXV)	; Maximum right value
	RPUSH	HL,HL		; Save maximum
	OR	A
	SBC	HL,DE		; Find actual width
	PUSH	HL		; Move to BC
	POP	BC
	RPOP	HL,DE		; Move to both
	DEC	HL		; Back one
	LDDR
	POP	BC		; Restore BC
	EXX
	INC	E		; Increase maximum
	LD	A,COL
	CP	E
	JR	NZ,$DI1		; If end, wrap over
	INC	D
	LD	E,0
$DI1	EXX
	CALL	CXYA
	LD	(HL),C		; Store character
; Move one character right
	CALL	DSCRN		; Display screen
	JP	$LKR		; Move right
$LOVER	EXX
	RPUSH	BC,DE,HL	; Save all
	CALL	CXY		; Convert to address
	LD	DE,(RMAXV)	; Right maximum
	OR	A
	SBC	HL,DE		; See if same
	RPOP	HL,DE,BC	; Restore all
	EXX
	JP	Z,$LLOOP	; If end of line, loop
	JP	NC,$LLOOP
	CALL	CXYI		; Convert to address
	LD	(HL),C		; Store in key in memory
; Make maximum if higher
	EXX
	RPUSH	HL,DE,BC
	EX	DE,HL
	OR	A
	SBC	HL,BC		; See if higher
	RPOP	BC,DE,HL
	JR	NC,$LO2
	PUSH	BC		; Make current maximum
	POP	DE
$LO2	EXX			; Switch back
	CALL	DSCRN		; Display screen
	JP	$LLOOP		; Ahead to cursor
;==
; <RIGHT>
;==
$LKR	EXX
	EX	DE,HL
	PUSH	HL		; Save maximum
	LD	HL,$-$		; X, Y maximum
RMAXXY	EQU	$-2
	OR	A
	SBC	HL,BC		; See if same
	POP	HL		; Restore
	EX	DE,HL
	JP	Z,$LLO1		; If already, back
	JP	C,$LLO1
	LD	A,C		; Get X value
	CP	COL-1		; Is it end of screen?
	JR	Z,$LKR1		; If so, ahead
	INC	C
	JP	$LLO1
$LKR1	INC	B		; Next Y
	LD	C,0
	JP	$LLO1		; Loop back
;==
; <LEFT>
;==
$LKL	EXX
	PUSH	HL		; Save minimum
	OR	A
	SBC	HL,BC		; See if same
	POP	HL		; Restore HL
	JP	Z,$LLO1		; If already, back
	LD	A,C		; Get X value
	OR	A		; Is it left?
	JR	Z,$LKL1
	DEC	C		; Back one
	JP	$LLO1		; Back
$LKL1	DEC	B		; Back on Y
	LD	C,COL-1		; Put maximum in X
	JP	$LLO1
;==
; <SHIFT> <LEFT>
;==
$LKSL	EXX
	PUSH	HL		; Save minimum
	OR	A
	SBC	HL,BC		; See if at beginning
	POP	HL		; Restore minimum
	JR	Z,$LMU1		; Ahead if beginning
	PUSH	HL		; Otherwise, put at beginning
	POP	BC
	EXX
	JP	$LLOOP		; Loop until done
$LMU1	EXX
	LD	A,($LFNV)	; Field number
	DEC	A		; Is it beginning?
	JP	Z,$LLOOP	; Loop if so
	LD	($LFNV),A	; Store it
	JP	$LFLP		; Loop
;==
; <SHIFT> <UP>
;==
$LKSU	LD	A,($LFNV)	; Current field
	CP	1		; See if already there
	JP	Z,$LLOOP
	LD	A,1		; Otherwise, go to
	LD	($LFNV),A	; first field
	JP	$LFLP		; Loop
;==
; <SHIFT> <RIGHT>
;==
$LKSR	EXX
	EX	DE,HL		; Switch the two
	PUSH	HL		; Save maximum
	OR	A
	SBC	HL,BC		; See if at end
	POP	HL		; Restore maximum
	EX	DE,HL		; Switch them back
	JR	Z,$LSR1		; Ahead if at end
	JR	C,$LSR1		; Ahead if past end
	PUSH	DE		; Otherwise, put at end
	POP	BC
	EXX
	JP	$LLOOP		; Loop until done
$LSR1	EXX
	LD	A,($LFNV)	; Field number
	LD	B,A
	LD	A,(FCOUNT)	; Maximum count
	CP	B		; Is it end?
	JP	Z,$LLOOP	; Loop if so
$LMDD	LD	A,B
	INC	A		; Increment
	LD	($LFNV),A	; Store it
	JP	$LFLP		; Loop
;==
; <SHIFT> <DOWN>
;==
$LKSD	LD	A,($LFNV)	; Current field
	LD	B,A
	LD	A,(FCOUNT)	; Maximum count
	CP	B		; See if same
	JP	Z,$LLOOP	; Loop if already there
	LD	($LFNV),A	; Otherwise, load it
	JP	$LFLP		; Loop
;==
; <ENTER>
;==
$LKENT	LD	A,(FCOUNT)	; Maximum count
	DEC	A		; Is it only one?
	JR	NZ,$LKE0	; Ahead if not
	CALL	CURSOFF		; Cursor off
	RET
; Try to move down
$LKE0	LD	HL,($LHL)	; Address of form
	CALL	SFRM		; Select entire form
	EXX
	PUSH	HL		; Get X, Y of minimum
	EXX
	POP	BC		; Put in BC
; Back up two spaces
	DEC	C		; Back up two
	JR	Z,$LKEX
	DEC	C
; Go down once
$LKEX	INC	B		; Increment Y
	LD	A,ROW-3		; See if past
	CP	B
	JR	Z,$LKEYW	; Ahead if off screen
	CALL	CXY		; Convert to address
	BIT	7,(HL)		; See if reverse
	JR	Z,$LKEX		; Loop if not
; See if after field
	PUSH	BC		; Save X, Y
	EXX
	POP	BC		; Restore X, Y
	EXX			; Switch registers
	LD	($LKV),BC	; Store X, Y
	CALL	$LFCF		; Find correct field
	LD	BC,$-$
$LKV	EQU	$-2
	JR	$LKEX		; Loop if not
; Wrap-around
$LKEYW	LD	B,255		; Top of screen (minus one)
	INC	C		; Increment X
	LD	A,C		; See if at end
	CP	COL
	JR	NZ,$LKEX	; Loop until done
; Return
	CALL	CURSOFF		; Cursor off
	RET
;==
; <CONTROL> <D>
;==
$LKCNTD	LD	(MODFLAG),A	; Signal record is modified
	EXX			; Switch registers
	PUSH	HL		; Save
	PUSH	DE		; Move maximum to HL
	POP	HL
	OR	A		; Reset carry
	SBC	HL,BC		; Is it at end?
	POP	HL
	JP	Z,$LLO1		; Loop if at end
	JP	C,$LLO1		; Loop if past end
	RPUSH	HL,DE,BC	; Save registers
	CALL	CXY		; Convert to address
	EX	DE,HL		; Put address in DE
	PUSH	HL		; Move maximum to BC
	POP	BC
	CALL	CXY		; Convert to address
	PUSH	DE		; Save address
	PUSH	DE		; and again
	OR	A
	SBC	HL,DE		; Find length
	PUSH	HL		; Move to BC
	POP	BC
	POP	HL		; Restore HL
	POP	DE		; Put in DE
	INC	HL		; Back one
	LDIR			; Move it
	CALL	DSCRN		; Display screen
	RPOP	BC,DE,HL	; Restore registers
	DEC	E		; Back one
	JP	NZ,$LLO1	; Ahead if nothing
	DEC	D		; Back Y
	LD	E,COL		; Put in X
	JP	$LLO1		; Loop
;==
; <CLEAR> <LEFT>
;==
$LKCL	EXX
	PUSH	HL		; Save minimum
	OR	A
	SBC	HL,BC		; See if same
	POP	HL		; Restore HL
	JP	Z,$LLO1		; If already, back
	LD	A,C		; Get X value
	OR	A		; Is it left?
	JR	Z,$LKCL1
	DEC	C		; Back one
	EXX
	JR	$LKCNTD		; Go to delete
$LKCL1	DEC	B		; Back on Y
	LD	C,COL-1		; Put maximum in X
	EXX
	JR	$LKCNTD		; Go to delete
;==
; <SHIFT> <CLEAR>
;==
$LKSC	LD	(MODFLAG),A	; Signal record is modified
	EXX			; Switch registers
	RPUSH	HL,DE,BC	; Save registers
	PUSH	HL		; Move minimum
	POP	BC		; to BC
	CALL	CXY		; Convert to address
; Minimum in DE
	EX	DE,HL		; Move to DE
	PUSH	HL		; Move maximum
	POP	BC		; to BC
	CALL	CXY		; Convert to address
	PUSH	DE		; Save minimum address
	OR	A
	SBC	HL,DE		; Find difference
	EX	DE,HL		; Move to DE
	POP	HL		; Put in HL
$LKCS1	LD	A,D		; See if zero
	OR	E
	JR	Z,$LKCS2	; Ahead if zero
	LD	(HL),32		; Zero character
	INC	HL		; Next byte
	DEC	DE		; Previous count
	JR	$LKCS1
$LKCS2	CALL	DSCRN		; Display screen
	RPOP	BC,DE,HL	; Restore registers
	PUSH	HL		; Move minimum
	POP	DE
	PUSH	HL		; to all
	POP	BC
	JP	$LLO1
;==
; <UP>
;==
$LKU	EXX
	LD	A,B		; See if beginning
	OR	A
	JR	Z,$LMUS1
	DEC	B		; Up one position
	JR	$LMUS2
$LMUS1	LD	B,ROW-4		; Bottom of screen
$LMUS2	EXX			; Switch registers
	CALL	$LFCF		; Find correct field
	JR	$LKU		; Loop if not correct
;==
; <DOWN>
;==
$LKD	EXX
	LD	A,B		; See if end
	CP	ROW-4
	JR	Z,$LMDS1
	INC	B		; Down one position
	JR	$LMDS2
$LMDS1	LD	B,0		; Top of screen
$LMDS2	EXX			; Switch registers
	CALL	$LFCF		; Find correct field
	JR	$LKD		; Loop if not correct
; Find correct field according to cursor
$LFCF	LD	HL,($LHL)	; Address of form
	XOR	A		; Store field counter
	LD	($LFNV),A
	LD	B,A		; Initialize counter
	PUSH	HL
$LFL	LD	A,(HL)		; Get byte
	CP	0FEH		; Is it comment?
	JR	Z,$LF1		; Skip if so
	INC	A		; See if end of form
	JR	Z,$LFS		; Success if so
; See if past entry
	INC	HL		; Next byte (Y)
	LD	A,(HL)
	DEC	HL		; Back to X
	EXX
	CP	B		; Compare with Y
	EXX
	JR	C,$LFF		; Ahead if too early
	JR	NZ,$LFS		; Success if past
	LD	A,(HL)		; Get X
	EXX
	CP	C		; Compare with X
	EXX
	JR	Z,$LFF		; Ahead if exactly the same
	JR	C,$LFF		; Ahead if too early
; Success!
$LFS	POP	HL
	INC	HL		; Past Y
	INC	HL		; to TYPE
	LD	A,(HL)		; Get byte
	CP	7		; See if title
	RET	C		; Return if successful failure
	DEC	HL
	DEC	HL
	EX	(SP),HL		; Eliminate call
	POP	HL
	EXX
	PUSH	BC		; Save X, Y
	EXX
; Need to determine if after title
	CALL	$LRSET		; Set up registers
	EXX
	POP	BC		; Restore X, Y
	EXX
	CALL	CXYA		; Convert to HL
	BIT	7,(HL)		; See if reverse video
	JR	NZ,$LFSF	; Jump ahead if reverse
	DEC	HL		; See if after colon
	BIT	7,(HL)
	JR	NZ,$LFSF	; Ahead if not succesful
	LD	DE,(RMAXV)	; See if past maximum
	OR	A
	PUSH	HL
	SBC	HL,DE
	POP	HL
	JP	C,$LFLP1	; Loop if not past
	EX	DE,HL
	JR	$L87
$LFSF	INC	HL		; Next byte
	BIT	7,(HL)		; See if reverse
	JR	NZ,$LFSF	; Loop if reverse
	INC	HL		; Go past space
$L87	CALL	CADXY		; Convert to X, Y
	PUSH	BC		; Put in BC'
	EXX
	POP	BC
	EXX
	JP	$LFLP1		; Jump back
; Failure!
$LFF	EX	(SP),HL		; Push on stack
	POP	HL
	PUSH	HL
	INC	B		; Increase counter
	LD	A,B		; Put into memory
	LD	($LFNV),A
	INC	HL		; Past X, Y
	INC	HL
	LD	A,(HL)		; Get type
	INC	HL		; Next byte
	CP	7		; Is it title or above?
	JR	C,$LF0		; If so, ahead
	INC	HL		; Past number
	INC	B		; Compensate for title
$LF0	DEC	B		; Decrease count
$LF1	LD	A,(HL)		; Get byte
	INC	HL
	OR	A
	JR	NZ,$LF1		; Loop until next
	JR	$LFL		; Loop until done
;---
; Sets up registers according to $LFNV
;---
; Display form
$LRSET	LD	HL,$-$		; Get address
$LHL	EQU	$-2
	PUSH	HL		; Save HL
	CALL	DFRM		; Display form
; Highlight field
	POP	HL		; Restore
	LD	B,1		; Field number
$LFNV	EQU	$-1
	CALL	SFN		; Select field
	PUSH	DE		; Save address
; Find maximum length (if fixed length)
	LD	BC,0		; Maximum length
MLV	EQU	$-2
	LD	A,B		; Is it zero?
	OR	C
	JR	Z,$LFL0		; If nothing, ahead
	PUSH	BC		; Move to HL
	POP	HL
	ADD	HL,DE		; Add value and length
	INC	HL		; Make correct length
	INC	HL
	JR	$LED10A		; Move ahead
; Find actual maximum length
$LFL0	LD	A,(HL)		; Get byte
	CP	0FFH		; Is it end?
	JR	NZ,$LFL1	; Ahead if not
	LD	BC,ROW-3<8+0	; Move to end
	JR	$LFL2		; Skip past
$LFL1	LD	C,(HL)		; Load X, Y
	INC	HL
	LD	B,(HL)
$LFL2	EXX
	CALL	CXYA		; Convert to address
; Absolute maximum in RMAXV (address)
$LED10A	DEC	HL
	LD	(RMAXV),HL	; Store maximum right
	CALL	CADXY		; Convert to X, Y
	LD	(RMAXXY),BC	; Store X, Y
	INC	HL
$LED1	DEC	HL		; Back one
	LD	A,(HL)		; Get byte
	CP	32		; Is it space?
	JR	Z,$LED1		; Loop if so
	CALL	CADXY		; Convert back to X, Y
; Address of end of field name
	POP	HL		; Move to stack
	PUSH	BC
	INC	HL		; Ahead one
	CALL	CADXY		; Convert to X, Y
	PUSH	BC		; Move to alternate
	PUSH	BC
	EXX
	POP	BC		; In current
	POP	HL		; Also minimum
	POP	DE		; Maximum
	INC	E
	LD	A,L		; See if empty
	DEC	A
	CP	E
	JR	NZ,$LED1A	; Ahead if not
	INC	E		; If so, one forward
$LED1A	EXX
	RET
;=====
; Screen editor
; without disk
;=====
SEDITND:
	LD	A,5
	LD	(HKEYB),A
	XOR	A		; Not modified
	LD	(EXTENDE),A
	LD	(MODFLAG),A
	LD	(FPFLAG),A
	INC	A
	LD	(SND),A
	CALL	DINFO
	JP	$SEDNF		; Jump ahead
;=====
; Screen editor
; with disk
;=====
SEDIT:	LD	A,5
	LD	(HKEYB),A
	XOR	A		; Eliminate extend error
	LD	(EXTENDE),A
	LD	(MODFLAG),A	; Signal not modified
	LD	(SND),A
	INC	A		; Force screen form zero
	LD	(CPAGE),A
	LD	HL,CFRM$	; Display message
	CALL	DMB
$SEDIT1	XOR	A
	LD	(PPLUS),A	; Make not plus
	LD	(PMINUS),A	; Make not minus
	LD	A,(CPAGE)	; Get page
	DEC	A		; See if first page
	JR	Z,$SPL
	INC	A
	LD	(PMINUS),A	; Make minus if so
	DEC	A
$SPL	CP	31		; See if end
	JR	Z,$SMI		; Ahead if last page
	INC	A
	CALL	DFSF		; Find screen form
	LD	A,B		; See if nothing
	OR	C
	JR	Z,$SMI		; Ahead if nothing
	LD	(PPLUS),A	; Create plus sign
$SMI	LD	HL,0
	LD	(CFORM),HL	; Turn off form display
	LD	A,1
	LD	(FPFLAG),A	; Turn on page display
	CALL	DINFO		; Display information line
	CALL	CSCRN		; Clear screen
	CALL	SSCRN		; Save screen
; Load screen form (if it exists)
	LD	A,(CPAGE)
	DEC	A
	CALL	DFSF		; Find default screen form
	LD	($CSFB),BC	; Store current block
	LD	A,0FFH		; Zero form buffer
	LD	(FORM),A
	LD	(APAGE),A	; Eliminate page
	LD	A,B		; See if nothing
	OR	C
	JR	Z,$SEDNF	; Ahead if nothing
	LD	DE,FORM		; Form address
	CALL	DRDATA		; Read screen form
	JP	NZ,SEDERR	; Ahead if error
	LD	A,(CPAGE)	; Make correct page
	LD	(APAGE),A
	LD	HL,FORM		; Form address
	CALL	DFRM		; Display form
; Display screen and wait for key
$SEDNF	CALL	DSCRN		; Display screen
	CALL	CURSON		; Turn cursor on
	EXX			; Switch registers
	LD	BC,0		; Upper left
	EXX
; Main loop
$SLOOP:	EXX			; Switch back
	PUSH	BC		; Move BC
	EXX
	POP	HL		; to HL
	LD	B,3		; Set cursor
	SVC	@VDCTL
	CALL	MSKEY		; Wait for key
;	OR	A		; Ahead if button pressed
;	JP	Z,SEMS
	CP	80H
	JR	NZ,$SKEY
;==
; <BREAK>
;==
	CALL	CURSOFF		; Turn cursor off
	LD	A,(EXTENDE)	; See if extend error
	OR	A
	JR	Z,$SKBRK2	; Ahead if no error
; Verify exit
	CALL	SSCRN		; Save screen
	CALL	CSCRN		; Clear screen
; Play sound
	LD	A,48
	LD	(HTOPIC),A
	LD	HL,WARN1$	; Disk space warning
	CALL	DMENUB		; Display menu with beep
	CP	1		; Is it YES?
	JR	Z,$SKBRK1	; Exit if so
; Do not exit
	CALL	RSCRN		; Restore screen
	JR	$SEDNF		; Loop back
; Exit
$SKBRK1	LD	BC,0		; Zero screen form
	CALL	$SSBSF
$SKBRK2	XOR	A
	LD	(FPFLAG),A	; Turn off display
	CALL	DINFO		; Display information line
	XOR	A		; Signal <BREAK>
	RET
;---
; Key handler
;---
$SKEY	CP	136		; <CLEAR> <LEFT>
	JP	Z,$SKCL
	CP	160		; Reverse space
	JP	Z,$SKEYO
	BIT	7,A		; Is it above 127?
	JR	NZ,$SLOOP	; Skip it if so
	CP	32		; Is it above space?
	JR	NC,$SKEYO	; Skip ahead if so
; Skip disk routines if necessary
	LD	C,A
	LD	A,0		; 0 if disk, 1 if not
SND	EQU	$-1
	OR	A
	LD	A,C
	JR	Z,$SKEY0	; Skip past
	CP	3		; <CONTROL> <C>
	JR	NZ,$SKEY1
	LD	A,255
	RET
$SKEY0	CP	3		; <CONTROL> <C>
	JP	Z,$SKCNTC
	CP	14		; <CONTROL> <N>
	JP	Z,$SKCNTN
	CP	16		; <CONTROL> <P>
	JP	Z,$SKCNTP
$SKEY1	CP	4		; <CONTROL> <D>
	JP	Z,$SKCNTD
	CP	12		; <CONTROL> <L>
	JP	Z,$ZKDELL
	CP	19		; <CONTROL> <S>
	JP	Z,$ZKSPLIT
	CP	8		; <LEFT>
	JR	Z,$SKL
	CP	9		; <RIGHT>
	JR	Z,$SKR
	CP	10		; <DOWN>
	JP	Z,$SKD
	CP	11		; <UP>
	JR	Z,$SKU
	CP	24		; <SHIFT> <LEFT>
	JR	Z,$SKSL
	CP	25		; <SHIFT> <RIGHT>
	JR	Z,$SKSR
	CP	26		; <SHIFT> <DOWN>
	JR	Z,$SKSD
	CP	27		; <SHIFT> <UP>
	JR	Z,$SKSU
	CP	13		; <ENTER>
	JP	Z,$SKENT
	JP	$SLOOP		; Ignore key
; Ordinary keys
$SKEYO	LD	C,A		; Save key
	LD	(MODFLAG),A
	LD	A,(INSM)	; State of insert mode
	OR	A
	JR	Z,$SOVER	; If overtype, ahead
; Insert mode
	PUSH	BC
	CALL	CXYA		; Find address
	LD	A,COL		; Width of screen
	EXX
	SUB	C		; Subtract X
	EXX
	LD	C,A		; Put width in BC
	LD	B,0
	DEC	C		; Back one
	JR	Z,$SINS1	; No insert
	ADD	HL,BC		; Add width to it
	DEC	HL		; Back one
	PUSH	HL		; Copy HL
	POP	DE		; to DE
	INC	DE
	LDDR			; Delete block
$SINS1	POP	BC
	CALL	CXYA		; Convert to address
	LD	(HL),C		; Store key in memory
	CALL	DSCRN		; Display screen
	JP	$SKR		; Move right
; Overtype
$SOVER	CALL	CXYI		; Convert to address
	LD	(HL),C		; Store in key in memory
	CALL	DSCRN		; Display screen
	JP	$SLOOP		; Ahead to cursor
;==
; <RIGHT>
;==
$SKR	EXX
	LD	A,C		; Get X value
	INC	C
	CP	COL-1		; Is it end of screen?
	JR	NZ,$SKD1	; If not, ahead
	DEC	C
	LD	A,B
	CP	ROW-4		; Is it at end?
	JR	Z,$SKD1
	LD	C,0		; Otherwise, zero out
	JR	$SKD0		; and go down
;==
; <SHIFT> <RIGHT>
;==
$SKSR	EXX
	LD	C,COL-1		; Maximum X value
	JR	$SKD1
;==
; <LEFT>
;==
$SKL	EXX
	LD	A,C		; Get X value
	DEC	C
	OR	A		; Is it left?
	JR	NZ,$SKD1	; If not, skip
	INC	C
	INC	B		; Y value
	DEC	B
	JR	Z,$SKD1
	LD	C,COL-1		; Otherwise, put on right side
	JR	$SKU0		; and go up
;==
; <SHIFT> <LEFT>
;==
$SKSL	EXX
	LD	C,0		; Minimum X
	JR	$SKD1
;==
; <UP>
;==
$SKU	EXX
$SKU0:	LD	A,B		; Get Y value
	OR	A		; Is it up?
	JR	Z,$SKD1
	DEC	B		; Back one
	JR	$SKD1
;==
; <SHIFT> <UP>
;==
$SKSU	EXX
	LD	B,0
	JR	$SKD1
;==
; <SHIFT> <DOWN>
;==
$SKSD	EXX
	LD	B,ROW-4
	JR	$SKD1
;==
; <DOWN>
;==
$SKD	EXX
$SKD0:	LD	A,B		; Get Y value
	CP	ROW-4		; Is it end of screen?
	JR	Z,$SKD1
	INC	B		; Down one
$SKD1	EXX
	JP	$SLOOP		; Key loop
;==
; <CONTROL> <D>
;==
$SKCNTD	LD	(MODFLAG),A	; Signal modification
	CALL	CXYA		; Find address
	LD	A,COL		; Width of screen
	EXX
	SUB	C		; Subtract X
	EXX
	DEC	A		; Decrement one
	JR	Z,$SDC0		; If zero, loop
	LD	C,A		; Put width in BC
	LD	B,0
	PUSH	HL		; Copy HL
	POP	DE		; to DE
	INC	HL
	LDIR			; Delete block
	EX	DE,HL		; Switch them
$SDC0	LD	(HL),32		; Blank out end
	CALL	DSCRN		; Display screen
	JP	$SLOOP		; Key loop
;==
; <ENTER>
;==
$SKENT	EXX
	LD	A,B		; Get Y value
	CP	ROW-4		; Is it end of screen?
	JR	Z,$SKD1
	INC	B		; Down one
	LD	C,0		; Make X minimum
	JR	$SKD1
;==
; <CLEAR> <LEFT>
;==
$SKCL	EXX
	LD	A,C		; Get X value
	OR	A		; Is it left?
	JP	Z,$SKD1
	DEC	C		; Back one
	EXX
	JP	$SKCNTD		; Delete character
;==
; <CONTROL> <N>
;==
$SKCNTN	LD	A,(CPAGE)	; See if past
	CP	32
	JP	Z,$SLOOP	; Ahead if too many
	CALL	$SFSAVE		; Save current form to disk
	JP	NZ,SEDERR	; Ahead if error
	LD	A,(CPAGE)	; Increment page
	INC	A
	LD	(CPAGE),A	; Store page
	JP	$SEDIT1		; Move ahead
;==
; <CONTROL> <P>
;==
$SKCNTP	LD	A,(CPAGE)	; See if at beginning
	DEC	A
	JP	Z,$SLOOP	; Ahead if too many
	CALL	$SFSAVE		; Save current form to disk
	JP	NZ,SEDERR	; Ahead if error
	LD	A,(CPAGE)	; Increment page
	DEC	A
	LD	(CPAGE),A	; Store page
	JP	$SEDIT1		; Move ahead
;==
; <CONTROL> <C>
;==
$SKCNTC	CALL	$SFSAVE		; Save screen form to disk
	JP	NZ,SEDERR	; Ahead if error
	XOR	A
	LD	(FPFLAG),A	; Eliminate display
	CALL	DINFO		; Display information line
	LD	A,255
	RET
;==
; <CONTROL> <L>
; Concatenate line
;==
; Final byte of screen to consider
SCEND	DEFL	ROW-3*80-1+SCRN
$ZKDELL:
	LD	(MODFLAG),A	; Signal modified
	RPUSH	HL,DE,BC
	EXX
	PUSH	BC		; Move Y, X (BC')
	EXX
	POP	BC		; to BC
; See if on final line
	LD	A,B
	CP	ROW-4
	JR	Z,$SPOUT1	; Skip LDIR if so
; Transfer part of line
	PUSH	BC
	CALL	CXY		; Convert to address
	LD	A,COL		; Calculate length
	SUB	C
	LD	C,A
	LD	B,0
	LD	D,H		; Move to DE
	LD	E,L
	ADD	HL,BC
	LDIR			; Move it
	POP	BC
; See if on next to final line
	LD	A,B
	CP	ROW-5
	JR	Z,$SPOUT	; Delete bottom line
; Otherwise, scroll up
	PUSH	BC
	LD	C,0
	INC	B
	CALL	CXY
	LD	D,H
	LD	E,L
	LD	BC,COL		; Make next line
	ADD	HL,BC
	POP	BC
	PUSH	HL		; Save setup
	LD	B,H		; Move to BC
	LD	C,L
	LD	HL,SCEND	; Screen end
	OR	A
	SBC	HL,BC		; Find difference
	LD	B,H		; Move to BC
	LD	C,L
	INC	BC		; Increase count
	POP	HL
	LDIR			; Do transfer
; Now delete final line
$SPOUT:	LD	HL,ROW-4*COL+SCRN
	LD	DE,ROW-4*COL+SCRN+1
	LD	BC,COL-1
$SPL8:	LD	(HL),32
	LDIR			; Space it out
	CALL	DSCRN		; Display the screen
	RPOP	BC,DE,HL
	JP	$SLOOP
; Delete rest of line
$SPOUT1:
	CALL	CXY		; Convert to HL
	LD	D,H
	LD	E,L
	INC	DE
	LD	A,COL
	SUB	C
	LD	C,A
	LD	B,0
	JR	$SPL8		; Jump into it
;==
; <CONTROL> <S>
; Split line
;==
$ZKSPLIT:
	LD	(MODFLAG),A	; Signal modified
	RPUSH	HL,DE,BC
	EXX
	PUSH	BC		; Move Y, X (BC')
	EXX
	POP	BC		; to BC
; Find difference
	CALL	CXY		; Find address
	LD	($R67T),HL
	LD	A,COL
	SUB	C		; Find difference
	LD	($R68T),A
	LD	($RTYY7),A
	LD	A,B
	CP	ROW-4
	JR	Z,$ZGOEND
; Move lines down
	RPUSH	HL,DE,BC
	INC	B
	INC	B
	LD	C,0		; Set to zero
	CALL	CXY		; Find address
	EX	DE,HL
	LD	HL,SCEND	; End of screen
	OR	A
	SBC	HL,DE
	JR	C,$WESD		; Skip if overflow
	LD	B,H		; Found length
	LD	C,L
	LD	HL,SCEND-COL
	LD	DE,SCEND
	INC	BC
	LDDR
; Blank out line
	INC	HL
	LD	D,H
	LD	E,L
	INC	DE
	LD	BC,COL-1
	LD	(HL),32
	LDIR
$WESD:	RPOP	BC,DE,HL
; Split lines
	LD	C,0
$RTYY7	EQU	$-1
	LD	B,0
; Compute start addresses
	LD	D,H
	LD	E,L
	ADD	HL,BC		; Add it on
	EX	DE,HL
	LDIR			; Move it
; Blank out the rest
$ZGOEND:
	LD	HL,$-$
$R67T	EQU	$-2
	LD	C,0
$R68T	EQU	$-1
	LD	B,0
	LD	D,H
	LD	E,L
	INC	DE
	LD	(HL),32
	DEC	C		; Go back, and skip LDIR if 0
	JR	Z,$Y99
	LDIR			; Blank out rest of line
$Y99:	CALL	DSCRN		; Display it
	RPOP	BC,DE,HL
	JP	$SLOOP
;---
; Save screen form to disk
;---
$SFSAVE	LD	A,(MODFLAG)	; See if modified
	OR	A
	RET	Z		; Return if not
	XOR	A		; No extend error
	LD	(EXTENDE),A
	CALL	CURSOFF		; Turn cursor off
	CALL	SSCRN		; Save screen
	CALL	CSFRM		; Convert to form
	RET	NZ		; Return if error
	LD	A,255
	LD	(DE),A		; End form
	INC	DE
; Prepare to save data
	LD	(DEND),DE	; End of data to save
	LD	HL,FORM		; Start of form
	LD	(DSTART),HL	; Start of data to save
	LD	BC,$-$		; Current block
$CSFB	EQU	$-2
	LD	A,B		; See if new needed
	OR	C
	JR	NZ,$SENO	; Ahead if old blocks
; Need to write new blocks
	CALL	DFREE		; Reserve available block
	RET	NZ
	PUSH	BC		; Save block number
	CALL	DWDATA		; Write new data
	POP	BC		; Restore block number
	RET	NZ
; Store block number in screen form
	CALL	$SSBSF
	CALL	FREC0		; Flush record zero
	RET	NZ
	LD	(MODFLAG),A
	RET
$SENO	CALL	DWDATAO		; Save to disk
	RET	NZ
	CALL	FREC0
	RET	NZ
	LD	(MODFLAG),A
	RET
;---
; Store block in screen form
;---
$SSBSF	LD	A,(CPAGE)	; Get form number
	DEC	A
SSFB	LD	HL,HEADER+8	; Record 0 buffer
	ADD	A,A		; Double number
	ADD	A,L		; Find correct position
	LD	L,A		; Put back in L
	LD	(HL),C		; Save block number
	INC	L
	LD	(HL),B
	RET
;---
; SEDIT error handler
;---
SEDERR	PUSH	AF
	CALL	RSCRN		; Restore screen
	POP	AF
	CALL	DOSERR		; Display DOS error
	JP	$SEDNF		; Loop
;---
; SEDIT mouse handler
;---
;SEMS	LD	B,1		; Get mouse position
;	SVC	@MOUSE
;	LD	A,E		; See if past
;	CP	20
;	JP	NC,$SLOOP
;	LD	H,E		; Calculate text cursor
;	PUSH	HL
;	EXX
;	POP	BC		; Set to cursor
;	EXX
;	JP	$SLOOP		; Loop
MODFLAG	DB	0
;===
; Blank form
;===
NOTES	DB	0,0,8,1,'NOTES:',0,0FFH
NOTESL	EQU	$-NOTES
;===
; Disk space warning
;===
WARN1$	DB	2
	DB	36,6,1,'WARNING!',0
	DB	12,8,1,'There was not enough disk space to'
	DB	' save this screen form',0
	DB	13,9,1,'If you exit now, it will be destroyed!',0
	DB	20,11,1,'Do you still want to exit?',0
	DB	48,11,8,'Y','YES',0
	DB	53,11,8,'N','NO',0
	DB	255
RMVSQ	DB	1
	DB	24,8,1,'This form is about to be removed',0
 	DB	18,10,1,'Are you sure you want it removed?',0
	DB	53,10,8,'Y','YES',0
	DB	0FEH,'Yes, remove this form',0
	DB	58,10,8,'N','NO',0
	DB	0FEH,'No, return to main menu',0
	DB	255
