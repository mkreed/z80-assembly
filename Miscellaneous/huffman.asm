;=====================================
; HELP file generator, version 1.0
; copyright (c) 1995, by Matthew Reed
; all rights reserved
;=====================================
*GET EQUATES
	COM	'<Copyright (c) 1995 by Matthew Reed, all rights reserved>'
	ORG	3000H
; Display opener
START	PUSH	HL		; Save HL
	LD	HL,OPEN$
	SVC	@DSPLY
	POP	HL
; Put filespecs in FCBs
	LD	DE,FCB1		; FCB
	SVC	@FSPEC		; File to read
	JP	NZ,DERRS	; Ahead if error
	LD	DE,FCB2		; FCB
	SVC	@FSPEC		; File to write to
	JP	NZ,DERRS
; Open file to read
	LD	DE,FCB1		; FCB
	LD	HL,BUFF1	; Disk buffer
	SVC	@OPEN		; Open file
	JP	NZ,DERR		; Ahead if error
; Create statistics
	LD	HL,READ$	; Display read message
	SVC	@DSPLY
	LD	A,(FCB1+12)	; MSB
	DEC	A
	LD	H,A
	LD	A,(FCB1+8)	; Byte offset
	LD	L,A
	CALL	RPERC		; Register percent
	CALL	CCHARS		; Count characters
	LD	HL,STRING	; Area to start
	CALL	CHUFF		; Create Huffman table
; Create second file
	LD	DE,FCB2		; FCB
	LD	HL,BUFF2	; Disk buffer
	LD	B,0		; LRL = 256
	SVC	@INIT		; Create file
	JP	NZ,DERR
	LD	DE,FCB1		; Rewind first file
	SVC	@REW
	JP	NZ,DERR
; Encode file
	LD	HL,WRITE$	; Write string
	SVC	@DSPLY
	LD	HL,0		; Zero bytes
	LD	DE,256		; Actual position
	EXX
;***
; Write Huffman table
	LD	HL,$-$		; Second table
HUFFT2	EQU	$-2
GH0	LD	A,(HL)		; Get byte
	OR	A		; See if end
	JR	Z,GH1
	BIT	7,A		; See if character
	JR	Z,GH01		; Ahead if count
	INC	HL
	CALL	PUT		; Save byte
	JR	GH0		; Loop until done
; Count
GH01	LD	B,0		; Zero count
GH00	LD	A,(HL)		; Get byte
	INC	HL
	INC	B		; Increase count
	BIT	7,A		; See if count
	JR	Z,GH00		; Loop until done
; Save count
	LD	A,B		; Save count
	DEC	A
	CALL	PUT
	DEC	HL		; Back one character
	JR	GH0		; Loop
; Final byte
GH1	CALL	PUT		; Save final byte
;***
; Read starting number
GY00	CALL	CVS		; Convert number
	PUSH	AF		; Save byte
; Put in correct entry
	LD	A,C		; Directory entry
	ADD	A,A
	LD	H,.HIGH.DIR
	LD	L,A
	EXX
	PUSH	DE
	EXX
	POP	DE
	LD	(HL),E
	INC	L
	LD	(HL),D
; Encode rest of entry
	POP	AF		; Restore byte
	LD	BC,0001H	; Initialize with 1 bit
	JR	GTN0		; Skip read
GETNEW	CALL	GET		; Get byte
	JP	NZ,SHER
GTN0	OR	A		; Loop if byte is zero
	JP	Z,GETNEW
	CP	129		; Is it above 128?
	JP	NC,GETNEW	; Loop if so
; See if end of topic
	PUSH	BC		; Save BC
	LD	C,A
	LD	A,B
	CP	']'		; See if ending bracket
	JR	Z,EBRACK
	CP	'\'		; See if end of topic
	LD	A,C
	POP	BC		; Restore BC
	JP	Z,NXTTPC	; Next topic if end
; See if end of topic byte
	CP	']'		; See if ending bracket
	JR	Z,GTN000
	CP	'\'		; See if topic end
	JR	NZ,GTN00	; Ahead if not
GTN000	LD	B,A		; Store in B
GTN00	EXX
	INC	L		; Next byte
	JP	NZ,GTN1
	INC	H
	CALL	DPERC		; Display percent
GTN1	EXX
	LD	HL,STRING	; Huffman table
	PUSH	BC		; Save B
;***
	CALL	DBC		; Generate code
	POP	BC
	EX	DE,HL		; Switch registers
SHLOOP	LD	A,(HL)		; Get byte (0 or 1)
	DEC	HL
	OR	A		; See if end
	JP	Z,GETNEW
	RRCA			; Move into carry
	RL	C		; Rotate bits
	CALL	C,SAVIT
	JR	SHLOOP		; Loop until done
; Ending bracket
EBRACK	LD	A,C		; Restore character
	LD	C,0
	CALL	CVSNG		; Get number
	PUSH	AF		; Save character
; AF on stack
	LD	A,C		; Convert to binary
	CALL	HBIN8
	POP	AF
	POP	BC		; Restore BC
	PUSH	AF
	EX	DE,HL		; Switch registers
SHL1	LD	A,(HL)		; Get byte (0 or 1)
	DEC	HL
	OR	A		; See if end
	JR	Z,EBGET
	RRCA			; Move into carry
	RL	C		; Rotate bits
	CALL	C,SAVIT
	JR	SHL1		; Loop until done
EBGET	POP	AF		; Restore A
	LD	B,0		; Reset character
	JP	GTN0		; Loop
; See if error or end
SHER	CP	28		; Is it end of file?
	JP	NZ,DERR		; Disk error if not
SHER1	LD	A,C
	OR	A
	JR	Z,SHER2		; No save if zero
	RL	C		; Rotate into place
	JR	NC,SHER1
	LD	A,C		; Save final byte
	CALL	PUT
;;;
; Wipe out remaining sector
SHER2:	LD	A,(FCB2+5)	; Is it at end?
	OR	A
	JR	Z,$SH3
	LD	H,.HIGH.BUFF2	; MSB
	LD	L,A		; LSB
	XOR	A		; Find difference
	SUB	L
	LD	C,A
	LD	B,0
	LD	D,H
	LD	E,L
	INC	DE
	LD	(HL),0
	LDIR			; Blank out rest
	XOR	A
	CALL	PUT		; Save the rest
;;;
$SH3:	LD	DE,FCB2		; Close output file
	SVC	@CLOSE
	JP	NZ,DERR
	CALL	DDPERC		; Display done
	JP	EXIT		; Exit the program
;
SAVIT	LD	A,C		; Save byte
	CALL	PUT
	LD	C,1
	RET
; Display disk error
DERRS	LD	A,19		; "Illegal file name"
DERR	LD	C,A		; Put in C
	PUSH	BC
	LD	C,29		; Erase line
	SVC	@DSP
	POP	BC
	SET	6,C		; Limited error
	SVC	@ERROR		; Exit the system
EXIT	SVC	@EXIT
NXTTPC	RL	C		; Rotate until lined up
	JR	NC,NXTTPC
	LD	A,C		; Save byte
	CALL	PUT
	JP	GY00		; Loop back
;---
; Calculate value of string
; C <= value
; A <= byte
;---
CVS	LD	C,0		; Zero C
GY10	CALL	GET		; Get byte
	JP	NZ,SHER
CVSNG	CP	'9'+1		; Is it within range?
	RET	NC
	CP	'0'
	RET	C
	PUSH	AF		; Store A
	LD	A,C		; Multiply x 10
	LD	B,9
GY2	ADD	A,C
	DJNZ	GY2		; Loop until done
	LD	C,A
	POP	AF
	SUB	'0'		; Make into number
	ADD	A,C
	LD	C,A
	JR	GY10
;---
; Count characters
; DE <= number of characters
;---
CCHARS:	LD	DE,0		; Zero counter
CCLOOP:	CALL	GET		; Read byte
	JP	NZ,CEND		; Possible end (or error)
	CALL	CCHAR		; Increment character counter
	INC	E		; Increment byte counter
	JP	NZ,CCLOOP	; Loop until done
	INC	D
	EX	DE,HL
	CALL	DPERC		; Display percent
	EX	DE,HL
	JP	CCLOOP		; Loop until done
CEND:	CP	28		; Is it end of file?
	JP	NZ,DERR		; Disk error if not
	CALL	DDPERC		; Display done
	RET
;---
; Increase character count
; Entry: A = character
; Destroys HL and BC
;---
CCHAR:	LD	L,A		; Double value
	LD	H,0
	ADD	HL,HL
	LD	BC,COUNT0	; Count buffer
	ADD	HL,BC
; Increment character count
	INC	(HL)		; Increment count
	RET	NZ
	INC	L
	INC	(HL)
	RET
;---
; Create Huffman table
; HL => address of table
; HL <= end of table
;---
;<<<<<< >>>>>>>>
CHUFF	LD	HL,STRING	; Buffer region
	EXX			; Switch registers
; Find lowest
CH1	CALL	FLOW		; Find lowest
	EX	AF,AF'
	PUSH	DE		; Save high
	LD	L,A
	DEC	L
	LD	(HL),0
	DEC	L
	LD	(HL),0
; Add to string
	SRL	A		; Divide by two
	EXX
	LD	(HL),A
	INC	HL
	EXX			; Switch back
; Find second lowest
	CALL	FLOW		; Find second lowest
	LD	A,E
	AND	D
	CP	0FFH		; See if end
	JP	Z,CHE		; Ahead if end
	POP	HL		; Put amount in HL
	ADD	HL,DE		; Add on amount
	EX	DE,HL		; Switch
	LD	H,.HIGH.COUNT0	; MSB
	EX	AF,AF'
	LD	L,A		; Put in LSB
	DEC	L
	LD	(HL),D
	DEC	L
	LD	(HL),E
; Add to string
	SRL	A		; Convert to ASCII
	EXX
	LD	(HL),A
	INC	HL
	EXX
	JP	CH1
CHE	POP	DE		; Restore stack
	EXX			; Remove last character
	DEC	HL
	LD	(HL),0
; HL => end
; Generate read table
	PUSH	HL
	POP	DE
	INC	DE		; DE = end + 1
	LD	DE,STRING+256
	LD	(HUFFT2),DE	; Store address
CHR0	DEC	HL		; Before 0
	LD	A,(HL)		; Character
	OR	A		; If zero, return
	JP	Z,CHR4
; See if occurs before
	PUSH	HL		; Save HL
	LD	B,0		; Initialize count
	LD	C,A		; Store character
CHR1	DEC	HL		; Back one character
	INC	B		; Next byte
	LD	A,(HL)		; Get byte
	OR	A		; Is it zero?
	JP	Z,CHR2
	CP	C		; Is it same?
	JP	NZ,CHR1		; Loop if not
; Store count
	LD	A,B		; Count
CHR3	LD	(DE),A
	INC	DE		; Next byte
	POP	HL		; Restore HL
	JP	CHR0		; Loop
; No character, so end of branch
CHR2	LD	A,C		; Get character
	OR	10000000B	; Set bit 7
	JP	CHR3		; Loop
; End of table
CHR4	XOR	A		; Zero A
	LD	(DE),A
	RET
;---
; Determine bits for character
; A => character
; HL => coding table
; DE <= end of correct bits
;---
DBC:	LD	DE,COUNT0	; Buffer
	LD	B,A		; Store character in B
DLOOP	LD	A,(HL)		; Get character
	OR	A		; See if end
	RET	Z		; Return if end
	INC	HL		; Next byte
	CP	B		; See if same
	JP	NZ,DLOOP	; Main loop
; Character found
	DEC	HL		; Eliminate extra increment
	LD	A,'0'		; Signify odd
	BIT	0,L		; See if number is even
	JP	NZ,DODD		; Ahead if odd
; Signify even
	LD	A,'1'
	INC	HL		; Previous byte
DODD	INC	DE
	LD	(DE),A		; Store in memory
; New character
	LD	B,(HL)		; Get byte
	INC	HL
	JP	DLOOP		; Loop until done
;---
; Determine binary form
; A => number
; DE <= end of correct bits
;---
HBIN8:	LD	DE,COUNT0+1	; Address of binary
	LD	C,A		; Put in C
	LD	B,7		; 7 lower bits
HLOOP	RR	C		; Send bit into carry flag
	LD	A,'0'		; C = "0"
	JR	NC,HBIN10	; If zero, HBIN10
	INC	A		; Make C = "1"
HBIN10	LD	(DE),A		; Load "0" or "1" into DE
	INC	DE		; Next byte
	DJNZ	HLOOP		; Loop
	DEC	DE
	RET			; until done
;---
; Find lowest value in count table
; Exit: DE = lowest value, C = byte value
;---
FLOW:	PUSH	HL
	LD	HL,COUNT0	; Count table
	LD	DE,0FFFFH	; Highest possible value
	LD	B,0		; Loop through them all
	LD	C,B		; Start with byte 0
FLOW0:	LD	A,(HL)		; LSB of count
	INC	HL
	PUSH	HL		; Now save position for later
	LD	H,(HL)		; MSB of count
	LD	L,A
	SBC	HL,DE		; Is new count lower?
	POP	HL
	JR	NC,FLOW1	; Continue if it is lower
	LD	D,H		; Move new count over old
	LD	E,L
	LD	C,B		; Store new byte value
FLOW1:	INC	HL		; Move to next entry
	DJNZ	FLOW0		; Loop until done
	POP	HL
	RET
;---
; Get character
; NZ if error
;---
GET	PUSH	DE		; Save DE
	LD	DE,FCB1		; FCB
	SVC	@GET
	POP	DE
	RET
;---
; Put character
; NZ if error
;---
PUT:	RPUSH	BC,DE		; Save BC
	LD	C,A		; Put in C
	LD	DE,FCB2		; Second FCB
	SVC	@PUT
	RPOP	DE,BC		; Restore registers
	EXX
	INC	DE		; Increase position
	EXX
	JP	NZ,DERR		; Jump if error
	RET
;---
; Register percent
; HL => maximum tick value
;---
RPERC	LD	C,100		; Divide by 100
	SVC	@DIV16
	LD	(PDIV),HL	; Store in routine
	RET
;---
; Display percent
; HL => tick value
;---
DPERC	RPUSH	DE,BC,HL,AF	; Save registers
	LD	DE,$-$		; Divisor value
PDIV	EQU	$-2
	XOR	A		; Zero A
DPLOOP	INC	A
; Reset carry not needed
	SBC	HL,DE		; Subtract divisor
	JP	NC,DPLOOP	; Loop until done
	DEC	A		; Correct value
	PUSH	AF		; Save value
	LD	B,4		; Get cursor position
	SVC	@VDCTL
	POP	AF		; Restore value
	PUSH	HL		; Save cursor
	LD	H,0		; Put A in HL
	LD	L,A
	LD	DE,PBUFF	; Buffer
	SVC	@HEXDEC		; Generate percent
	LD	HL,PBUFF	; Go to third digit
DPL0	INC	HL
	LD	A,(HL)		; See if space
	CP	32
	JP	Z,DPL0		; Loop until done space
	SVC	@DSPLY		; Display string
	POP	HL		; Restore cursor position
	LD	B,3
	SVC	@VDCTL
	RPOP	AF,HL,BC,DE	; Restore registers
	RET
;---
; Display done message
;---
DDPERC	LD	HL,DONE$	; Display done message
	SVC	@DSPLY
	RET
PBUFF	DB	'00000%',03H
DONE$	DB	'Done',0DH
OPEN$	DB	15,'HELP file generator 1.0',0AH
	DB	' copyright (c) 1995 by Matthew Reed',0AH
	DB	' all rights reserved',0AH,0DH
READ$	DB	'Generating statistics: ',03H
WRITE$	DB	'Writing help file: ',03H
FCB1	DS	32
FCB2	DS	32
; Blocks of data
	ORG	$-1<-8+1<8
BUFF2	DS	256
BUFF1	DS	256
DIR	DC	128*2,0		; Help directory
COUNT0	DC	256*2,0		; Count buffer (all letters)
STRING	EQU	$
	END	START
