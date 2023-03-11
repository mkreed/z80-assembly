*GET EQUATES
*GET MACROS
DIRRD@	EQU	18BBH		; Address of @DIRRD
OVHK	EQU	1ABAH		; Hook into SYS loader
LNTH	DEFL	ENDMOD-BEGIN	; Length of module
VAL	EQU	80H		; Set value bit
SW	EQU	40H		; Set switch bit
ABR	EQU	10H		; Set abbreviation bit
	ORG	2700H
;-----------
; Initialize
;-----------
START	LD	(STACK+1),SP	; Save old stack
	LD	SP,START	; New stack
	SVC	@CKBRKC		; Is break pressed?
	JP	NZ,ABORT	; If so, abort
	PUSH	HL		; Save command line
	LD	HL,OPEN$	; Opening message
	SVC	@DSPLY		; Display it
	POP	HL		; Restore command line
;--------------------------
; Parse parameters (if any)
;--------------------------
	LD	DE,PARM$	; Parameter table
	SVC	@PARAM		; Parse parameters
	JP	NZ,PARMERR	; Abort if error
;--------------------------------
; See if module should be removed
;--------------------------------
	LD	BC,0		; Default REMOVE=OFF
RMVVAL	EQU	$-2
	LD	A,B
	OR	C
	JP	NZ,REMOVE	; Remove module

;-----------------------------------------
; Make sure SYSTEM and DRIVE are numeric
;-----------------------------------------
	LD	A,(SYSRSP)	; Are SYSTEM
	LD	C,A
	LD	A,(DRVRSP)	; and DRIVE
	AND	C
	BIT	7,A		; numeric?
	JP	Z,PARMERR	; Abort if not
;-----------------------
; Make sure drives exist
;-----------------------
	LD	BC,0		; SYSTEM value
SYSVAL	EQU	$-2
	LD	A,C		; Put in
	LD	(SYSTEM),A	; driver
	CALL	TSTD		; Test for valid drive
	LD	BC,1		; DRIVE value
DRVVAL	EQU	$-2
	LD	A,C		; Put in
	LD	(DRIVE),A	; driver
	CALL	TSTD		; Test for valid drive
;----------------------------
; Make sure SYS1 is on drives
;----------------------------
	LD	A,(SYSVAL)	; Drive to search
	CALL	TSYS1		; Test for existence
	JP	Z,INSTALL	; Install if there
	LD	A,(DRVVAL)	; Drive to search
	CALL	TSYS1		; Test for existence
	JP	Z,INSTALL	; Install if there
;----------------
; Display errors
;----------------
NTINST	LD	HL,NTINST$	; Module not installed
	DB	0DDH
CNTRMV	LD	HL,CNTRMV$	; Module not removed
	DB	0DDH
IMDV	LD	HL,IMDV$	; Improper DOS version
	DB	0DDH
NS1	LD	HL,NS1$		; No SYS1
	DB	0DDH
DRN	LD	HL,DRN$		; Drive doesn't exist
	DB	0DDH
DNID	LD	HL,DNID$	; Disk not in drive
	DB	0DDH
MEMERR	LD	HL,MEMERR$	; Memory error
ERR	SVC	@LOGOT		; Log message
;--------------
; Abort or exit
;--------------
ABORT	LD	HL,-1		; Error
	DB	0DDH
EXIT	LD	HL,0		; Success
STACK	LD	SP,$-$		; Old stack
	RET			; Return
;--------------------
; Error routines
;--------------------
DRNE	LD	A,30H		; Zero
	ADD	A,C		; Make into number
	LD	(DRV1),A	; Put in message
	JR	DRN		; Signal error
;
DNIDE	LD	A,30H		; Zero
	ADD	A,C		; Make into number
	LD	(DRV2),A	; Put in message
	JR	DNID		; Signal error
;
PARMERR	LD	A,44		; Invalid parameters
;-----------
; DOS errors
;-----------
DOSERR	LD	L,A		; Put error
	LD	H,0		; in HL
	OR	0C0H		; Abbreviate, return
	LD	C,A		; Display
	SVC	@ERROR		; error message
	JR	STACK		; Abort
;----------
; Test SYS1
;----------
TSYS1	LD	C,A
	LD	B,3		; SYS1
	SVC	@DIRRD		; Read dir entry
	JR	NZ,DOSERR	; Fatal error
	LD	A,(HL)		; Get overlay
	AND	50H		; Was it purged
	XOR	50H		; or non-system?
	RET
;------------
; Test drive
;------------
TSTD	CP	8		; Is it invalid?
	JP	NC,PARMERR	; Abort if error
	SVC	@DCSTAT		; Does it exist?
	JP	NZ,DRNE		; Abort if no
	SVC	@CKDRV		; Is there a disk?
	JP	NZ,DNIDE	; Abort if no
	RET
;-----------------
; Install SYSFLEX
;-----------------
INSTALL	LD	DE,FLEX$	; look for module
	SVC	@GTMOD
	JR	NZ,INHG		; Put in high if not
	PUSH	HL		; Save pointer to module
	LD	BC,SYSTEM-BEGIN	; Point to SYSTEM
	ADD	HL,BC
	LD	A,(SYSTEM)	; Get SYSTEM drive
	LD	(HL),A		; Put in module
	LD	BC,DRIVE-SYSTEM	; Point to DRIVE
	ADD	HL,BC
	LD	A,(DRIVE)	; Get DRIVE drive
	LD	(HL),A		; Put in module
	JR	LINK		; Link into system
INHG	LD	A,(OVHK)	; Test byte
	CP	0BBH		; Is it 18BBH?
	JP	NZ,IMDV		; Abort if error
	LD	A,(OVHK+1)
	CP	18H
	JP	NZ,IMDV		; Abort if error
	LD	HL,0		; Retrieve address
	LD	B,H		; High memory
	SVC	@HIGH$
	JP	NZ,MEMERR	; Abort if error
	LD	(OLDHI),HL	; Save HIGH$ in module
	LD	BC,LNTH		; Length of module
	OR	A		; Reset carry
	SBC	HL,BC		; Find new HIGH$
	LD	B,0		; Set new HIGH$
	SVC	@HIGH$
	JP	NZ,MEMERR	; Abort if error
	PUSH	HL		; Save for later
	EX	DE,HL		; Point DE to destination
	INC	DE
	LD	HL,BEGIN	; Point HL to source
	LD	BC,LNTH		; Length to transfer
	LDIR
;--------------------------------
; Make linkage into system loader
;--------------------------------
LINK	LD	BC,17		; Length of header
	POP	HL		; Restore HIGH$
	ADD	HL,BC		; Find SYSFLEX
	LD	(OVHK),HL	; Install hook
;--------------------------
; Announce success and exit
;--------------------------
	LD	HL,SCC$		; Display message
	SVC	@DSPLY
	JP	EXIT		; Exit
;-----------------
; Turn SYSFLEX off
;-----------------
REMOVE	LD	HL,DIRRD@	; System SYS loader
	LD	(OVHK),HL	; Reload it
	XOR	A		; Drive 0
	LD	(0092H),A	; Put in system FCB
;--------------------------
; Remove module from memory
;--------------------------
	LD	DE,FLEX$	; Module name
	SVC	@GTMOD		; Look in high memory
	JP	NZ,NTINST	; Abort if not found
	PUSH	HL		; Save module address
	LD	HL,0		; Get HIGH$
	LD	B,H
	SVC	@HIGH$
	JP	NZ,MEMERR	; Abort if error
	EX	DE,HL		; DE = HIGH$
	POP	HL		; HL = module address
	DEC	HL		; Back one
	OR	A		; Compare
	SBC	HL,DE
	JP	NZ,CNTRMV	; Abort if error
	EX	DE,HL		; Switch to HL
	INC	HL		; Go to OLDHI
	INC	HL
	INC	HL
	LD	E,(HL)
	INC	HL
	LD	D,(HL)		; DE = (OLDHI)
	EX	DE,HL		; Switch to HL
	LD	B,0		; Set new HIGH$
	SVC	@HIGH$
	JP	NZ,MEMERR	; Abort if error
;--------------------------
; Announce success and exit
;--------------------------
	LD	HL,RMVSCC$	; Remove success message
	SVC	@DSPLY
	JP	EXIT
;---------
; Messages
;---------
OPEN$	DB	'SYSFLEX, modified SYS file loader 1.0',LF
	DB	'  copyright (c) 1990 by Matthew Reed',LF
	DB	'  all rights reserved',LF,CR
SCC$	DB	'SYSFLEX correctly installed and operational',0DH
RMVSCC$	DB	'SYSFLEX is turned off and memory is reclaimed',0DH
;
NS1$	DB	'Neither drive has SYS1!',0DH
DRN$	DB	'Drive 0'
DRV1	EQU	$-1
	DB	' is not enabled!',0DH
DNID$	DB	'There is no disk in drive 0!',0DH
DRV2	EQU	$-3
MEMERR$	DB	'High memory address can''t be changed!',0DH
IMDV$	DB	'Overlay hook already in use!',0DH
CNTRMV$	DB	'SYSFLEX is turned off but memory can''t be reclaimed',0DH
NTINST$	DB	'SYSFLEX is not installed',0DH
FLEX$	DB	'SYSFLEX',03H
;----------------
; Parameter table
;----------------
PARM$	DB	80H		; Start of table
	DB	VAL.OR.ABR.OR.6
	DB	'SYSTEM'	; SYSTEM parameter	
SYSRSP	DB	VAL
	DW	SYSVAL
;
	DB	VAL.OR.ABR.OR.5
	DB	'DRIVE'		; DRIVE parameter
DRVRSP	DB	VAL
	DW	DRVVAL
;
	DB	SW.OR.6
	DB	'REMOVE'
	DB	SW
	DW	RMVVAL
	DB	0		; End of table
;---------------------------
; SYSFLEX high memory module
;---------------------------
;--------------
; Memory header
;--------------
BEGIN	JR	SYSFLEX		; Branch around linkage
OLDHI	DW	$-$		; Last byte used
	DB	7,'SYSFLEX'	; Name of module
MODDCB	DW	$-$		; No DCB pointer
	DW	0		; Reserved by DOS
;--------------
; Start of code
;--------------
SYSFLEX	LD	A,0		; SYSTEM
SYSTEM	EQU	$-1
	LD	(0092H),A	; System FCB
	LD	C,A
	CALL	DIRRD@		; Read dir entry
	RET	NZ		; Return if error
	LD	A,(HL)		; Was overlay purged?
	AND	50H		;  or is it non-system?
	XOR	50H
	RET	Z		; Return if successful
	LD	A,1		; DRIVE
DRIVE	EQU	$-1
	LD	(0092H),A	; System FCB
	LD	C,A
	JP	DIRRD@		; Read dir entry
ENDMOD	EQU	$		; End of module
	END	START
