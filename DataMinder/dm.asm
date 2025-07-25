;-------------------------------------
; DATA-MINDER database manager
; copyright (c) 1995, by Matthew Reed
; all rights reserved
; DM/ASM, main program file
;-------------------------------------
COL	EQU	80
ROW	EQU	24
	COM	'<Copyright (c) 1995 by Matthew Reed, all rights reserved>'
	ORG	2600H
; Patch area
	DC	100,0		; One hundred bytes of patches
	DS	256		; One page of stack
STACK	EQU	$
*GET EQUATES
*GET DMHELP
*GET DMEDIT
*GET DMUNIV
*GET DMFORM
*GET DMMENU
*GET DMDISK
CFNAME	DEFL	14*COL+39+SCRN
;================
; Initialization
;================
START	LD	SP,STACK	; Reset stack
	LD	A,(HL)		; See if nothing
	CP	0DH
	JR	Z,START1
	LD	(CLFN),HL	; Store filename
START1	LD	BC,8<8+'_'	; Set cursor to underline
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
	LD	(DATE1),A
	INC	DE		; Go to month
	INC	DE
	LD	(DATE$),DE	; Store
;	LD	DE,MOUSE$	; Is driver in memory?
;	SVC	@GTMOD
;	JR	NZ,$NO		; If not, not installed
;	SVC	@FLAGS$		; Find SVC table entry 120
;	LD	H,(IY+26)
;	LD	L,0F0H
;	LD	A,(HL)		; Get address pointed to
;	INC	L		; at table
;	LD	H,(HL)
;	LD	L,A
;	LD	A,(HL)		; Is first byte "LD A,n",
;	CP	3EH		; start of SVC error?
;	JR	Z,$NO		; If so, not installed
;	LD	HL,0		; Eliminate MKEY
;	LD	(MSKEY),HL
;	XOR	A		; Eliminate PTROFF blockage
;	LD	(PTROFF),A
;	LD	HL,79		; Set driver to 80
;	LD	DE,23		; by 24 with
;	LD	BC,0401H	; sensitivity of 3
;	SVC	@MOUSE
; Other initialization
$NO	LD	C,10H		; Enable reverse video
	SVC	@DSP
	LD	C,11H		; but turn it off
	SVC	@DSP
	CALL	CSCRN		; Clear screen
	LD	HL,MMENU$	; Display menu message
	CALL	DMB
;---
; Prompt for filename
;---
FPMT	CALL	DINFO		; Initialize
	CALL	CSCRN		; Clear screen
;	CALL	PTROFF		; Turn pointer off
	LD	HL,MTITLE	; Display title
	CALL	DFRM
	LD	HL,MMENU+1	; Address of menu
	CALL	DFRM		; Display form
	LD	HL,$-$
CLFN	EQU	$-2
	PUSH	HL
	LD	HL,0
	LD	(CLFN),HL	; Make it zero
	POP	HL
	LD	A,H
	OR	L
	JR	NZ,FPO2		; Ahead if command line filename
; Prompt for filename
	LD	A,10
	LD	(HTOPIC),A
	LD	HL,FFORM	; Filename form
	LD	DE,FDATA	; Empty data
	CALL	LEDITO		; Edit one item
	OR	A		; Is it <BREAK>?
	JR	NZ,FPO		; Ahead if not
	LD	A,(FNAME)	; See if empty
	CP	3
	JP	NZ,MAIN		; Main menu if not empty
	JP	SHUTDWN		; Shutdown if empty
; Open filename just entered
FPO	LD	A,(FNAME)	; See if empty
	CP	3
	JR	Z,FPO1		; Ahead if empty
	CALL	DCLOSE		; Close previous file
FPO1	LD	HL,ROW-2*COL+10+SCRN
FPO2	CALL	DOPNV		; Open file
	PUSH	AF
	CP	24		; "File not in directory"
	JR	Z,FPNEW		; New file prompt
	POP	AF
	JP	NZ,FPERR	; Ahead if error
	LD	DE,FNAME	; Move filename to buffer
	CALL	DMFDE
;---
; Main menu loop
;---
MAIN	LD	A,11
	LD	(HTOPIC),A
	LD	SP,STACK	; Reset stack
	XOR	A		; Turn off form display
	LD	(CBL),A		; Turn line on
	LD	(FPFLAG),A
	LD	(PRVIEW),A
	LD	(DSCRN),A
	CALL	DINFO		; Display information line
	CALL	CSCRN		; Clear screen
	LD	HL,MMENU$	; Main menu message
	CALL	DMB
	LD	HL,MTITLE	; Main title
	CALL	DFRM
	LD	HL,MMENU	; Display main menu
	CALL	DMENU
; Compare various options
; <BREAK>
	OR	A		; Is it <BREAK>?
	JP	Z,FPMT		; Prompt for filename
	DEC	A
	JP	Z,ADD		; ADD
	DEC	A
	JP	Z,SEARCH	; SEARCH
	DEC	A
	JP	Z,COPY		; COPY
	DEC	A
	JP	Z,PRINT		; PRINT
	DEC	A
	JP	Z,REMOVE	; REMOVE
	DEC	A
	JP	Z,SDS		; MODIFY DESIGN
	DEC	A
	JP	Z,EXIT		; END PROGRAM
	JP	MAIN		; OTHER
;---
; File prompt error
;---
FPERR	PUSH	AF		; Save error
	CALL	DINFO		; Display info line
	POP	AF		; Restore error
	CALL	DOSERR		; Display error
	LD	A,3		; Eliminate old name
	LD	(FNAME),A
	JP	FPMT		; Jump back
; Prompt for new file
FPNEW	POP	AF
	LD	A,13
	LD	(HTOPIC),A
	LD	HL,FFORM	; Eliminate highlight
	CALL	DFIELD
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
	JP	Z,FPMT		; Jump back if so
	CP	2		; Is it NO?
	JP	Z,FPMT		; Jump back if so
; Initialize file
	CALL	DINITV		; Create file
	JP	NZ,FPNDE
	LD	DE,FNAME	; Move filename to buffer
	CALL	DMFDE
	LD	A,12
	LD	(HTOPIC),A
	CALL	CBL		; Clear bottom line
	CALL	DINFO
	CALL	CSCRN		; Clear screen
	LD	HL,CSNNO	; Use existing order
	LD	(MDFO),HL	;  (for SEDIT)
	CALL	SEDIT		; Screen editor
	OR	A		; Was it <BREAK>?
	JP	Z,FNEWERR
	CALL	CSCRN		; Clear screen
	JP	MAIN
; File new error
FPNDE	PUSH	AF		; Save error
	CALL	DINFO		; Display info line
	POP	AF		; Restore error
	CALL	DOSERR		; Display error
FNEWERR	CALL	DREMOVE		; Remove file
	LD	A,3
	LD	(FNAME),A	; Remove filename
	JP	FPMT		; Prompt user
; Program end
EXIT	LD	HL,END$		; Display message
	CALL	DMB
	LD	A,55
	LD	(HTOPIC),A
	CALL	CSCRN		; Clear screen
	LD	HL,END
	CALL	DMENU		; Display menu
	OR	A		; Is it <BREAK>?
	JP	Z,MAIN		; Main menu if so
	CP	2		; Is it NO?
	JP	Z,MAIN		; Main menu if so
; Actual program shutdown
	CALL	DCLOSE		; Close data file
SHUTDWN	LD	BC,8<8+'_'	; Set cursor to underline
OLDCURS	EQU	$-2
	SVC	@VDCTL
	SVC	@CLS		; Clear screen
	SVC	@CKBRKC		; Clear <BREAK> bit
	LD	HL,0		; No error
	SVC	@EXIT		; Exit the program
;---
; SDS
;---
SDS	CALL	CSCRN		; Clear screen
	LD	A,45
	LD	(HTOPIC),A
	LD	HL,MDM$		; Modify design menu
	CALL	DMB
	LD	HL,MDMENU	; Modify design menu
	CALL	DMENU		; Choose option
	OR	A
	JP	Z,MAIN		; Main menu if BREAK
; Put in or eliminate
	DEC	A
	JR	Z,SRNME
	LD	HL,CSNNO	; Use existing order
	DB	0FDH
SRNME	LD	HL,CSFTD	; Create new order
	LD	(MDFO),HL
	ADD	A,46
	LD	(HTOPIC),A
	CALL	SEDIT
	JP	MAIN
; Modify design options
MDMENU	DB	1
	DB	29,7,1,'Modify design options',0
	DB	26,9,8,'1','1 - Add/delete/move',0
	DB	0FEH,'Add new fields, delete fields, or move existing fields',0
	DB	26,10,8,'2','2 - Rename',0
	DB	0FEH,'Rename existing fields',0
	DB	0FFH
;---
; Add form at end of file
;---
ADD	CALL	CSCRN		; Clear screen
	LD	A,15
	LD	(HTOPIC),A
	LD	HL,ADD$		; Add message
	CALL	DMB
; Set correct variables
ADDL	LD	HL,(ACTF)	; Turn on form display
	INC	HL
	LD	(CFORM),HL
; Edit new record
	CALL	ADDF		; Add first
	CALL	LEDITD		; Line editor
	JR	NZ,$ADD1	; Ahead if not <BREAK>
	CALL	DDFORM		; Delete form
	CALL	DWFLUSH
	JP	MAIN		; Exit
$ADD1	CALL	ADDN		; Add next record
	JR	Z,ADDL		; Loop if not error
	CALL	DOSERR		; Signify error
	JP	MAIN
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
;---
; Search for forms
;---
SEARCH	LD	HL,SSPEC$	; Search specification
	CALL	DMB
	LD	A,20
	LD	(HTOPIC),A
	CALL	SGSPEC		; Get specification
	LD	HL,SEARCH$	; Search
	CALL	DMB
	CALL	SFIRST		; Find first search
	JR	NZ,SEERR
	OR	A		; See if form or end
	JR	NZ,SEEND	; Ahead if end
; Edit form
SEARCH1	LD	HL,SEARCH$	; Search
	CALL	DMB
	LD	A,21
	LD	(HTOPIC),A
	SVC	@CKBRKC
	JR	NZ,SEBRK
	LD	BC,(CFORMB)	; Beginning block
	CALL	LEDITE		; Edit form
	JP	Z,SEBRK		; End of search if <BREAK>
	CALL	SNEXT		; Search next
	JR	NZ,SEERR	; Ahead if error
	OR	A
	JR	Z,SEARCH1	; Loop if form found
; End
SEEND	CALL	DWFLUSH		; Flush buffer
	LD	A,22
	LD	(HTOPIC),A
	LD	HL,FR$		; Found message
	JP	$SRCHM		; Display message
; Error
SEERR	PUSH	AF
	CALL	DWFLUSH
	POP	AF
	CALL	DOSERR
	JP	MAIN
; BREAK
SEBRK	CALL	DWFLUSH		; Flush buffer
	JP	MAIN
;---
; Remove forms
;---
REMOVE	LD	HL,RSPEC$	; Search specification
	CALL	DMB
	LD	A,40
	LD	(HTOPIC),A
	CALL	SGSPEC		; Get specification
	LD	HL,REMOVE$	; Remove
	CALL	DMB
; Display warning
	LD	HL,SPEC		; See if empty specification
REM0	LD	A,(HL)		; Get byte
	INC	HL
	INC	A		; See if end
	JR	Z,REM0		; Loop until done
	CP	0F1H		; See if end
	LD	A,42
	JR	Z,REM1
	LD	HL,WARNR	; Ordinary warning
	INC	A
	DB	0FDH
REM1	LD	HL,WARNRE	; Extreme warning
	LD	(HTOPIC),A
	CALL	CSCRN		; Clear screen
	PUSH	BC
	LD	A,1		; Turn off query
	LD	(QUERY1),A
	CALL	DMENU
	POP	BC
	CP	3		; Is it query?
	JR	Z,$QUERY
	PUSH	AF
	XOR	A
	LD	(QUERY1),A	; Turn on query
	POP	AF
	CP	1		; Is it YES?
	JP	NZ,SEBRK	; Exit if not
; Begin search
$QUERY:	CALL	SFIRST		; Find first search
	JP	NZ,SEERR
	OR	A		; See if form or end
	JR	NZ,REEND	; Ahead if end
; Remove selected form
REMOVE1	LD	HL,FORM		; Display form
	LD	DE,DATA
	CALL	DFRMD
	CALL	DSCRN
; Ask if form should be removed
	RPUSH	HL,DE,BC
	CALL	CBL		; Clear it
	LD	A,0C9H		; "RET"
	LD	(CBL),A
; Need help topic
	LD	A,23
	LD	(HTOPIC),A
; Reduce number found
	LD	HL,(FFNUM)
	DEC	HL
	LD	(FFNUM),HL
	LD	A,0
QUERY1	EQU	$-1
	OR	A
	JR	Z,$RMVE		; Skip question if set
	LD	HL,RMVQST	; Remove question
	CALL	DMENU		; Display menu
	PUSH	AF
	XOR	A
	LD	(CBL),A
	CALL	CBL		; Clear the line
	POP	AF
	RPOP	BC,DE,HL
	OR	A		; Is it <BREAK>?
	JR	Z,REEND		; End of delete if so
	DEC	A		; Is it YES?
	JR	NZ,RESKIP	; Close if NO
; Now remove form
$RMVE:	LD	HL,(FFNUM)
	INC	HL
	LD	(FFNUM),HL
	LD	BC,(CFORMB)	; Start of form
	CALL	RFORM		; Remove form
RESKIP:	CALL	SNEXT		; Search for next
	JP	NZ,SEERR	; Ahead if error
	OR	A
	JR	Z,REMOVE1	; Loop if still forms
; End
REEND	CALL	DWFLUSH		; Flush buffer
	LD	A,41
	LD	(HTOPIC),A
	LD	HL,RR$		; Found message
	JP	$SRCHM		; Display message
;--
; Warnings for remove
;--
WARNRE	DB	2
	DB	36,6,1,'WARNING!',0
	DB	23,8,1,'All forms are about to be removed!',0
	DB	14,10,1,'Are you sure you want them removed?',0
	DB	51,10,8,'Y','YES',0
	DB	0FEH,'Yes, remove all forms',0
	DB	56,10,8,'N','NO',0
	DB	0FEH,'No, return to main menu',0
	DB	60,10,8,'Q','QUERY',0
	DB	0FEH,'Query before removing each form',0
	DB	255
; Less extreme warning
WARNR	DB	1
	DB	21,8,1,'Selected forms are about to be removed',0
 	DB	19,10,1,'Do you want them removed?',0
	DB	46,10,8,'Y','YES',0
	DB	0FEH,'Yes, remove selected forms',0
	DB	51,10,8,'N','NO',0
	DB	0FEH,'No, return to main menu',0
	DB	55,10,8,'Q','QUERY',0
	DB	0FEH,'Query before removing each form',0
	DB	255
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
;---
; Copy menu
;---
COPY	CALL	CSCRN		; Clear screen
	LD	HL,CMENU$	; Display message
	CALL	DMB
	LD	A,25
	LD	(HTOPIC),A
	LD	HL,COPYM	; Copy menu
	CALL	DMENU		; Choose option
	OR	A
	JP	Z,MAIN		; Main menu if BREAK
	PUSH	AF		; Save A
	LD	A,26
	LD	(HTOPIC),A
	LD	HL,COPYF	; Filename form
	LD	DE,FDATA	; Empty data
	CALL	LEDITO		; Edit one item
	OR	A		; Main menu if BREAK
	JP	Z,MAIN
	POP	AF		; Restore item
	DEC	A		; See if whole file
	JR	Z,COPYW
	DEC	A
	JR	Z,COPYD
	DEC	A
	JP	Z,CSR
;---
; Copy whole file
;---
COPYW	CALL	COPDR		; Copy design
	LD	A,0FFH		; Empty form
	LD	(SPEC),A
	LD	A,0F0H
	LD	(SPEC+1),A
	JP	CSR1		; Copy specified records
;---
; Copy design
;---
COPYD	CALL	COPDR		; Copy design
; End of copy design
CDSEND	CALL	SWAPFCB		; Swap back
CDS1	CALL	DWFLUSH		; Flush buffer
	CALL	DCLOSE
CDS90:	CALL	SWAPFCB		; Swap FCBs to normal
	JP	MAIN
;--
; Copy design routine
;--
COPDR	LD	HL,COPYD$	; Display copy message
	CALL	DMB
	CALL	SWAPFCB		; Swap FCBs
	LD	HL,CFNAME
; See if file exists
	CALL	DOPEN		; Open file
	PUSH	AF
; See if duplicate files
	LD	HL,(FCB1+6)	; DEC and drive
	LD	BC,(FCB2+6)
	OR	A
	SBC	HL,BC
	LD	A,250
	PUSH	AF
	JP	Z,CERRSNO
	POP	AF
	POP	AF
	PUSH	AF
	CP	24		; See if file exists
	JR	Z,CDEXSTS	; Ahead if not found
	OR	A		; See if error
	JP	NZ,CERRSNO	; Swapped and not open
; Ask if file should be overwritten
	POP	AF
	LD	A,(FCB1)
	BIT	7,A
	LD	A,8
	PUSH	AF
	JP	Z,CERRSNO
	POP	AF
	CALL	CSCRN		; Clear screen
	CALL	DSCRN
	LD	A,28
	LD	(HTOPIC),A
	LD	HL,WARNFE	; File exists
	CALL	DMENUB		; Display menu and beep
	CP	1		; See if YES
	JP	NZ,CDS90	; End if not
;;;
	LD	DE,SPACE
	CALL	DMFDE		; Store filename
	CALL	DREMOVE		; Remove file
;;;
	PUSH	DE		; Save DE
	LD	DE,FCB1		; FCB # 1
	LD	HL,SPACE
	CALL	FSPEC		; Move into FCB
	POP	DE		; Restore DE
	PUSH	AF
;;
; Fall into routine
CDEXSTS	POP	AF		; Restore error
	LD	DE,FCB1		; FCB
	CALL	DINITV		; Initialize file
	JP	NZ,CERRSO	; Swapped and open
	CALL	SWAPFCB		; Swap back
; Read in screen form page
	LD	HL,0
	LD	(CFORM),HL	; No form display
	LD	A,1
	LD	(FPFLAG),A
	XOR	A
; Loop
$CDSGNL	INC	A
	LD	(CPAGE),A	; Store in page
	PUSH	AF
	XOR	A
	LD	(PPLUS),A	; Make not plus
	LD	(PMINUS),A	; Make not minus
	POP	AF		; Restore page
	DEC	A		; See if first page
	JR	Z,$CPL
	INC	A
	LD	(PMINUS),A	; Make minus if so
	DEC	A
$CPL	CP	31		; See if end
	JR	Z,$CML		; Ahead if last page
	INC	A
	CALL	DFSF		; Find screen form
	LD	A,B		; See if nothing
	OR	C
	JR	Z,$CML		; Ahead if nothing
	LD	(PPLUS),A	; Create plus sign
$CML	LD	A,(CPAGE)	; Get current page
	DEC	A
	CALL	DFSF		; Get block number
	LD	A,B
	OR	C
	RET	Z		; Return if zero
	LD	DE,DATA		; Load into data buffer
	LD	(DSTART),DE
	CALL	DRDATA
	JP	NZ,CERRO
	LD	(DEND),DE
; Display screen
	CALL	CSCRN
	LD	HL,DATA
	CALL	DFRM		; Display form
	CALL	DINFO		; Information line
	CALL	DSCRN
; Write out screen form page
	CALL	SWAPFCB		; Swap FCBs
	CALL	DFREE		; Find free block
	JP	NZ,CERRSO	; Swapped and open
	PUSH	BC
	CALL	DWDATA		; Write screen page
	POP	BC
	JP	NZ,CERRSO
	CALL	$SSBSF		; Store in header
	CALL	SWAPFCB
	LD	A,(CPAGE)	; Get page number
	CP	32		; See if past
	JP	NZ,$CDSGNL	; Loop if not
	CALL	SWAPFCB		; Swap it
	RET
;---
; Copy specified records
;---
CSR	CALL	SWAPFCB		; Swap FCBs
	LD	HL,CFNAME
	CALL	DOPNV		; Open file
	JP	NZ,CERRSO	; Swapped and open
; See if duplicate files
	LD	HL,(FCB1+6)	; DEC and drive
	LD	BC,(FCB2+6)
	OR	A
	SBC	HL,BC
	LD	A,250
	PUSH	AF
	JP	Z,CERRSNO
	POP	AF
	CALL	SWAPFCB		; Swap back
; Display information
	LD	HL,CSPEC$	; Copy specification
	CALL	DMB
	CALL	SGSPEC		; Get specification
CSR1	LD	HL,COPYF$	; Copy
	CALL	DMB
; Begin search
	CALL	SFIRST		; Find first search
	JP	NZ,CERRO	; Ahead if error (no open)
	OR	A		; See if form or end
	JP	NZ,CENDO	; Ahead if end (no open)
; Transfer form
COPYS1	LD	HL,FORM		; Display form and data
	LD	DE,DATA
	CALL	DFRMD
	CALL	DSCRN
	CALL	SWAPFCB		; Swap FCBs
	CALL	ADDF		; First part of add
	LD	DE,DATA		; Start of data
	LD	(DSTART),DE	; Store start
	CALL	DFREE		; Find free block
	JP	NZ,CERRSO	; (swapped and open)
	PUSH	BC
	CALL	DWFORM		; Write new form to disk
; **ERROR**
	POP	BC
	CALL	ADDN
	JP	NZ,CERRSO	; (swapped and open)
COPYS6	CALL	SWAPFCB		; Swap FCBs
; See if another page
	LD	BC,(NXPAGE)	; Next page
	LD	A,B
	OR	C
	JP	Z,COPYS7
; There is another form
	LD	DE,DATA		; Read other page
	CALL	DRPAGE
	JR	NZ,CERRO	; (open)
	CALL	SWAPFCB		; Switch to write
; Make new page
	LD	BC,(SBLOCK)	; Starting block
	LD	(PVPAGE),BC	; Store in previous page
	CALL	DFREE		; Find free block
	JR	NZ,CERRSO	; (swapped and open)
	PUSH	BC
	CALL	DWPAGE		; Write new page to disk
	POP	BC
	JR	NZ,CERRSO
	PUSH	BC
	LD	BC,(PVPAGE)	; Read previous page
	CALL	DRBLKW		; Read first block of form
	POP	BC		; Restore next form block
	JR	NZ,CERRSO
	LD	A,4		; Go to "next page"
	ADD	A,L
	LD	L,A
	LD	(HL),C		; Store in form
	INC	L
	LD	(HL),B
	JR	COPYS6		; Loop until done
; See if another form
COPYS7	CALL	SNEXT		; Search next
	JR	NZ,CERRO	; Ahead if error (open)
	OR	A
	JR	Z,COPYS1	; Loop if form found
; End (open but not swapped)
CENDO	CALL	SWAPFCB		; Swap FCBs
	CALL	DWFLUSH		; Flush buffer
	CALL	DCLOSE
	CALL	SWAPFCB		; Swap FCBs to normal
; Not open
CENDNO	LD	A,27
	LD	(HTOPIC),A
	LD	HL,CR$		; Found message
	JP	$SRCHM		; Display message
; Error
; Open but not swapped
CERRO	PUSH	AF
	CALL	SWAPFCB		; Make it swapped
	POP	AF
; Swapped and open
CERRSO	PUSH	AF
	CALL	DWFLUSH
	CALL	DCLOSE		; Close file
CERRSNO	CALL	SWAPFCB		; Put back to normal
	POP	AF
; Not open
CERRNO	CALL	DOSERR
	JP	MAIN
;--
; File exists warning
;--
WARNFE	DB	2
	DB	29,9,1,'File already exists!',0
	DB	20,11,1,'Do you want to overwrite it?',0
	DB	50,11,8,'Y','YES',0
	DB	0FEH,'Yes, destroy file',0
	DB	55,11,8,'N','NO',0
	DB	0FEH,'No, return to main menu',0
	DB	255
;--
; Copy menu
;--
COPYM	DB	1
	DB	29,7,1,'Copy options',0
	DB	26,9,8,'1','1 - Copy whole file',0
	DB	0FEH,'Copy the design and forms to a new file',0
	DB	26,10,8,'2','2 - Copy design',0
	DB	0FEH,'Copy the design to a new file',0
	DB	26,11,8,'3','3 - Copy forms',0
	DB	0FEH,'Copy selected forms to an existing file',0
	DB	0FFH
;--
; Copy filename
;--
COPYF	DB	22,14,9,0,23,'File to copy to:',0
	DB	0FEH,'Type in a filename',0
	DB	255
;---
; Print
;---
PRINT	LD	HL,SSPEC$	; Search specification
	CALL	DMB
	LD	A,20
	LD	(HTOPIC),A
	CALL	SGSPEC		; Get specification
	CALL	CPRINT		; Get print specifics
	JP	PFSG5
; Get print specification
CPRINT	LD	HL,PSPEC$	; Print specification
	CALL	DMB
	LD	A,31
	LD	(HTOPIC),A
	LD	HL,PSPEC	; Store in print
	LD	(TSPEC),HL
	CALL	SGSPECA		; Get specification
	INC	DE
	LD	HL,SPEC
	LD	(TSPEC),HL
; Get print options
PROPY	CALL	CSCRN		; Clear screen
	LD	A,32
	LD	(HTOPIC),A
	XOR	A
	LD	(FPFLAG),A
	CALL	DINFO		; Display information
	LD	HL,POPT$	; Printer options
	CALL	DMB
	LD	HL,PROPT
	LD	DE,PRDAT
	CALL	LEDIT		; Edit options
	OR	A
	JP	Z,MAIN		; Main menu
	SVC	@CKBRKC		; Reset BREAK bit
	LD	A,1
	LD	(FPFLAG),A
	CALL	CBL		; Clear bottom line
; Process printer options
; Process yes/no options
	LD	A,(COL*8+35+SCRN)
	LD	HL,PFN		; Field names
	CALL	PYESNO
	LD	A,(COL*9+35+SCRN)
	LD	HL,PCRLF	; CR/LF
	CALL	PYESNO
	LD	A,(COL*12+35+SCRN)
	LD	HL,PPBP		; Pause between pages
	CALL	PYESNO
; Left margin
	LD	HL,COL*10+35+SCRN
	SVC	@DECHEX		; Convert to decimal
	LD	A,C
	CP	253+1
	JR	NC,PFSG		; Skip if invalid
	LD	(LMARGIN),A
	LD	HL,PLMAR	; Storage
	CALL	CVTAHL3		; Store
; Line length
PFSG	LD	HL,COL*6+35+SCRN
	SVC	@DECHEX		; Convert to decimal
	LD	A,C		; Maximum characters
	CP	5		; See if below
	JR	C,PFSG1
	CP	253+1
	JR	NC,PFSG1
	LD	(MCHAR),A
	LD	HL,PLLEN	; Line length
	CALL	CVTAHL3		; Convert
; Page length
PFSG1	LD	HL,COL*7+35+SCRN
	SVC	@DECHEX
	LD	A,C		; Page length
	CP	1
	JR	C,PFSG2
	CP	253+1
	JR	NC,PFSG2
	LD	(MLINE),A
	LD	HL,PPLEN
	CALL	CVTAHL3		; Convert
; Print device
PFSG2	LD	HL,PDEV		; Fill with spaces
	LD	B,23
PFSG3	LD	(HL),32
	INC	HL
	DJNZ	PFSG3
	LD	HL,COL*5+35+SCRN
	LD	DE,PFCB		; Transfer to FCB
	SVC	@FSPEC
	PUSH	AF
	LD	A,3
	LD	HL,PFCB		; Transfer to title
	LD	DE,PDEV
PFSG30	CP	(HL)		; See if same byte
	JR	Z,PFSG31
	LDI
	JR	PFSG30
; Open file
PFSG31	POP	AF
	LD	A,19		; Illegal file name
	JR	NZ,PFSG32
	LD	HL,PDATA
	LD	DE,PFCB
;****
	LD	B,0
	SVC	@INIT
	JR	Z,PFSG4		; Ahead if no error
	CP	42		; LRL open fault
	JR	Z,PFSG4		; No error
PFSG32	PUSH	AF
	LD	HL,PROPT
	CALL	DFRM
	POP	AF
	CALL	DOSERR		; Display error
	JP	PROPY
; See if writing to *DO
PFSG4	LD	HL,(PFCB+6)
	LD	DE,'OD'
	XOR	A
	LD	(PRVIEW),A
	SBC	HL,DE
	RET	NZ
; Definitely in preview mode
	LD	A,0C9H		; RET
	LD	(PRVIEW),A
	RET
; Possible sort in page zero
PFSG5	XOR	A
	LD	(SORTP),A
; See if "S" in specification
	LD	HL,PSPEC	; Print specification
PFSS	LD	A,(HL)		; See if end
	INC	A
	JP	Z,PFEP
	INC	HL		; Past type and number
	INC	HL
	LD	A,(HL)		; See if "S" or "s"
	AND	11011111B
	CP	'S'
	LD	DE,LETTERS
	JR	Z,PFSFND
	CP	'N'		; See if "N" or "n"
	LD	DE,NUMBS
	JR	Z,PFSFND
	CP	'D'		; See if "D" or "d"
	LD	DE,DATES
	JR	Z,PFSFND
	CP	'E'		; See if "E" or "e"
	LD	DE,EDATES
	JR	Z,PFSFND
PFSL	LD	A,(HL)		; Find end of field
	INC	HL
	OR	A
	JR	NZ,PFSL		; Loop until done
	JR	PFSS		; Loop back
PFEP	INC	HL		; See if end of specification
	LD	A,0		; Increment page
SORTP	EQU	$-1
	INC	A
	LD	(SORTP),A
	LD	A,(HL)
	CP	0F0H
	JR	NZ,PFSS
	JP	PSRCH		; Search (no sort)
PFSFND	LD	(SROUT),DE	; Store routine
	DEC	HL
	LD	A,(HL)		; Store number
	LD	(SORTN),A
; Store records in memory
	LD	HL,SORT$	; Sort message
	CALL	DMB
	EXX
	LD	HL,0		; Get HIGH$
	LD	B,H
	SVC	@HIGH$
	LD	DE,SORTD
	EXX
; Do first search
	CALL	SFIRST		; Find first
	JP	NZ,PSEERR
	OR	A
	JP	NZ,PSORTE	; Ahead if end of sort
; Store sort data
PSORT1	EXX			; See if enough memory
	PUSH	HL
	OR	A
	SBC	HL,DE
	LD	A,H
	OR	A
	JR	NZ,PSO1
	LD	A,L		; See if under 25 bytes
	CP	25
	JR	NC,PSO1
	LD	A,248		; Out of memory
	JP	PSEERR
PSO1	POP	HL
	EXX
	SVC	@CKBRKC		; Check BREAK
	JP	NZ,MAIN
	LD	HL,FORM		; Display data
	LD	DE,DATA
	CALL	DFRMD
	LD	A,(SORTP)	; Page number
	LD	B,A
PSORT10	LD	HL,DATA		; Start of data
	LD	A,B
	OR	A		; See if end
	JR	Z,PSORT2
	DEC	B
; Read in next page
	PUSH	BC
	LD	BC,(NXPAGE)	; Next page
	LD	A,B		; See if end
	OR	C
	JR	Z,$PSCH5	; Ahead if end
	LD	DE,DATA		; Load at data
	CALL	DRPAGE		; Otherwise, load in page
	POP	BC
	JP	NZ,PSEERR
	JR	PSORT10		; and loop
; End of pages to load
$PSCH5	POP	BC
	LD	HL,EMPTY$	; Empty form
; Now find correct field
PSORT2	LD	A,0		; Sort number
SORTN	EQU	$-1
	CALL	DFDN		; Find corresponding data
	OR	A		; If nothing, make it null
	JR	NZ,$PS1
	LD	HL,NULL$
$PS1	EXX
	PUSH	DE
	EXX
	POP	DE
; Store block number and form number
	LD	BC,(CFORMB)	; Block of form
	EX	DE,HL
	LD	(HL),C
	INC	HL
	LD	(HL),B
	INC	HL
	LD	BC,(CFORM)	; Current form number
	LD	(HL),C
	INC	HL
	LD	(HL),B
	INC	HL
	EX	DE,HL
; Store data
	LD	BC,10		; 10 bytes
	LDIR
	PUSH	DE
	EXX
	POP	DE
	EXX
; Search for next
	CALL	SNEXT		; Search next
	JP	NZ,PSEERR
	OR	A
	JP	Z,PSORT1	; Loop until done
; End of storing
PSORTE	EXX
	XOR	A
	LD	(DE),A
	INC	DE
	LD	(DE),A
	EXX
	PUSH	HL		; Display PRINT instead of SORT
	LD	HL,PRINT$
	CALL	DMB
	POP	HL
	CALL	PCLS
; Find first in sort
PSRTL	LD	DE,SORTD+4
	LD	HL,SORTD	; Start of data
PSRTL0	LD	A,(HL)		; See if end
	INC	HL
	OR	(HL)
	JP	Z,PSRTET	; End of table
	INC	HL
	INC	HL
	INC	HL
	RPUSH	HL,DE		; Save entry start
	JP	LETTERS		; Jump to correct sort
SROUT	EQU	$-2
; European date sort
EDATES	LD	A,1		; "dd/mm/yy"
	DB	6		; "LD B,n"
; Date sort
DATES	XOR	A		; "mm/dd/yy"
	LD	(FDTERMM+1),A
	INC	A
	LD	(FDTERMD+1),A
	EX	DE,HL
	RPUSH	HL,DE		; Save registers
	PUSH	DE		; Save second
	CALL	FDTERMY		; Convert year
	EX	DE,HL
	EX	(SP),HL		; Get off stack
	CALL	FDTERMY		; Convert year
	POP	HL		; Restore value
	OR	A
	SBC	HL,DE		; Compare values
	RPOP	DE,HL		; Restore registers
	JP	NZ,PSRTNE
; Month field
	RPUSH	HL,DE		; Save registers
	PUSH	DE		; Save second
	CALL	FDTERMM		; Convert month
	EX	DE,HL
	EX	(SP),HL		; Get off stack
	CALL	FDTERMM		; Convert month
	POP	HL		; Restore value
	OR	A
	SBC	HL,DE		; Compare values
	RPOP	DE,HL		; Restore registers
	JP	NZ,PSRTNE
; Day field
	PUSH	DE		; Save second
	CALL	FDTERMD		; Convert day
	EX	DE,HL
	EX	(SP),HL		; Get off stack
	CALL	FDTERMD		; Convert day
	POP	HL		; Restore value
	OR	A
	SBC	HL,DE		; Compare values
	JP	PSRTNE
FDTERMY	LD	B,2		; Year field
	CALL	FDTERM		; Convert it
	EX	DE,HL
	LD	A,H		; See if above 255
	OR	A
	JR	NZ,FDTY1
	LD	A,L		; See if above 100
	OR	A		; See if zero
	JR	Z,FDTY2
	CP	101
	JR	NC,FDTY1
FDTY0	LD	A,L		; See if below 19
	CP	20
	JR	NC,FDTY00
	LD	DE,100
	ADD	HL,DE
FDTY00	LD	DE,1900		; Add on century
	ADD	HL,DE
FDTY1	EX	DE,HL		; Switch them
	RET
FDTY2	INC	B
	DEC	B
	JR	Z,FDTY0		; 1900 if 3 terms
	LD	L,93		; Current year
DATE1	EQU	$-1
	DEC	B
	JR	Z,FDTY0		; Current year if two terms
	LD	HL,0
	JR	FDTY1		; Year 0 if fewer terms
FDTERMD	LD	B,0		; Day
	JR	FDTERM
FDTERMM	LD	B,1		; Month
FDTERM	LD	C,11
	INC	B
	INC	B
	LD	DE,0FFFFH
	LD	A,(HL)		; See if zero
	INC	A		; Return with maximum if so
	RET	Z
FDT1	DEC	B
	RET	Z		; Return if correct term
	LD	DE,0		; Reset value
FDT2	DEC	C		; Return if done
	RET	Z
	LD	A,(HL)		; See if number
	OR	A
	JR	Z,FDT3		; Return if end
	INC	HL
	SUB	'0'
	JR	C,FDT1		; Loop if invalid
	CP	10
	JR	NC,FDT1		; Loop if invalid
	PUSH	DE		; Exchange DE with HL
	EX	(SP),HL
	ADD	HL,HL		; Multiply by 2
	ADD	HL,HL		;  * 4
	ADD	HL,DE		;  * 5
	ADD	HL,HL		;  * 10
	LD	D,0		; Merge in digit
	LD	E,A
	ADD	HL,DE
	EX	DE,HL		; Put back in DE
	POP	HL
	JR	FDT2		; New byte
FDT3	DEC	B		; See if correct
	RET	Z
	LD	DE,0		; No value
	RET
; Number sort
NUMBS	CALL	GREAT
	RRA
	CCF
	JP	PSRTNE
; Letter sort
LETTERS	LD	A,(HL)		; Compare bytes
	CP	'a'		; Check for lowercase
	JR	C,PSR55		; None
	CP	'z'+1		; Check for lowercase
	JR	NC,PSR55	; None
	SUB	32		; Make lowercase
PSR55	LD	B,A
	LD	A,(DE)
	CP	'a'		; Check for lowercase
	JR	C,PSR56		; None
	CP	'z'+1		; Check for lowercase
	JR	NC,PSR56	; None
	SUB	32		; Make lowercase
PSR56	CP	B
	INC	HL
	INC	DE
	JR	NZ,PSRTNE
	OR	A		; See if zero
	JR	NZ,LETTERS	; Loop if not zero
; Equal entries fall through
PSRTNE	RPOP	DE,HL		; Restore entry start
	JR	C,PSRTDT
	PUSH	HL		; Move to DE
	POP	DE
PSRTDT	LD	BC,10		; Move to beginning
	ADD	HL,BC
	JP	PSRTL0
; End of table
PSRTET	LD	A,(DE)		; Find byte
	INC	A		; If 255, then reached end
	JR	Z,PSRTEND
	EX	DE,HL
	INC	HL
	XOR	A
	LD	(HL),A		; Make highest entry
	DEC	HL
	DEC	A
	LD	(HL),A
	DEC	HL
	LD	B,(HL)		; Current form
	DEC	HL
	LD	C,(HL)
	LD	(CFORM),BC	; Store current
	DEC	HL
	LD	B,(HL)		; Block number
	DEC	HL
	LD	C,(HL)
	CALL	FPRINT		; Print form
	JP	PSRTL
PSRTEND	JP	PSEEND
; Process yes/no
PYESNO	AND	11011111B	; Field names
	CP	'Y'		; See if yes
	JR	Z,PFS2
	CP	'N'		; See if no
	RET	NZ		; Return if not
PFS2	LD	(HL),A
	RET
;---
; Print individual form
;---
FPRINT	XOR	A
	LD	(POEND),A	; Eliminate RET
FPRINTA	LD	A,0
PRVIEW	EQU	$-1
	LD	(DSCRN),A	; Disable/enable screen
	LD	DE,DATA		; Display data on screen
	CALL	DRFORM
	JP	NZ,PSEERR	; Ahead if error
; Make sure correct page is loaded
	LD	A,(APAGE)	; Get current page
	DEC	A
	JR	Z,PRNT0		; Ahead if already zero
	XOR	A
	CALL	DFSF		; Get block number
	LD	A,1
	LD	(CPAGE),A
	LD	(APAGE),A
	LD	DE,FORM		; Load into form buffer
	LD	(DSTART),DE
	CALL	DRDATA
	JP	NZ,PSEERR
PRNT0	CALL	CSCRN
	LD	HL,FORM
	LD	DE,DATA
	CALL	DFRMD
	CALL	DINFO
	CALL	DSCRN
	LD	HL,PSPEC	; Print specification
PRNT1	LD	A,(HL)		; See if end
	INC	A
	JP	Z,PRNTEP	; End of page
	INC	HL		; Past type
	LD	A,(HL)		; Store number
	LD	(PDAT),A
	INC	HL
	LD	BC,(PRADD)	; Store printer address
	LD	(GG),BC
PRNT2	LD	A,(HL)		; See if end
	INC	HL
	OR	A
	JR	Z,PRNT1		; Loop back
	CP	'+'		; 2 spaces
	JR	Z,$PR8
	CP	'?'		; Print entry if exists
	JR	Z,PRQME
	CP	'"'		; Quoted information
	JP	Z,PRQ
	CP	'/'		; ENTER
	JP	Z,PRENT
	CP	39		; Single quote
	JP	Z,PRQ
	CP	','		; See if separator
	JP	Z,PRSEP
	AND	11011111B	; Make lowercase
	CP	'X'		; Next line
	JR	Z,$PR8
	CP	'C'		; Last, first
	JR	Z,PRLF
	CP	'F'		; Print field only
	JR	NZ,PRNT2	; Loop until done
	JR	$PR8
; See if field is empty
PRQME	LD	(PROP),A	; Store property
	PUSH	HL
	LD	A,(PDAT)	; Number of data
	LD	HL,DATA
	CALL	DFDN		; Find field
	OR	A
	POP	HL
	JR	Z,TEFND		; If empty, no data
	LD	A,(HL)		; See if empty
	OR	A
	JR	NZ,PRNT2	; Loop if data
; Field empty - print alternate
TEFND	LD	BC,$-$		; Previous address
GG	EQU	$-2
	LD	B,0
$PRW0	LD	A,(HL)		; Get byte
;%%%
	OR	A
	JR	Z,PRTENF	; End if empty
	INC	HL
	CP	'"'		; Double quote
	JR	Z,$PRSDQ
	CP	27H		; Single quote
	JR	Z,$PRSDQ
	CP	','		; See if separator
	JR	NZ,$PRW0	; Loop if not
; Separator
	JR	PRNT2		; Print rest of it
$PRSDQ	INC	B		; See if anything
	DEC	B
	JR	Z,$PRSDQ1
	CP	B		; See if same
	JR	NZ,$PRW0	; Loop if not
	LD	B,0		; Eliminate it
	JR	$PRW0
$PRSDQ1	LD	B,A		; Store value
	JR	$PRW0
; Acceptable option (in A)
$PR8	LD	(PROP),A
	PUSH	HL
$PRW1	LD	A,0		; Number of data
PDAT	EQU	$-1
	CALL	PRFIELD		; Print field
	POP	HL
	LD	A,0		; Printer option
PROP	EQU	$-1
	CP	'+'		; 2 spaces
	JR	NZ,$PR7
	LD	A,32
	CALL	PRCHAR		; Print 2 spaces
	LD	A,32
	CALL	PRCHAR
	JR	PRTENF
$PR7	CP	'X'
	JR	Z,$PRK7
	CP	'?'		; Next line
	JR	PRTENF
$PRK7	CALL	PRENDL		; Print CR
; End of field
PRTENF	JP	PRNT2
; Print last, first
PRLF	LD	BC,PRLLF	; Last, first routine
	LD	(PLROUT),BC
	LD	A,(PDAT)	; Printer data
	PUSH	HL
	CALL	PRFIELD		; Print field
	POP	HL
	LD	BC,PRLINE	; Normal routine
	LD	(PLROUT),BC
	JR	PRTENF
; Print carriage return
PRCR	LD	A,(PCRLF)	; See if CR/LF
	CP	'Y'
	JR	NZ,PRCR1	; Ahead if not
	CALL	PRCR1		; Print CR
	LD	A,0AH		; Print LF
	JR	PRCHAR1
PRSEP	LD	A,(HL)		; Go to end
	OR	A
	JP	Z,PRNT2
	INC	HL
	JR	PRSEP
PRCR1	LD	A,0DH
; Print character
PRCHAR1	RPUSH	HL,DE,BC
	LD	C,A
PRCHAR2	LD	DE,PFCB
	SVC	@PUT
	JP	NZ,PSEERR
	RPOP	BC,DE,HL
	RET
PRCHAR	PUSH	HL		; Save HL
	LD	HL,SCRN1	; Start of buffer
PRADD	EQU	$-2
	LD	(HL),A		; Store it
	INC	HL
	LD	(PRADD),HL
	POP	HL
	RET
;--
; Print end of line
; Remove spaces from end (but not beginning)
; (PRADD) = end of printed material
; SCRN1 = start of material
; (MCHAR) = maximum line width
;--
PREE:
	JP	$PRE8
PRENDL:	RPUSH	DE,HL
	LD	HL,(PRADD)	; Address in printer buffer
	LD	(HL),0		; Mark end
; See if at beginning
	LD	DE,SCRN1
	OR	A
	SBC	HL,DE
	JR	Z,PREE		; If at beginning, print CR only
	EX	DE,HL		; Move to HL
; Find end of line
PREND1:	LD	B,80		; Maximum line width
MCHAR	EQU	$-1
	LD	C,0
	PUSH	HL		; Save start
$FRZ1:	LD	A,(HL)		; See if end
	OR	A
	JR	Z,$RT56		; Reached end (doesn't matter)
	CP	32
	JR	NZ,$FRZ0
	INC	C		; Increase number of spaces
$FRZ0:	INC	HL
	DJNZ	$FRZ1		; Loop until done
; Any spaces?
	INC	C
	DEC	C
	JR	Z,$RT56		; Skip if no spaces
; See if at 0
	DEC	HL
	LD	A,(HL)		; If at end, then skip
	OR	A
	JR	Z,$RT56
	INC	HL
; Back over any non-space characters
$RT55:	DEC	HL
	LD	A,(HL)		; See if space
	CP	32
	JR	Z,$RT56		; Skip if space found
	INC	B
	JR	$RT55		; Loop until done
; Find correct length
$RT56:	LD	A,(MCHAR)	; Maximum number of characters
	SUB	B
	LD	B,A
; Found end (character count in B)
; Print left margin
$FRZ8:	PUSH	BC		; Save start and count
	LD	B,0		; Left margin
LMARGIN	EQU	$-1
	INC	B
	DEC	B
	JR	Z,$UIO		; Skip if 0
$UIOP:	LD	A,32		; Space
	CALL	PRCHAR1		; Print it
	DJNZ	$UIOP
$UIO:	POP	BC
; Ready to print
	POP	HL		; Restore start
$FRZ9:	LD	A,(HL)		; Get character
	OR	A
	JR	Z,$PRE8		; Abort if found
	CALL	PRCHAR1		; Print character
	INC	HL
	DJNZ	$FRZ9		; Loop
; Print end of line
	RPUSH	HL,DE,BC
	CALL	MCL		; Make correct line number
	RPOP	BC,DE,HL
	JR	PREND1		; Loop
; End of string found
$PRE8	LD	HL,SCRN1
	LD	(PRADD),HL
	LD	(GG),HL
	RPOP	HL,DE
; Make correct line
MCL	LD	A,(NLINE)	; Line number
	INC	A
	CP	6		; Compare with maximum
MLINE	EQU	$-1
	JR	NZ,$PRE7
	XOR	A		; Make zero
	LD	(NLINE),A
	CALL	PRCR
	JR	PRENDP2
$PRE7	LD	(NLINE),A
	JP	PRCR		; CR
; Print end of page
PRENDP	LD	A,(PRADD)	; See if only one line
	CP	.LOW.SCRN1	;  but unprinted
	JR	NZ,PRENDP1
PRENDP9	LD	A,0		; Line number
NLINE	EQU	$-1
	OR	A		; Return if zero
	RET	Z
PRENDP1	CALL	PRENDL		; Print line end
	JR	PRENDP9		; Loop until done
PRENDP2	LD	A,(PPBP)	; See if should pause
	CP	'Y'
	RET	NZ
	RPUSH	HL,DE,BC
	LD	A,34
	LD	(HTOPIC),A
	LD	HL,PRESS	; Press a key
	CALL	DFIELD
	CALL	DSCRN
PRENDP3	CALL	MSKEY		; Wait for key
	INC	A
	JR	Z,PRENDP3
	RPOP	BC,DE,HL
	CP	129		; BREAK key
	CALL	Z,PSEBRK
	CALL	CBL
	RET
; Print quoted information
PRQ	LD	C,A		; Store value
PRQ1	LD	A,(HL)		; See if end
	OR	A
	JP	Z,PRNT2
	INC	HL
	CP	0FFH		; See if compression
	JR	Z,PRQS
	CP	C		; See if end quote
	JP	Z,PRNT2
	CALL	PRCHAR		; Print character
	JR	PRQ1		; Loop until done
PRQS	LD	B,(HL)		; Get count
	INC	HL
	INC	HL
PRQS1	LD	A,32		; Space
	CALL	PRCHAR
	DJNZ	PRQS1
	JR	PRQ1
; Print ENTER
PRENT	CALL	PRENDL		; End line
	JP	PRNT2
;---
; Find numbered field
; B => number
;---
FNF	PUSH	HL		; Save address
	LD	A,(HL)		; Get byte
	CP	0FEH		; Is it comment?
	JR	Z,FNF1		; Skip if so
	INC	HL		; Past X, Y
	INC	HL
	LD	A,(HL)		; Get type
	INC	HL		; Next byte
	CP	7		; Is it title or above?
	JR	C,FNF1		; If so, ahead
	LD	A,(HL)		; Number
	INC	HL		; Past number
	JR	Z,FNF1		; Ahead if comment
	CP	B		; See if same
	JR	Z,FNF2		; Ahead if so
FNF1	LD	A,(HL)		; Get byte
	INC	HL
	OR	A
	JR	NZ,FNF1		; Loop until next
	EX	(SP),HL		; Destroy address
	POP	HL
	JR	FNF		; Loop until done
FNF2	POP	HL		; Restore HL
	RET
; Print field
PRFIELD	RPUSH	HL,DE,BC
	PUSH	AF
	LD	A,(PFN)		; Print item names
	CP	'Y'
	JR	NZ,$PZZ1
	POP	AF
; Find item name
	PUSH	AF
	LD	HL,FORM		; Find field name
	LD	B,A
	CALL	FNF
	INC	HL
	INC	HL
	INC	HL
	INC	HL
	CALL	PRLINE		; Print line
	LD	A,32
	CALL	PRCHAR
$PZZ1	POP	AF
	LD	HL,DATA
	CALL	DFDN		; Find field
	OR	A
	JR	NZ,$PRF7
	LD	HL,NULL$	; Null field if nothing
$PRF7	CALL	PRLINE		; Print line
PLROUT	EQU	$-2
	RPOP	BC,DE,HL
	RET
; Print last, first correctly
; Find first
PRLLF	PUSH	HL		; Save address
PRLLF0	LD	A,(HL)		; Get byte
	OR	A
	JR	Z,PRLLF01	; Ahead if end
	INC	HL
	CP	','
	JR	NZ,PRLLF0	; Loop until found
; Found comma, skip space
	LD	A,(HL)
	CP	32		; See if space
	JR	NZ,PRLLF00
	INC	HL		; Skip if space
PRLLF00	CALL	PRLINE		; Print line
	LD	A,32
	CALL	PRCHAR		; Print character
; Print last
PRLLF01	POP	HL		; Restore address
	LD	A,','
	LD	(BCOMMA),A	; End on comma
	CALL	PRLINE		; Print line
	XOR	A
	LD	(BCOMMA),A
	RET
; Print line
PRLINE	PUSH	DE
PRLINE1	LD	A,(HL)		; Get byte
	OR	A		; See if end
	JR	Z,PRLINEE
	CP	0		; See if byte
BCOMMA	EQU	$-1
	JR	Z,PRLINEE
	INC	HL
	CP	0FFH		; See if compression
	JR	Z,PRLINES
	CALL	PRCHAR		; Print character
	JR	PRLINE1
PRLINEE	POP	DE
	RET
; Handle space compression
PRLINES	LD	B,(HL)		; Get count
	INC	HL
	INC	HL
PRLINS1	LD	A,32
	CALL	PRCHAR		; Print space
	DJNZ	PRLINS1		; Loop until done
	JR	PRLINE1		; Jump back
;---
; Go to next page
;---
PRNTEP	PUSH	HL		; Save address
	SVC	@CKBRKC		; Check BREAK
	CALL	NZ,PSEBRK	; Go if BREAK
	POP	HL		; Restore address
	INC	HL		; See if end of specification
	LD	A,(HL)
	CP	0F0H
	JR	Z,PEPAGE	; End of page
; Load in next page (if it exists)
	LD	BC,(NXPAGE)	; Next page
	LD	A,B		; See if end
	OR	C
	JR	Z,PEPAGE	; Ahead if end
	PUSH	HL
	LD	DE,DATA		; Load at data
	CALL	DRPAGE		; Otherwise, load in page
	JP	NZ,PSEERR
	POP	HL
; Load in form page if needed
	LD	A,(PFN)		; Print item names?
	CP	'Y'
	JP	NZ,PRNT1	; Process next page
; Load in new screen form page
	LD	A,(CPAGE)	; Get current page
	PUSH	HL
	CALL	DFSF		; Get block number
	POP	HL
	LD	A,(CPAGE)
	INC	A
	LD	(APAGE),A
	LD	(CPAGE),A
	PUSH	HL
	LD	A,B
	OR	C
	JR	NZ,PRNTEP1	; Ahead if something
	LD	HL,NOTES	; "NOTES:"
	LD	DE,FORM
	LD	BC,NOTESL
	LDIR			; Move
	POP	HL
	JP	PRNT1		; Process next page
PRNTEP1	LD	DE,FORM		; Load into form buffer
	LD	(DSTART),DE
	CALL	DRDATA
	LD	(DEND),DE
	POP	HL
	JP	NZ,PSEERR
	JP	PRNT1		; Process next page
PEPAGE	JP	PRENDP		; Print page end
PSRCH	LD	HL,PRINT$	; Print
	CALL	DMB
	CALL	CBL		; Clear bottom line
	CALL	SFIRST		; Find first search
	JR	NZ,PSEERR
	OR	A		; See if form or end
	JR	NZ,PSEEND	; Ahead if end
	CALL	PCLS
; Print form
PRINT1	LD	BC,(CFORMB)	; Beginning block
	CALL	FPRINT		; Print form
	CALL	SNEXT		; Search next
	JR	NZ,PSEERR	; Ahead if error
	OR	A
	JR	Z,PRINT1	; Loop if form found
; End
PSEEND
POEND	NOP
	XOR	A
	LD	(DSCRN),A	; Enable screen
	LD	A,(PRVIEW)	; See if preview
	OR	A
	JR	Z,PSEEND1
	LD	A,34
	LD	(HTOPIC),A
	LD	A,(PPBP)	; Skip if pause between pages
	CP	'Y'
	JR	Z,PSEEND1
POEND1	CALL	MSKEY
	INC	A
	JR	Z,POEND1
	CP	129		; <BREAK>
	CALL	Z,PSEBRK
PSEEND1	CALL	PCLOS		; Close file
	LD	A,35
	LD	(HTOPIC),A
	LD	HL,PR$		; Found message
	JP	$SRCHM		; Display message
; Error
PSEERR:	PUSH	AF
	XOR	A
	LD	(DSCRN),A	; Enable screen
	POP	AF
	CP	8		; Device not available
	JR	NZ,PSEERR1	; Ahead if not
PSEERR0	PUSH	BC
	CALL	CBL		; Clear it
	LD	A,0C9H		; "RET"
	LD	(CBL),A
	LD	A,36
	LD	(HTOPIC),A
	LD	HL,PRERROR	; Printer error
	CALL	DMENU		; Display menu
	PUSH	AF
	XOR	A
	LD	(CBL),A
	POP	AF
	POP	BC
	OR	A		; Is it <BREAK>?
	JP	Z,PSEERR0	; Jump back if so
	DEC	A		; Is it YES?
	JP	NZ,PCLOSE	; Close if NO
	PUSH	BC
	CALL	PCLS
	POP	BC
	JP	PRCHAR2		; Jump back if yes
PSEERR1	PUSH	AF
	CALL	PCLOS
	POP	AF
	CALL	DOSERR
	JP	MAIN
; BREAK
PSEBRK	SVC	@CKBRKC		; Eliminate BREAK
	XOR	A
	LD	(DSCRN),A	; Enable screen
	LD	A,33
	LD	(HTOPIC),A
	CALL	CBL		; Clear it
	LD	A,0C9H		; "RET"
	LD	(CBL),A
	LD	HL,BREAK	; BREAK prompt
	CALL	DMENU		; Display menu
	PUSH	AF
	XOR	A
	LD	(CBL),A
	POP	AF
	OR	A		; Is it <BREAK>?
	JP	Z,PSEBRK	; Jump back if so
	DEC	A		; Is it YES?
	JR	NZ,PCLOSE
	CALL	PCLS
	RET
; Close file properly
PCLOSE	CALL	PCLOS		; Close file
	JP	MAIN
PCLOS	LD	A,(PFCB)	; Compare bit
	BIT	7,A
	RET	Z		; Return if not open
	LD	DE,PFCB		; Close file
	SVC	@CLOSE
	RET
PCLS	LD	A,(PRVIEW)
	OR	A
	RET	Z
	SVC	@CLS
	LD	C,10H
	SVC	@DSP
	LD	C,11H
	SVC	@DSP
	LD	A,(PRVIEW)
	LD	(DSCRN),A
	RET
;===
; Print options
PROPT	DB	10,5,1,0
	DB	21,5,9,0,23,'Print device:',0
	DB	0FEH,'*PR for printer or filename',0
	DB	21,6,9,1,3,'Line length :',0
	DB	0FEH,'Acceptable values: 5-253 (default is 80)',0
	DB	21,7,9,2,3,'Page length :',0
	DB	0FEH,'Acceptable values: 1-253 (default is 6)',0
	DB	21,8,9,3,1,'Field names :',0
	DB	0FEH,'Print field names? (Y for yes, N for no)',0
	DB	21,9,9,4,1,'LF after CR :',0
	DB	0FEH,'Print a line feed after each carriage '
	DB	'return? (Y for yes, N for no)',0
	DB	21,10,9,5,3,'Left margin :',0
	DB	0FEH,'Acceptable values: 0-253 (default is 0)',0
	DB	39,10,1,0
	DB	14,12,9,6,1,'Pause between pages:',0
	DB	0FEH,'Wait for a key after printing each page '
	DB	'(Y for yes, N for no)',0
	DB	67,12,1,0
	DB	0FFH
PDEV	EQU	$+2
PRDAT	DB	9,0,'*PR                    ',0
	DB	9,1,'80 ',0
PLLEN	EQU	$-4
	DB	9,2,'6  ',0
PPLEN	EQU	$-4
	DB	9,3,'N',0
PFN	EQU	$-2
	DB	9,4,'N',0
PCRLF	EQU	$-2
	DB	9,5,'0  ',0
PLMAR	EQU	$-4
	DB	9,6,'N',0
PPBP	EQU	$-2
	DB	0FFH
;--
EMPTY$	DB	0FFH,0FFH
MHEAD	DB	'DM4',VERSION,0,0,0,0
MHEADC	EQU	$-MHEAD
;===========
; Data area
;===========
PFCB	DS	32
PDATA	DS	256
FFORM	DB	0,20,1,0
	DB	0,22,9,0,23,'Filename:',0
	DB	0FEH,'Type in a filename',0
	DB	30,22,1,0
FDATA	DB	255
FCOUNT	DB	0
RMAXV	DW	0
;===
HFILE$	DB	'DM/HLP',0DH
;MOUSE$	DB	'$MOUSE',03H
SORT$	DB	9,'Sorting'
ADD$	DB	12,'Add record'
CFRM$	DB	15,'Create design'
CMENU$	DB	11,'Copy menu'
MMENU$	DB	11,'Main menu'
MDM$	DB	20,'Modify design menu'
SSPEC$	DB	22,'Search specification'
RSPEC$	DB	22,'Remove specification'
PSPEC$	DB	21,'Print specification'
CSPEC$	DB	20,'Copy specification'
POPT$	DB	15,'Print options'
HELP$	DB	6,'Help'
PRINT$	DB	7,'Print'
SEARCH$	DB	8,'Search'
REMOVE$	DB	8,'Remove'
COPYD$	DB	13,'Copy design'
COPYF$	DB	12,'Copy forms'
END$	DB	6,'Exit'
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
	DB	34,7,1,'version 1.0 ',0
HERE	EQU	$+4
	DB	12,10,1,'copyright (c) 1995 by Matthew Reed, '
	DB	'all rights reserved',0
	DB	24,11,1,'distributed by COMPUTER NEWS 80',0
	DB	0FFH
MMENU	DB	1
	DB	31,13,8,'1','1 - Add',0
	DB	0FEH,'Add a record to the file',0
	DB	31,14,8,'2','2 - Search',0
	DB	0FEH,'Search and modify specified records',0
	DB	31,15,8,'3','3 - Copy',0
	DB	0FEH,'Copy elements of this file to another file',0
	DB	31,16,8,'4','4 - Print',0
	DB	0FEH,'Print specified records',0
	DB	31,17,8,'5','5 - Remove',0
	DB	0FEH,'Delete specified records',0
	DB	31,18,8,'6','6 - Modify design',0
	DB	0FEH,'Modify the existing screen forms',0
	DB	31,19,8,'7','7 - Exit',0
	DB	0FEH,'Exit DATA-MINDER',0
	DB	255
;===
END	DB	2
	DB	11,10,1,'Are you sure you want to exit?',0
	DB	43,10,8,'Y','YES',0
	DB	0FEH,'Yes, exit DATA-MINDER',0
	DB	49,10,8,'N','NO',0
	DB	0FEH,'No, return to the main menu',0
	DB	255
NEW	DB	2
	DB	0,23,1,'File does not exist; create it?',0
	DB	33,23,8,'Y','YES',0
	DB	38,23,8,'N','NO',0
	DB	255
RMVQST	DB	1
	DB	0,23,1,'Do you want to remove this form?',0
	DB	34,23,8,'Y','YES',0
	DB	39,23,8,'N','NO',0
	DB	255
PRERROR	DB	1
	DB	0,23,1,'Printing error!  Continue printing?',0
	DB	37,23,8,'Y','YES',0
	DB	42,23,8,'N','NO',0
	DB	255
BREAK	DB	1
	DB	0,23,1,'Continue printing?',0
	DB	20,23,8,'Y','YES',0
	DB	25,23,8,'N','NO',0
	DB	255
PRESS	DB	0,23,1,'Press a key to continue...',0
;===
CR$	DB	30,9,1,'Forms copied:',0
PR$	DB	29,9,1,'Forms printed:',0
RR$	DB	29,9,1,'Forms removed:',0
FR$	DB	31,9,1,'Forms found:',0
FOUND$	DB	44,9,1
FFNUM$	DB	'00000',0
	DB	21,11,1,'Press a key to return to the main menu',0
	DB	255
SPACE	DS	32
;=====
; Data areas
;=====
FORM	DS	2048		; Maximum of 2K
DATA	DS	2048		; Maximum of 2K
SPEC	DS	2048		; Maximum of 2K
PSPEC	DS	2048		; Maximum of 2K
SORTD	EQU	$
	END	START
