	ORG	0000H
START:	DI
	XOR	A
	OUT	(0E4H),A		; Turn off NMI
	OUT	(0E0H),A		; Turn off MI
	OUT	(84H),A			; Switch to Model 3 mode
	LD	A,38H			; Switch to 64 * 16
	OUT	(0ECH),A
	LD	A,81H			; Set modem control register
	OUT	(0E8H),A
	LD	A,12			; Reset video MSB
	OUT	(88H),A
	XOR	A
	OUT	(89H),A
	LD	A,13			; Reset video LSB
	OUT	(88H),A
	XOR	A
	OUT	(89H),A
	LD	SP,407DH		; Set up stack pointer
	CALL	CLS
; Start disk I/O
	LD	A,0D0H			; Force an interrupt
	OUT	(0F0H),A
	IN	A,(0F0H)		; Test the status
	INC	A			; Are there no disks in the drives?
	JR	Z,NODISKS
; Restore to track 0
	LD	A,81H			; Double density, side 0, drive 0
	OUT	(0F4H),A
	LD	A,8
	OUT	(0F0H),A		; Send RESTORE command
; Read sector 1
	LD	A,81H
	OUT	(0F4H),A
	LD	A,1
	OUT	(0F2H),A		; Indicate sector 0
	LD	HL,4300H		; Address to load boot sector
	LD	A,82H
	OUT	(0F0H),A		; Send READ SECTOR command
	IN	A,(0F0H)		; Test status
	AND	10011100B		; Was there an error?
	JR	NZ,NODISKS
	LD	BC,00F3H		; Data register and 256 bytes
	LD	A,81H
$L1:	OUT	(0F4H),A		; Select drive
	INI				; Read one byte
	JR	NZ,$L1			; Loop until done
; Now see if boot sector is Model 4 or 3
	LD	IX,4300H
	LD	B,256-2
$L2:	LD	A,(IX+0)
	CP	0CDH
	JR	NZ,$L3
	LD	A,(IX+2)
	OR	A
	JR	Z,$L4
$L3:	INC	IX
	DJNZ	$L2
; Match was not found, must be Model 4 boot sector
	JP	4300H			; Execute
; Model 3 boot sector found
$L4:	LD	HL,MODEL3$
	LD	DE,3C00H
	CALL	PRINT
	JR	$
NODISKS:
	LD	HL,NODISK$
	LD	DE,3C00H
	CALL	PRINT
	JR	$
; Clear TRS-80 screen
CLS:	LD	HL,3C00H
	LD	DE,3C01H
	LD	BC,1024
	LD	(HL),32
	LDIR
	RET
; Print message on screen
PRINT:	PUSH	DE
$P1:	LD	A,(HL)
	INC	HL
	OR	A
	JR	Z,$PE
	CP	0DH
	JR	Z,$PCR
	LD	(DE),A
	INC	DE
	JR	$P1
$PE:	POP	DE
	RET
$PCR:	POP	DE
	EX	DE,HL
	LD	BC,64
	ADD	HL,BC
	EX	DE,HL
	JR	PRINT
;
NODISK$	DB	'ERROR!',0DH
	DB	'There is no disk in emulated drive 0!',0DH
	DB	'Use the F8 menu to place a disk in drive 0 '
	DB	'and try again.',0
MODEL3$	DB	'ERROR!',0DH
	DB	'The disk in drive 0 is a Model 3 disk!',0DH
	DB	'To use this disk will require that the MODEL4.ROM '
	DB	'file be in',0DH,'your emulator directory.',0DH
	DB	'See the emulator document file for more details.',0
;
	END	START
