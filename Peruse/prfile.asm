*LIST ON
BLANK	EQU	4296H		; Blank password
	IF	TRSDOS
FCBLEN	EQU	50
	ELSE
FCBLEN	EQU	32
	ENDIF
;==
; File manipulation routines
;==
SMENU	DB	'F'
	DW	RFSORT
	DB	'E'
	DW	RESORT
	DB	'S'
	DW	RSSORT
	DB	'D'
	DW	RDSORT
	DB	'N'
	DW	RNSORT
	DB	0
; Kill file message
KILL$	DB	'128 marked file(s) will be deleted.  Are you sure? (Y/N)',0
KILL1$	DB	'Selected file will be deleted.  Are you sure? (Y/N)',0
KILL9$	DB	'Deleting:',0
; Copy message
COPY$	DB	'128 file(s) to copy to what drive:',0
COPY1$	DB	'Copy selected file to what drive:',0
COPY9$	DB	'Copying:',0
FILE$	DB	'FILENAME/EXT',0
; Move messages
MOVE$	DB	'128 file(s) to move to what drive:',0
MOVE1$	DB	'Move selected file to what drive:',0
MOVE9$	DB	'Moving: ',0
; Rename messages (only with Model 4)
	IF	MOD4
RENAME$	DB	'Rename',0
RENAM1$	DB	'to:',0
	ENDIF
; New drive message
DRIVE$	DB	'New drive number:',0
;--
; Menu key processor
; Entry: A = key
;  HL = address of menu specifier
; Exit: if Z, no match found
;  if NZ, routine called
;--
MNU_KEY:
	AND	11011111B	; Make uppercase
	LD	C,A		; Store key
$MNUL:	LD	A,(HL)		; Menu key to match
	INC	HL
	OR	A
	RET	Z		; Not found
	CP	C		; Is it same?
	JR	Z,$MNUF		; Ahead if found
	INC	HL		; Go past word
	INC	HL
	JR	$MNUL		; Loop
; Menu key found
$MNUF:	LD	A,(HL)		; LSB
	INC	HL
	LD	H,(HL)		; MSB
	LD	L,A
	JP	(HL)		; Jump to routine
;--
; Determine sort type
; Exit: NZ always
;--
KEY_SORT:
	LD	HL,YMAX-1*XMAX+SCREEN
	LD	DE,SORT$
	CALL	DSP_CBL		; Clear bottom line
	CALL	DSP_PRINT	; Print on screen
	LD	HL,SMENU	; Sort menu
	CALL	DSP_PAINT
	CALL	KBD_GET		; Get key
	CALL	MNU_KEY		; Process key
	OR	1		; Make sure screen is redisplayed
	RET
;--
; Extension sort
;--
ESORT:	LD	($WHL),HL
	LD	($WDE),DE
	EX	DE,HL
	INC	DE
	INC	HL
; *** MISTAKE ***
	LD	B,9
;	ADD	HL,BC
	CALL	$ES6		; Go to slash
	EX	DE,HL
;	ADD	HL,BC
	LD	B,9
	CALL	$ES6
	LD	B,3		; Compare three bytes (no slash)
	JR	$WS9		; Normal sort
$WS8:	INC	DE
	INC	HL
$WS9:	LD	A,(DE)		; Compare the two
	CP	(HL)
	RET	NZ		; Return if not match
	DJNZ	$WS8		; Loop until done
; Extensions are equal
	LD	HL,$-$
$WHL	EQU	$-2
	LD	DE,$-$
$WDE	EQU	$-2
	JR	FSORT		; Sort by filename
$ES6:	INC	HL
	LD	A,(HL)		; See if slash
	CP	'/'
	RET	Z
	DJNZ	$ES6
	RET
;--
; Size sort
;--
SSORT:	LD	BC,17		; Move to size
	ADD	HL,BC
	EX	DE,HL
	ADD	HL,BC
	EX	DE,HL
; Do comparison
$SDR	LD	A,(DE)
	CP	(HL)
	DEC	HL
	DEC	DE
	JR	Z,$SDR
	RET
;--
; No sort
;--
NSORT:	SCF
	RET
;--
; Date sort
;--
DSORT:	LD	BC,16		; Move to date (2 off)
$SFR:	ADD	HL,BC
	EX	DE,HL
	ADD	HL,BC
	EX	DE,HL
	LD	B,5
	JR	$FS7		; Jump past setup
;--
; Filename sort
;--
FSORT:	LD	B,12		; Filename + ext
$FS7:	INC	DE
	INC	HL
$FS8:	INC	DE		; Skip initial byte
	INC	HL
$FS9:	LD	A,(DE)		; Compare the two
	CP	(HL)
	RET	NZ		; Return if not match
	DJNZ	$FS8		; Loop until done
	SCF			; No need for swap
	RET
;--
; Sort headers
;--
RESORT:	LD	HL,ESORT
	JR	RSORT
RDSORT:	LD	HL,DSORT
	JR	RSORT
RSSORT:	LD	HL,SSORT
	JR	RSORT
RNSORT:	LD	HL,NSORT
	JR	RSORT
RFSORT:	LD	HL,FSORT	; Filename sort
;--
; Sort the filenames
; Entry: HL = sort routine
;--
RSORT:	LD	(SORTX),HL	; Store it
;--
; Sort the filenames
;--
SORT:
; Set up registers
$SL0:	LD	HL,BUFFER+DELEN
	LD	DE,BUFFER
	LD	C,0		; No swaps
; Main loop
$SL1:	LD	A,(HL)		; See if at end
	INC	A
	JR	Z,$SWEND	; If at end, skip
; Perform compare
	RPUSH	HL,DE,BC	; Save registers
	CALL	FSORT		; Default to filename
SORTX	EQU	$-2
	RPOP	BC,DE,HL	; Restore
	JR	C,$SL2		; Don't swap if no need
; Swap filenames
	LD	B,DELEN		; Length to swap
$SWZ1:	LD	A,(DE)		; One byte
	LD	C,(HL)		; Swap bytes
	LD	(HL),A
	LD	A,C
	LD	(DE),A
	INC	DE
	INC	HL
	DJNZ	$SWZ1
	LD	C,1		; Indicate swap
; Loop
	JR	$SL1
; Move to next file
$SL2:	PUSH	BC
	LD	BC,DELEN
	EX	DE,HL
	ADD	HL,BC
	EX	DE,HL
	ADD	HL,BC
	POP	BC
	JR	$SL1
; End of files reached
$SWEND:	LD	A,C		; Any swaps?
	OR	A
	JR	NZ,$SL0		; Try again if so
; Success!
	RET
;--
; Delete files
;--
KEY_KILL:
	CALL	CFILES		; Find out how many
	OR	A
	JR	NZ,$KDN		; Ahead if checked
	LD	A,(FNUM)	; File number
	INC	A
	LD	(O1FILE),A	; Store
	LD	HL,KILL1$
	JR	$KDN1		; Skip past next
; Store number within message
$KDN:	LD	HL,KILL$
	CALL	CBYTE		; Store number within message
$KDN1:	EX	DE,HL		; Move to DE
	LD	HL,YMAX-1*XMAX+SCREEN
	CALL	KBD_DKEY	; Wait for key
	AND	11011111B
	CP	'Y'		; Is it yes?
	RET	NZ		; Return if not yes
; Delete the files
	SVC	@CKBRKC
	CALL	DELETE		; Delete files
	CALL	NZ,ERROR	; Display error
	CALL	SORT		; Sort directory
	LD	A,(DRIVE)
	LD	C,A
; Not really needed
	IF	TRSDOS
	ELSE
	SVC	@GTDCT
	ENDIF
	CALL	RDGAT		; Read information
	CALL	STATUS		; Display it
$WDV:	OR	1
	RET
;--
; Delete files
;--
DELETE0:
	LD	A,(EFNUM)	; Decrement ending number
	DEC	A
	LD	(EFNUM),A
DELETE:
	CALL	FCFILEC		; Find file
	RET	Z		; Return if done
; Display messsage
	LD	($T667A),HL	; Store for later
	PUSH	DE
	LD	DE,KILL9$
	CALL	FMDISP		; Display filename
	POP	DE
	LD	DE,FCB
	CALL	PASSOFF
; TRS-DOS 1.3 does not require opening
	IFEQ	TRSDOS,FALSE
	SVC	@OPEN		; Open the file
	JR	Z,$U88
	CP	42		; LRL open error
	RET	NZ
	ENDIF
$U88:	SVC	@REMOV		; Delete the file
	RET	NZ
; Delete from memory
	LD	HL,$-$
$T667A	EQU	$-2
	LD	D,H
	LD	E,L
	LD	BC,DELEN	; Length of entry
	ADD	HL,BC
	PUSH	HL
	LD	HL,BEND		; End of buffer
	OR	A
	SBC	HL,DE
	LD	B,H		; Move count to BC
	LD	C,L
	POP	HL
	LDIR			; Delete entry
; Decrement current if last
	LD	A,(SFNUM)	; Starting offset
	LD	H,A
	LD	A,(FNUM)	; Number
	ADD	A,H
	LD	H,A
	INC	H
	LD	A,(EFNUM)	; Ending number
	CP	H		; Is it the same?
	JR	NZ,DELETE0	; If not, OK
; Must decrease number
	LD	A,(FNUM)
	OR	A		; At beginning?
	JR	Z,DEL5
	DEC	A
	LD	(FNUM),A	; Store again
	JR	DELETE0		; OK
; Must scroll screen
DEL5:	LD	A,(SFNUM)
	SUB	XFILES
	LD	(SFNUM),A
	JR	DELETE0
;--
; Copy filename to message
;--
FCFILEC:
	CALL	FCFILE		; Find file
	RET	Z		; Return if none found
CFTM:	RPUSH	HL,DE,BC
	LD	HL,FCB		; Filename
	LD	DE,FILE$-1
$R89Y:	INC	DE
	LD	A,(HL)		; Byte
	INC	HL
	LD	(DE),A
	CP	':'
	JR	NZ,$R89Y	; Loop until done
	XOR	A
	LD	(DE),A		; Store over colon
	RPOP	BC,DE,HL
	OR	1		; Make NZ
	RET
;--
; Display file message
; Entry: DE points to message start
;--
FMDISP:
	RPUSH	HL,BC
	CALL	DSP_CBL		; Clear bottom
	LD	HL,YMAX-1*XMAX+SCREEN
	CALL	DSP_PRINT	; Print message
	INC	HL
	LD	DE,FILE$	; Filename
	CALL	DSP_PRINT
	CALL	DSP_PAINT
	RPOP	BC,HL
	RET
;--
; Write entire allocation to FCB2
; Entry: BC = amount to allocate
; Exit: NZ if error
;--
WRERN:	LD	DE,FCB2		; Second file
	LD	A,B		; If space = 0, don't
	OR	C		; do any allocation
	RET	Z
	DEC	BC		; Adjust for 0 offset
	SVC	@POSN		; Position to the "size"
	SVC	@WRITE		; Write dummy sector
	JR	NZ,WRERN1	; Branch on error
	SVC	@REW		; Rewind the file
	LD	HL,0		; Set ERN to zero
	IF	TRSDOS
	INC	HL
	ENDIF
	LD	(FCB2+12),HL
	RET
WRERN1:	CP	27		; Disk full?
	RET	NZ
	SVC	@REMOV		; Remove what can't fit
	LD	A,27		; Return with "disk full"
	OR	A		; and NZ flag
	RET
;--
; Copy files
; Entry: A = drive #
;--
COPY:
	ADD	A,'0'		; Make ASCII
	LD	(TDRIVE),A	; Store number
; Copy loop
$CLP:	CALL	FCFILEC		; Find file
	RET	Z		; Return if all
; Copy FCB to second
	LD	HL,FCB
	LD	DE,FCB2
	LD	BC,FCBLEN
	LDIR
; Change drive number
	LD	HL,FCB2		; Second
; Go to colon
$CLC:	LD	A,(HL)
	INC	HL
	CP	':'
	JR	NZ,$CLC
; Colon found, change drive
	LD	A,0
TDRIVE	EQU	$-1
	CP	(HL)		; Is it same?
	JR	NZ,$CLC0
	LD	A,32		; Illegal drive number
	OR	A
	RET
$CLC0:	LD	(HL),A
; FCBs in order
; OPEN old file
	LD	DE,FCB
	LD	B,0		; LRL of 256
	CALL	PASSOFF
	SVC	@OPEN
	JR	Z,$CL7		; Skip if OK
	CP	42		; LRL error?
	RET	NZ		; No, real error
; Read directory entry for later
$CL7:	LD	A,(FCB+6)	; Drive #
	AND	00000111B
	LD	(CSDRIVE),A
	LD	A,(FCB+7)	; DEC
	LD	(CSDEC),A
	LD	B,$-$		; DEC
CSDEC	EQU	$-1
	LD	C,$-$		; Drive
CSDRIVE	EQU	$-1
	SVC	@DIRRD
	RET	NZ
	LD	DE,SDBUFF$	; Directory buffer
	LD	BC,FCBLEN
	LDIR
; INIT new file
	LD	DE,FCB2		; Second FCB
	LD	B,0		; LRL of 256
	CALL	PASSOFF
	SVC	@INIT
	JR	Z,$CL8		; Skip if OK
	CP	42		; LRL error?
	RET	NZ		; No, real error
;<<<<
	PUSH	IY
	LD	A,(TDRIVE)	; New drive
	LD	C,A
	SVC	@GTDCT
	LD	D,(IY+9)	; Directory value
	POP	IY
	LD	HL,BGAT		; GAT buffer
	LD	E,0		; GAT sector
	SVC	@RDSSC		; Read system sector
	RET	NZ		; Return if error
	LD	A,(BGAT+0CDH)	; Disk type byte
	BIT	3,A
	LD	A,0FFH		; New style
	JR	Z,$R755
	XOR	A
$R755:	LD	(NDATE1),A
;>>>>
; Display message
$CL8:	PUSH	DE
	LD	DE,COPY9$	; Message
VCOPY3	EQU	$-2
	CALL	FMDISP		; Display file message
	POP	DE
; Save ERN
	LD	HL,(FCB+12)
	INC	HL
;()()
	IF	TRSDOS
	INC	HL
	ENDIF
	LD	(ZERN),HL	; Store for later
	LD	(ZERN2),HL
; Do entire allocation
	LD	BC,(FCB+12)	; Ending record number
;()()
	IF	TRSDOS
	DEC	HL
	ENDIF
	CALL	WRERN		; Write to ERN
	RET	NZ		; Return if error
; Read file records
$RDFILE:
	LD	HL,FBUFF	; Buffer
$RDFL1:	LD	DE,$-$		; Number of records
ZERN	EQU	$-2
	DEC	DE		; Decrement count
	LD	(ZERN),DE
	LD	A,D		; Is it zero?
	OR	E
	JR	Z,$WRFILE	; Write file if end
	LD	DE,FCB		; Read FCB
	LD	(FCB+3),HL	; Stuff value
	SVC	@READ		; Read record
	RET	NZ		; Return if error
	INC	H		; Increase buffer
	LD	A,H
	CP	$-$		; See if there
ZHIMEM	EQU	$-1
	JR	C,$RDFL1	; Loop if not there
; Write file records
$WRFILE:
	LD	HL,FBUFF	; Buffer
$WRFL1:	LD	DE,$-$		; Second copy of ERN
ZERN2	EQU	$-2
	DEC	DE
	LD	(ZERN2),DE	; Store
	LD	A,D		; Check for zero
	OR	E
	JR	Z,$CDONE	; Go if done
	LD	DE,FCB2
	LD	(FCB2+3),HL	; Store value
	SVC	@WRITE		; Write record
	RET	NZ
	INC	H		; Next page
	LD	A,H
	CP	$-$		; See if at end
ZHIMEM2	EQU	$-1
	JR	C,$WRFL1	; Loop if not at end
	JR	$RDFILE		; Loop READ if at end
; Done with writing, should clean up FCB
$CDONE:	LD	HL,(FCB+8)	; Offset, LRL
	LD	(FCB2+8),HL
; Store values for later
	LD	A,(FCB2+6)	; Destination drive #
	AND	00000111B
	LD	(CDDRIVE),A
	LD	A,(FCB2+7)	; DEC
	LD	(CDDEC),A
; Close destination file
	LD	DE,FCB2
	SVC	@CLOSE
	RET	NZ
	LD	B,$-$		; DEC
CDDEC	EQU	$-1
	LD	C,$-$		; Drive
CDDRIVE	EQU	$-1
	SVC	@DIRRD
	RET	NZ
	PUSH	BC
	EX	DE,HL		; Move SBUFF to DE
	LD	HL,SDBUFF$+1
	RES	6,(HL)		; reset MOD flag
	DEC	HL
	LD	BC,5		; Move 5 bytes
	LDIR
	LD	A,E		; Point to password or time
	ADD	A,11
	LD	E,A
	LD	A,L
	ADD	A,11
	LD	L,A
	LD	BC,4		; Move password or time
	LDIR
;<<<<
; Now make changes if dates do not match
	DEC	DE		; Move to password/time
	DEC	DE
	LD	A,(NDATE)	; Dating scheme on original
	LD	C,A
	LD	A,(NDATE1)	; Scheme on copy
	CP	C
	JR	Z,$YUI1		; If match, no problem
	CP	0FFH		; Is second disk new?
	JR	NZ,$YUI0
; Convert new to old
	LD	A,.LOW.BLANK	; Fill with blank password
	LD	(DE),A
	INC	DE
	LD	A,.HIGH.BLANK
	LD	(DE),A
	JR	$YUI1
; Convert old to new
$YUI0:	XOR	A		; Blank time
	LD	(DE),A
	INC	DE
	LD	A,(SDBUFF$+2)	; Year byte
	AND	00000111B	; Mask out others
	LD	(DE),A		; Store year
;>>>>
$YUI1:	POP	BC
	SVC	@DIRWR		; Write to directory
	RET	NZ
; Completed!!
; Either close file or remove it
	LD	A,'C'		; Is it copy or move?
VCOPYB	EQU	$-1
	CP	'C'
	JR	NZ,$T678
	LD	DE,FCB
	SVC	@CLOSE		; Close file
	RET	NZ
	JP	$CLP		; Loop
$T678:	LD	DE,FCB
	SVC	@REMOV		; Remove file instead
	RET	NZ		; If error, return
	JP	$CLP
;--
; Copy files and move files
; Exit: NZ always
;--
KEY_COPY:
	LD	HL,COPY1$
	LD	(VCOPY1),HL
	LD	HL,COPY$
	LD	(VCOPY2),HL
	LD	HL,COPY9$
	LD	(VCOPY3),HL
	LD	A,'C'		; Copy
	LD	(VCOPYB),A
	JR	KEY_BOTH
KEY_MOVE:
	LD	HL,MOVE1$
	LD	(VCOPY1),HL
	LD	HL,MOVE$
	LD	(VCOPY2),HL
	LD	HL,MOVE9$
	LD	(VCOPY3),HL
	LD	A,'M'		; Move
	LD	(VCOPYB),A
KEY_BOTH:
	CALL	CFILES		; Find out how many
	OR	A
	JR	NZ,$CPN		; Ahead if checked
	LD	A,(FNUM)	; File number
	INC	A
	LD	(O1FILE),A	; Store it
	LD	DE,COPY1$
VCOPY1	EQU	$-2
	JR	$CPN1		; Skip past next
; Store number within message
$CPN:	LD	HL,COPY$
VCOPY2	EQU	$-2
	CALL	CBYTE		; Store in message
	EX	DE,HL
$CPN1:	LD	HL,YMAX-1*XMAX+SCREEN
	CALL	KBD_DNUM	; Get number
	JR	NZ,$BVC1
	CP	8		; Only 0 - 7 allowed
	JR	NC,$BVC1
; Make sure not the same drive
	LD	C,A
	LD	A,(DRIVE)
	CP	C
	LD	A,C
	JR	Z,$KCERR
; Make sure drive not write protected (if move)
	LD	B,A
	LD	A,(VCOPYB)	; Is it move?
	CP	'M'
	LD	A,B
	JR	NZ,$SLK		; Skip this part if copy
	PUSH	BC
	LD	A,(DRIVE)	; Current drive
	LD	C,A		; Put drive in C
	SVC	@CKDRV		; See if write protected
	POP	BC
	LD	A,B
	JP	C,MOVERR	; Move error
; Start copy
$SLK:	PUSH	AF
	SVC	@CKBRKC
	POP	AF
	CALL	COPY		; Copy files
	JR	Z,$NOERR1
	CALL	NZ,ERROR
	LD	HL,$-$
CKERR	EQU	$-2
	LD	A,H
	OR	L
	JR	Z,$NOERR1
	SET	7,(HL)		; Check it again
	LD	HL,0
	LD	(CKERR),HL
$NOERR1:
	LD	A,(VCOPYB)	; Is it move?
	CP	'M'
	CALL	Z,DIR_STORE	; Read new directory
	OR	1
	RET
; Error
$KCERR:	LD	A,32		; Illegal drive
	CALL	ERROR
	OR	1
	RET
; Illegal drive
$BVC1:	OR	1		; Return NZ
	RET
; Write protected disk
MOVERR:	LD	A,15
	CALL	ERROR		; Display error
	OR	1		; Return NZ
	RET
;--
; Receive drive number
; Exit: NZ always
;--
KEY_DRIVE:
	LD	HL,YMAX-1*XMAX+SCREEN
	LD	DE,DRIVE$
	CALL	KBD_DNUM	; Get number
	RET	NZ		; Return if invalid
KEY_DRIVEA:
	CP	8		; Only 0 - 7 allowed
	JR	NC,$KKL9	; Redisplay screen
	LD	C,A
	CALL	DIR_STORE1	; Reload directory
$KKL9:	OR	1		; No error (reset carry)
	RET
;--
; Rename file (only in Model 4 version)
; Exit: NZ always
;--
	IF	MOD4
KEY_RENAME:
; Get filename in FCB
	LD	A,(FNUM)	; Highlighted
	CALL	DIR_FDE		; Point to entry
	CALL	RFSPEC		; Move to FCB
	CALL	CFTM		; Copy filename to message
; Display message
	LD	HL,YMAX-1*XMAX+SCREEN
	LD	DE,RENAME$
	CALL	KBD_DLINE	; Wait for keys
	JR	C,$PLM		; Return if BREAK
; Put filename in FCB2
	LD	HL,UBUFF$
	LD	DE,FCB2
	SVC	@FSPEC
	LD	A,19		; Illegal file name
	JR	NZ,$KRP1	; Error
; Rename file
	LD	DE,FCB
	LD	HL,FCB2
	SVC	@RENAM
	JR	NZ,$KRP1	; Error
; Rename file in memory
	LD	A,(FNUM)	; Still highlighted
	CALL	DIR_FDE		; Point to it
	INC	HL		; Past mark
	INC	HL		; and DEC
	LD	DE,FCB2
	LD	B,12		; FILENAME/EXT
; Transfer from DE to HL
$POI:	LD	A,(DE)		; See if colon
	INC	DE
	CP	':'
	JR	Z,$UYT		; Jump ahead if so
	LD	(HL),A		; Store it
	INC	HL
	DJNZ	$POI		; Go until done
; Done
	JR	$PLM		; Jump past
$UYT:	LD	(HL),32		; Space over the rest
	INC	HL
	DJNZ	$UYT
$PLM:	CALL	SORT		; Successful, so sort
$PLM1:	OR	1		; NZ
	RET
$KRP1:	CALL	ERROR		; Display error
	JR	$PLM1
	ENDIF
;--
; Display message and wait for number
; Entry: HL = position, DE = string
; Exit: Z, A = number value
;  NZ, invalid number
;  C, BREAK pressed
;--
KBD_DNUM:
	CALL	KBD_DKEY	; Get key
	CP	KBREAK		; BREAK?
	JR	Z,KBD_DBRK
	PUSH	BC
	LD	C,A
	CALL	CNB		; Convert
	SCF			; Make sure not BREAK
	CCF
	PUSH	AF
	LD	A,C
	CALL	Z,DSP_DSP	; Display only if OK
	POP	AF
	POP	BC
	RET	Z		; Return if no error
	XOR	A
	CP	0FFH
	CCF
	RET			; A = 0, but NZ
KBD_DBRK:
	OR	A		; Make NZ
	SCF			; Make C
	RET
;--
; Display message and wait for key
; Entry: HL = position
;  DE = string
; Exit: A = key
;--
KBD_DKEY:
	CALL	DSP_CBL		; Clear the line
	CALL	DSP_PRINT	; Print the message
	INC	HL
	CALL	DSP_PAINT
	CALL	DSP_SADD	; Set X, Y cursor
	CALL	DSP_CON		; Turn on cursor
	CALL	KBD_GET
	PUSH	AF
	CALL	DSP_COFF
	POP	AF
	RET
; RENAME doesn't work with Model 3
	IF	MOD4
;--
; Display message and wait for input
; Entry: HL = position
;  DE = string
; Exit: UBUFF = line, C if BREAK pressed
;--
KBD_DLINE:
	CALL	DSP_CBL		; Clear bottom line
	CALL	DSP_PRINT
	INC	HL
	LD	DE,FILE$
	CALL	DSP_PRINT
	INC	HL
	LD	DE,RENAM1$
	CALL	DSP_PRINT
	INC	HL
	CALL	DSP_PAINT
	CALL	DSP_SADD	; Set X, Y cursor
	CALL	DSP_CON		; Turn on cursor
	RPUSH	HL,DE,BC
	LD	HL,UBUFF$
	LD	B,12		; Maximum
	CALL	KEYIN		; Get line
	RPOP	BC,DE,HL
	PUSH	AF
	CALL	DSP_COFF
	POP	AF
	RET
;--
; Read keyboard line
; Entry: HL = buffer, B = maximum
; Exit: ?
;--
KEYIN:
	LD	C,0
$KEYIN1:
	CALL	KBD_GET		; Wait for key
	CP	KLEFT		; Backspace?
	JR	Z,$ZLEFT
	CP	KBREAK		; BREAK?
	JR	Z,$ZBREAK
	CP	KENTER		; ENTER?
	JR	Z,$ZENTER
; See if too many
	PUSH	DE
	LD	E,A
	LD	A,C
	CP	B
	LD	A,E
	POP	DE
	JR	Z,$KEYIN1	; Loop if too many
; See if acceptable
	CP	32
	JR	C,$KEYIN1	; If too low, ignore
	CP	128
	JR	NC,$KEYIN1	; If too high, ignore
; Character is acceptable
	LD	(HL),A		; Store character
	INC	HL
	INC	C		; Increase count
	CALL	DSP_DSP		; Display character
	JR	$KEYIN1		; Loop
; BREAK
$ZBREAK:
	SCF			; Means BREAK pressed
	RET
; ENTER
$ZENTER:
	LD	(HL),A		; Store ENTER (don't display)
	XOR	A		; No BREAK
	RET
; Backspace
$ZLEFT:	INC	C
	DEC	C		; At zero?
	JR	Z,$KEYIN1	; Ignore if there
	DEC	HL
	DEC	C
	CALL	DSP_DSP		; Display character
	JR	$KEYIN1		; Loop
UBUFF$	DS	13
	ENDIF
	DB	'===> HERE'
NDATE1	DB	0
SDBUFF$	DS	FCBLEN
