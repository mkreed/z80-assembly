;-------------------------------------
; DATA-MINDER database manager
; copyright (c) 1995, by Matthew Reed
; all rights reserved
; DMFORM/ASM, form processing
;-------------------------------------
SCRNEND	DEFL	ROW-3*COL+SCRN
TNB	DEFL	SPEC-1<-8+1<8
;------------------------
; Convert screen to data
; DE => data buffer
;------------------------
CSDATA:	LD	A,20H		; "JR NZ,"
	LD	(CWSBT),A
	LD	HL,FORM		; Form buffer
	PUSH	DE		; Save data buffer
	CALL	MFRM		; Mark the form
	POP	DE		; Restore DE
	LD	HL,SCRN		; Screen
; Make sure not end of screen
CSD1	LD	A,H		; Is it end of screen?
	CP	.HIGH.SCRNEND
	JR	NZ,CSD2
	LD	A,L		; Is it end of screen?
	CP	.LOW.SCRNEND
	JR	NZ,CSD2
; End of screen
	LD	A,0FFH		; End of data
	LD	(DE),A		; Store
	INC	DE
	RET			; Return
; Loop until data found
CSD2	LD	A,(HL)		; Get byte from screen
	INC	HL		; Ahead one
	CP	31		; Is it space?
	JR	NC,CSD1		; Loop if it is
	OR	A
	JR	Z,CSD1		; Loop if only zero
; See state of entry
	CP	8		; Is it text?
	JR	Z,CSTEXT	; Go if so
; If undefined, store as text
CSTEXT	LD	(DE),A		; Store type
	INC	DE		; Ahead
	LD	A,(HL)		; Number
	LD	(DE),A		; Store it
	INC	DE
	INC	HL
	LD	A,(HL)
	OR	A
	JR	NZ,$CST1
	INC	HL
	DEC	DE
	DEC	DE
	JR	CSD1
; Store data
$CST1	CALL	CWSB		; Copy to buffer
	JR	CSD1		; Loop until done
;---
; Convert screen to form
;---
CSFRM:	LD	HL,FORM		; Copy form to data buffer
	LD	DE,DATA
	LD	BC,2048
	LDIR
	LD	A,06H		; "LD B,n"
	LD	(CWSBT),A
	XOR	A		; Signal no field
	LD	(FITI),A
	LD	(FITI1),A
	LD	HL,SCRNEND
; Eliminate possible final colons
	LD	A,':'
	LD	B,3
$CGG0	CP	(HL)		; Compare to see
	JR	NZ,$CGG1
	LD	(HL),32
$CGG1	DEC	HL		; Previous byte
	DJNZ	$CGG0		; Loop until done
	CALL	CSFFN		; Make table of used numbers
; Start processing screen
	LD	HL,SCRN		; Screen
	LD	DE,FORM		; Buffer
; Find field name, title, or end
$CSF1	LD	A,(HL)		; Get character
	INC	HL		; Advance HL
	CP	':'		; Is it extra colon?
	JR	Z,$CSF1		; Skip if so
	CP	32		; Is it space?
	JR	Z,$CSF1		; Skip if so
	DEC	HL		; Back up
; Found one, now determine which one
	PUSH	HL		; HL IS ON STACK!!
	CALL	CADXY		; Convert to X, Y
	LD	A,C		; Put in memory
	LD	(DE),A
	INC	DE
	LD	A,B
	LD	(DE),A
	INC	DE
$CSF2	LD	A,H		; Is it end of screen?
	CP	.HIGH.SCRNEND
	JR	NZ,$CSF3
	LD	A,L		; Is it end of screen?
	CP	.LOW.SCRNEND
	JR	NZ,$CSF3
	POP	HL		; Restore HL
	DEC	DE		; Back over X, Y
	DEC	DE
	JP	CGFC		; Give correct numbers
; Not end of screen, find out how long
$CSF3	LD	A,(HL)		; Get character
	INC	HL		; Next byte
	CP	':'		; Is it end of name?
	JR	Z,$CSFF		; Ahead if so
	CP	32		; Loop if not space
	JR	NZ,$CSF2
	CP	(HL)		; See if same
	JR	NZ,$CSF2	; Loop if not
; Make sure it is title
	PUSH	HL		; Save HL
$CSF31	LD	A,(HL)		; Get character
	INC	HL		; Next byte
	CP	':'		; Is it end of name?
	JR	Z,$CSFF0
	CP	32		; Is it space?
	JR	Z,$CSF31	; Loop if space
; Clean up stack
	POP	HL		; Restore HL
	DEC	HL		; Back one
; End of title
	LD	A,1		; Signal title
	LD	(DE),A
	LD	A,0FFH
	LD	(FITI1),A
	INC	DE
	JR	$CSFF1		; Store the rest
; End of field name
$CSFF0	EX	(SP),HL		; Eliminate BC, HL
	POP	HL
$CSFF	LD	A,8		; Signal field
	LD	(DE),A
	LD	A,251		; Show field exists
	LD	(FITI),A
	INC	DE
	XOR	A
	LD	(DE),A		; Store zero
	INC	DE
$CSFF1	LD	(HL),0
	POP	HL		; Restore HL
	CALL	CWSB		; Write to buffer
	JR	$CSF1		; Loop until done
;--
; Now give fields correct numbers
;--
CGFC	LD	A,(0FFH)
	LD	(DE),A
	LD	A,(FORM)	; See if empty
	INC	A
	RET	Z		; Return if empty
	LD	A,0		; See if field
FITI	EQU	$-1
	XOR	251		; Reverse error
	JR	Z,CGFC1		; Ahead if fields
	AND	0		; Mix in titles
FITI1	EQU	$-1
	RET			; Return (error or not)
CGFC1	PUSH	DE
	LD	DE,FORM		; FORM address
; See if duplicated
$CSF21	LD	A,(DE)		; See if end
	INC	A
	JR	Z,$CSF2E	; Ahead if end
	INC	DE		; Past X, Y
	INC	DE
	LD	A,(DE)		; See what type
	INC	DE
	CP	7
	JR	C,$CSF22	; Skip past field
	INC	DE		; Past number
	CALL	CSFTD		; See if text is duplicated
MDFO	EQU	$-2
	DEC	DE
	OR	A		; See if duplicate
	JR	Z,$CSF23
; Duplicated
$CSF220	LD	(DE),A		; Store number
	INC	DE
$CSF22	LD	A,(DE)		; See if end
	INC	DE
	OR	A
	JR	NZ,$CSF22	; Loop until done
	JR	$CSF21		; Loop
; Not duplicated
$CSF23	PUSH	HL		; Save HL
	LD	HL,TNB		; Go to table
$CSF231	INC	L
	JP	PE,$CSF23E	; Ahead if error
	LD	A,(HL)		; Get byte
	OR	A
	JR	NZ,$CSF231	; Loop until found
; Found unused number
	INC	(HL)		; Make not zero
	LD	A,L		; Put in A
	POP	HL		; Restore HL
	JR	$CSF220		; Jump back
; End of processing
$CSF2E	POP	DE		; Restore DE
	XOR	A
	RET
; Processing error
$CSF23E	RPOP	HL,DE		; Restore registers
	LD	A,252		; Too many fields
	RET
;---
; See if field text is duplicated
; DE => text of field
; A <= field number (0 if none)
;---
CSFTD	LD	HL,DATA		; Possible duplicate in DATA
CSN0	LD	A,(HL)		; Get byte
	INC	A		; See if end
	RET	Z		; Return if end
	INC	A		; Is it comment?
	JR	Z,CSN1		; Skip if so
	INC	HL		; Past X, Y
	INC	HL
	LD	A,(HL)		; Get type
	INC	HL		; Next byte
	CP	7		; Is it title or above?
	JR	C,CSN1		; If so, ahead
	INC	HL		; Past number
; See if field text is same
	RPUSH	DE,HL		; Save registers
CSN00	LD	A,(DE)		; See if same
	CP	(HL)
	JR	NZ,CSN01	; Ahead if not same
	OR	(HL)		; See if end of both
	JR	Z,CSN02		; Ahead if match
	INC	DE		; Next byte of each
	INC	HL
	JR	CSN00		; Loop until done
; Fields did match
CSN02	RPOP	HL,DE		; Restore registers
	DEC	HL		; Back one
	LD	A,(HL)		; Get number
	RET			; Successful match
; Fields did not match
CSN01	RPOP	HL,DE		; Restore registers
CSN1	LD	A,(HL)		; Get byte
	INC	HL
	OR	A
	JR	NZ,CSN1		; Loop until zero
	JR	CSN0		; Loop
;---
; Find next number in order
;---
CSNNO	LD	BC,TNB+256	; Other buffer
CSNNO1	LD	A,(BC)		; Get byte
	INC	C
	RET	PE		; Return if past
	OR	A		; See if zero
	JR	Z,CSNNO1	; Loop if not
	PUSH	AF
	XOR	A
	DEC	C
	LD	(BC),A
	POP	AF
	RET
;---
; Count unused fields
;---
; Zero specification buffer
CSFFN	LD	HL,TNB
	LD	DE,TNB+1
	LD	BC,512
	LD	(HL),0
	LDIR
	LD	HL,DATA		; Field is in DATA
	LD	DE,TNB+256	; Other field numbers
CFN0	LD	A,(HL)		; Get byte
	CP	0FFH		; See if end
	RET	Z		; Return if end
	CP	0FEH		; Is it comment?
	JR	Z,CFN1		; Skip if so
	INC	HL		; Past X, Y
	INC	HL
	LD	A,(HL)		; Get type
	INC	HL		; Next byte
	CP	7		; Is it title or above?
	JR	C,CFN1		; If so, ahead
	LD	A,(HL)		; Number
	INC	HL		; Next byte
; Mark entry in table
	LD	(DE),A		; Put in order table
	INC	DE
	PUSH	HL		; Save HL
	LD	H,.HIGH.TNB
	LD	L,A
	LD	(HL),1		; Signal in use
	POP	HL
CFN1	LD	A,(HL)		; Get byte
	INC	HL
	OR	A
	JR	NZ,CFN1		; Loop until zero
	JR	CFN0		; Loop
;---
; Write characters to buffer including compression
; HL => screen
; DE => buffer
; BC is destroyed
;---
CWSB	LD	A,(HL)		; Get character
	INC	HL
	LD	(DE),A		; Store in buffer
	INC	DE
	OR	A		; See if zero (and end)
	RET	Z		; Return if so
; See if space (or not)
	CP	32		; See if space
CWSBT	JR	NZ,CWSB		; Loop if not same
; If not end, see if next is same
	CP	(HL)		; See if same
	JR	NZ,CWSB		; Loop if not same
; It is same, see if three are
	INC	HL
	CP	(HL)		; Is third byte same?
	DEC	HL		; Back the byte
	JR	NZ,CWSB		; Loop if not same
; Three bytes are same
	DEC	DE		; Write duplicate byte
	LD	A,0FFH
	LD	(DE),A
	INC	DE
	LD	B,2		; Initialize count
	LD	A,(HL)		; Get character
; Loop
CWSBL	INC	HL
	INC	B
	JR	Z,CWSBE
	CP	(HL)		; See if same
	JR	Z,CWSBL
; Write character and count
CWSBE	INC	DE
	LD	(DE),A
 	DEC	DE
	LD	A,B
	DEC	A		; Back one byte
	LD	(DE),A
	INC	DE
	INC	DE
	JR	CWSB		; Loop until done
;---
; Mark form
; Eliminate all text except for data
; Mark positions of field and end with zero
;---
MFRM	LD	A,(HL)		; X value
	INC	A		; Is it end?
	RET	Z
	CALL	MFIELD		; Display entry
	JR	MFRM		; Loop until done
	RET
;---
; Mark field
; HL => address
;---
MZERO	LD	DE,$-$		; Address of start of field
EFFADD	EQU	$-2
; Process field
MFIELD	PUSH	HL
	CALL	SDFIELD		; Special field display
	LD	A,240
	LD	(DE),A
	RPUSH	HL,DE
	LD	A,(HL)
	LD	C,A
	INC	A		; See if end
	LD	DE,SCRNEND	; End of screen
	JR	Z,$MFI2		; Jump ahead if so
	INC	HL
	LD	B,(HL)
	CALL	CXY
	EX	DE,HL
$MFI2	DEC	DE		; Back one
	LD	A,(DE)		; Get byte
	CP	32		; Is it space?
	JR	Z,$MFI2		; Loop if so
; End of space
	INC	DE		; Ahead one
	XOR	A		; Signal end
	LD	(DE),A
	RPOP	DE,HL
	EX	(SP),HL
	LD	A,(EFTYPE)	; Field type
	CP	8		; Is it text or above?
	JR	C,$MFS1		; Return if not
	INC	HL		; Go past X, Y
	INC	HL
	DEC	DE		; Go back one
	LD	A,(HL)		; Put type on screen
	INC	HL
	LD	(DE),A
	INC	DE
	LD	A,(HL)		; Put number on screen
	LD	(DE),A
	OR	A		; Make no carry
$MFS1	POP	HL		; Restore HL
	RET
;---
; Compare search specification with string
; DE => specification
; HL => string
; BC is destroyed
;---
COMP	XOR	A		; Make "NOP"
	LD	(CSFE),A
	LD	A,(DE)		; First byte
	OR	A		; See if end
	JP	Z,CSUCC		; Automatic success if nothing
COMP0	LD	A,(DE)
	INC	DE
	CP	32		; See if space
	JR	Z,COMP0		; Loop if so
	DEC	DE		; Back one
	CP	0FFH		; See if space
	JR	NZ,COMP1
	INC	DE
	INC	DE
	JR	COMP0		; Check for other spaces
; Time to compare for "/", "=", "<", ">",".."
COMP1	CP	'/'		; See if NOT
	JP	Z,CNOT		; Go if so
	CP	'='		; See if equal
	JP	Z,CEQUAL
	CP	'>'		; See if greater than
	JP	Z,CGREAT
	CP	'<'		; See if less than
	JP	Z,CLESS
COMP10	CP	'.'		; See if ".."
	JR	NZ,COMP2
	INC	DE
	LD	A,(DE)		; See if other "."
	CP	'.'
	JR	NZ,COMP14
	CALL	CMCWILD		; Go if it is
	JR	CSFE
COMP14	DEC	DE		; Otherwise, decrement
COMP2	CALL	COMP3		; Call comparison routine
CSFE	NOP			; Space for "INC A"
CSFE1	AND	00000001B	; Take off all but bit 0
	RET
CSFNE	LD	A,1		; Make not equal
	JR	CSFE
CSFEE	XOR	A		; Make equal
	JR	CSFE
;---
; Actual string matching
;---
; Skip past extra spaces
COMP3	LD	A,(HL)		; First byte of string
	INC	HL
	CP	32		; See if space
	JR	Z,COMP3		; Advance past space
	CP	0FFH		; See if multiple spaces
	JR	NZ,COMP39	; Ahead
	INC	HL
	INC	HL
	JR	COMP3		; Loop until done
COMP39	LD	A,(DE)		; See if both are at end
	OR	(HL)
	JP	Z,CSUCC		; If they are same, then success
	DEC	HL
; See if "@" or ".."
COMP5	LD	A,(DE)		; Get spec byte
	CP	'@'		; Go if wildcard
	JR	Z,CWILD
	CP	'.'		; See if multiple wildcard
	JR	NZ,COMP51
	INC	DE
	LD	A,(DE)
	CP	'.'
; Extremely experimental
	JR	NZ,COMP48
	INC	DE		; Next byte
	LD	A,(DE)		; See if zero
	DEC	DE
	OR	A
	JR	Z,CSUCC		; Signal success
	JP	CMCWILD		; Or go on
COMP48	DEC	DE
	LD	A,(DE)
COMP51	CP	(HL)		; See if the same
	JR	Z,COMP6		; Ahead if the same
;*
	XOR	(HL)
	CP	223		; See if same
	JR	Z,COMP62
	LD	A,(DE)
;*
	AND	11011111B	; Eliminate lowercase
	CP	'A'
	JR	C,CFAIL		; Fail if below
	CP	'Z'+1
	JR	NC,CFAIL	; Fail if above
	LD	A,(DE)		; Get byte
	XOR	00100000B	; Reverse upper or lower
	CP	(HL)		; See if same
	JR	NZ,CFAIL	; Fail if not the same
; See if both spaces
COMP6	INC	A		; See if count
	JR	Z,COMP62	; Ahead if so
	CP	33		; See if spaces
	JR	Z,COMP62	; Ahead if so
COMP61	INC	DE		; Next byte for both
	INC	HL
COMP66	LD	A,(DE)		; See if both are at end
	OR	(HL)
	JR	Z,CSUCC		; Success if both at end
	JR	COMP5		; Loop until done
; Advance past spaces
COMP62	CALL	COMP62A		; Go past space
	EX	DE,HL
	CALL	COMP62A
	EX	DE,HL		; Switch back
	JR	COMP66		; Loop back
COMP62A	LD	A,(HL)
	CP	0FFH		; See if compression
	JR	NZ,COMP62B
	INC	HL		; Go past compression
	INC	HL
	INC	HL
	RET
COMP62B	INC	HL		; Go past space
	LD	A,(HL)		; Get byte
	CP	32
	JR	Z,COMP62B	; Loop until done
	RET
; NOT routine
CNOT	INC	DE		; Next byte
	LD	A,3CH		; "INC A"
	LD	(CSFE),A	; Negate either
	JP	COMP0		; Jump back
; Wildcard routine
CWILD	LD	A,(HL)		; See if space
	CP	32
	JR	Z,CFAIL		; Fail if it is space
;*
	CP	0FFH		; See if space
	JR	Z,CFAIL		; Fail if space
;*
	JR	COMP6		; Otherwise, ignore compare
; Success routine
CSUCC	XOR	A
	RET
; Failure routine
CFAIL	OR	1
	RET
; Multiple character wildcard
CMCWILD	INC	DE		; Go past "."
	LD	A,(DE)		; See if done
	OR	A
	JR	NZ,CMC1		; If something, ahead
	OR	(HL)		; See if zero
	JR	Z,CMCC1
	LD	A,255		; Success
CMCC1	INC	A		; Failure
	RET			; End it
CMC1	PUSH	DE		; Otherwise, save spec
	PUSH	HL		; Save string
	CALL	COMP39		; See if successful
	POP	HL		; Restore string
	POP	DE		; Restore spec
	RET	Z		; If successful, leave
	INC	HL		; Next byte
	LD	A,(HL)		; See if end
	OR	A
	JR	NZ,CMC1		; If not, try again
	LD	A,1		; Otherwise, signal failure
	RET
;--
; Numeric routines
;--
; Equal routine
CEQUAL	EX	DE,HL
	PUSH	HL		; Save HL
CEQ1	LD	A,(HL)		; Get byte
	INC	HL
	OR	A		; See if zero
	JR	Z,CEQ2		; Ahead if nothing
	CP	1		; See if already done
	JR	Z,CEQ10
	CP	'.'		; See if period
	JR	NZ,CEQ1		; Loop until done
	CP	(HL)		; See if same
	JR	NZ,CEQ1		; Loop if not same
; Found "through" operator
	LD	(HL),1		; Block out indicator
	DEC	HL
	LD	(HL),1
CEQ10	POP	HL		; Restore HL
	EX	DE,HL		; Switch registers
	RPUSH	HL,DE		; Save registers
	CALL	GREAT		; Comparison
	RPOP	HL,DE
	LD	(CEQ1V),A	; Store value
	XOR	3		; See if matched
	JP	Z,CSFE		; Jump back if so
; Find number after ".."
CEQ11	LD	A,(HL)		; Find the ".."
	INC	HL
	DEC	A		; See if 1
	JR	NZ,CEQ11	; Loop until found
	INC	HL
	CALL	GREAT		; Do comparison
	CP	3		; See if matched
	JP	Z,CSFEE
	XOR	0		; XOR with other result
CEQ1V	EQU	$-1
	JP	CSFE		; Jump back
; Do ordinary equals condition
CEQ2	POP	HL		; Restore HL
	EX	DE,HL		; Switch back
; Normal equal operation
	CALL	CNC		; Find lengths
	EX	DE,HL		; Number in memory
	CALL	CNC		; Find lengths
; See if lengths are equal
	LD	A,B		; First length
	CP	C
	JP	NZ,CSFNE	; Not equal
; Compare numbers of equal length
; C = count
	RES	7,C		; Eliminate minus
	LD	A,C		; See if zero length
	OR	A
	JR	Z,CEDEC		; If so, ahead to decimals
CEE1	CALL	CGBHL		; Get bytes
	CP	B		; See if same
	JP	NZ,CSFNE	; Not equal
; Number is equal
	DEC	C		; See if end
	JR	NZ,CEE1		; Loop if not
; First part is equal
CEDEC	CALL	FPDR		; First part of routine
; See if lengths are equal
	LD	A,B		; First length
	CP	C
	JR	NZ,CEFNE	; Not equal
; Compare decimals of equal length
; C = count
	LD	A,C		; See if zero length
	OR	A
	JR	Z,CEFE		; Success if equal
CED1	CALL	CGBHL		; Get bytes
	CP	B		; See if same
	JR	NZ,CEFNE	; Not equal
; Number is equal
	DEC	C		; See if end
	JR	NZ,CED1		; Loop if not
;--
; Ending code
;--
CEFE	XOR	A		; Success
	JP	CSFE		; Jump back
CEFNE	LD	A,1		; Failure
	JP	CSFE
CGFE	XOR	A		; Success
CGFE1	XOR	0
CGFEO	EQU	$-1
	RET			; Jump back
CGFNE	LD	A,1		; Failure
	JR	CGFE1
;--
; Less than routine
; disk entry < specification
;--
CLESS	EX	DE,HL
;--
; Greater than routine
; disk entry > specification
;--
CGREAT	CALL	GREAT		; Call greater than
	JP	CSFE		; Jump back
;--
; Greater than comparison
;--
GREAT	XOR	A
	LD	(CGFEO),A	; Eliminate bit toggle
	CALL	CNC		; Find lengths
	EX	DE,HL		; Number in memory
	CALL	CNC		; Find lengths
; See if negative
	LD	A,B
	OR	C
	BIT	7,A		; See if negative
	JR	NZ,$CGR
	LD	A,1		; Toggle bit
	LD	(CGFEO),A
; See if lengths are equal
$CGR	LD	A,B		; Specification
	CP	C
	JR	Z,CEG0		; Ahead if same length
	JR	NC,CGFNE	; Not equal
	JR	CGFE		; Equal
; Compare numbers of equal length
; C = count
CEG0	RES	7,C		; Eliminate minus
	LD	A,C		; See if zero length
	OR	A
	JR	Z,CEDGC		; If so, ahead to decimals
CEG1	CALL	CGBHL		; Get bytes
	CP	B		; See if same
	JR	Z,CEG2		; Loop if equal
CGV1	JR	C,CGFNE		; Not equal (too high)
	JR	NC,CGFE		; Equal (too low)
; Number is equal
CEG2	DEC	C		; See if end
	JR	NZ,CEG1		; Loop if not
; First part is equal
CEDGC	CALL	FPDR		; First part of routine
; Compare decimals
CGD0	LD	A,C		; See if zero length
	OR	B
	JR	Z,CGD3		; Failure if zero
; See if zero
	AND	B		; See if B is zero
	JR	Z,CGFNE		; Failure if so
	LD	A,C		; See if C is zero
	OR	A
	JR	Z,CGFE		; Success if zero
CGD1	PUSH	BC
	CALL	CGBHL		; Get bytes
	POP	BC
	DEC	DE
	LD	A,(DE)
	INC	DE
	DEC	HL
	CP	(HL)		; See if same
	INC	HL
	JR	Z,CGD2
	JR	NC,CGFNE	; Not equal
	JR	CGFE		; Equal
; Number is equal
CGD2	LD	A,B		; See if counts are 1
	OR	C
	CP	1
CGD3	LD	A,3		; Not equal or equal
	RET	Z		; Not equal (even if negative)
	DEC	B		; See if end
	JR	Z,CGFNE
	DEC	C
	JR	Z,CGFE		; Success if no more
	JR	CGD1		; Loop
;--
; First past of decimal routine
;--
FPDR	LD	B,0
	PUSH	HL
	CALL	CADP1		; Find lengths
	POP	HL
	LD	C,B
	LD	B,0
	EX	DE,HL		; Number in memory
	PUSH	HL
	CALL	CADP1
	POP	HL
	RET
;--
; Count after decimal point
;--
CADP1	LD	A,(HL)		; Get byte
	CP	31
	JR	C,CADP2		; Return if end
	INC	HL		; Next byte
	CALL	CVN		; See if valid
	JR	Z,CADP1		; Loop until done
	INC	B
	JR	CADP1		; Loop until done
CADP2	LD	A,B		; See if nothing
	OR	A
	RET	Z
	DEC	HL
	LD	A,(HL)		; Get byte
	DEC	B
	CP	'0'		; See if trailing "0"
	JR	Z,CADP2		; Loop if so
	INC	B
	CALL	CVN		; See if valid
	JR	Z,CADP2		; Loop until done
	RET
;--
; Get byte in HL
;--
CGBHL	LD	A,(HL)		; Get byte
DH1	INC	HL
	LD	B,A
	CALL	CVN		; See if valid
	JR	Z,CGBHL		; Loop if not
; Get byte in DE
CGBDE	LD	A,(DE)		; Get byte
	INC	DE
	CALL	CVN		; See if valid
	JR	Z,CGBDE		; Loop if not
	RET
;--
; Determine length of number (except for decimal point)
; HL => number, B <= length (sign in bit 7)
;--
CNC	LD	C,B		; Exchange numbers
	LD	A,(HL)		; See if 255
	LD	B,A
	INC	A		; Return if so
	RET	Z
	LD	B,128		; Zero counter (positive)
	PUSH	HL		; Save HL
	CALL	CPOSNEG		; See if positive or negative
	POP	HL		; Restore HL
	JR	CNCL00		; Jump ahead
; Count numbers
CNCL0	INC	HL		; Next byte
CNCL00	LD	A,(HL)		; Get byte
	CP	31		; See if end
	RET	C
	CP	'.'		; See if decimal
	RET	Z		; Return if nothing
	CP	'0'		; See if leading zero
	JR	Z,CNCL0		; Loop if zero
	CALL	CVN		; See if valid
	JR	Z,CNCL0		; Loop if none valid
	DEC	B
; Now into valid numbers
	PUSH	HL		; Save value
CNCL1	INC	B		; Add to count
CNCL2	LD	A,(HL)		; Get byte
DH2	INC	HL		; Next byte
	CP	31		; See if end
	JR	C,CNCEND	; Go if end
	CP	'.'		; See if decimal
	JR	Z,CNCEND	; Go if end
	CALL	CVN		; See if valid
	JR	Z,CNCL2		; Loop until done
	JR	NZ,CNCL1	; Loop until done
; End of string
CNCEND	POP	HL		; Restore value
	RET
;--
; See if positive or negative
;--
CPOSNEG	LD	A,(HL)		; Get byte
	INC	HL		; Next byte
	CP	31		; See if end
	RET	C
	CP	'+'		; See if positive
	RET	Z
	CP	'-'
	JR	NZ,CPOSNEG	; Loop until done
	RES	7,B		; Make negative
	RET
;--
; See if valid number
;--
CVN	CP	'0'
	JR	C,CVF		; Fail if below
	CP	'9'+1
	JR	NC,CVF		; Fail if above
	OR	A		; Number
	RET
CVF	XOR	A		; Not number
	RET
