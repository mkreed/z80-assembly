;-------------------------------------
; DATA-MINDER database manager
; copyright (c) 1995, by Matthew Reed
; all rights reserved
; DMUNI/ASM, universal routines
;-------------------------------------
;---
; Recognize keyboard and mouse input
;---
MSKEY:
;	JR	KEY		; Ahead to only key
;MKEY	LD	B,1		; Get mouse X, Y
;	SVC	@MOUSE
;	LD	H,E		; Convert to 8 bit X, Y
;	LD	(PXY),HL	; Stuff in routine
;	LD	B,1		; Get byte at X, Y
;	SVC	@VDCTL
;	LD	(PCHAR),A	; Stuff in routine
;	XOR	128		; Make reverse video
;	LD	C,A
;	LD	B,2		; Put cursor at X, Y
;	SVC	@VDCTL
;KM1	LD	B,1		; Get mouse X, Y, buttons
;	SVC	@MOUSE
;	AND	00000111B	; Are buttons pressed?
;	CP	00000111B
;	JR	Z,KM2		; Ahead if not
;	XOR	A		; Make A zero and return
;	JR	PTROFF
;KM2	LD	D,E		; Convert to 8 bit X, Y
;	LD	E,L		; in DE
;	LD	HL,(PXY)	; Old pointer coordinates
;	OR	A
;	SBC	HL,DE		; Are they different?
;	JR	Z,MKBD		; If no change, keyboard
;	CALL	PTROFF		; Remove pointer
;	JR	MKEY		; Loop
;MKBD	CALL	KBD		; Is there key?
;	JR	NZ,KM1		; If not, loop
;PTROFF	RET			; Removed if there is mouse
;	PUSH	AF		; Get byte
;	LD	HL,$-$		; Screen address
;PXY	EQU	$-2
;	LD	C,0		; Character at pointer
;CHAR	EQU	$-1
;	LD	B,2
;	SVC	@VDCTL		; Put on screen
;	POP	AF		; Restore byte
;	OR	A		; Set to NZ
;	RET
KEY	LD	A,(UKEYM)	; User key marker
	CP	'P'+128
	JP	Z,PKEY7		; Play back key
KEY5	CALL	KBD		; Is there key?
	JR	NZ,KEY
	RET
KBD	LD	A,($-$)		; Get minute byte
TIME1$	EQU	$-2
	CP	0		; Compare with current minute
MIN	EQU	$-1
	JR	Z,KBD01		; Ahead if same
	LD	(MIN),A		; Store new minute
	CALL	DDTIME		; Display date and time
;	CALL	PTROFF		; Turn pointer off
	CALL	DSCRN		; Display screen
	POP	HL		; Remove call
	JR	MSKEY		; Loop
;
KBD01	SVC	@KBD		; Is there key?
	RET	NZ
	OR	A		; Is it <CONTROL> <@>?
	JR	Z,KBD0
	CP	129		; Is it <F1>?
	JR	Z,KF1
	CP	130		; Is it <F2>?
	JR	Z,KF2
	CP	131		; Is it <F3>?
	JR	Z,KF3
	CP	21		; Is it <CONTROL> <U>?
	JP	Z,KCU
	CP	177		; Is it <CLEAR> <1>?
	JP	Z,KC1
	CP	1		; Is it <CONTROL> <A>?
	JR	Z,KF3
	LD	B,0
KCQ	EQU	$-1
	DEC	B
	JR	Z,KBD1		; Skip if if help
; Help entries
	CP	28		; <CONTROL> <?>
	JR	Z,KHELP
	CP	91H		; <SHIFT> <F1>
	JR	Z,KHELP1
	CP	92H		; <SHIFT> <F2>
	JR	Z,KHELP1
	CP	93H		; <SHIFT> <F3>
	JR	Z,KHELP3
	JR	KBD1
;
KF3:	CALL	TINSERT		; Toggle insert
KBD0	OR	1
	RET
KF1	LD	A,3
	JR	KBD1
KF2	LD	A,4
KBD1	LD	B,A		; Save A
	LD	A,(UKEYM)	; Marker
	CP	'-'
	LD	A,B		; Restore A
	JR	Z,KBD99
	PUSH	HL		; Save HL
	LD	HL,$-$		; User key buffer
UKEYA	EQU	$-2
	LD	(HL),A		; Store key
	INC	L
	PUSH	AF
	DEC	L		; See if zero
	POP	AF
	INC	HL
	LD	(UKEYA),HL	; Store address
	PUSH	AF
	CALL	Z,KCU		; Turn it off
	POP	AF
	POP	HL
KBD99	CP	A		; Signal key
	RET
KHELP:	LD	A,0
HTOPIC	EQU	$-1
KH1:	RPUSH	HL,DE,BC
	PUSH	AF
	LD	A,1
	LD	(KCQ),A
	POP	AF
	CALL	DHELP		; Display help
; Flush type-ahead buffer
$KBD1:	SVC	@KBD
	JR	Z,$KBD1
; Eliminate BREAK bit
	SVC	@CKBRKC
	RPOP	BC,DE,HL
	LD	A,255
	LD	(KCQ),A
	CP	A
	RET
; SHIFT F1 or F2
KHELP1:	SUB	91H		; Determine topic
	JR	KH1
; Special F3 handler
KHELP3:	LD	A,(HKEYB)	; Special keyboard
	JR	KH1
;;;
; User key define
KCU	LD	A,(UKEYM)	; Marker
	CP	'-'
	LD	A,'U'+128	; Turn it on (if off)
	JR	Z,KCUOFF
	CP	'P'+128		; See if playback
	JR	Z,KCUO5
	LD	HL,(UKEYA)	; Address
	LD	(HL),0
KCUO5	LD	A,'-'		; Turn it off
KCUOFF	LD	(UKEYM),A
	LD	HL,UKEYB	; Buffer
	LD	(UKEYA),HL	; Reset buffer
	LD	A,(UKEYM)	; Possible user key
	LD	(ROW-2*COL+SCRN-1),A
	CALL	DSCRN
	OR	1
	RET
; User key playback
KC1	LD	A,(UKEYM)	; See if still defining
	CP	'-'
	RET	NZ		; Return if so
	LD	HL,UKEYB	; Buffer
	LD	(UKEYA),HL
	LD	A,'P'+128
	LD	(UKEYM),A	; Store it
	LD	A,(UKEYM)	; Possible user key
	LD	(ROW-2*COL+SCRN-1),A
	CALL	DSCRN
	OR	1
	RET
; Play back key
PKEY7	LD	HL,(UKEYA)	; User key address
	LD	A,(HL)		; Get byte
	INC	HL
	LD	(UKEYA),HL	; Store new address
	OR	A
	JR	Z,PKEY71	; Ahead if key
	CP	A		; Return key
	RET
PKEY71	CALL	KCUO5		; Turn it off
	JP	KEY5		; Wait for key
;---
; Clear screen buffer
;---
CSCRN	RPUSH	HL,DE,BC
	LD	HL,SCRN		; Clear screen
	LD	DE,SCRN+1
	LD	BC,ROW-3*COL-1
	LD	(HL),32
	LDIR			; Clear it
	RPOP	BC,DE,HL
	RET
;---
; Save screen buffer
;---
SSCRN	RPUSH	HL,DE,BC
	LD	HL,SCRN
	LD	DE,SCRN1
	LD	BC,ROW*COL-1
	LDIR
	RPOP	BC,DE,HL
	RET
;---
; Restore screen buffer
;---
RSCRN	RPUSH	HL,DE,BC
	CALL	PCLS
RSCRN9	LD	DE,SCRN
	LD	HL,SCRN1
	LD	BC,ROW*COL-1
	LDIR
RSCRN8	RPOP	BC,DE,HL
	RET
;---
; Display mode bar
; HL => message
;---
DMB	RPUSH	BC,DE,HL
	LD	HL,ROW-3*COL+SCRN
	LD	DE,ROW-3*COL+SCRN+1
	LD	BC,COL-1
	LD	(HL),'-'
	LDIR
	POP	HL		; Restore HL
	LD	A,(HL)		; Get length
	INC	HL		; Next byte
	PUSH	HL		; Save HL again
	LD	C,A		; Put in BC
	LD	B,0
	LD	A,COL		; Width of screen
	SUB	C		; Subtract message
	SRL	A		; Divide by 2
	LD	E,A		; Put in DE
	LD	D,0
	LD	HL,ROW-3*COL+SCRN
	ADD	HL,DE		; Add them
	EX	DE,HL		; Switch to DE
	POP	HL		; Restore again
	LD	A,32
	LD	(DE),A
	INC	DE
	DEC	C
	DEC	C
	LDIR			; Transfer
	LD	A,32
	LD	(DE),A
	LD	A,'-'		; Possible user key
UKEYM	EQU	$-1
	LD	(ROW-2*COL+SCRN-1),A
	RPOP	DE,BC
	RET
;---
; Display screen buffer
;---
DSCRN	NOP
DSCRN1	RPUSH	HL,DE,BC
	LD	HL,SCRN
DSCRN2	LD	B,5		; Display screen
	SVC	@VDCTL		; Display it
	RPOP	BC,DE,HL
	RET
; Change cursor character
CCURS	LD	B,8		; Function number
	SVC	@VDCTL
	RET
; Turn cursor on
CURSON	LD	A,14
	JR	CURS
; Turn cursor off
CURSOFF	LD	A,15
CURS	LD	(CSTATE),A
	RPUSH	DE,BC		; Save registers
	LD	C,A
	SVC	@DSP
	RPOP	BC,DE		; Restore registers
	RET
CSTATE	DB	0
;---
; Toggle insert mode
;---
TINSERT	LD	A,(INSM)	; Insert mode
	XOR	1		; Toggle it
	LD	(INSM),A	; Store it
	CALL	DINSERT		; Display insert message
	CALL	DSCRN		; Display screen
	RET
;---
; Display insert message
;---
DINSERT	RPUSH	HL,DE,BC	; Save registers
	LD	A,(INSM)	; Insert mode
	OR	A
	JR	NZ,TIINS	; Go to insert if so
	LD	HL,OVER$	; Start of message
	LD	C,'_'		; Cursor character
	JR	TII1
TIINS	LD	HL,INSERT$	; Start of message
	LD	C,0A0H		; Cursor character
TII1	CALL	CCURS		; Change cursor character
	LD	DE,ROW-1*COL-8+SCRN
	LD	BC,8		; Length of message
	LDIR			; Move to screen
	RPOP	BC,DE,HL
	RET
;---
; Display information line
;---
DINFO	RPUSH	HL,DE,BC	; Save registers
	CALL	CINFO		; Clear information line
; Display filename message
	LD	DE,ROW-2*COL+SCRN
	LD	HL,F1
	LD	BC,10
	LDIR
; See if no filename
DINFO1	LD	A,(HL)		; Get byte
	CP	3		; See if zero
	JR	Z,DINFO2	; Ahead if so
	LDI			; Otherwise, move it
	JR	DINFO1		; Loop
; Display form and page data (if required)
DINFO2	LD	A,(FPFLAG)	; See if necessary
	OR	A
	JR	Z,DINFO3	; Ahead if not
	LD	HL,(CFORM)	; Number of forms
	LD	A,H
	OR	L
	JR	NZ,DINFOF	; Full display of information
; Display only page information
	LD	DE,ROW-1*COL-41+SCRN
	LD	HL,PD
	LD	BC,11
	LDIR
	JR	DINFOP
DINFOF	LD	DE,ROW-1*COL-54+SCRN
	LD	HL,FPD
	LD	BC,24
	LDIR
; Display form number
	LD	HL,(CFORM)	; Number of forms
	LD	DE,ROW-1*COL-47+SCRN
	SVC	@HEXDEC		; Convert to decimal
; Display page number
DINFOP	LD	HL,ROW-1*COL-34+SCRN
	LD	A,(CPAGE)
	CALL	CVTAHL		; Display number
; Display "+", "-", or ""
	LD	B,32		; Nothing
	LD	A,(PPLUS)	; Plus sign
	OR	A
	JR	Z,DIFM		; Ahead if nothing
	LD	B,'+'
DIFM	LD	A,(PMINUS)	; Minus sign
	OR	A
	JR	Z,DIFP		; Ahead if nothing
	LD	A,B
	LD	B,'-'		; Minus sign
	OR	B		; See if both
	CP	2FH
	JR	NZ,DIFP		; Ahead if not both
	LD	B,''		; Plus and minus
DIFP	LD	(HL),B		; Store in memory
; Display date and time
DINFO3	CALL	DDTIME
; Display insert message
	CALL	DINSERT		; Display message
	RPOP	BC,DE,HL	; Restore registers
	RET
; Display date and time
DDTIME	LD	DE,$-$		; Date area + 2
DATE$	EQU	$-2
	LD	HL,ROW-1*COL-29+SCRN
	LD	(HL),'['	; First bracket
	INC	HL
	LD	A,(DE)		; Get month
	DEC	DE
	LD	B,A
	LD	A,(DE)		; Get day
	DEC	DE
	LD	C,A
; B = month, C = day, (DE) = year
	LD	A,B		; Month
	CALL	CVTAHL0		; Convert
	LD	(HL),'-'	; Date separator
DSEP	EQU	$-1
	INC	HL
	LD	A,C		; Day
	CALL	CVTAHL0		; Convert
	LD	A,(DSEP)	; Date separator
	LD	(HL),A
	INC	HL
	LD	A,(DE)		; Year
	CP	100		; See if 100 or above
	JR	C,DD1		; Ahead if not
	SUB	100		; Otherwise, truncate
DD1	CALL	CVTAHL0		; Display
	INC	HL		; Make space
; Display time
	LD	DE,$-$		; Time area + 2
TIME$	EQU	$-2
	LD	A,(DE)		; Get hour
	DEC	DE
	LD	B,'A'		; Set to AM
	CP	12		; See if above 11:00 AM
	JR	Z,DT0
	JR	C,DT1		; Ahead if not
	SUB	12
DT0	LD	B,'P'		; Set to PM
DT1	OR	A		; See if zero
	JR	NZ,DT2
	LD	A,12		; Set to 12:00 AM if so
DT2	CALL	CVTAHL		; Display hour
	LD	(HL),':'	; Time separator
TSEP	EQU	$-1
	INC	HL
	LD	A,(DE)		; Get minutes
	CALL	CVTAHL0		; Display minute (with zero)
	INC	HL		; Make space
	LD	(HL),B		; Display "A" or "P"
	INC	HL
	LD	(HL),'M'	; Display M
	INC	HL
	LD	(HL),']'	; Final bracket
	RET
; Clear info line
CINFO	LD	HL,ROW-2*COL+SCRN
	LD	DE,ROW-2*COL+SCRN+1
	LD	BC,COL-1
	LD	(HL),32
	LDIR
	RET
;---
; Convert A to decimal at HL
;---
CVTAHL	LD	(HL),'0'	; Initialize tens
	SUB	10		; See if above ten
	JR	NC,CVT1		; Ahead if it is
	LD	(HL),32		; Make space if not
	JR	CVT2		; Jump ahead
CVTAHL0	LD	(HL),2FH	; Initialize tens
CVT1	INC	(HL)		; Next digit
	SUB	10		; See if above 10
	JR	NC,CVT1		; Loop if it is
CVT2	ADD	A,3AH		; Correct the remainder
	INC	HL		; Go to ones
	LD	(HL),A		; Store it
	INC	HL		; Next byte
	RET
;---
; A to three-byte decimal at HL
;---
CVTAHL3	LD	B,0		; No bytes yet
	LD	C,100		; Hundreds
	CALL	CVT30
	LD	C,10
	CALL	CVT30
	LD	C,1
	CALL	CVT30
; Pad spaces
	INC	B		; If nothing, ensure zero
	DEC	B
	JR	Z,CVT3Z
	LD	A,3		; Correct number of spaces
	SUB	B
	RET	Z
	LD	B,A
CVT3L	LD	(HL),32
	INC	HL
	DJNZ	CVT3L		; Loop until done
	RET
CVT30	LD	(HL),'0'-1	; Initialize hundreds
	CP	C		; See if above 100
	JR	NC,CVT31	; Ahead if so
	INC	B		; See if spaces yet
	DEC	B
	RET	Z		; Return if no numbers
CVT31	INC	(HL)
	SUB	C		; See if above hundred
	JR	NC,CVT31	; Ahead if it is
	ADD	A,C		; Correct for remainder
	INC	HL
	INC	B
	RET
CVT3Z:	LD	(HL),'0'	; Make sure at least a zero
	RET
;---
; Handle DOS errors
; Errors 248 to 255 are topic 101 to 108
; DOS error is 100
;---
DOSERR	PUSH	AF		; Save A
;;;
	LD	A,(HTOPIC)	; Store topic #
	LD	($TMPH),A
;;;
	LD	A,100
	LD	(HTOPIC),A
;;;
	CALL	CBL		; Clear bottom line
	POP	AF		; Restore A
	CP	255		; Is it "Not DM file"?
	JR	NZ,DO0		; Ahead if not
	LD	HL,NDM$		; Message
	LD	BC,23
DOO0	SUB	147		; Store help topic
	LD	(HTOPIC),A
	LD	DE,ROW-1*COL+SCRN+7
	LDIR			; Transfer
	JP	DOSE3		; Jump ahead
DO0	CP	253		; Is it "Help error"?
	JR	NZ,DO1
	LD	HL,FNI$		; Message
	LD	BC,16
	JR	DOO0
DO1	CP	254
	JR	NZ,DO2
	LD	HL,FFN$		; "File format not supported"
	LD	BC,26
	JR	DOO0
DO2	CP	252		; "Screen form has too many fields"
	JR	NZ,DO3
	LD	HL,SFTMF$
	LD	BC,32
	JR	DOO0
DO3	CP	251		; "Screen form has no fields"
	JR	NZ,DO4
	LD	HL,SFNF$
	LD	BC,26
	JR	DOO0
DO4	CP	250		; "Cannot copy to itself"
	JR	NZ,DO5
	LD	HL,CCF$
	LD	BC,26
	JR	DOO0
DO5	CP	249		; "Help file not found"
	JR	NZ,DO6
	LD	HL,HFNF$
	LD	BC,20
	JR	DOO0
DO6	CP	248		; "Not enough memory"
	JR	NZ,DOSE0
	LD	BC,27
	LD	HL,OM$
	JR	DOO0
DOSE0:
;;;;
	PUSH	AF
	CP	15
	JR	NZ,$DO1		; "Write protect"
	LD	A,109
	JR	$DO0
$DO1:	CP	19		; "Illegal filename"
	JR	NZ,$DO2
	LD	A,110
	JR	$DO0
$DO2:	CP	24		; "File not in directory"
	JR	NZ,$DO3
	LD	A,111
	JR	$DO0
$DO3:	CP	27		; "Disk space full"
	JR	NZ,$DO4
	LD	A,112
	JR	$DO0
$DO4:	CP	32		; "Illegal drive number"
	JR	NZ,$DO5
	LD	A,113
	JR	$DO0
$DO5:	CP	25		; "Illegal access"
	JR	NZ,$DOSE
	LD	A,114
$DO0:	LD	(HTOPIC),A
$DOSE:	POP	AF
;;;;
	OR	10000000B	; Display AND return
	LD	C,A
	SET	7,(IY+'C'-'A')	; Put message in buffer
	LD	DE,ROW-1*COL+SCRN+7
	PUSH	DE
	SVC	@ERROR		; Error message
	POP	DE
DOSE1	LD	A,(DE)		; See if CR
	INC	DE
	CP	13
	JR	NZ,DOSE1	; Back if not
	DEC	DE
	LD	A,32		; Replace CR with space
	LD	(DE),A
	DEC	DE
	LD	A,'!'		; Replace space with "!"
	LD	(DE),A
DOSE3	LD	HL,ERROR$	; Error message
	LD	DE,ROW-1*COL+SCRN
	LD	BC,7
	LDIR
	CALL	CURSOFF		; Turn cursor off
	CALL	DSCRN		; Display screen
	LD	B,00001010B	; Medium tone, one second
	SVC	@SOUND		; Play sound
	CALL	MSKEY		; Wait for key
	CALL	CBL		; Clear bottom line
;;;
	LD	A,0
$TMPH	EQU	$-1
	LD	(HTOPIC),A	; Restore old help topic
;;;
	RET
;---
; Get specification
;---
SGSPEC	LD	HL,SPEC		; Point to spec
	LD	(TSPEC),HL
SGSPECA	CALL	CSCRN
; Set correct variables
	LD	HL,0		; Turn off form display
	LD	(CFORM),HL
; Get search specification
	LD	(NXFORM),HL
	LD	(PVFORM),HL
	PUSH	HL		; New blocks
	POP	BC
	CALL	LEDITD		; Edit specification
	RPUSH	AF,BC
	CALL	DDFORM		; Delete form
	RPOP	BC,AF
	JR	NZ,$SRCH0	; Jump ahead
	CALL	DWFLUSH		; Flush write buffer
	JP	MAIN		; Exit
; Load specification
$SRCH0	LD	DE,SPEC		; Put in specification
TSPEC	EQU	$-2
	CALL	DRFORM		; Read page 1
	RET	NZ
$SRCH1	DEC	DE
	LD	A,(DE)		; See if zero
	OR	A
	JR	Z,$SRCH1	; Loop until not
	INC	DE
; Load in next page
	LD	BC,(NXPAGE)	; Next page
	LD	A,B		; See if end
	OR	C
	JR	Z,$SRCH5	; Ahead if end
	CALL	DRPAGE		; Otherwise, load in page
	RET	NZ
	JR	$SRCH1		; and loop
; End of pages to load
$SRCH5	LD	A,0F0H		; End of form
	LD	(DE),A
	RET
;---
; Find first search
;---
; Display information
SFIRST	SVC	@CKBRKC		; Eliminate BREAK bit
	LD	HL,1
	LD	(CFORM),HL
	DEC	HL
	LD	(FFNUM),HL
; Look at first record
	LD	BC,(FRSTF)	; First record
	LD	A,B
	OR	C		; See if nothing
	LD	A,180
	RET	Z		; Return if end
; Load first screen form
$SRCHL	LD	(CFORMB),BC	; Store block numbers
	LD	A,(APAGE)	; Loaded page
	DEC	A		; See if first
	JR	Z,$SRCHL1	; Ahead if first
	LD	A,1
	LD	(APAGE),A
	DEC	A
	CALL	DFSF		; Find screen form
	LD	A,B		; See if nothing
	OR	C
	JR	NZ,$SRC10	; Ahead if value
; Use notes form
$SRCEF	LD	HL,NOTES	; "NOTES:"
	LD	DE,FORM
	LD	BC,NOTESL
	LDIR			; Move
	JR	$SRCHL1		; Jump ahead
; Load screen form
$SRC10	LD	DE,FORM		; Form address
	CALL	DRDATA		; Read screen form
	RET	NZ
; Make sure form is not empty
	LD	A,(FORM)	; See if empty
	INC	A
	JR	Z,$SRCEF
; Continue
$SRCHL1	CALL	CSCRN		; Clear screen
	LD	DE,DATA		; Data buffer
	LD	BC,(CFORMB)	; Get block number
	CALL	DRFORM		; Read first page
	LD	(DEND),DE	; Store data end
	RET	NZ
	LD	A,1		; First page
	LD	(CPAGE),A
	LD	BC,(NXPAGE)	; Plus if next page
	LD	A,B
	OR	C
	LD	(PPLUS),A
	XOR	A		; Make no minus
	LD	(PMINUS),A
	CALL	DINFO		; Display information
	CALL	DSCRN		; and screen
; Compare with specification
	LD	DE,SPEC
$SR0	LD	HL,DATA
	LD	A,(DE)		; See if nothing
	INC	A
	JR	Z,$SR21		; Ahead if nothing
	INC	DE
	LD	A,(DE)		; Read number of data
	INC	DE
	CALL	DFDN		; Find corresponding data
	OR	A		; If nothing, make it null
	JR	NZ,$SR1
	LD	HL,NULL$
$SR1	PUSH	DE		; Save DE
	CALL	COMP		; Do comparison
	POP	DE		; Restore DE
	JP	NZ,SNEXT	; Next form if not match
; Data did match
$SR2	LD	A,(DE)		; Go to end of field
	INC	DE
	OR	A
	JR	NZ,$SR2
	LD	A,(DE)		; Loop if not end of form
	CP	0FFH
	JR	NZ,$SR0
; See if end of pages
$SR21	INC	DE
	LD	A,(DE)		; End of pages?
	CP	0F0H
	JR	Z,$SRSUCC	; Ahead if so
	LD	BC,(NXPAGE)	; Load next page
	LD	A,B
	OR	C		; See if end
	JR	Z,$SR3		; Ahead if end of pages
	PUSH	DE		; Save specification address
	LD	DE,DATA		; Load into data
	CALL	DRPAGE		; Read page
	POP	DE		; Restore address
	RET	NZ
	JR	$SR0		; Loop until done
$SR3	LD	A,0FFH		; Zero data area
	LD	(DATA),A
	JR	$SR0		; Loop until done
; Entire form matched
$SRSUCC	LD	HL,(FFNUM)	; Increment number of forms found
	INC	HL
	LD	(FFNUM),HL
	XOR	A		; Make not zero
	RET
;---
; Find next form
;---
SNEXT	LD	BC,(NXFORM)	; Get next form
	LD	A,B
	OR	C		; If nothing, display
	LD	A,180		; Return if end
	RET	Z
	SVC	@CKBRKC		; See if BREAK
	JR	NZ,SNEXTB
	LD	HL,(CFORM)	; Increment form number
	INC	HL
	LD	(CFORM),HL
	LD	(CFORMB),BC	; Store block number
	JP	$SRCHL1
SNEXTB	CP	A
	RET
; Display final message
$SRCHM	PUSH	HL
	CALL	CSCRN		; Clear screen
	XOR	A		; Turn off information line
	LD	(FPFLAG),A
	CALL	DINFO		; Display information
	LD	HL,(FFNUM)	; Number of forms found
	LD	DE,FFNUM$
	SVC	@HEXDEC		; Convert to decimal
	POP	HL
	CALL	DFIELD
	LD	HL,FOUND$	; Display form
	CALL	DFRM
	CALL	DSCRN
$SRCHM9	CALL	MSKEY
	INC	A
	JR	Z,$SRCHM9
	JP	MAIN
F1	DB	'Filename: '
FNAME	DB	3
	DS	14
FPD	DB	'[Form:      , page:    ]'
PD	DB	'[page:    ]'
INSM	DB	0
NDM$	DB	'Not a Data-Minder file!'
FNI$	DB	'Help file error!'
FFN$	DB	'File format not supported!'
SFTMF$	DB	'Screen form has too many fields!'
SFNF$	DB	'Screen form has no fields!'
CCF$	DB	'Can''t copy file to itself!'
HFNF$	DB	'Help file not found!'
OM$	DB	'Not enough memory for sort!'
ERROR$	DB	'Error: '
INSERT$	DB	'  ','I'+128,'N'+128,'S'+128,'E'+128
	DB	'R'+128,'T'+128
OVER$	DB	'O'+128,'V'+128,'E'+128,'R'+128,'T'+128
	DB	'Y'+128,'P'+128,'E'+128
; Indicator flags
FPFLAG	DB	0		; Form, page indicator display flag
CFORM	DW	0		; Current form number
CPAGE	DB	0FFH		; Current page number
CFORMB	DW	0		; Current form block
FFNUM	DW	0		; Number of forms found
PPLUS	DB	0		; Plus condition
PMINUS	DB	0		; Minus condition
NULL$	DC	10,0
