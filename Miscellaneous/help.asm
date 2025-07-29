*GET EQUATES
-----------------------------------------
; Help File Displayer, copyright (c) 1990, by Matthew Reed
; Displays help file directory and lists help topics
;----------------------------------------------------------
@WAM	EQU	7CH		; PRO-WAM SVC number
	ORG	2700H		; Program starts at 2800H
;----------------------------------------------------------
; Information sector
;----------------------------------------------------------
	DB	'PROWAM'
	DB	'Help Display',03H
	DC	13,0
	DW	IROW1,ICOL1
	DW	IROW2,ICOL2
	DC	.HIGH.$<8-$+256-56,0
	DB	'copyright (c) 1990, by Matthew Reed, '
	DB	'all rights reserved'
;----------------------------------------------------------
; Open window and request information
;----------------------------------------------------------
START	LD	HL,BUFF		; HL = BUFF
	LD	(HLI),HL	; Put in HLI
	LD	B,7		; WCREAT (opens window)
	LD	HL,0707H	; Start of window
IROW1	EQU	$-1
ICOL1	EQU	$-2
	LD	DE,043BH	; Size of window
	SVC	@WAM		; Create window
	JR	NZ,BEEP		; Beep and return
ST1	LD	HL,HFD$		; Opening screen
	CALL	KEY		; Get keyboard input
	JR	C,CLOS		; If break or export, CLOS
	LD	BC,0800H	; WCLOSE and return
	SVC	@WAM		; Close it
;----------------------------------------------------------
; Open file, parsing the command line pointed to by HL
;----------------------------------------------------------
	LD	HL,(HLI)	; Get buffer address
	LD	DE,FCB		; 32 byte FCB
	SVC	@FSPEC		; Put it into FCB
	JR	NZ,START	; Prompt again if error
	LD	(HLI),HL	; Save buffer address
	LD	HL,HLP		; Default extension
	SVC	@FEXT		; Add extension to FCB
	SVC	@FLAGS$		; Get pointer to SFLAG$
	SET	0,(IY+18)	; Do not set file open bit
	LD	B,1		; LRL of 1
	LD	HL,BUF		; 256 byte I/O buffer
	SVC	@OPEN		; Open file
	JR	Z,HPRS		; If no error, skip past
	CALL	BEEP		; Beep
	JR	START		; Prompt again if error
;----------------------------------------------------------
; Act upon input
; Either display help directory or display a help topic
;----------------------------------------------------------
HPRS	LD	HL,0000H	; Full screen
IROW2	EQU	$-1
ICOL2	EQU	$-2
	LD	DE,1850H	; window
	LD	B,7		; WCREAT
	SVC	@WAM		; Open window
	RET	NZ		; Return if error
HA	LD	HL,(HLI)	; Pointer to command line
	LD	A,(HL)		; Value of delimiter
	CP	0DH		; Is there no topic?
	JR	Z,HD		; If so, skip to directory
	CALL	HLIST		; Otherwise, list topic
	JR	C,CLOS		; If break or export, CLOS
	JR	NZ,HD		; Get directory if error
	JR	HC		; Skip to enter keyword
HD	CALL	HDIR		; Get help directory
	JR	C,CLOS		; If break or export, CLOS
	JR	Z,HC		; If no error, skip to HC
	LD	C,0		; Close and return
	CALL	CLOS		; Close window
	CALL	BEEP		; Beep
	JR	START		; Start at the beginning
HC	LD	HL,RBYTE	; Reverse video byte
	LD	(HL),11H	; Reset reverse video
	LD	HL,EK$		; "Enter keyword: "
	CALL	KEY		; Get keyboard input
	JR	C,CLOS		; If break, skip to CLOS
	CALL	E9		; Clear screen
	JR	HA		; Go back to process input
;----------------------------------------------------------
; Routines to beep and close windows
;----------------------------------------------------------
BEEP	LD	B,2		; One beep
	SVC	@SOUND		; Beep	
	RET			; Return
CLOS	LD	B,08		; WCLOSE
	SVC	@WAM		; Close it
	RET			; Return
;----------------------------------------------------------
; Displays message in HL, gets keyboard input,
; and converts it to uppercase (KEY)
;----------------------------------------------------------
KEY	LD	B,10		; WDSPLY (displays string)
	SVC	@WAM		; Display it
	LD	HL,BUFF		; Buffer for keyboard input
	LD	(HLI),HL	; Save it in HLI
	LD	BC,0020H	; WKEYIN for 32 characters
	SVC	@WAM		; Get keyboard input
	RET	C		; Return if break or export
	LD	HL,BUFF		; Retrieve BUFF
KEY1	LD	A,(HL)		; Get byte
	CP	0DH		; Is it CR?
	RET	Z		; If so, return
	CP	'a'		; Is it above "a"?
	JR	C,KEY2		; No, so skip to KEY2
	CP	'z'+1		; Is it below "z"?
	JR	NC,KEY2		; No, so skip to KEY2
	AND	0DFH		; Uppercase it
KEY2	LD	(HL),A		; Save it in HL
	INC	HL		; Next byte
	JR	KEY1		; Loop
;----------------------------------------------------------
; Displays the byte in A, interpreting reverse video,
; expanding tabs, and paging (BDSP)
;----------------------------------------------------------
BDSP	PUSH	HL		; Save HL
	PUSH	DE		; Save DE
	PUSH	BC		; Save BC
	LD	HL,LBYTE	; Last byte
	LD	B,(HL)		; B = value of last byte
	PUSH	AF		; Save A
	LD	A,B		; Copy B to A
	OR	7FH		; Set bits 1-6
	LD	B,A		; Put it into B
	POP	AF		; Restore A
	LD	(HL),A		; Save A as last byte
	AND	B		; Combine A and B
	BIT	7,A		; Was bit 7, and now tab?
	JR	NZ,TAB		; Yes, go to TAB
	LD	C,A		; Transfer A to C
	CP	0DH		; Is it a CR?
	JR	Z,ENT		; If so, go to ENT
	CP	7FH		; Is it reverse video?
	JR	Z,RVRSE		; If so, RVRSE
	CP	20H		; Is it below 32?
	JR	C,DONE		; If so, leave
BD1	LD	B,09H		; WDSP
	SVC	@WAM		; Display it
	LD	HL,LBYTE	; HL = LBYTE
	BIT	7,(HL)		; Was bit 7 set?
	JR	Z,DONE		; If bit 7 not set, done
	LD	A,1		; If so, one iteration
TAB	AND	127		; Reset bit 7
	LD	B,A		; Transfer A to B
T1	PUSH	BC		; Save B
	LD	BC,0920H	; WDSP and C equals space
	SVC	@WAM		; Display it
	POP	BC		; Retrieve B
	DJNZ	T1		; Loop until done
DONE	XOR	A		; Reset carry flag
	POP	BC		; Restore BC
CDN	POP	DE		; Restore DE
	POP	HL		; Restore HL
	LD	A,(LBYTE)	; Get value of A displayed
	RET			; Return
ENT	LD	B,04H		; WGCUR
	SVC	@WAM		; Get cursor
	LD	A,17H		; A = 23
	CP	H		; See if end of screen
	JR	NZ,BD1		; Return if not end
	LD	BC,0000H	; WKEYIN and 0 characters
	LD	HL,MSB		; Dummy buffer
	SVC	@WAM		; Do it
	POP	DE		; Eliminate BC
	JR	C,CDN		; Return if break or export
	PUSH	DE		; Put BC back
	CALL	E9		; Clear the screen
	JR	DONE		; Skip to finish
RVRSE	LD	A,(RBYTE)	; Get reverse video byte
	XOR	1		; Toggle between two
	LD	(RBYTE),A	; Save it
	LD	C,A		; For display
	JR	BD1		; Displayu
E9	LD	BC,091CH	; WDSP to go to upper left
	SVC	@WAM		; Do it
	LD	BC,091FH	; WDSP to clear screen
	SVC	@WAM		; Do it
	RET			; Return
;----------------------------------------------------------
; Positions disk file to table pointed to at the end of
; the file (PTAB) 
;----------------------------------------------------------
PTAB	LD	DE,FCB		; DE = FCB
	SVC	@LOF		; Calculate EOF, in BC
	RET	NZ		; Abort if error
	DEC	BC		; Go to pointer
	DEC	BC		; two before
	LD	(FCNT),BC	; Save pointer in FCNT
	LD	DE,FCB		; DE = FCB
	SVC	@POSN		; Position to pointer
	RET	NZ		; Return if error
	CALL	MPNT		; Position to pointer value
	RET	NZ		; Return if error
	LD	HL,(FCNT)	; Get pointer again
	XOR	A		; Reset carry flag
	SBC	HL,BC		; Find length of table
	LD	(FCNT),HL	; Save in FCNT
	XOR	A		; Set Z flag
	RET			; Return
;----------------------------------------------------------
; Display directory of help topics (HDIR)
;----------------------------------------------------------
HDIR	CALL	PTAB		; Go to topic table
	RET	NZ		; Abort if error
	LD	HL,DIR$		; Directory message
	LD	B,0AH		; WDSPLY
	SVC	@WAM		; Display it
	LD	C,04H		; Four tabs in a line
D0	LD	B,13H		; Twenty characters in tab
D1	CALL	GETT		; Read byte from topic list
	RET	NZ		; Return if error
	LD	A,(HL)		; A equals byte from disk
	CALL	BDSP		; Display it
	RET	C		; Return if break or export
	DEC	B		; Decrement character count
	JP	Z,ZNZ		; Abort if overlong
	BIT	7,A		; Was bit 7 set?
	JR	Z,D1		; No, loop to D1
	SET	7,B		; Make tab character
	DEC	C		; Decrement count
	JR	NZ,D3		; If four tabs not used, D3
	LD	BC,0D04H	; B=CR, C=four more tabs
D3	LD	A,B		; Either tab or CR
	CALL	BDSP		; Display it
	RET	C		; Return if break
D2	CALL	GETT		; Skip past the pointer
	RET	NZ		; Abort if error
	CALL	GETT		; Finish skipping
	RET	NZ		; Abort if error
	CALL	TDONE		; Is table over?
	RET	Z		; If so, return
	JR	D0		; Loop
;----------------------------------------------------------
; Display contents of help topic (HLIST)
; HLI = topic entry
;----------------------------------------------------------
HLIST	CALL	SSRCH		; Position to topic text
	RET	NZ		; Abort if error
	LD	HL,(HLI)	; HL = topic entry
	LD	B,10		; WDSPLY
	SVC	@WAM		; Do it
HL1	CALL	GETT		; Read byte of file
	RET	NZ		; Abort if error
	LD	A,(HL)		; A equals byte from disk
	CP	0CH		; Is it end of help?
	RET	Z		; If so, return
	CALL	BDSP		; Display byte in A
	RET	C		; Return if break or export
	JR	HL1		; Loop
;----------------------------------------------------------
; Moves to address of pointer in file (MPNT)
;----------------------------------------------------------
MPNT	LD	DE,FCB		; DE = FCB
	SVC	@GET		; Get a byte
	LD	(LSB),A		; LSB of address
	RET	NZ		; Abort if error
	SVC	@GET		; Get a byte
	LD	(MSB),A		; MSB of address
	RET	NZ		; Abort if error
	LD	BC,(LSB)	; BC = address
	SVC	@POSN		; Position to address
	RET
;----------------------------------------------------------
; Searches disk file for topic entry (SSRCH)
; HLI = topic entry
;----------------------------------------------------------
SSRCH	CALL	PTAB		; Position to table start
	RET	NZ		; Abort if error
S1	LD	DE,(HLI)	; Get address of topic
	CALL	RD		; Get next byte to test
	RET	NZ		; Abort if error
	CP	(HL)		; Do they match?
	JR	C,ZNZ		; If too high, abort
	JR	NZ,ADVNC	; If not, skip to ADVNC
SLOOP	INC	DE		; Advance topic byte
	CALL	RD		; Get next bytes to test
	RET	NZ		; Abort if error
	XOR	(HL)		; Do they match?
	JR	Z,SLOOP		; If so, loop again
	CP	128		; Was bit 7 set, but match
	JR	NZ,ADVNC	; If not, ADVNC
	INC	DE		; Is it the
	LD	A,(DE)		; end of the
	CP	0DH		; topic?
	JR	NZ,ADVNC	; If not, ADVNC
	CALL	MPNT		; Position to proper place
	RET			; Return
A1	CALL	GETT		; Read next byte
	RET	NZ		; Abort if error
ADVNC	LD	A,(HL)		; Get byte from disk
	BIT	7,A		; Is bit 7 set?
	JR	Z,A1		; If bit 7 is not set, loop
	CALL	GETT		; If end of entry add two
	CALL	GETT		; to get past pointer
	RET	NZ		; Return if error
	CALL	TDONE		; Is table over?
	JR	Z,ZNZ		; If so, error, skip to ZNZ
	LD	DE,(HLI)	; Restore pointer to entry
	JR	S1		; Head back to beginning
ZNZ	INC	A		; Make NZ
	RET			; Return NZ
RD	CALL	GETT		; Read a byte
	LD	A,(DE)		; Load one from the topic
	RET			; Return
;----------------------------------------------------------
; Tests to see if the table is done (TDONE)
;----------------------------------------------------------
TDONE	PUSH	HL		; Save HL
	LD	HL,FCNT		; HL points to table length
	LD	A,(HL)		; A = first byte
	INC	HL		; HL points to next byte
	OR	(HL)		; Are both zero?
	POP	HL		; Restore HL
	RET			; Return
;----------------------------------------------------------
; Gets a byte from disk while saving DE (GETT)
;----------------------------------------------------------
GETT	PUSH	DE		; Save DE
	LD	DE,FCB		; DE = FCB
	SVC	@GET		; Get a byte
	LD	(LSB),A		; Put in LSB
	LD	HL,(FCNT)	; HL = length of table
	DEC	HL		; Reduce one
	LD	(FCNT),HL	; Load back into table
	LD	HL,LSB		; HL = UREC
	POP	DE		; Restore DE
	RET			; Return
;----------------------------------------------------------
; Data area (messages)
;----------------------------------------------------------
HFD$	DB	11H,0AH
	DB	'  Help File Displayer,'
	DB	' copyright (c) 1990 by Matthew Reed'
	DB	0AH
	DB	'    Enter category: ',03H
DIR$	DB	'Directory of help topics:',0AH,0DH
EK$	DB	11H,0AH
	DB	'Enter keyword: ',03H
;----------------------------------------------------------
; Data area (storage)
;----------------------------------------------------------
HLP	DB	'HLP'		; Help extension
FCNT	DW	0000H		; Counter for topic length
HLI	DW	BUFF		; Points to keyboard buffer
LSB	DB	00H		; Used as LSB and scratch
MSB	DB	00H		; Used as MSB and scratch
LBYTE	DB	7FH		; Last byte (used by BDSP)
RBYTE	DB	11H		; Reverse video byte
BUFF	DC	33,0		; Keyboard buffer
FCB	DC	32,0		; File control block
BUF	DC	256,0		; Disk I/O buffer
;----------------------------------------------------------
LAST	EQU	$
	IF	LAST.GT.3000H
	ERR	'Program is too long!'
	ENDIF
	IFLT	LAST,3000H
	DC	.HIGH.$.SHL.8-$+256,0
	ENDIF
	END	START

