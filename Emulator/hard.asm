;===
; Hard disk driver
; For use with TRS-80 Model 4 emulator
;
;===
	COM	'<Copyright (c) 1998 by Matthew Reed, all rights reserved>'
*GET EQUATES
@EXIT3		EQU	402DH		; DOS return entry
@DSPLY3		EQU	4467H		; Display message (Model 1/3)
@TRSDSPLY	EQU	021BH		; Display message (TRSDOS 1.3)
@PARAM1		EQU	4476H		; Parameter scanner (Model 1)
@PARAM3		EQU	4454H		; Parameter scanner (Model 3)
@GTDCT3		EQU	478FH		; Find DCT (Model 1/3)
HIGH1$		EQU	4049H		; HIGH$ (Model 1)
HIGH3$		EQU	4411H		; HIGH$ (Model 3)
	ORG	5200H
START:
	CALL	TESTMODEL		; Set MODEL number
; See if Model 1/3 LDOS or Model 4 LS-DOS
	LD	A,(IX+0)
	CP	3			; Is it LS-DOS?
	JR	Z,$OSOK
	OR	A			; Is it Model 1/3?
	JP	NZ,OSBAD
	CALL	CKDOS			; See if TRSDOS 1.3
	JP	Z,OSBAD
; Operating system was OK
$OSOK:	LD	DE,PARMTBL
	CALL	PARAM		; Parse parameters
	PUSH	AF
	LD	DE,$-$
QUPARM	EQU	$-2
	LD	A,D
	OR	E
	LD	A,0C9H
	JR	Z,$HD1
	LD	(DSPLY),A	; Force RET if QUIET
$HD1:	LD	HL,OPENER$
	CALL	DSPLY
	POP	AF
	JP	NZ,PARMERR	; Error if bad parameters
; Set real-time clock
 	LD	HL,0
	DB	0EDH,0FEH		; CLOCK instruction
	LD	A,H			; See if anything happened
	OR	L
	JP	Z,BADEMU		; Nothing did
	CALL	SETTIME			; Set date and time buffers
; Set parameters in DCT
	XOR	A
	LD	B,A
	LD	C,A
	LD	B,255
	DB	0EDH,0FFH
	JP	NZ,NOHARD		; No hard disk file
	OR	B			; See if hard drive not supported
	OR	C
	JP	Z,BADEMU
	LD	A,L			; Determine density
	OR	L
	JR	Z,$NT1
	LD	A,80H			; Set requests to double-density
	LD	(DENSITY),A
	LD	A,(DCT+3)
	OR	40H			; Set DCT to double density
	LD	(DCT+3),A
$NT1:	LD	(DCT+6),DE
	LD	(DCT+8),BC
;===
; Install driver
;===
; See if drive is available
INSTALL:
	LD	BC,4		; Default to drive 4
DRVPARM	EQU	$-2
	LD	A,B
	OR	A		; Is drive too high?
	JR	NZ,ILLDRV
	LD	A,C
	CP	8		; Is drive too high?
	JR	NC,ILLDRV
	LD	A,C
	ADD	A,'0'		; Convert into number
	LD	(UDRIVE),A	; Store in message
; Move to correct DCT
	LD	A,C
	CALL	GTDCT
	LD	A,(IY+0)
	CP	0C9H		; Is drive activated?
	JR	NZ,DRVACT
; Make sure not already installed
	PUSH	IY
	CALL	TESTINST
	JP	NZ,ALRERR
	CALL	INSTMEM		; Install into memory
	LD	H,D
	LD	L,E
	LD	BC,HRDDRV-HARD
	ADD	HL,BC
	LD	A,L
	LD	(DCT+1),A	; Install jump address in DCT
	LD	A,H
	LD	(DCT+2),A
; Install DCT
	POP	DE
	LD	HL,DCT
	LD	BC,10
	LDIR			; Move DCT entry into table
; Successful finish
ISUCCESS:
	LD	HL,ISUCCESS$
SUCC:	CALL	DSPLY
	JP	EXIT
; Error routines
ILLDRV:	LD	HL,ILLDRV$
	DB	0FDH
DRVACT:	LD	HL,DRVACT$
	DB	0FDH
PARMERR:
	LD	HL,PARAMERR$
	DB	0FDH
BADEMU:	LD	HL,BADEMU$
	DB	0FDH
ALRERR: LD	HL,ALRERR$
	DB	0FDH
IOERR:	LD	HL,IOERR$
	DB	0FDH
NOROOM:	LD	HL,NOROOM$
	DB	0FDH
OSBAD:	LD	HL,OSBAD$
	DB	0FDH
NOHARD:	LD	HL,NOHARD$
ERREXIT:
	LD	A,(DSPLY)
	CP	0C9H
	JR	NZ,$VH1
	PUSH	HL
	LD	HL,OPENER$
	CALL	DSPLY
	POP	HL
$VH1:	CALL	DSPLY
	JP	EXIT
;--
; See if driver already installed
; Exit: Z if not installed
;	NZ if installed, HL = DCT
;--
TESTINST:
	LD	C,0		; Start at beginning of DCT
	CALL	GTDCT
	LD	B,8		; Total of 8
$S0:	LD	A,0C9H		; Is it RET?
	CP	(IY+0)
	JR	Z,$S1		; Skip if so
	LD	L,(IY+1)	; Address
	LD	H,(IY+2)
	DEC	HL
	LD	C,(HL)
	LD	DE,EDFF-HRDDRV+1
	ADD	HL,DE
	LD	A,(HL)
	CP	0EDH		; Is it driver invocation?
	JR	NZ,$S1
	INC	HL
	LD	A,(HL)		; See if still same
	CP	0FFH
	JR	Z,$S2		; Go if the same
$S1:	LD	DE,10
	ADD	IY,DE		; Move to next DCT
	DJNZ	$S0		; Loop until done
	XOR	A
	RET			; None found
$S2:	PUSH	IY
	POP	HL
	OR	1		; Make NZ
	RET
;===
; Install module in high or low memory
; Exit: HL = start of driver in memory
;===
INSTMEM:
	LD	A,(MODEL)
	CP	3		; Is it LS-DOS?
	JR	Z,$IM1
; Model 1/3 install
	CALL	GETHIGH
	LD	(OLDHI),HL
	LD	BC,LENGTH
	XOR	A
	SBC	HL,BC
	CALL	SETHIGH
	INC	HL
	EX	DE,HL
	PUSH	DE
	LD	HL,HARD
	LDIR
	POP	DE
	RET
; Model 4 install
$IM1:	LD	DE,'IK'
	SVC	@GTDCB
	JP	NZ,IOERR
	DEC	HL
	LD	D,(HL)
	DEC	HL
	LD	E,(HL)
	LD	(LDPTR+1),HL
; Make sure driver will fit
	LD	HL,MODEND-HARD
	ADD	HL,DE
	LD	(OLDHI),HL
	LD	BC,1300H
	XOR	A
	SBC	HL,BC
	JP	NC,NOROOM
; Move driver into low memory
LDPTR:	LD	HL,$-$
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	PUSH	DE
	PUSH	HL
	LD	HL,HARD
	LD	BC,LENGTH
	LDIR
	POP	HL
	LD	(HL),D
	DEC	HL
	LD	(HL),E
	POP	DE
	DEC	HL
	RET
;---
; GTDCT routine
;---
GTDCT:	LD	A,(MODEL)
	CP	3		; Is it LS-DOS?
	JR	Z,$GT1
	JP	@GTDCT3
$GT1:	SVC	@GTDCT
	RET
;--
; PARAM routine
;--
PARAM:	LD	A,(MODEL)	; Model number
	CP	3		; Is it LS-DOS?
	JR	Z,$PR1
	LD	A,(125H)	; Model 1 check
	CP	'I'
	JP	Z,@PARAM3
	JP	@PARAM1
$PR1:	SVC	@PARAM
	RET
;---
; Get HIGH$
;---
GETHIGH:
	LD	A,(125H)	; Model 1 check
	CP	'I'
	JR	Z,$GH3
	LD	HL,(HIGH1$)
	RET
$GH3:	LD	HL,(HIGH3$)
	RET
;---
; Set HIGH$
;---
SETHIGH:
	LD	A,(125H)	; Model 1 check
	CP	'I'
	JR	Z,$SH3
	LD	(HIGH1$),HL
	RET
$SH3:	LD	(HIGH3$),HL
	RET
;---
; Set date and time buffers
;---
SETTIME:
	LD	A,(IX+0)
	OR	A			; Is it Model 1/3?
	JR	Z,$M13
	DEC	A			; Is it DOSPLUS 4?
	JR	Z,$MD4
	DEC	A			; Is it MULTIDOS 4?
	JR	Z,$MM4
; It is LS-DOS
	LD	(002DH),HL		; Store seconds, minutes
	LD	A,E
	LD	(002FH),A		; Store hours
	LD	A,D
	LD	(0033H),A		; Store year
	LD	(0034H),BC		; Store month, day
	RET
; Model 4 DOSPLUS
$MD4:	LD	(00A4H),HL		; Store seconds, minutes
	LD	(00A6H),DE		; Store hours, year
	LD	(00A8H),BC		; Store month, day
	RET
; Model 1
$M13:	LD	A,(125H)
	CP	'I'
	JR	Z,$MM4			; Go if Model 3
	CALL	YRCORRECT		; Correct year
	LD	(4041H),HL		; Store seconds, minutes
	LD	(4043H),DE		; Store hours, year
	LD	(4045H),BC		; Store month, day
	RET
; Model 4 MULTIDOS and Model 3
$MM4:	CALL	YRCORRECT		; Correct year
	LD	(4217H),HL		; Store seconds, minutes
	LD	(4219H),DE		; Store hours, year
	LD	(421BH),BC		; Store month, day
	RET
; Correct year if over 2000
YRCORRECT:
	LD	A,D			; Is value over 100?
	CP	100
	RET	C			; Return if not
	SUB	100			; Correct if so
	LD	D,A
	RET
;
EXIT:	LD	A,(MODEL)
	CP	3			; LS-DOS
	JR	Z,$E4
	CP	1			; DOSPLUS 4
	JR	Z,$E4
	JP	@EXIT3
$E4:	SVC	@EXIT
;
DSPLY:	NOP
DSPLY1:	LD	A,(MODEL)
	CP	3			; LS-DOS
	JR	Z,$D4
	CP	1			; DOSPLUS 4
	JR	Z,$D4
	CP	2			; MULTIDOS 4
	JR	Z,$D3
	CALL	CKDOS
	JP	Z,@TRSDSPLY
$D3:	JP	@DSPLY3
$D4:	SVC	@DSPLY
	RET
;
;--
; See which DOS
; Z if TRS-DOS 1.3
;--
CKDOS:	LD	A,(125H)
	CP	'I'
	RET	NZ		; NZ if Model 1
	LD	A,(4400H)
	CP	0F5H
	RET			; NZ if LDOS
; Determine model and DOS
TESTMODEL:
	LD	IX,MODEL
	LD	(IX+0),0		; Assume Model 1/3
	PUSH	HL
	LD	HL,(0009H)		; Bytes after RST 8H
	XOR	A
	LD	DE,4000H
	SBC	HL,DE			; Is it 4000H?
	JR	Z,$DM0			; If Model 1/3
	INC	(IX+0)
	LD	A,(0000H)		; Is it DOSPLUS 4?
	CP	0C9H
	JR	Z,$DM0			; If DOSPLUS 4
	INC	(IX+0)
	LD	HL,(0009H)		; Is it MULTIDOS 80/64?
	XOR	A
	LD	DE,0BEE3H
	SBC	HL,DE
	JR	Z,$DM0
	INC	(IX+0)			; It is LS-DOS
$DM0:	POP	HL
	RET
;===
; Data
;===
; 0 if Model 1/3, 1 if DOSPLUS 4, 2 if MULTIDOS 80/64, 3 if LS-DOS
MODEL		DB	0
; Messages
OPENER$		DB	'TRS-80 Model 4 emulator hard disk driver'
		DB	' for LDOS and LS-DOS',0AH
		DB	'copyright (c) 1998 by Matthew Reed,'
		DB	' all rights reserved',0AH,0DH
PARAMERR$	DB	'Parameter error!',0AH
HELP$		DB	'Usage: HARD <DRIVE=n> <QUIET>',0AH
		DB	' DRIVE:  install driver on drive n (default = 4)',0AH
		DB	' QUIET:  eliminate success message',0DH
ALRERR$		DB	'The hard disk driver is already installed!',0DH
ISUCCESS$	DB	'The hard disk driver was successfully installed '
		DB	'on drive 4.',0DH
UDRIVE		EQU	$-3
DRVACT$		DB	'The drive is already in use!',0DH
ILLDRV$		DB	'Illegal drive number',0DH
BADEMU$		DB	'The Model 4 emulator version 1.00 is '
		DB	'not running!',0DH
NOROOM$		DB	'There was not enough room in low memory to '
		DB	'install the driver!',0DH
IOERR$		DB	'Model 4 low memory has been corrupted!',0DH
OSBAD$		DB	'This hard disk driver will only work with LDOS or '
		DB	'LS-DOS!',0DH
NOHARD$		DB	'The emulator hard disk file was not found!',0DH
;
; Parameter table
PARMTBL		DB	'DRIVE '
		DW	DRVPARM
		DB	'QUIET '
		DW	QUPARM
		DB	0
;
; DCT for hard drive
DIRCYL		EQU	3
MAXCYL		EQU	202
SECCYL		EQU	104
GRANCYL		EQU	7
SECGRAN		EQU	SECCYL/GRANCYL
;
DCT	JP	0000H			; Invoke driver, then return
	DB	00001100B		; SDEN, hard, fixed
	DB	01010000B		; DD, Alien
	DB	0			; Scratch (current cylinder)
	DB	MAXCYL-1		; Maximum cylinder on drive
	DB	SECCYL-1		; Maximum sector/cylinder
	DB	GRANCYL<4+SECGRAN	; granules/cylinder, sectors/granule
	DB	DIRCYL			; Directory cylinder
;---
; Hard disk memory header
;---
HARD	JR	HRDDRV
OLDHI	DW	$-$
	DB	MODDCB-HARD-5
	DB	'HARD'
MODDCB	DW	$-$
	DW	0
;---
; Hard disk driver
;---
HRDDRV:	LD	A,B			; Test function code
	CP	12			; Is it not a write?
	JR	C,$DOIT
	BIT	7,(IY+1)		; Error if write protected
	LD	A,15			; Assume write protection error
	JR	NZ,$WE
$DOIT:	LD	A,0
DENSITY	EQU	$-1
EDFF:	DB	0EDH,0FFH		; DISK
$WE:	OR	A
	RET
MODEND	EQU	$-1
LENGTH	EQU	$-HARD
;
	END	START
