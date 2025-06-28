;=====================================
; DATA-MINDER database manager
; copyright (c) 1995, by Matthew Reed
; all rights reserved
; DMMENU/ASM, menu and form display
;=====================================
;---
; Find data #
; A => number
; HL <= data
; A <= 0 if none
;---
DFDN	LD	C,A		; Put in C
DFDN0	LD	A,(HL)		; Is it end?
	XOR	0FFH		; Make zero if so
	RET	Z		; Return if end
	LD	A,(HL)		; Put type in B
	LD	B,A
	INC	HL		; Otherwise,
	LD	A,(HL)		; compare to see
	INC	HL
	CP	C		; if correct
	LD	A,1		; Signal success
	RET	Z
	LD	A,B		; Advance to next item
	CP	8		; Text
	JR	Z,DFDNT
; Assume text if undefined
DFDNT	LD	A,(HL)		; Get byte
	INC	HL
	OR	A		; Is it zero?
	JR	NZ,DFDNT	; Loop until it is
	JR	DFDN0		; Go back to main loop
;---
; Display form and data
; HL => form
; DE => data
; Uses AF'
;---
DFRMD	XOR	A		; Zero count
	EX	AF,AF'
	PUSH	HL		; Save address
	EX	DE,HL		; Put data in DE
	EX	(SP),HL		; Switch them
DFRMD1	LD	A,(HL)		; X value
	CP	0FFH		; Is it end?
	JR	NZ,DFZ0
	POP	HL		; Equalize stack
	RET
DFZ0	CALL	DFIELD		; Otherwise, display field
	EX	AF,AF'
	LD	(FCOUNT),A	; Store count
	EX	AF,AF'
	LD	A,0		; Field type
EFTYPE	EQU	$-1
	CP	8		; Is it text or above?
	JR	C,DFRMD1	; Loop if not
	EX	(SP),HL		; Exchange form for data
	LD	A,0		; Field number
EFNUM	EQU	$-1
	PUSH	HL		; Save address
	CALL	DFDN		; Find field data
	OR	A		; Is it error?
	JR	Z,DFRMD3	; If not found, ahead
	LD	DE,$-$		; Address to write to
EFADD	EQU	$-2
	LD	A,32
	LD	(DE),A
	INC	DE		; Next byte
DFRMD2	LD	A,(HL)		; Get byte
	INC	HL
	OR	A		; Is it end?
	JR	Z,DFRMD3	; Ahead if so
	CP	0FFH		; See if duplicate bytes
	JR	Z,DFRMD4	; Ahead if so
	LD	(DE),A		; Otherwise, store
	INC	DE
	JR	DFRMD2		; Loop until done
DFRMD3	POP	HL		; Restore data
	EX	(SP),HL		; Exchange back
	JR	DFRMD1		; Loop until done
; Display duplicate bytes
DFRMD4	LD	A,(HL)		; Get count
	INC	HL
	LD	B,A		; Put in B
	LD	A,(HL)		; Get character
	INC	HL
DFRMD42	LD	(DE),A		; Store duplicate character
	INC	DE
	DJNZ	DFRMD42		; Loop until done
	JR	DFRMD2		; Display characters
;---
; Display form
; Uses AF'
;---
DFRM	XOR	A		; Zero count
	EX	AF,AF'
DFRM1	LD	A,(HL)		; X value
	CP	0FFH		; Is it end?
	RET	Z		; Return if so
	CALL	DFIELD		; Otherwise, display field
	EX	AF,AF'
	LD	(FCOUNT),A	; Store count
	EX	AF,AF'
	JR	DFRM1		; Loop until done
;---
; Display field
; Uses AF'
; HL => address
;---
DFIELD	CALL	CBL		; Clear bottom line
DFIELD1	LD	C,(HL)		; X value
	INC	HL
	LD	B,(HL)		; Y value
	INC	HL
	LD	A,(HL)		; Get type
	INC	HL
	LD	(EFTYPE),A	; Store type
	CP	7		; Is it title or above?
	JR	C,DFI1
	LD	A,(HL)		; Get number
	LD	(EFNUM),A	; Store it
	INC	HL		; Past number
	JR	Z,DFI1		; Ahead if comment
	EX	AF,AF'
	INC	A		; Increment count
	EX	AF,AF'
DFI1	PUSH	HL		; Save address
	CALL	CXY		; Convert to address
	LD	(EFFADD),HL	; Store first address
	POP	DE		; Form in DE
;--
	LD	A,C		; X value
	OR	A		; Is it zero?
	JR	Z,DFI2		; Skip if so
	DEC	HL
;**
	LD	A,(HL)		; See if zero
	OR	A
	JR	Z,DFI10
;**
	LD	(HL),32
DFI10	INC	HL
;--
; See if fixed-length
DFI2	LD	A,(EFTYPE)	; Field type
	CP	9		; Is it fixed?
	LD	A,0		; Default automatic length
	JR	NZ,DX1
	LD	A,(DE)		; Get length
	INC	DE
DX1	LD	(MLV),A		; Store
DF2	LD	A,(DE)		; Byte from form
	INC	DE
	OR	A		; Is it end?
	JR	Z,DFEND
;--
	CP	0FFH		; See if duplicate
	JR	Z,DXDUP
;**
;	AND	01111111B
	OR	0		; Reverse video byte
RVRSE	EQU	$-1
	LD	(HL),A		; Put on screen
	INC	HL
	JR	DF2		; Loop until done
; Duplicate bytes
DXDUP	LD	A,(DE)		; Get count
	INC	DE
	LD	B,A		; Put in B
	LD	A,(DE)		; Get character
	INC	DE
;**
;	AND	01111111B
	LD	C,A		; Put in C
	LD	A,(RVRSE)	; Reverse video byte
DXDUPI	OR	C		; Make it (if so)
DXDUPL	LD	(HL),A		; Store duplicate character
	INC	HL
	DJNZ	DXDUPL		; Go until done
	JR	DF2		; Loop until done
DFEND	LD	(HL),32
	LD	(EFADD),HL	; Store address
	EX	DE,HL		; Switch the two
;-
DCFLAG	NOP
	LD	A,(HL)		; See if comment
	CP	0FEH
	RET	NZ		; Return if not
	PUSH	DE		; Save DE
	LD	DE,ROW-1*COL+SCRN
	INC	HL		; Go past FEH
DFEND0	LD	A,(HL)		; Get byte
	INC	HL
	OR	A
	JR	Z,DFEND1	; Ahead if end
	LD	(DE),A		; Otherwise, store
	INC	DE
	JR	DFEND0		; Loop
DFEND1	POP	DE		; Restore DE
	RET
;---
; Special field display
; DE <= start of description
;---
SDFIELD	LD	A,3EH		; "LD A,n"
	LD	(RVRSE-1),A
	LD	A,32
	LD	(RVRSE),A
	XOR	A
	LD	(DXDUPI),A
	CALL	DFIELD1		; Bypass bottom line clear
	LD	A,0F6H		; "OR n"
	LD	(RVRSE-1),A
	XOR	A		; Make NOP
	LD	(RVRSE),A
	LD	A,10110001B	; "OR C"
	LD	(DXDUPI),A
	LD	DE,(EFADD)	; Start of description
	RET
;---
; Clear bottom line
;---
CBL	NOP
	RPUSH	HL,DE,BC	; Save registers
	LD	HL,ROW-1*COL+SCRN
	LD	DE,ROW-1*COL+SCRN+1
	LD	BC,COL-1
	LD	(HL),32
	LDIR			; Clear bottom line
	RPOP	BC,DE,HL	; Restore registers
	RET
;---
; Alter reverse state
;---
RVSOFF	XOR	A		; Turn it off
	JR	RVS1
RVSON	LD	A,128		; Turn it on
RVS1	LD	(RVRSE),A
	RET
;---
; Select field #
; B => field #
; HL => form
;---
SFN	CALL	RVSON		; Reverse video on
	CALL	DFN		; Display field
	CALL	RVSOFF		; Turn it off
	RET
;---
; Select entire form
;---
SFRM	CALL	RVSON		; Turn it on
	CALL	DFRM		; Display form
	CALL	RVSOFF		; Turn it off
	RET
;---
; Display field number
;---
DFN	CALL	FFN		; Find field
	JP	DFIELD		; Display it
;---
; Find field number
;---
FFN	PUSH	HL		; Save address
	INC	B		; Just in case
	LD	A,(HL)		; Get byte
	CP	0FEH		; Is it comment?
	JR	Z,FFN1		; Skip if so
	DEC	B		; Not needed
	INC	HL		; Past X, Y
	INC	HL
	LD	A,(HL)		; Get type
	INC	HL		; Next byte
	CP	7		; Is it title or above?
	JR	C,FFN00		; If so, ahead
	INC	HL		; Past number
	JR	Z,FFN00		; Ahead if comment
	DEC	B		; Back one (compensation)
FFN00	INC	B		; Ahead one
FFN1	LD	A,(HL)		; Get byte
	INC	HL
	OR	A
	JR	NZ,FFN1		; Loop until next
	DEC	B		; Is it this one?
	JR	Z,FFN2		; Ahead if so
	EX	(SP),HL		; Destroy address
	POP	HL
	JR	FFN		; Loop until done
FFN2	POP	HL		; Restore HL
	RET
;---
; Beep and display menu
;---
DMENUB	CALL	CURSOFF		; Turn cursor off
	LD	B,00001010B	; Medium tone, one second
	SVC	@SOUND		; Play sound
; Fall into display menu
;---
; Display menu
; HL => menu
; A <= entry selected (0 if BREAK)
;---
DMENU:	LD	A,2
	LD	(HKEYB),A
	CALL	CURSOFF		; Turn cursor off
	INC	HL		; Next byte
	PUSH	HL
	CALL	DFRM		; Display it
	POP	HL		; Restore and save
	PUSH	HL
	DEC	HL
	LD	B,(HL)		; Put old in B
	LD	C,B		; Store new in C
MENU1	POP	HL		; Restore and save address
	RPUSH	HL,BC
	CALL	DFN		; Display old name
	RPOP	BC,HL		; Restore BC
	PUSH	HL
	LD	B,C		; Put new in old
	PUSH	BC		; Save BC
	CALL	SFN		; Highlight name
	CALL	DSCRN		; Display screen
MENU2	CALL	MSKEY		; Get keystroke
	POP	BC		; Restore BC
;	OR	A		; Ahead if mouse
;	JP	Z,MENUM
	CP	8		; Left arrow
	JR	Z,MENUU
	CP	11		; Up arrow
	JR	Z,MENUU
	CP	9		; Right arrow
	JR	Z,MENUD
	CP	10		; Down arrow
	JR	Z,MENUD
	CP	32		; SPACEBAR
	JR	Z,MENUS
	POP	HL
	CP	13		; <ENTER>
	JR	Z,MENENT
	CP	128		; <BREAK>
	JR	Z,MENBRK
; Uppercase the key
MENU4	CP	'a'		; Check for lowercase
	JR	C,MENNL		; None
	CP	'z'+1		; Check for lowercase
	JR	NC,MENNL	; None
	SUB	32		; Make lowercase
MENNL	LD	D,A		; Store in D
	LD	A,(FCOUNT)	; Maximum field
; See if key matches entry
	PUSH	BC		; Save BC
	LD	B,A		; Put maximum in B
MENFN	RPUSH	HL,BC		; Save address and count
	CALL	FFN		; Find correct field
	INC	HL		; Past X
	INC	HL		; Past Y
	INC	HL		; Past type
	LD	A,(HL)		;  to number
	RPOP	BC,HL		; Restore address and count
	CP	D		; Is it same?
	JR	Z,MENFNS	; Success if so
	DEC	B		; Back one
	JR	NZ,MENFN	; Loop if not done
	POP	BC		; Restore BC
	JR	MENU5		; Loop if no number
; Return with correct number
MENFNS	LD	A,B		; Result in A
	POP	BC		; Restore BC
	LD	C,A		; Put in C
MENUX	RPUSH	AF,HL,BC	; Save value
	CALL	DFN		; Display old name
	RPOP	BC,HL		; Restore BC
	LD	B,C		; Put new in old
	CALL	SFN		; Highlight name
	CALL	DSCRN		; Display screen
	CALL	CBL		; Clear comment line
	POP	AF		; Restore value
	RET
MENU5	PUSH	HL		; Save HL
	JR	MENU1		; Loop for key
; Arrow keys
MENUU	LD	A,C		; Is it too low?
	CP	1
	JR	Z,MENU3		; Loop if too low
	DEC	C		; Otherwise, back one
	JR	MENU1		; Loop
MENUD	LD	A,(FCOUNT)	; Field count
	CP	C		; Is it too high?
	JR	Z,MENU3		; Loop if too high
	INC	C		; Otherwise, ahead one
	JP	MENU1		; Loop
MENUS	LD	A,(FCOUNT)	; Field count
	INC	A
	INC	C		; Ahead one
	CP	C		; Is it too high?
	JP	NZ,MENU1	; If not, loop
	LD	C,1		; Otherwise, reset counter
	JP	MENU1		; Loop
MENU3	PUSH	BC		; Save BC
	JP	MENU2
; <ENTER> and <BREAK>
MENENT	LD	A,C		; Correct value
	JR	MENUX
MENBRK	XOR	A		; Signal error
	JR	MENUX
;---
; DMENU mouse handler
;---
;MENUM	POP	HL		; Restore HL
;	RPUSH	BC,HL
;	CALL	SFRM		; Mark entire form
;	LD	B,1		; Get mouse pointer
;	SVC	@MOUSE
;	LD	B,E
;	LD	C,L
;	CALL	CXY		; Convert to address
;	BIT	7,(HL)		; See if reverse
;	JR	Z,MENUMF	; Ahead if not
;MENUM1	DEC	HL
;	BIT	7,(HL)		; See if reverse
;	JR	NZ,MENUM1	; Loop until not
;	INC	HL
;	LD	A,(HL)		; Get byte
;	AND	01111111B	; Make not reverse
;	POP	HL
;	RPUSH	HL,AF
;	CALL	DFRM		; Display form
;	RPOP	AF,HL,BC
; HL SHOULD NOT BE ON STACK
;	JP	MENU4		; Loop until done
;MENUMF	POP	HL
;	PUSH	HL
;	CALL	DFRM		; Display form
;	RPOP	HL,BC
;	PUSH	HL
; HL SHOULD BE ON STACK
;	JP	MENU1		; Loop until done
;=====
; X, Y and address conversion routines
;=====
;---
; Convert X, Y to address and increment
; BC' => X, Y
; HL <= address
;---
CXYI	CALL	CXYA		; Compute address
	EXX			; Switch registers
	INC	C		; Advance X
	LD	A,C		; Is it past?
	CP	COL
	JR	NZ,CXYI1
	LD	C,0		; If so, zero X
	INC	B		; Increment Y
	LD	A,B
	CP	ROW-3		; Is it past?
	JR	NZ,CXYI1
	DEC	B		; If so, back to before
	LD	C,COL-1
CXYI1	EXX			; Switch back
	RET
;---
; Convert X, Y to address
; BC' => X, Y
; HL <= address
; no registers destroyed
;---
CXYA	EXX			; Switch registers
	PUSH	HL		; Save HL
	CALL	CXY		; Convert to address
	EX	(SP),HL		; Switch HL' with old
	EXX
	POP	HL		; Restore value
	RET
;---
; Convert X, Y to address
; BC => Y, X
; HL <= address
; no registers destroyed
;---
CXY	PUSH	DE		; Save DE
	XOR	A		; Zero A
	LD	H,A		; Zero bytes
	LD	D,A
	LD	L,B		; X, Y
	LD	E,C
	ADD	HL,HL		; * 2
	ADD	HL,HL		; * 4
	ADD	HL,HL		; * 8
	ADD	HL,HL		; * 16
	PUSH	HL		; Save * 16
	ADD	HL,HL		; * 32
	ADD	HL,HL		; * 64
	ADD	HL,DE		; + X
	POP	DE		; Previous * 16
	ADD	HL,DE		; * 80 + X
	LD	DE,SCRN		; Screen start
	ADD	HL,DE
	POP	DE		; Restore DE
	RET
;---
; Convert address to X, Y
; HL => address
; BC <= Y, X
;---
CADXY	RPUSH	HL,DE		; Save registers
	LD	DE,SCRN		; Screen start
	OR	A
	SBC	HL,DE		; Subtract start
	LD	DE,COL		; Width of column
	LD	B,0FFH		; Zero Y
CADXY1	INC	B		; Increment Y
	OR	A
	SBC	HL,DE		; Subtract column
	JR	NC,CADXY1
	ADD	HL,DE		; Correct
	LD	C,L		; Store X
	RPOP	DE,HL		; Restore registers
	RET
