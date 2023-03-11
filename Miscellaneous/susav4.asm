NMIM4	EQU	0066H
	ORG	0F000H
;-------------------------------
; Program to save SUPER UTILITY
;-------------------------------
SU	DI			; Disable interrupts
; Save registers
	PUSH	HL
	PUSH	DE
	PUSH	BC
	PUSH	IX
	PUSH	IY
	LD	A,I
	PUSH	AF
	LD	(STACK),SP	; Preserve stack
	LD	(8D70H),SP	; Store also
	LD	SP,0ED00H
; Eliminate linkage
	LD	HL,1923H
	LD	(0627H),HL
; Disable INTRQ and timeout
	XOR	A
	OUT	(0E4H),A
; Force interrupt
	LD	A,11010000B
	CALL	FDCMD		; Pass command
	LD	HL,0000H	; Start of program
	LD	DE,0EE00H	; Buffer area
	LD	BC,256
	LDIR			; Move it
	LD	HL,NMIRET	; Set NMI vector
	LD	(NMIM4+1),HL
	LD	A,0C3H
	LD	(NMIM4),A
	LD	A,0C9H		; Disable maskable
	LD	(0038H),A	; interrupts
	LD	A,'1'		; Signify start
	LD	(0F801H),A
;--------------------
; Save SUPER UTILITY
;--------------------
; Turn on drive
	LD	BC,10000
$R56:	LD	A,81H
	OUT	(0F4H),A	; Select
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,$R56		; Loop until done
; Now write first sector
	LD	HL,0EE00H-1	; First page
	LD	D,1		; Track 1,
	LD	E,0		; sector 0
	CALL	WTSEQ		; Write sector
	LD	HL,0000H-1	; Back to normal
	JR	WTSU1		; Go normally
WTSU0	LD	E,0		; Sector 0
WTSU	CALL	WTSEQ		; Write sector
WTSU1	INC	H		; Next page
	INC	E		; Next sector
	LD	A,E		; Is sector too high?
	CP	18
	JR	NZ,WTSU		; Loop if not
	INC	D		; Next track
	LD	A,10		; Is it track 10?
	CP	D
	JR	NZ,WTSU0	; Loop if not
;----------
; Success!
;----------
	LD	A,'2'		; Signify success
	LD	(0F801H),A
	LD	HL,0EE00H	; Buffer area
	LD	DE,0000H
	LD	BC,256
	LDIR			; Move it back
	LD	SP,$-$		; Stack address
STACK	EQU	$-2
	POP	AF
	LD	I,A
	POP	IY
	POP	IX
	POP	BC
	POP	DE
	POP	HL
	XOR	A
	RET			; Return to it
;------------------------
; Routine to write sector
;------------------------
WTSEQ	LD	B,5		; Retry counter
	LD	A,(0F801H)
	INC	A
	LD	(0F801H),A
WTS1	PUSH	BC		; Save counters
	PUSH	HL
	CALL	WRITE		; Attempt a write
	POP	HL		; Restore again
	POP	BC
	AND	1CH		; Mask status
	RET	Z		; Return if no error
	DJNZ	WTS1		; Retry if error
	LD	DE,0F801H	; Video memory
	LD	HL,DSKERR$	; Error string
	LD	BC,DSKEL
	LDIR			; Display on screen
	JR	$		; Loop forever
WRITE	LD	BC,81F4H	; DDEN
	OUT	(C),B
	DEC	C		; Point to data register
	LD	A,1BH		; Seek command (40 ms)
	OUT	(C),D		; Set desired track
	CALL	FDCMD		; Pass command and delay
SEEK1	IN	A,(0F0H)	; Get status
	RRCA			; Is it busy?
	JR	C,SEEK1		; Loop until ready
	LD	A,E		; Set sector register
	OUT	(0F2H),A
	LD	A,81H		; DDEN
	OUT	(0F4H),A
	PUSH	DE
	LD	DE,81H!40H<8!2	; DDEN, WSGEN
	LD	A,0A0H		; FDC WRITE command
	CALL	FDCMD
	LD	A,0C0H		; Enable INTRQ and timeout
	OUT	(0E4H),A
WRITE1	IN	A,(0F0H)	; Get status
	AND	E		; Test bit 1
	JR	Z,WRITE1
	LD	A,D		; DDEN, WSGEN
WRITE2:	OUT	(0F4H),A	; Continue to set
	OUTI
	JR	WRITE2		; Loop until done
NMIRET	POP	DE		; Pop interrupt return
	POP	DE		; Restore DE
	XOR	A		; Eliminate INTRQ and timeout
	OUT	(0E4H),A
	LD	A,81H		; Reselect drive
	OUT	(0F4H),A
	IN	A,(0F0H)	; Get status
	LD	(DSKERR$+1),A
	RET
FDCMD	OUT	(0F0H),A	; Give command to controller
	LD	B,35		; Time delay
	DJNZ	$
	RET
DSKERR$	DB	'Disk error'
DSKEL	EQU	$-DSKERR$
	DC	$+40<-8+1<8-$,0
	END	0F000H
