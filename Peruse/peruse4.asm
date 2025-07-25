;==
; Model 4 assembly file
; March 23, 1995
;==
	COM	'<Copyright (c) 1997 by Matthew Reed, all rights reserved>'
*GET EQUATES
TRUE	EQU	-1
FALSE	EQU	0
LDOS	EQU	FALSE
TRSDOS	EQU	FALSE
MOD4	EQU	TRUE
MOD3	EQU	FALSE
; Model 4 specific equates
RVIDEO	EQU	TRUE		; Reverse video
XMAX	EQU	80		; 80 wide
YMAX	EQU	24		; 24 deep
XFILES	EQU	2		; 2 files wide
LONGHEX	EQU	TRUE
CHKMRK	EQU	'*'		; Asterisk
; Keyboard equates
KLEFT	EQU	8
KRIGHT	EQU	9
KUP	EQU	11
KDOWN	EQU	10
KENTER	EQU	0DH
KSPACE	EQU	32
KBREAK	EQU	128
KSUP	EQU	27
KSDOWN	EQU	26
KCUP	EQU	139
KCDOWN	EQU	138
KCTLV	EQU	22
KCTLC	EQU	3
KCTLS	EQU	19
KCTLR	EQU	18
	ORG	2700H		; Acceptable start
STACK	EQU	$
;--
; Turn passwords off
;--
PASSOFF:
	RET
;--
; Exit routine
;--
EXIT:	LD	BC,8<8+'_'	; Restore old cursor
OLDCURS	EQU	$-2
	SVC	@FLAGS$
	LD	A,(IY+'N'-'A')
	AND	01111111B	; Mask out bit 7
	OR	0		; Old state of network flag
NFLAG	EQU	$-1
	LD	(IY+'N'-'A'),A
	SVC	@CLS
	SVC	@CKBRKC		; Toggle BREAK bit
	LD	HL,0		; No error
	SVC	@EXIT
;--
; Start program
;--
START:	LD	SP,STACK	; New stack
	LD	BC,8<8+'_'	; Set cursor to underline
	SVC	@VDCTL
	LD	(OLDCURS),A	; Store old cursor
	SVC	@FLAGS$
	LD	A,(IY+'N'-'A')
	AND	10000000B	; Save only network bit
	SET	7,(IY+'N'-'A')
	LD	(NFLAG),A
; Onto main program
*GET PRDIR
