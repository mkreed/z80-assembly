NMIM3	EQU	4049H
	ORG	4300H
;----------------------
; Start of boot sector
;----------------------
	NOP			; Indicate Model 4
	CP	14H		; Directory on track 20
	DI
;-------------------
; Relocate to FF00H
;-------------------
REL	LD	HL,SUA		; Routine after relocate
	LD	DE,0FF00H	; Place to move to
	LD	BC,256		; Amount to move
	LDIR			; Move it
	JP	SU		; Start of routine
SUA	EQU	$
;------------------------------
; Start of high memory routine
;------------------------------
	ORG	0FF00H
SU	LD	SP,0FF00H	; Stack space
	LD	HL,NMIRET	; Set NMI vector
	LD	(NMIM3+1),HL
	LD	A,0C3H
	LD	(NMIM3),A
	LD	A,0C9H		; Disable maskable
	LD	(4012H),A	; interrupts
;--------------------
; Load SUPER UTILITY
;--------------------
; Read screen
	ld	hl,3c00H	; Screen address
	ld	d,0		; Track 0
	ld	e,1		; Sector 1
RDSCR:	call	rdseq		; Read sector
	inc	h		; Next page
	inc	e		; Next sector
	ld	a,e		; Is it too high?
	cp	5
	jr	nz,RDSCR	; Loop if not
; Read program
	LD	HL,4300H	; Start of load
	LD	D,1		; Track 1,
RDSU0	LD	E,0		; sector 0
RDSU	CALL	RDSEQ		; Read sector
	INC	H		; Next page
	INC	E		; Next sector
	LD	A,E		; Is sector too high?
	CP	18
	JR	NZ,RDSU		; Loop if not
	INC	D		; Next track
	LD	A,10		; Is it track 10?
	CP	D
	JR	NZ,RDSU0	; Loop if not
;-------------------
; Run SUPER UTILITY
;-------------------
	XOR	A		; Disable NMI
	OUT	(0E4H),A
	LD	HL,4300H	; Start of load
	LD	DE,4000H	; Actual start
	LD	BC,0A200H	; 37 K
	LDIR			; Move it
	LD	A,0FDH		; Necessary for operation
	LD	I,A
	LD	SP,415DH	; Stack area
	RET			; Go to SUPER UTILITY
;------------------------
; Routine to read sector
;------------------------
RDSEQ	LD	B,5		; Retry counter
RDS1	PUSH	BC		; Save counters
	PUSH	HL
	CALL	READ		; Attempt a read
	POP	HL		; Restore again
	POP	BC
	AND	1CH		; Mask status
	RET	Z		; Return if no error
	DJNZ	RDS1		; Retry if error
	LD	DE,3C00H	; Video memory
	LD	HL,DSKERR$	; Error string
	LD	BC,DSKEL
	LDIR			; Display on screen
	JR	$		; Loop forever
READ	LD	BC,81F4H	; DDEN
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
	LD	A,80H		; FDC READ command
	CALL	FDCMD
	LD	A,0C0H		; Enable INTRQ and timeout
	OUT	(0E4H),A
READLP1	IN	A,(0F0H)	; Get status
	AND	E		; Test bit 1
	JR	Z,READLP1
	INI
	LD	A,D		; DDEN, WSGEN
READLP2	OUT	(0F4H),A	; Continue to set
	INI
	JR	READLP2		; Loop until done
NMIRET	POP	DE		; Pop interrupt return
	POP	DE		; Restore DE
	XOR	A		; Disable INTRQ and timeout
	OUT	(0E4H),A
	LD	A,81H		; Reselect drive
	OUT	(0F4H),A
	IN	A,(0F0H)	; Get status
	RET
FDCMD	OUT	(0F0H),A	; Give command to controller
	LD	B,23		; Time delay
	DJNZ	$
	RET
DSKERR$	DB	'Disk error'
DSKEL	EQU	$-DSKERR$
	DC	$+40<-8+1<8-$,0
	END	3400H
