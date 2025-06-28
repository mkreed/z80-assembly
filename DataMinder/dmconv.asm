;-------------------------------------
; DATA-MINDER conversion program
; copyright (c) 1995, by Matthew Reed
; all rights reserved
; DM/ASM, main program file
;-------------------------------------
COL	EQU	80
ROW	EQU	24
	COM	'<Copyright (c) 1995 by Matthew Reed, all rights reserved>'
	ORG	2600H
	DC	50,0		; Patch area
	DS	256		; One page of stack
STACK	EQU	$
*LIST OFF
*GET EQUATES
*GET DMHELP
*GET DMEDIT
*GET DMUNIV
*GET DMFORM
*GET DMMENU
*GET DMDISK
*LIST ON
;================
; Initialization
;================
MAIN
START	LD	SP,STACK	; Reset stack
	SVC	@CKBRKC
	LD	BC,8<8+'_'	; Set cursor to underline
	SVC	@VDCTL
	LD	(OLDCURS),A	; Store old cursor
	LD	HL,SCRN		; Get time address
	SVC	@TIME
	INC	DE		; Go to hour
	LD	(TIME1$),DE	; Store
	INC	DE
	LD	(TIME$),DE	; Store
	LD	HL,SCRN
	SVC	@DATE		; Get date address
	LD	A,(DE)		; Get year
	INC	DE		; Go to month
	INC	DE
	LD	(DATE$),DE	; Store
; Other initialization
$NO	LD	C,10H		; Enable reverse video
	SVC	@DSP
	LD	C,11H		; but turn it off
	SVC	@DSP
	CALL	CSCRN		; Clear screen
	LD	HL,CONV$	; Display message
	CALL	DMB
	LD	HL,CSNNO	; Use existing order
	LD	(MDFO),HL	;  (for SEDIT)
;---
; Prompt for filename
;---
FPMT	CALL	DINFO		; Initialize
	CALL	CSCRN		; Clear screen
	LD	HL,MTITLE	; Display title
	CALL	DFRM
	LD	HL,PFRM0
	LD	(AROUT),HL
; Prompt for filename
PFRM0	LD	A,10
	LD	(HTOPIC),A
	LD	HL,FFORM	; Filename form
	LD	DE,FDATA	; Empty data
	CALL	LEDITO		; Edit one item
	OR	A		; Is it <BREAK>?
	JP	Z,SHUTDWN	; End if so
; Open PFS:file file and verify
	LD	HL,COL*16+14+SCRN
	LD	DE,FCB2		; FCB
	CALL	FSPEC
	LD	A,19
	JP	NZ,FPERR
	LD	HL,BUFF1	; Buffer to be used
	LD	B,128
	SVC	@OPEN		; Open file
	JR	Z,RZT0
	CP	42		; LRL fault
	JP	NZ,FPERR
RZT0	LD	BC,0		; Header
	LD	HL,PHEAD
	CALL	DRPBLK		; Read header
	JP	NZ,FPERR
; Make sure it is PFS:file
	LD	HL,PHEAD+16
	LD	DE,PINTEG	; "TYPE 3"
	LD	BC,6
PILOOP	LD	A,(DE)		; Get byte
	INC	DE
	CPI
	JP	NZ,PFSERR	; Not PFS:file
	JP	PO,PILOOP	; Loop until done
; Prompt for second filename
	LD	HL,PFRM1
	LD	(AROUT),HL
PFRM1	LD	A,11
	LD	(HTOPIC),A
	LD	HL,FFORM	; Eliminate highlight
	CALL	DFRM
	LD	HL,SFORM	; Filename form
	LD	DE,FDATA
	CALL	LEDITO		; Edit one item
	OR	A		; See if <BREAK>
	JP	Z,SHUTDWN	; End if so
	LD	HL,COL*18+15+SCRN
	LD	DE,FCB1		; FCB # 1
	CALL	FSPEC		; Move into FCB
	LD	A,19		; "Illegal file name"
	JP	NZ,FPERR	; Return if error
	LD	HL,SFORM
	CALL	DFRM		; Eliminate highlight
; Make sure file does not exist
;;;
	SVC	@FLAGS$
	SET	0,(IY+'S'-'A')	; Force to read
	LD	HL,BUFF1
	LD	DE,FCB1
	LD	B,0
	SVC	@OPEN
	JR	Z,$FPO1		; If no error, check
	CP	24		; File not in directory
	JR	Z,FPO21		; If so, create file
	JP	FPERR		; If error
; See if the same files
$FPO1:	LD	HL,(FCB1+6)	; DEC and drive
	LD	BC,(FCB2+6)
	OR	A
	SBC	HL,BC
	LD	A,250
	JP	Z,FPERR		; If error
;;;
; Query about existing file
$FPO2:	LD	A,12
	LD	(HTOPIC),A
	CALL	CBL		; Clear it
	LD	A,0C9H		; "RET"
	LD	(CBL),A
	LD	HL,NEW		; New file prompt
	CALL	DMENU		; Display menu
	PUSH	AF
	XOR	A
	LD	(CBL),A
	POP	AF
	OR	A		; Is it <BREAK>?
	JP	Z,PFRM1		; Jump back if so
	CP	2		; Is it NO?
	JP	Z,PFRM1		; Jump back if so
;;;
	LD	DE,FCB1
	CALL	DREMOVE		; Delete file
;;;
FPO21:	SVC	@CKBRKC
	LD	HL,COL*18+15+SCRN
	LD	DE,FCB1		; FCB # 1
	SVC	@FSPEC		; Move into FCB
	CALL	DINITV		; Create file
	JP	NZ,FPERR	; Ahead if error
	XOR	A
; Create name
FPO3	LD	DE,FNAME	; Move filename to buffer
	LD	BC,(FCB2+6)	; Get DEC and drive
	SVC	@FNAME		; Move filename to buffer
	JR	FPNEW		; New file
;---
; File prompt error
;---
FPERR	PUSH	AF		; Save error
	CALL	DINFO		; Display info line
	POP	AF		; Restore error
	CALL	HDOSERR		; Display error
RRLB	JP	$-$		; Jump back
AROUT	EQU	$-2
PFSERR	CALL	CBL
	LD	A,108+147
	LD	(HTOPIC),A
	LD	HL,PFSERR$	; Not a PFS:file
	LD	BC,23
	CALL	DOO0
	JR	RRLB
; Initialize file
FPNEW	CALL	CBL		; Clear bottom line
	LD	A,1		; Initialize counter
	LD	(CPAGE),A
	LD	(APAGE),A
	LD	(FPFLAG),A	; Turn it on
	CALL	DINFO
; Display PFS:file screen forms on screen
	LD	BC,(PHEAD)	; First page
RRR1	SVC	@CKBRKC		; See if BREAK
	CALL	NZ,EQUEST
	CALL	CSCRN		; Clear screen
	LD	HL,UREC
	CALL	DRPBLKS
	JP	NZ,FPNDE
	LD	HL,UREC+6	; Start of data
	LD	BC,6
	LD	A,(CPAGE)	; Current page
	DEC	A
	JR	NZ,RR10
	ADD	HL,BC
RR10	CALL	PDFORM		; Display form
	CALL	DINFO		; Display information
	CALL	DSCRN
	LD	BC,0		; Signal new
	LD	($CSFB),BC
	LD	A,1		; Signal modified
	LD	(MODFLAG),A
	CALL	$SFSAVE		; Save current form to disk
	JP	NZ,FPNDE
	LD	A,(CPAGE)	; Increment page
	INC	A
	LD	(CPAGE),A	; Store page
	LD	(APAGE),A
	LD	BC,(UREC+0)	; Next PFS page
	LD	A,B
	OR	C		; See if end
	JR	NZ,RRR1		; Loop if not
; Display PFS:file forms on screen
	LD	BC,1
	LD	(CFORM),BC
	DEC	BC
	LD	(FFNUM),BC	; None found
	LD	BC,(PHEAD+8)	; Final form
RR20	LD	A,B
	OR	C
	JP	Z,RRR9		; Finished if nothing
	LD	($LEFB),BC
	LD	DE,0		; Zero previous page
	LD	(PVPAGE),DE
	LD	(NXPAGE),DE
	LD	A,1
	LD	(CPAGE),A	; Initialize
	SVC	@CKBRKC		; See if BREAK
	CALL	NZ,EQUEST
RRR2	CALL	CSCRN		; Clear screen
	LD	HL,UREC
	CALL	DRPBLKS
	JP	NZ,FPNDE
; Create "+", "-", or ""
	LD	BC,(UREC+2)	; Make minus
	LD	A,B
	OR	C
	LD	(PMINUS),A
	LD	BC,(UREC+0)	; Make plus
	LD	A,B
	OR	C
	LD	(PPLUS),A
	LD	A,(APAGE)	; Loaded page
	LD	B,A
	LD	A,(CPAGE)	; Desired page
	CP	B		; See if same
	JR	Z,$PFDD2	; If same, ahead
	DEC	A
	CALL	DFSF		; Find screen form
	LD	A,B		; See if nothing
	OR	C
	JR	NZ,$PFDD10	; Ahead if value
; Use notes form
$PFDEF	LD	HL,NOTES	; "NOTES:"
	LD	DE,FORM
	LD	BC,NOTESL
	LDIR			; Move
	JR	$PFDD2		; Jump ahead
; Load screen form
$PFDD10	LD	DE,FORM		; Form address
	CALL	DRDATA		; Read screen form
	JP	NZ,FPNDE	; Ahead if error
; Make sure form is not empty
	LD	A,(FORM)	; See if empty
	INC	A
	JR	Z,$PFDEF
; Update loaded page
$PFDD2	LD	A,(CPAGE)
	LD	(APAGE),A
; Turn on display
	LD	A,1		; Turn on display
	LD	(FPFLAG),A
	CALL	DINFO		; Display information line
	LD	HL,UREC+6	; Start of data
	LD	BC,6
	LD	A,(CPAGE)	; Current page
	DEC	A
	JR	NZ,RR21
	ADD	HL,BC
	LD	BC,(UREC+10)	; Get previous form
	LD	(TTRZ),BC
RR21	PUSH	HL
	LD	HL,FORM
	CALL	DFRM		; Display form
	POP	HL
	CALL	PDFORM		; Display form
	CALL	DSCRN
; Save in DATA-MINDER file
	LD	BC,0
	LD	A,(CPAGE)	; Page number
	DEC	A
	JR	NZ,RR88		; Ahead if not first
	CALL	ADDF		; Add first
RR88	LD	($LEDB),BC	; Store value
	LD	A,1
	LD	(MODFLAG),A
	CALL	$LSPAGE		; Save page
	JP	NZ,FPNDE
	LD	DE,(UREC)	; Next page
	LD	A,D
	OR	E
	JR	Z,RR210		; Ahead if no next page
	LD	(PVPAGE),BC	; Put in previous page
	LD	BC,(NXPAGE)	; Next page
	LD	HL,0
	LD	(NXPAGE),HL
	LD	A,(CPAGE)
	INC	A
	LD	(CPAGE),A
	LD	HL,UREC
	LD	BC,(UREC)	; Next page
	JP	NZ,RRR2		; Get new pages
RR210	LD	BC,($LEFB)	; First block
	CALL	ADDN		; Add next record
	JR	NZ,FPNDE
; Increment counts
	LD	DE,(CFORM)	; Form number
	INC	DE
	LD	(CFORM),DE	; Modify information
	LD	DE,(FFNUM)	; Increment forms found
	INC	DE
	LD	(FFNUM),DE
	LD	BC,$-$		; Previous form
TTRZ	EQU	$-2
	JP	RR20		; Loop
RRR9	LD	A,(WDIRT)	; See if dirty
	OR	A
	CALL	NZ,DWFLUSH	; Flush write buffer
	JP	NZ,FPNDE
	CALL	EXIT1		; Close all files
	LD	A,14
	LD	(HTOPIC),A
	LD	HL,CV$		; Conversion
	JP	$SRCHM
; File new error
FPNDE	PUSH	AF		; Save error
	CALL	DINFO		; Display info line
	POP	AF		; Restore error
	CALL	HDOSERR		; Display error
	JR	EXIT
EQUEST	RPUSH	HL,DE,BC
	CALL	CSCRN		; Clear screen
	LD	HL,END
	LD	A,13
	LD	(HTOPIC),A
	CALL	DMENU		; Display menu
	RPOP	BC,DE,HL
	OR	A		; Is it <BREAK>?
	RET	Z
	CP	2		; Is it NO?
	RET	Z
; Program shutdown
EXIT	CALL	EXIT1
SHUTDWN	LD	BC,8<8+'_'	; Set cursor to underline
OLDCURS	EQU	$-2
	SVC	@VDCTL
	SVC	@CLS		; Clear screen
	SVC	@CKBRKC		; Clear <BREAK> bit
	LD	HL,0		; No error
	SVC	@EXIT		; Exit the program
EXIT1	LD	A,(FCB2)	; Test bit
	BIT	7,A
	JR	Z,SHUTDWN	; Skip if not open
	LD	DE,FCB2		; Close file
	SVC	@CLOSE
	LD	A,(FCB1)	; Test bit
	BIT	7,A
	JR	Z,SHUTDWN	; Skip if not open
	CALL	DCLOSE		; Close data file
	RET
; Make correct help topic
HDOSERR:
	JP	DOSERR
;---
; PFS:file routines
;---
PDFORM	LD	A,(HL)		; Get length
	INC	HL
	OR	(HL)		; See if end
	RET	Z		; Return if end
	INC	HL
	LD	C,(HL)		; Get X, Y
	INC	HL
	LD	B,(HL)
	INC	HL
	EX	DE,HL
	RES	7,B		; Eliminate bit 7
	CALL	CXY		; Convert
	CALL	RPL1		; Display on screen
	EX	DE,HL
	JR	PDFORM		; Loop until done
; Display on screen
RPL1	LD	A,(DE)		; Get byte
	INC	DE
	CP	4		; See if extra
	JR	Z,RPL1		; Loop if so
	OR	A
	RET	Z
	CP	1		; See if space compression
	JR	Z,RPL2
	RES	7,A		; Eliminate
	LD	(HL),A
	INC	HL
	JR	RPL1		; Loop until done
RPL2	LD	A,(DE)		; Get count
	INC	DE
	INC	DE
	LD	B,A		; Count
	LD	A,32		; Space
RPL3	LD	(HL),A
	INC	HL
	DJNZ	RPL3		; Loop until done
	JR	RPL1		; Loop
; HL => address to read to
DRPBLKS	CALL	DRPBLK		; Read block
	RET	NZ
	LD	DE,126		; Move to link
	ADD	HL,DE
	LD	C,(HL)		; Put in BC
	INC	HL
	LD	B,(HL)
	LD	A,B
	OR	C
	RET	Z		; Return if end
	DEC	HL
	JR	DRPBLKS		; Loop until done
; HL => address to read to
DRPBLK	LD	DE,FCB2		; FCB to read
	SVC	@POSN		; Position to block
	RET	NZ
	SVC	@READ		; Read block
	RET
;--
; Add first
;--
ADDF	LD	HL,(LSTF)	; Last form
	LD	(PVFORM),HL	; Store as previous
	LD	HL,0
	LD	(NXFORM),HL	; No next
	PUSH	HL
	POP	BC		; Make new record
	RET
;--
; Add next
; BC => block number
;--
ADDN	PUSH	BC		; Save block number
; Increment active records
	LD	BC,(ACTF)	; Active records
	INC	BC
	LD	(ACTF),BC	; Store address
	LD	BC,(LSTF)	; Last record
; Preserve former last record block
	LD	(PVFORM),BC	; Store in memory
	POP	BC		; New last block
	LD	(LSTF),BC	; Store in last record slot
; See if records exist
	LD	HL,FRSTF	; See if nothing
	LD	A,(HL)
	INC	L
	OR	(HL)
	JR	NZ,ADDR1
	LD	(FRSTF),BC	; Create first record
ADDR1	PUSH	BC		; Save again
	CALL	FREC0		; Write record zero
	POP	BC
	RET	NZ
	PUSH	BC
; Now store new form as next form in former last form
	LD	BC,(PVFORM)	; Old last form
	LD	A,B		; See if nothing
	OR	C
	JR	Z,ADDF6		; Ahead if something
	CALL	DRBLKW		; Read first block of form
	POP	BC		; Restore next form block
	RET	NZ
	LD	A,8		; Go to "next form"
	ADD	A,L
	LD	L,A
	LD	(HL),C		; Store in form
	INC	L
	LD	(HL),B
	PUSH	BC		; Save yet again
ADDF6	POP	BC		; Restore BC
	XOR	A		; No error
	RET
;--
; Remove form and update links
;--
RFORM	LD	A,B		; Make sure not zero
	RES	7,A
	OR	C
	RET	Z
; Transfer header to buffer
	PUSH	BC		; Save BC
	CALL	DRBLK		; Read block
	INC	L		; Past word
	INC	L
	LD	DE,PVPAGE	; Start of structure
	LD	BC,8		; Bytes to transfer
	LDIR
	POP	BC
; Delete form
	CALL	DDFORM		; Delete form
; See if previous exists
	LD	BC,(PVFORM)	; Previous form
	LD	A,B		; Ahead if previous exists
	OR	C
	JR	NZ,RNX0
; Update first form
	LD	BC,(NXFORM)	; Next form
	LD	(FRSTF),BC
	JR	RNX1		; Jump ahead
; Link previous to next
RNX0	CALL	DRBLKW		; Read block
	LD	A,8
	ADD	A,L
	LD	L,A
	LD	BC,(NXFORM)	; Next form
	LD	(HL),C
	INC	L
	LD	(HL),B
; See if next exists
RNX1	LD	BC,(NXFORM)	; Next form
	LD	A,B		; Ahead if no form
	OR	C
	JR	NZ,RNX2
; Update last form
	LD	BC,(PVFORM)	; Previous form
	LD	(LSTF),BC	; Make last form
	JR	RNX3
; Link next to previous
RNX2	CALL	DRBLKW		; Read block
	LD	A,6		; Go to previous form
	ADD	A,L
	LD	L,A
	LD	BC,(PVFORM)	; Previous form
	LD	(HL),C
	INC	L
	LD	(HL),B
; Decrement active forms
RNX3	LD	BC,(ACTF)	; Decrement active forms
	DEC	BC
	LD	(ACTF),BC
	CALL	FREC0		; Flush record zero
	RET
;--
EMPTY$	DB	0FFH,0FFH
MHEAD	DB	'DM4',VERSION,0,0,0,0
MHEADC	EQU	$-MHEAD
;===========
; Data area
;===========
HFILE$	DB	'DMCONV/HLP',0DH
FFORM	DB	0,16,9,0,23,'File to read:',0
	DB	0FEH,'Type in the name of the file to convert, '
	DB	'or press <BREAK>',0
	DB	255
SFORM	DB	0,18,9,0,23,'File to write:',0
	DB	0FEH,'Type in the new filename, or press <BREAK>',0
	DB	255
FDATA	DB	9,0,0FFH,25,32,0
FCOUNT	DB	0
RMAXV	DW	0
;===
CONV$	DB	12,'Conversion'
CFRM$	DB	15,'Create design'
HELP$	DB	6,'Help'
END$	DB	7,'Abort'
SCRN	DS	ROW*COL
SCRN1	DS	2048
;===
MTITLE	DB	0,0,1
	DB	0FFH,80,160
	DB	0
	DB	4,2,1,'                                                                        ',0
	DB	4,3,1,'                                                                        ',0
	DB	4,4,1,'                                                                        ',0
	DB	4,5,1,'                                                                       ',0
	DB	4,6,1,'                                                                        ',0
	DB	0,8,1
	DB	0FFH,80,160
	DB	0
	DB	34,7,1,'version 1.0',0
	DB	12,10,1,'copyright (c) 1995 by Matthew Reed, '
	DB	'all rights reserved',0
	DB	24,11,1,'distributed by COMPUTER NEWS 80',0
	DB	30,13,1,'Conversion Utility',0
	DB	26,20,1,'Press <CONTROL> <?> for help',0
	DB	0FFH
;===
END	DB	2
	DB	5,8,1,'Conversion is in progress;'
	DB	' are you sure you want to exit?',0
	DB	64,8,8,'Y','YES',0
	DB	0FEH,'Yes, abort conversion',0
	DB	69,8,8,'N','NO',0
	DB	0FEH,'No, continue the conversion',0
	DB	255
NEW	DB	2
	DB	0,23,1,'File exists; write over it?',0
	DB	29,23,8,'Y','YES',0
	DB	34,23,8,'N','NO',0
	DB	255
;===
CV$	DB	27,9,1,'Forms converted:',0
PR$	DB	29,9,1,'Forms printed:',0
RR$	DB	29,9,1,'Forms removed:',0
FOUND$	DB	44,9,1
FFNUM$	DB	'00000',0
	DB	22,11,1,'Press a key to convert another file',0
	DB	255
PINTEG	DB	'TYPE 3'
PFSERR$	DB	'File is not a PFS:file!'
CPRINT
FPRINTA
PCLOS
PCLS
POEND
PPBP
PRINT$
PRVIEW
	RET
;=====
; Data areas
;=====
FCB3	DS	32
FORM	DB	0FFH
	DS	2048		; Maximum of 2K
DATA	DB	0FFH
	DS	2048		; Maximum of 2K
BUFF1	DS	256
PHEAD	DS	128
SPEC	DS	1024
UREC	EQU	$
	END	START
