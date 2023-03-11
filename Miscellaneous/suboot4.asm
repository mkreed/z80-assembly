NMIM4	EQU	0066H
	ORG	4300H
;----------------------
; Start of boot sector
;----------------------
	NOP			; Indicate Model 4
	CP	14H		; Directory on track 20
	DI
;--
; Disable ROMS, enable video RAM, and make 64*16, make FAST
;--
	LD	A,01001000B
	OUT	(0ECH),A
	LD	A,10000010B
	OUT	(84H),A
;-------------------
; Relocate to F000H
;-------------------
REL	LD	HL,SUA		; Routine after relocate
	LD	DE,0F000H	; Place to move to
	LD	BC,256		; Amount to move
	LDIR			; Move it
	JP	SU		; Start of routine
SUA	EQU	$
;------------------------------
; Start of high memory routine
;------------------------------
	ORG	0F000H
SU	LD	SP,0EF00H	; Stack space
	LD	HL,NMIRET	; Set NMI vector
	LD	(NMIM4+1),HL
	LD	A,0C3H
	LD	(NMIM4),A
	LD	A,0C9H		; Disable maskable
	LD	(0038H),A	; interrupts
;--------------------
; Load SUPER UTILITY
;--------------------
; Read screen
	LD	HL,0F800H	; Screen address
	LD	D,0		; Track 0
	LD	E,6		; Sector 2
RDSCR:	CALL	RDSEQ		; Read sector
	INC	H		; Next page
	INC	E		; Next sector
	LD	A,E		; Is it too high?
	CP	10
	JR	NZ,RDSCR	; Loop if not
; Read program
	LD	HL,0100H	; Start of load
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
; Transfer date
	LD	HL,0033H
	LD	DE,0133H
	LD	BC,5
	LDIR
	XOR	A		; Disable NMI
	OUT	(0E4H),A
	LD	HL,0100H	; Start of load
	LD	DE,0000H	; Actual start
	LD	BC,0A200H	; 37 K
	LDIR			; Move it
	CALL	8E00H		; Set correct date
; Set correct registers
	LD	HL,(8D60H)	; Correct stack
	LD	SP,HL
	POP	AF
	LD	I,A
	POP	IY
	POP	IX
	POP	BC
	POP	DE
	POP	HL
	XOR	A
	EI
	JP	1923H		; Perform jump
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
	LD	DE,0F800H	; Video memory
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
	END	4300H
