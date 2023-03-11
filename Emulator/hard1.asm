;===
; Hard disk driver installer
; Used with TRS-80 Model 1/3 emulator
;
; HARD            to install driver on drive 4
; HARD (DRIVE=5)  to install driver on drive 5
; HARD (REMOVE)   to eliminate driver linkage and remove from memory
;===
	COM	'<Copyright (c) 1997 by Matthew Reed, all rights reserved>'
DCTSTART	EQU	4700H		; Start of DCT
@EXIT		EQU	402DH		; DOS return entry
@ABORT		EQU	4030H		; Error abort
@DSPLY		EQU	4467H		; Display message
@TRSDSPLY	EQU	021BH		; TRSDOS 1.3 display
@PARAM1		EQU	4476H		; Parameter scanner (Model 1)
@PARAM3		EQU	4454H		;  (Model 3)
;
	ORG	5200H
START:
	LD	DE,PARMTBL
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
	CALL	CKDOS		; Make sure it is LDOS
	JP	Z,DOSERR
	POP	AF
	JP	NZ,PARMERR	; Error if bad parameters
; Set real-time clock
	LD	IY,4700H
	LD	B,3
	LD	A,10
	DB	0EDH,0FFH
	CP	10
	JP	Z,BADEMU
	LD	BC,$-$
RMVPARM	EQU	$-2
	LD	A,B
	OR	C
	JR	Z,INSTALL
;***
; Remove driver
;***
	CALL	TESTINST
	JP	Z,NOTINST
	LD	(HL),0C9H	; Stuff in RET
	INC	HL
	LD	(HL),00H
	INC	HL
	LD	(HL),00H
	JP	RSUCCESS
;***
; Install driver
;***
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
	LD	B,C
	INC	B
	LD	HL,DCTSTART-10
	LD	DE,10
$SD1:	ADD	HL,DE
	DJNZ	$SD1
	LD	A,(HL)
	CP	0C9H		; Is drive activated?
	JR	NZ,DRVACT
; Make sure not already installed
	PUSH	HL
	CALL	TESTINST
	POP	DE
	JR	NZ,ALRERR	; Error if already installed
; Install it
	PUSH	DE
	LD	HL,DCT
	LD	BC,10
	LDIR			; Move DCT entry into table
	POP	DE
; Stuff in JP to user space
	PUSH	DE
	LD	HL,(4DFEH)	; Address of user space
	INC	DE
	EX	DE,HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
; Install HDRIVE instruction
	LD	A,0EDH
	LD	(DE),A
	INC	DE
	LD	A,0FFH
	LD	(DE),A
	INC	DE
	LD	A,0C9H
	LD	(DE),A
; Now initialize DCT
	POP	IY
	LD	B,2
	DB	0EDH,0FFH	; HDRIVE
	JR	Z,ISUCCESS	; If success
	LD	(IY+0),0C9H	; Force a RET
	JR	IFAIL
; Successful finish
ISUCCESS:
	LD	HL,ISUCCESS$
	JR	SUCC
RSUCCESS:
	LD	HL,RSUCCESS$
SUCC:	CALL	DSPLY
	JP	@EXIT
DSPLY:	NOP
	CALL	@DSPLY
	RET
; Error routines
IFAIL:	LD	HL,IFAIL$
	DB	0FDH
NOTINST:
	LD	HL,NOTINST$
	DB	0FDH
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
ERREXIT:
	LD	A,(DSPLY)
	CP	0C9H
	JR	NZ,$VH1
	PUSH	HL
	LD	HL,OPENER$
	CALL	@DSPLY
	POP	HL
$VH1:	CALL	@DSPLY
	JP	@ABORT
DOSERR:	LD	HL,DOSERR$
	CALL	DSPLYT
	JP	@EXIT
;
DSPLYT:	CALL	CKDOS
	JP	Z,@TRSDSPLY
	JP	@DSPLY
;
;--
; See if driver already installed
; Exit: Z if not installed
;	NZ if installed, HL = DCT
;--
TESTINST:
	LD	IX,DCTSTART	; Start of DCT
	LD	B,8		; Total of 8
$S0:	LD	A,0C9H		; Is it RET?
	CP	(IX+0)
	JR	Z,$S1		; Skip if so
	LD	L,(IX+1)	; Address
	LD	H,(IX+2)
	LD	A,(HL)
	CP	0EDH		; Is it driver invocation?
	JR	NZ,$S1
	INC	HL
	LD	A,(HL)		; See if still same
	CP	0FFH
	JR	NZ,$S1		; Skip if not
	INC	HL
	LD	A,(HL)
	CP	0C9H
	JR	Z,$S2		; Go if the same
$S1:	LD	DE,10
	ADD	IX,DE		; Move to next DCT
	DJNZ	$S0		; Loop until done
	XOR	A
	RET			; None found
$S2:	PUSH	IX
	POP	HL
	OR	1		; Make NZ
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
;--
; Model 1/3 PARAM routine
;--
PARAM:	LD	A,(125H)	; Model 1 check
	CP	'I'
	JP	Z,@PARAM3
	JP	@PARAM1
;
; Messages
OPENER$		DB	'TRS-80 Model 1/3 emulator hard disk driver'
		DB	' for LDOS',0AH
		DB	'copyright (c) 1997 by Matthew Reed,'
		DB	' all rights reserved',0AH,0DH
PARAMERR$	DB	'Parameter error!',0AH
HELP$		DB	'Usage: HARD <DRIVE=n> <REMOVE>',0AH
		DB	' DRIVE:  install driver on drive n (default = 4)',0AH
		DB	' REMOVE: uninstall driver',0DH
ALRERR$		DB	'The hard disk driver is already installed!',0DH
ISUCCESS$	DB	'The hard disk driver was successfully installed '
		DB	'on drive 4.',0DH
UDRIVE		EQU	$-3
RSUCCESS$	DB	'The hard disk driver was successfully un-installed.',0DH
DRVACT$		DB	'The drive is already in use!',0DH
ILLDRV$		DB	'Illegal drive number',0DH
NOTINST$	DB	'The hard disk driver is not installed!',0DH
DOSERR$		DB	'The operating system must be LDOS!',0DH
IFAIL$		DB	'The emulator hard disk file was not found!',0DH
BADEMU$		DB	'The Model 1/3 emulator is not running!',0DH
;
; Parameter table
PARMTBL		DB	'REMOVE'
		DW	RMVPARM
		DB	'DRIVE '
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
	DB	01001100B		; DDEN, hard, fixed
	DB	01010000B		; DD, Alien
	DB	0			; Scratch (current cylinder)
	DB	MAXCYL-1		; Maximum cylinder on drive
	DB	SECCYL-1		; Maximum sector/cylinder
	DB	GRANCYL<4+SECGRAN	; granules/cylinder, sectors/granule
	DB	DIRCYL			; Directory cylinder
;
	END	START
