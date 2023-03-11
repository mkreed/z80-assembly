*GET EQUATES
*GET MACROS
;----------------------------------------------------------
; READPCK
; Program to read PCX files
; Type: READPCX filename
;----------------------------------------------------------
	ORG	3000H
	LD	DE,FCB		; File control block
	SVC	@FSPEC		; Put in FCB
	JP	NZ,IFN		; Invalid file name
	LD	HL,PCX$		; Default extension
	SVC	@FEXT		; Add it
	LD	HL,IOBUFF	; I/O buffer
	LD	B,1		; LRL of 1
	SVC	@OPEN		; Open the file
	JR	NZ,FOE		; File open error
;
; Read important information from PCX file
;
	CALL	GTBYTE		; Get byte from file
	CP	10		; PCX file identifier
	JR	NZ,NPCX		; Not a PCX file
	LD	B,65		; 65 bytes to skip
LOOP1	CALL	GTBYTE		; Get byte
	DJNZ	LOOP1		; Loop
	CP	1		; Is it B/W?
	JR	NZ,NBW		; Not a B/W image
	CALL	GTBYTE		; First byte of BPL
	LD	D,A		; Put in D
	CALL	GTBYTE		; Make sure no second byte
	OR	A		; Is it zero?
	JR	NZ,IMTBG	; Image too big
	LD	B,60		; 60 bytes to skip
LOOP2	CALL	GTBYTE		; Get byte
	DJNZ	LOOP2		; Loop
;
; Set up high resolution board
;
	XOR	A		; Zero A
	OUT	(128),A		; Zero X
	OUT	(129),A		; Zero Y
	LD	E,A		; Zero BPTL
	LD	H,A		; Zero Y store
	LD	A,10000001B	; Board set up code
	OUT	(131),A		; Set it up
;
; Start reading file
;
READ	CALL	GTBYTE		; Get byte from disk
	LD	B,A		; Save A
	AND	11000000B	; Mask out rest
	CP	11000000B	; Is it encoded?
	JR	NZ,NONECD	; If not, ahead
	LD	A,B		; Restore A
	AND	00111111B	; Mask out rest
	LD	B,A		; Put in count
	CALL	GTBYTE		; Get byte to repeat
	JR	RPT		; Repeat
NONECD	LD	A,B		; Restore A
	LD	B,1		; Count of one
RPT	OUT	(130),A		; Display a byte
	INC	E		; Increment BPTL
	DJNZ	RPT		; Loop
	LD	A,D		; BPL
	CP	E		; Are they same?
	JR	NZ,READ		; Go back to READ
	INC	H		; Y value
	LD	A,H		; Y value
	OUT	(129),A		; Ouput it
	XOR	A		; Zero A
	OUT	(128),A		; Zero X
	LD	E,A		; Zero BPTL
	JR	READ		; Go back to READ
;
; GETBYTE -- reads a byte from disk
;
GTBYTE	PUSH	DE		; Save DE
	LD	DE,FCB		; Make it FCB
	SVC	@GET		; Get byte
	JR	Z,LEAV		; If no error, leave
	CP	28		; Is it EOF?
	LD	HL,0000H	; Signify no error
	JR	Z,LEAVE		; Leave if so
	LD	HL,0FFFFH	; Signify error
	OR	11000000B	; Display small error and return
	LD	C,A		; Put error in C
	SVC	@ERROR		; Display error
LEAVE	POP	DE		; Restore stack
LEAV	POP	DE		; Eliminate call
	RET			; Return
;
; Error routines
;
IFN	LD	HL,IFN$		; Invalid file name
	JR	ERROR
FOE	LD	HL,FOE$		; File open error
	JR	ERROR
NPCX	LD	HL,NPCX$	; Not a PCX file
	JR	ERROR
NBW	LD	HL,NBW$		; Not a B/W image
	JR	ERROR
IMTBG	LD	HL,IMTBG$	; Image too big
ERROR	SVC	@LOGOT		; Log error
	LD	HL,0FFFFH	; Signal error
	RET			; Return to system
IFN$	DB	'Invalid file name',0DH
FOE$	DB	'File opening error',0DH
NPCX$	DB	'Not a PCX file',0DH
NBW$	DB	'Not a black and white image',0DH
IMTBG$	DB	'Image too big to display',0DH
PCX$	DB	'PCX'
FCB	DS	32
IOBUFF	DS	256
*GET TEST
	END	3000H
