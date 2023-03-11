;===
; Mouse driver for use with Model 4 emulator
;   copyright (c) 1998, by Matthew Reed
;===
*GET EQUATES
@MOUSE	EQU	120
	COM	'<Copyright (c) 1998 by Matthew Reed, all rights reserved>'
;-----------------------
; Start of installation
;-----------------------
	ORG	3000H
BEGIN	LD	(STACK),SP	; Save stack
	LD	SP,BEGIN	; Make new stack
	SVC	@CKBRKC		; Abort if break pressed
	JP	NZ,ABORT
	PUSH	HL		; Save command line
	LD	HL,TITLE$	; Display title
	SVC	@DSPLY
	POP	HL
;---------------------
; Test for parameters
;---------------------
	SVC	@FLAGS$		; Set IY
	LD	A,(IY+26)	; SVC table MSB
	LD	(SVCA1),A	; Stuff in program
	LD	(SVCA2),A
	PUSH	IY		; Put in HL
	LD	DE,PARM$	; Parameter table
	SVC	@PARAM		; Parse parameters
	JP	NZ,PARME	; Abort if error
	LD	BC,0		; REMOVE = OFF
REMOVE	EQU	$-2
	LD	A,B		; Is it ON?
	OR	C
	JP	NZ,RMV		; REMOVE if ON
;----------------
; Install $MOUSE
;----------------
	LD	DE,MOUSE$	; "$MOUSE"
	SVC	@GTMOD		; Is it in high memory?
	JR	NZ,GOH		; Ahead if not
	CALL	CSAME		; Make sure it is the same
	JP	LINK		; Link into driver if so
;---------------
; Get old HIGH$
;---------------
GOH	LD	HL,0		; Get current HIGH$
	LD	B,L
	SVC	@HIGH$
	JP	NZ,NOMEM$	; No high memory
	LD	(OLDHI),HL	; Put in module
;-----------------------
; Move into high memory
;-----------------------
MOVH	LD	DE,(OLDHI)	; Destination
	LD	HL,MODEND	; Last byte of module
	LD	BC,LENGTH	; Length of module
	LDDR			; Move into high memory
	EX	DE,HL		; HL = HIGH$
	SVC	@HIGH$		; Set it
	JP	NZ,NOMEM	; Abort if error
	INC	HL		; Ahead one
;-----------------
; Install SVC 120
;-----------------
LINK	LD	BC,SVC120-MOUSE	; Find SVC address
	ADD	HL,BC
	LD	(01F0H),HL	; Put in SVC table
SVCA1	EQU	$-1
;------------------------
; Initialize mouse driver
;------------------------
	LD	B,7		; Enable mouse driver
	SVC	@MOUSE
	LD	HL,80		; Set maximum values
	LD	DE,24
	LD	BC,0401H	; Sensitivity
	SVC	@MOUSE
;---------------
; Success, exit
;---------------
	LD	HL,SCC$		; Installation success
	DB	0DDH
RSCC	LD	HL,RSCC$	; Remove success
	SVC	@DSPLY
EXIT	LD	HL,0		; No error
	DB	0DDH
ABORT	LD	HL,-1		; Error
	LD	SP,$-$		; Restore stack
STACK	EQU	$-2
	RET
;==
; Make sure mouse driver is the same
;==
CSAME	PUSH	HL		; Push HL and DE
	PUSH	DE
	INC	DE		; Add 4
	INC	DE
	INC	DE
	INC	DE
	LD	HL,IDENT	; Point to identifier
	LD	BC,3		; 3 bytes
CSAME1	LD	A,(DE)		; Get byte
	INC	DE
	CPI
	JP	NZ,NSDME
	JP	PE,CSAME1	; Loop until done
	POP	DE		; Pop DE and HL
	POP	HL
	RET			; Successful
;---------------------
; Remove mouse driver
;---------------------
RMV	LD	DE,MOUSE$	; Module name
	SVC	@GTMOD		; Look in high memory
	JP	NZ,NTINST	; Abort if not found
	CALL	CSAME		; Make sure same mouse driver
	PUSH	HL		; Save address
	LD	HL,01F0H	; @MOUSE SVC
SVCA2	EQU	$-1
	LD	A,(HL)		; Get address
	INC	L
	LD	H,(HL)
	LD	L,A
	LD	A,(HL)
	CP	3EH		; Is it active?
	JR	Z,RMV1		; If not, already disabled
	LD	B,6		; Disable mouse interrupt
	SVC	@MOUSE
RMV1	LD	HL,1AF4H	; SVC error
	LD	(01F0H),HL	; Put in table
SVCA3	EQU	$-1
	LD	HL,0		; Get HIGH$
	LD	B,H
	SVC	@HIGH$
	JP	NZ,NOMEM	; Abort if error
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
	LD	A,(HL)
	INC	HL
	LD	H,(HL)
	LD	L,A		; HL = (OLDHI)
	LD	B,0		; Set new HIGH$
	SVC	@HIGH$
	JR	Z,RSCC		; Go if success
;----------------
; Error routines
;----------------
NSDME	LD	HL,NSDME$	; Not same driver
	DB	0DDH
NOMEM	LD	HL,NOMEM$	; No memory
	DB	0DDH
PARME	LD	HL,PARME$	; Parameter error
	DB	0DDH
NTINST	LD	HL,NTINST$	; Driver not installed
	DB	0DDH
CNTRMV	LD	HL,CNTRMV$	; Can't remove
	SVC	@LOGOT
	JR	ABORT
;----------
; Messages
;----------
TITLE$	DB	'Model 4 emulator mouse driver',0AH
	DB	'copyright (c) 1998 by Matthew Reed,'
	DB	' all rights reserved',0AH,0DH
SCC$	DB	'Mouse driver successfully installed',0DH
RSCC$	DB	'Mouse driver turned off and memory reclaimed',0DH
NOMEM$	DB	'High memory address can''t be changed!',0DH
PARME$	DB	'Parameter error!',0DH
NTINST$	DB	'Mouse driver is not installed!',0DH
CNTRMV$	DB	'Mouse driver turned off but memory can''t be reclaimed',0DH
NSDME$	DB	'A different mouse driver is already in memory!',0DH
MOUSE$	DB	'$MOUSE',03H
;-----------------
; Parameter table
;-----------------
PARM$	DB	80H
	DB	STR.OR.ABR.OR.6
	DB	'REMOVE'
RRSP	DB	0
	DW	REMOVE
	DB	0
;----------------------------------
; Resident portion of mouse driver
;----------------------------------
MOUSE	JR	SVC120
OLDHI	DW	$-$		; Old HIGH$
	DB	MODDCB-MOUSE-5
	DB	'$MOUSE'
MODDCB	DW	$-$
	DW	0
IDENT	DB	'E4',10H
;-----------------
; SVC 120 handler
;-----------------
SVC120:	DB	0EDH,0FDH	; MOUSE
	RET
MODEND	EQU	$-1
LENGTH	EQU	$-MOUSE
	END	BEGIN
