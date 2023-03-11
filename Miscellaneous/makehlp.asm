*GET EQUATES
;----------------------------------------------------------
; MAKEHLP -- help file generator
; copyright (c) 1990, by Matthew Reed
; Generates /HLP files from a formatted text file
; Format: Topic title followed by CR,
;          or "|" for multiple titles
;	  "" toggles reverse video, "\" ends topic
;----------------------------------------------------------
	ORG	3000H		; Start at 3000H
START	PUSH	HL		; Save command line pointer
	LD	HL,OPENER	; Opening message
	SVC	@DSPLY		; Display it
	POP	HL		; Restore HL
	CALL	SAVALL		; Save all the file
	JR	NZ,ERROR	; Go if error
CLOS	LD	DE,FCB2		; Second FCB
	SVC	@CLOSE		; Close it
	RET			; Return
ERROR	OR	11000000B	; Short error and return
	LD	C,A		; Error code
	SVC	@ERROR		; Display error
	JR	CLOS		; Close and exit
;
; SAVALL -- saves entire help topic (including directory)
;
SAVALL	CALL	RDTXT		; Read entire text
	CP	28		; Is it EOF?
	RET	NZ		; Return if error
	LD	HL,MESS2	; Writing directory message
	SVC	@DSPLY		; Display it
	CALL	LOC		; BC = LOC
	RET	NZ		; Return if error
	LD	(SDIR),BC	; Store directory address
SSRT1	LD	HL,BUFFER	; Start of buffer
	LD	A,126		; High to make sort true
	LD	(SBUFF),A	; Store it
SSORT	PUSH	HL		; Save HL for later use
	LD	DE,SBUFF	; Buffer for save
SSRT2	LD	A,(DE)		; Load byte from buffer
	LD	B,(HL)		; Byte from directory
	RES	7,A		; Remove bit 7
	RES	7,B		; Remove bit 7
	CP	B		; Compare the two
	JR	Z,SSRT3		; If zero, ahead
	JR	NC,SAV1		; If no carry, transfer
	JR	NZ,SADV		; If not zero, advance
SSRT3	LD	A,(DE)		; Get byte again
	BIT	7,A		; Test bit
	JR	NZ,SADV		; Advance
	BIT	7,(HL)		; Test bit
	JR	NZ,SAV1		; Transfer
	INC	DE		; Next byte
	INC	HL		; Next byte
	JR	SSRT2		; Loop
SAV1	POP	HL		; Restore HL
	CALL	SAV2		; Transfer into SBUFF
	JR	SCHK		; Go to check
SADV	POP	HL		; Restore HL
SADV1	INC	HL		; Next byte
	LD	A,127		; End byte
	CP	(HL)		; Is it nothing?
	JR	Z,SADV1		; If so, loop
	BIT	7,(HL)		; Is it end?
	JR	Z,SADV1		; Loop if not
	INC	HL		; Advance
	INC	HL		; Advance
	INC	HL		; Advance
SCHK	LD	DE,(TITLE)	; End of buffer
	LD	A,H		; Are they
	CP	D		; equal?
	JR	NZ,SSORT	; Loop if not
	LD	A,L		; Are they
	CP	E		; equal?
	JR	NZ,SSORT	; Loop if not
	LD	HL,SBUFF	; HL = save buffer
	LD	A,(HL)		; Get first byte
	CP	126		; Are we all done?
	JR	Z,SEND		; If so, go to end
SSV1	LD	A,(HL)		; Load byte
	CALL	PUT		; Save byte
	RET	NZ		; Return if error
	BIT	7,(HL)		; Is it end?
	INC	HL		; Advance
	JR	Z,SSV1		; If not, loop
	LD	A,(HL)		; Get byte
	CALL	PUT		; Save byte
	RET	NZ		; Return if error
	INC	HL		; Next byte
	LD	A,(HL)		; Get byte
	CALL	PUT		; Save byte
	RET	NZ		; Return if error
	LD	HL,(SPNT)	; Pointer
	LD	(HL),127	; Save high byte
	JR	SSRT1		; Loop back
SEND	LD	HL,(SDIR)	; Directory pointer
	LD	A,L		; First byte
	CALL	PUT		; Save it
	RET	NZ		; Return if error
	LD	A,H		; Second byte
	CALL	PUT		; Save it
	RET			; With or without error
;
; Transfer entry at HL to SBUFF, HL returns at entry end -1
;
SAV2	LD	DE,SBUFF	; Buffer for save
	LD	(SPNT),HL	; Save start of entry
SAVE21	LD	A,(HL)		; Load byte from table
	LD	(DE),A		; Load into buffer
	INC	HL		; Advance byte to get
	INC	DE		; Advance byte to store
	BIT	7,A		; Is it end?
	JR	Z,SAVE21	; If not, loop
	LD	A,(HL)		; Load directory byte
	LD	(DE),A		; Load into buffer
	INC	HL		; Advance
	INC	DE		; Advance
	LD	A,(HL)		; Load byte
	LD	(DE),A		; Load into buffer
	INC	HL		; Advance
	RET			; Return
;----------------------------------------------------------
; RDTXT -- reads text file and outputs help file
; Also stores list of topics
; Stops at end of file
;----------------------------------------------------------
RDTXT	PUSH	HL		; HL points to filename
	LD	DE,FCB1		; FCB for input
	SVC	@FSPEC		; Get filespec
	POP	HL		; Restore HL
	LD	A,19		; Illegal file name
	RET	NZ		; Return if error
	LD	DE,FCB2		; FCB for output
	SVC	@FSPEC		; Get filespec
	LD	A,19		; Illegal file name
	RET	NZ		; Return if error
SLOOP	LD	A,(DE)		; Filespec byte
	CP	'/'		; Is it extension?
	JR	Z,SYES		; If so, ahead
	CP	'.'		; Is it password?
	JR	Z,SYES		; If so, ahead
	CP	03H		; Is it end?
	JR	Z,SYES		; If so, ahead
	CP	':'		; Is it drive separator?
	JR	Z,SYES2		; If so, ahead
	INC	DE		; To next byte
	JR	SLOOP		; Loop otherwise
SYES	DEC	HL		; Previous byte
	DEC	HL		; Back to separator
	LD	A,(HL)		; Get byte
	CP	':'		; Is it drive separator?
	JR	NZ,SYES1	; Ahead if not
	LD	(DE),A		; Put in memory
	INC	DE		; Next byte
	INC	HL		; Next byte
	LD	A,(HL)		; Get drive number
	LD	(DE),A		; Put in memory
	INC	DE		; Next byte
SYES1	LD	A,03H		; End of line
	LD	(DE),A		; Put in memory
SYES2	LD	DE,FCB2		; Altered filename
	LD	HL,HLP$		; "HLP"
	SVC	@FEXT		; Add extension
	SVC	@FLAGS$		; Set force-to-read
	SET	0,(IY+'S'-'A')	; flag
	LD	DE,FCB1		; FCB for input
	LD	HL,BUFF1	; I/O buffer 1
	LD	B,0		; LRL = 256
	SVC	@OPEN		; Open file
	RET	NZ		; Return if error
	LD	DE,FCB2		; FCB for output
	LD	HL,BUFF2	; I/O buffer 2
	LD	B,1		; LRL = 1
	SVC	@INIT		; Initialize file
	RET	NZ		; Return if error
	LD	HL,MESS1	; Writing text message
	SVC	@DSPLY		; Display it
;
; Both files are now initialized
; Start of TOPIC -- routine to read title
; and text of topic
;
TOPIC	LD	HL,(TITLE)	; Address of title buffer
	CALL	GET		; Get byte from file
	RET	NZ		; Return if error
	CP	0DH		; Is it extra enter?
	JR	Z,TOPIC		; If so, discard it
	CP	'|'		; Is it wrong "or"?
	JR	Z,TOPIC		; If so, discard it
	JR	TTL11		; If ok, interpret it
TTL1	CALL	GET		; Get byte from file
	RET	NZ		; Return if error
	CP	0DH		; Is it end?
	JR	Z,TTL4		; If so, ahead
	CP	'|'		; Is it "or"
	JR	Z,TTL3		; If so, ahead
TTL11	CP	'a'		; Is it above "a"?
	JR	C,TTL2		; If not, ahead
	CP	'z'+1		; Is it below "z"?
	JR	NC,TTL2		; If not, ahead
	AND	0DFH		; Uppercase it
TTL2	LD	(HL),A		; Otherwise, put in buffer
	INC	HL		; Ahead one
	JR	TTL1		; Loop
TTLEND	DEC	HL		; Back one byte
	SET	7,(HL)		; Make it end
	INC	HL		; Restore location
	CALL	LOC		; BC = location
	RET	NZ		; Return if error
	LD	(HL),C		; Put in memory
	INC	HL		; Advance one
	LD	(HL),B		; Put rest in
	INC	HL		; Advance one
	LD	(TITLE),HL	; Store address
	RET			; Return
TTL3	CALL	TTLEND		; Handle end
	JR	TOPIC		; Head back for next
TTL4	CALL	TTLEND		; Handle end
;
; TEXT -- routine to read and write text
;
TEXT	LD	HL,LBYTE	; Previous byte
	LD	(HL),0		; Zero it
TEX0	XOR	A		; Zero A
	LD	B,A		; Zero B
	LD	C,A		; Zero C
TEX1	CALL	GET		; Get byte from file
	RET	NZ		; Return if error
TEXV	CP	32		; Is it space?
	JR	NZ,TEX2		; If not, ahead
	INC	B		; Increment count if so
	JR	TEX1		; Loop
TEX2	LD	C,A		; Save A
	LD	A,B		; Transfer B to A
TEX20	OR	A		; Is A zero?
	JR	Z,TEX3		; If so, ahead
	LD	B,C		; Store in B
	CP	1		; Is it just one?
	JR	NZ,TEX21	; If not, ahead
	LD	A,32		; Make it space
	JR	TEX5		; Save the byte
TEX21	BIT	7,(HL)		; Was last bit 7?
	JR	NZ,TEX22	; If so, ahead
	LD	D,A		; Save tab value
	LD	A,160		; Space and space
	CALL	PUT		; Save it
	RET	NZ		; Return if error
	LD	A,D		; Return value
	DEC	A		; Eliminate two
	DEC	A		; spaces
	JR	TEX20		; Handle it
TEX22	SET	7,A		; Make it space compression
	JR	TEX5		; Go to save byte
TEX3	LD	A,C		; Restore A
	CP	'\'		; End of topic?
	JR	Z,TEXEND	; Go to end
	BIT	7,(HL)		; Was last byte bit 7?
	JR	NZ,TEX31	; If so, no space bit
	CALL	GET		; Get byte from file
	RET	NZ		; Return if error
	CP	32		; Is it space?
	JR	NZ,TEX4		; If not, ahead
	SET	7,C		; Set space bit
	LD	A,C		; Put in A
TEX31	CALL	PUT		; Save byte to disk
	RET	NZ		; Return if error
	JR	TEX0		; Loop back
TEX4	LD	B,A		; Save A
	LD	A,C		; Restore C
TEX5	CALL	PUT		; Save byte to disk
	RET	NZ		; Return if error
TEX6	PUSH	BC		; Save BC
	XOR	A		; Zero A
	LD	B,A		; Zero B
	LD	C,A		; Zero C
	POP	AF		; Restore byte
	JR	TEXV		; Loop
TEXEND	LD	A,0CH		; End of topic
	CALL	PUT		; Save it
	RET	NZ		; Return if error
	CALL	GET		; Go past CR
	RET	NZ		; Return if EOF
	JP	TOPIC		; Go back to TOPIC
;----------------------------------------------------------
; GET - get byte from buffer 1
;----------------------------------------------------------
GET	PUSH	DE		; Save DE
	LD	DE,FCB1		; FCB 1
	SVC	@GET		; Get byte
	POP	DE		; Restore DE
	RET			; Return
;----------------------------------------------------------
; PUT - put byte to buffer 2
;----------------------------------------------------------
PUT	PUSH	DE		; Save DE
	PUSH	BC		; Save BC
	LD	DE,FCB2		; FCB number 2
	LD	(LBYTE),A	; Store in LBYTE byte
	LD	C,A		; Transfer to A
	SVC	@PUT
	POP	BC		; Restore BC
	POP	DE		; Restore DE
	RET			; Return
;----------------------------------------------------------
; LOC - get current location in BC
;----------------------------------------------------------
LOC	PUSH	DE		; Save DE
	LD	DE,FCB2		; FCB number 2
	SVC	@LOC		; Get LRN
	POP	DE		; Restore DE
	RET			; Return
;----------------------------------------------------------
; Data area
;----------------------------------------------------------
OPENER	DB	'MAKEHLP -- Copyright (c) 1990 by Matthew Reed, '
	DB	'All rights reserved',0AH,0DH
MESS1	DB	'Writing text of help topics',0DH
MESS2	DB	'Writing help directory',0DH
HLP$	DB	'HLP'
FCB1	DS	32
FCB2	DS	32
BUFF1	DS	256
BUFF2	DS	256
LBYTE	DB	0
SDIR	DW	0000H
SPNT	DW	0000H
TITLE	DW	BUFFER
SBUFF	DS	35
BUFFER	EQU	$
	END	START
