*GET EQUATES
	ORG	3000H
VAL	EQU	80H		; Value bit
SW	EQU	40H		; Switch bit
STR	EQU	20H		; String bit
ABR	EQU	10H		; Abbreviation bit
;===
; Disk file buffers
;===
BUFF1	DS	256		; On page boundaries
BUFF2	DS	256
;---
; Initialize
;---
START	LD	(STACK+1),SP	; Save old stack
	LD	SP,BUFF1	; Make new one
	SVC	@CKBRKC		; Abort if break pressed
	JP	NZ,ABORT
	PUSH	HL		; Save command line
	LD	HL,TITLE$	; Display title
	SVC	@DSPLY
	POP	HL		; Restore command line
;---
; Transfer filenames to FCBs
;---
	LD	DE,FCB1		; Transfer filespec
	SVC	@FSPEC
	JP	NZ,IFN		; Abort if erros
	LD	DE,FCB2		; Transfer filespec
	SVC	@FSPEC
	JP	NZ,IFN		; Abort if error
;---
; Parse parameters
;---
	LD	DE,PARM$	; Scan for parameters
	SVC	@PARAM
	JP	NZ,PARMERR	; Abort if error
;---
; Handle B/W switch
;---
BW	LD	BC,0		; Default = OFF
BVAL	EQU	$-2
	LD	A,B		; Merge bytes
	OR	C
	JR	NZ,TOP		; Ahead if on
	LD	A,2FH		; CPL command
	LD	(BWC),A		; Store it
;---
; Handle top margin
;---
TOP	LD	DE,72		; 1 inch from top
TVAL	EQU	$-2
	LD	HL,(HVAL)	; Height
	ADD	HL,DE		; Add them
	EX	DE,HL		; and switch
	LD	HL,792		; Top of page
	OR	A		; Clear carry flag
	SBC	HL,DE		; Subtract margin
	LD	DE,TM$		; Top margin string
	SVC	@HEXDEC		; Convert to decimal
;---
; Handle left margin
;---
LEFT	LD	HL,72		; 1 inch from left
LVAL	EQU	$-2
	LD	DE,LM$		; Left margin string
	SVC	@HEXDEC		; Convert to decimal
;---
; Handle height
;---
HEIGHT	LD	HL,216		; 3 inches high
HVAL	EQU	$-2
	LD	DE,HV$		; Height string
	SVC	@HEXDEC		; Convert to decimal
;---
; Handle width
;---
WIDTH	LD	HL,0		; Width value
WVAL	EQU	$-2
	LD	A,(WRSP)	; Width response
	OR	A		; Was anything typed in?
	JR	NZ,W1		; If so, ahead
	LD	HL,(HVAL)	; Get height
W1	LD	DE,WV$		; Width string
	SVC	@HEXDEC		; Convert to decimal
	JP	MAIN		; Main program
;---
; Abort or exit
;---
ABORT	LD	HL,-1		; Abort
	DB	0DDH
EXIT	LD	HL,0		; Exit
LEAVE	PUSH	HL		; Save state
	LD	DE,FCB2
	SVC	@CLOSE
	POP	HL
STACK	LD	SP,$-$		; Restore stack
	RET
;---
; Error routines
;---
IFN	LD	HL,IFN$		; Invalid filename
	SVC	@LOGOT		; Log it
	JR	ABORT
;
PARMERR	LD	A,44		; Parameter error
DOSERR	LD	L,A		; Put error in HL
	LD	H,0
	OR	80H		; Short errors
	LD	C,A		; Display errors
	SVC	@ERROR
	JR	LEAVE		; Restore stack
;---
; Open files
;---
OPEN	SVC	@FLAGS$		; Get SFLAG$
	SET	0,(IY+'S'-'A')	; Force to read
	LD	DE,FCB1		; FCB for 1
	LD	HL,BUFF1	; File buffer for 1
	LD	B,0		; LRL = 256
	SVC	@OPEN		; Open file
	JP	NZ,DOSERR	; Abort if DOS error
	LD	DE,FCB2		; FCB for 2
	LD	HL,BUFF2	; File buffer for 2
	LD	B,0		; LRL = 256
	SVC	@INIT		; Open file
	JP	NZ,DOSERR	; DOS error
	RET
;---
; Read a byte from file
;---
GET	PUSH	DE		; Save registers
	PUSH	BC
	LD	DE,FCB1		; First file
	SVC	@GET		; Get byte
	JP	NZ,DOSERR	; DOS error
	POP	BC		; Restore registers
	POP	DE
	RET
;---
; Save a byte to file
;---
PUT	PUSH	DE		; Save registers
	PUSH	BC
	LD	DE,FCB2		; Second file
	LD	C,A
	SVC	@PUT		; Save byte
	JP	NZ,DOSERR	; DOS error
	POP	BC		; Restore registers
	POP	DE
	RET
;---
; Save a string to a file
;---
PUTNUM	LD	A,(HL)		; Get byte
	CP	20H		; Is it space?
	JR	NZ,PUTSTR	; Ahead if not
	INC	HL		; Otherwise, ahead one
	JR	PUTNUM
PUTSTR	LD	A,(HL)		; Get byte
	OR	A
	RET	Z		; Return if end
	CALL	PUT		; Save byte to disk
	INC	HL		; Next byte
	JR	PUTSTR		; Loop
;---
; Start of main program
;---
MAIN	CALL	OPEN		; Open both files
	LD	HL,PROL		; Start of prolog
	CALL	PUTSTR		; Save entire string
	LD	HL,LM$		; Left margin
	CALL	PUTNUM
	LD	A,' '
	CALL	PUT
	LD	HL,TM$
	CALL	PUTNUM
	LD	HL,TCMD
	CALL	PUTSTR
	LD	HL,WV$
	CALL	PUTNUM
	LD	A,' '
	CALL	PUT
	LD	HL,HV$
	CALL	PUTNUM
	LD	HL,SCMD
	CALL	PUTSTR
	LD	B,240		; Number of lines
MAIN1	PUSH	BC		; Save first counter
	LD	B,80		; Number of bytes
MAIN2	CALL	GET		; Get graphics byte
BWC	NOP			; Nothing (or reverse)
	LD	C,A		; Store in C
	LD	HL,HEXSTR	; Storage area
	PUSH	HL		; Save start
	SVC	@HEX8		; Convert value
	POP	HL		; Restore
	CALL	PUTSTR		; Save hex string
	DJNZ	MAIN2		; Loop until done
	LD	A,0DH		; Signal end of line
	CALL	PUT
	POP	BC		; Line counter
	DJNZ	MAIN1		; Loop until done
	LD	HL,ECMD		; Final commands
	CALL	PUTSTR		; Save string
	LD	HL,SC$		; Success!
	SVC	@DSPLY		; Display
	JP	LEAVE		; Exit program
;===
; Messages and storage
;===
TITLE$	DB	'Convert HR to PS 1.0',0AH
	DB	'  copyright (c) 1991 by Matthew Reed',0AH
	DB	'  all rights reserved',0AH,0DH
IFN$	DB	'Invalid filename',0DH
SC$	DB	'File successfully converted',0DH
FCB1	DS	32
FCB2	DS	32
PROL	DB	'/wb 80 def',0DH,00H
LM$	DB	'00000',0
TM$	DB	'00000',0
TCMD	DB	' translate',0DH,00H
WV$	DB	'00000',0
HV$	DB	'00000',0
SCMD	DB	' scale',0DH
	DB	'640 240 1 [496 0 0 -240 0 240] {(%stdin)'
	DB	' (r) file wb string readhexstring'
	DB	' pop} image',0DH,00H
ECMD	DB	'save restore',0DH
	DB	'showpage',0DH,00H
HEXSTR	DB	'00',00H
EVAL	DW	0
;===
; Parameter table
;===
PARM$	DB	80H
;==
; Black-on-white switch
	DB	SW.OR.2
	DB	'BW'
BRSP	DB	0
	DW	BVAL
;==
; EPS file generation switch
	DB	SW.OR.3
	DB	'EPS'
ERSP	DB	0
	DW	EVAL
;==
; Top margin
	DB	VAL.OR.ABR.OR.3
	DB	'TOP'
TRSP	DB	0
	DW	TVAL
;==
; Left margin
	DB	VAL.OR.ABR.OR.4
	DB	'LEFT'
LRSP	DB	0
	DW	LVAL
;==
; Width of image
	DB	VAL.OR.ABR.OR.5
	DB	'WIDTH'
WRSP	DB	0
	DW	WVAL
;==
; Height of image
	DB	VAL.OR.ABR.OR.6
	DB	'HEIGHT'
HRSP	DB	0
	DW	HVAL
;
	END	START
