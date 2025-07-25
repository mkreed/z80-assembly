;=====================================
; DATA-MINDER database manager
; copyright (c) 1995, by Matthew Reed
; all rights reserved
; DMDISK/ASM, disk I/O routines
;=====================================
VERSION	EQU	10H		; Version of disk format
;=====
; Low level disk routines
;=====
;---
; Move specification
;---
FSPEC	SVC	@FSPEC
	RET	NZ		; Return if error
	LD	A,(DE)		; See if device
	XOR	'*'
	JR	Z,FSPE
	XOR	A
	RET
FSPE	OR	19		; Illegal filename
	RET
;---
; Open main disk file
; HL => filename
; Z <= reset if error, error in A
;---
DOPEN	PUSH	DE		; Save DE
	LD	DE,FCB1		; FCB # 1
	CALL	FSPEC		; Move into FCB
	POP	DE		; Restore DE
	LD	A,19		; "Illegal file name"
	RET	NZ		; Return if error
	LD	B,0		; LRL = 256
	LD	HL,WBUFF	; Disk write buffer
	LD	A,@OPEN		; Open file
	CALL	DSVC
	RET	NZ
	LD	A,(FCB1+6)	; Get drive
	LD	C,A
	SVC	@CKDRV		; See if write-protected
	RET	NC
	LD	A,15		; Write-protected error
	OR	A
	RET
;---
; Initialize main disk file
;---
DINIT	LD	B,0		; LRL = 256
	LD	HL,WBUFF	; Disk write buffer
	LD	A,@INIT		; Initialize
	JR	DSVC
;---
; Close main disk file
; Z <= reset if error
;---
DCLOSE	CALL	FREC0		; Flush record 0
	LD	A,@CLOSE	; Close file
	JR	DSVC
;---
; Remove current file
;---
DREMOVE	LD	A,@REMOV	; Remove file
	JR	DSVC
;---
; Read four record of main file
; Z <= reset if error
;---
DREAD	RPUSH	BC,DE,HL	; Save registers
	LD	DE,FCB1		; First FCB
	LD	HL,4		; MSB of buffer
	ADD	HL,DE
	LD	B,4		; 4 record (1024 bytes)
$DR0	SVC	@READ		; Read sector
	JR	NZ,$DR1		; Ahead if error
	INC	(HL)		; Next memory page
	DJNZ	$DR0		; Loop until done
$DR1	LD	(HL),.HIGH.WBUFF
				; Reset buffer pointer
	RPOP	HL,DE,BC	; Restore registers
	OR	A		; Make no error (or error)
	RET
;---
; Write four records of main file
; Z <= reset if error
;---
DWRITE	RPUSH	BC,DE,HL	; Save registers
	LD	DE,FCB1		; First FCB
	LD	HL,4		; MSB of buffer
	ADD	HL,DE
	LD	B,4		; 4 records (1024 bytes)
$DW0	SVC	@WRITE		; Write record
	JR	NZ,$DW1		; Ahead if error
	INC	(HL)		; Next memory page
	DJNZ	$DW0		; Loop until done
$DW1	LD	(HL),.HIGH.WBUFF
				; Reset buffer pointer
	RPOP	HL,DE,BC	; Restore registers
; See if nothing written
	CP	15		; Write protected disk
	JR	Z,$DWERR
	CP	37		; Illegal access to protected file
	JR	Z,$DWERR
	OR	A		; Make no error (or error)
	RET
; Nullify buffer in memory
$DWERR	RPUSH	HL,AF		; Save registers
	LD	HL,0FFFFH	; Make record into nothing
	LD	(WREC),HL
	XOR	A		; Make buffer not dirty
	LD	(WDIRT),A
	LD	HL,(FFBLK)	; First free block
	DEC	HL
	LD	A,H
	OR	L
	JR	Z,$DWE1
	LD	(FFBLK),HL	; Store first free block
$DWE1	RPOP	AF,HL		; Restore registers
	OR	A		; Make error
	RET
;---
; Position to record
; BC => record number
; Z <= reset if error
;---
DPOSN	LD	(WREC),BC	; Store record number
DPOSN1	LD	A,@POSN		; Position to record
DSVC	RPUSH	DE,HL		; Save registers
	LD	DE,FCB1		; FCB # 1
	RST	28H		; SVC
	RPOP	HL,DE		; Restore registers
	CP	42		; "LRL open fault"
	JR	Z,$DSVC1	; Ahead if error
	CP	28		; "End of file encountered"
	JR	Z,$DSVC1
	OR	A
	RET
$DSVC1	XOR	A		; No error
	RET
;=====
; Higher-level disk routines
;=====
;---
; Move filename to DE
;---
DMFDE	PUSH	BC
	LD	BC,(FCB1+6)	; Get DEC and drive
	SVC	@FNAME		; Move filename to buffer
	POP	BC
	RET
;---
; Open file and verify integrity
; HL => filename
; Z <= reset if error
; A <= 255 if not a DATA-MINDER file
; A <= 254 if not correct version of file
;---
DOPNV:	CALL	CLEARV		; Clear variables
	CALL	DOPEN		; Open file
	RET	NZ		; Return if error
	CALL	DREAD		; Read header
	JR	NZ,$DOPV1	; Check type of error
	LD	HL,WBUFF	; Move header to buffer
	LD	DE,HEADER
	LD	BC,256
	LDIR			; Move
	LD	HL,HEADER	; Header record
	LD	A,(HL)		; Is it "D"?
	INC	HL
	CP	'D'+128
	JR	NZ,$DOERR1	; Ahead if not
	LD	A,(HL)		; Is it "M"?
	INC	HL
	CP	'M'+128
	JR	NZ,$DOERR1
	LD	A,(HL)		; Is it "4"?
	INC	HL
	CP	'4'+128
	JR	NZ,$DOERR1
	LD	A,VERSION	; Current disk format version
	CP	(HL)		; Disk file version number
	JR	C,$DOERR2	; Ahead if later
	XOR	A		; Signal no error
	RET
$DOERR1	LD	A,255		; Signal not DM4
	OR	A
	RET
$DOERR2	LD	A,254		; Signal not correct version
	OR	A
	RET
$DOPV1:	CP	29		; Record out of range
	RET	NZ
	LD	A,255		; Not DM4
	OR	A
	RET
;---
; Create a new file
;---
DINITV	CALL	CLEARV		; Clear variables
	CALL	DINIT		; Initialize file
	RET	NZ
; Generate file header
	CALL	BUFFCLR		; Clear buffer
	LD	DE,DSCAN	; Disk buffer
	LD	HL,FHEAD	; File header
	LD	BC,FHEADC	; Count
	LDIR
	EX	DE,HL
	LD	L,81H		; Mark block in use
	LD	(HL),80H
; Move to buffer
	LD	L,0		; Move header to buffer
	LD	DE,HEADER
	LD	BC,256
	LDIR			; Move
; Save to disk
	LD	A,.HIGH.DSCAN
	LD	(FCB1+4),A
	CALL	DWRITE		; Write records
	RET
; Buffer clear
BUFFCLR	LD	HL,DSCAN	; Disk scan buffer
	LD	(HL),0
	LD	DE,DSCAN+1
	LD	BC,1023		; 1 K
	LDIR			; Clear buffer
	RET
; Clear variables
CLEARV	PUSH	HL
	LD	HL,0FFFFH	; Store invalid record number
	LD	(WREC),HL
	LD	(DSREC),HL
	LD	A,H
	LD	(APAGE),A	; Current page
	POP	HL
	XOR	A
	LD	(WDIRT),A	; Buffer is not dirty
	RET
;--
; Swap FCB1 with FCB2
;--
SWAPFCB	RPUSH	HL,DE,BC	; Save registers
; Exchange FCBs
	LD	HL,FCB1		; Swap FCB1 with FCB2
	LD	DE,FCB2
	LD	BC,35
	CALL	SWP1		; Swap the two
; Exchange form information
	LD	HL,FMBLK	; Start
	LD	DE,AFMBLK	; Alternate structure
	LD	BC,12
	CALL	SWP1		; Swap the two
; Exchange file header
	LD	HL,HEADER
	LD	DE,AHEADER
	LD	BC,256
	CALL	SWP1		; Swap the headers
	LD	HL,SCRN1	; Swap data pages
	LD	DE,DSCAN
	LD	BC,2048
	CALL	SWP1		; Transfer
	RPOP	BC,DE,HL
	RET
; Swap routine
SWP1	LD	A,(DE)		; Save value
	EX	AF,AF'
	LD	A,(HL)
	EX	AF,AF'
	LD	(HL),A		; Store in HL
	EX	AF,AF'
	LD	(DE),A
	INC	HL
	INC	DE
	DEC	BC		; See if end
	LD	A,B
	OR	C
	JR	NZ,SWP1		; Loop until done
	RET
;---
; Find screen form
; A => form number
; BC <= screen form block
;---
DFSF	LD	HL,HEADER+8	; Record 0 buffer
	ADD	A,A		; Double number
	ADD	A,L		; Find correct position
	LD	L,A		; Put back in L
	LD	C,(HL)		; Get block number
	INC	L
	LD	B,(HL)
	XOR	A
	RET
;---
; Read block number for writing purposes
;---
DRBLKW	CALL	DRBLK		; Read block
	PUSH	AF
	LD	A,1		; Write buffer is dirty
	LD	(WDIRT),A
	POP	AF
	RET
;---
; Read block number
; BC => block number
; Z <= reset if error
; HL <= address of block
;---
DRBLK:	RES	7,B		; Eliminate possible bit
	SRL	B		; Divide by two
	RR	C
	LD	L,0		; Generate proper low order
	RR	L
	LD	A,C		; Mask out upper bits
	AND	00000011B
	LD	H,A		; Store in H
	PUSH	HL		; Save HL
	LD	A,C		; Mask out lower bits
	AND	11111100B
	LD	C,A
; See if already loaded
	LD	HL,(WREC)	; Records in buffer
	LD	A,C		; See if same
	CP	L
	JR	NZ,$DRBL2	; Ahead if not
	LD	A,B
	CP	H		; Compare
	JR	NZ,$DRBL2	; Ahead if not same
; Is already loaded
$DRBL0	LD	A,.HIGH.WBUFF	; Disk write buffer
	POP	HL		; Restore data
	ADD	A,H		; Make correct MSB
	LD	H,A		; Put in H
	XOR	A		; No error
	RET
; Is not loaded
$DRBL2	LD	A,(WDIRT)	; See if dirty
	OR	A
	CALL	NZ,DWFLUSH	; Flush write buffer
	JR	NZ,$DRBERR	; Ahead if error
	CALL	DPOSN		; Position to record
	JR	NZ,$DRBERR	; Ahead if error
	CALL	DREAD		; Read records
	JR	Z,$DRBL0	; Loop if not error
$DRBERR	POP	HL		; Restore stack
	RET			; Return
;---
; Read next block
; HL => address in block
; Z <= reset if error, A <= 0 if no more blocks
; HL <= address of block
; BC <= destroyed
;---
DRNBLK	LD	A,L		; Go to next block number
	AND	10000000B
	LD	L,A
	LD	C,(HL)		; Put in BC
	INC	L
	LD	B,(HL)
	RES	7,B
	LD	A,B		; See if zero
	OR	C
	JR	NZ,DRBLK	; Read block if not
	OR	H		; Otherwise, signal
	LD	A,C		; no more blocks
	RET
;---
; Read data into memory
; BC => starting block
; DE => buffer to write to
; Z <= reset if error
;---
DRDATA	CALL	DRBLK		; Read first block
	RET	NZ
$DRB11	INC	L		; Past word
	INC	L
	LD	BC,126		; Bytes to transfer
$DRB12	LDIR			; Transfer
	DEC	HL
	CALL	DRNBLK		; Read next block
	JR	Z,$DRB11	; Loop until done
	OR	A		; Is it end of blocks?
	RET			; Return (even if not)
;---
; Read first page of form
; DE => data area
; BC => block number
; DE is not preserved
;---
DRFORM:	LD	(FMBLK),BC	; Store block number
	CALL	DRBLK		; Read first block
	RET	NZ
	INC	L		; Past word
	INC	L
	PUSH	DE		; Save DE
	LD	DE,PVPAGE	; Start of structure
	LD	BC,8		; Bytes to transfer
	LDIR
	POP	DE		; Restore DE
	LD	BC,118		; Bytes to transfer
	JR	$DRB12		; Jump back
;---
; Read subsequent page of form
; DE => data area
; BC => block number
; DE is not preserved
;---
DRPAGE	LD	(FMBLK),BC	; Store block number
	CALL	DRBLK		; Read first block
	RET	NZ
	INC	L		; Past word
	INC	L
	PUSH	DE		; Save DE
	LD	DE,PVPAGE	; Start of structure
	LD	BC,4		; Bytes to transfer
	LDIR
	POP	DE		; Restore DE
	LD	BC,122		; Bytes to transfer
	JR	$DRB12		; Jump back
;---
; Write subsequent page of form (old blocks)
;---
DWPAGEO	LD	(SBLOCK),BC	; Store starting block
	CALL	DRBLKW		; Read block
	RET	NZ		; Ahead if error
	PUSH	HL		; Save address
	LD	BC,6
	ADD	HL,BC		; Move past header
	EX	DE,HL		; Switch registers
	LD	HL,(DSTART)	; Start of data
	LD	BC,122
	JR	$DWO0
;***
;---
; Write first page of form (old blocks)
; (DSTART) => start of data to write
; (DEND) => end of data to write
; BC => old block number
;---
DWFORMO	LD	(SBLOCK),BC	; Store starting block
	CALL	DRBLKW		; Read block
	RET	NZ		; Ahead if error
	PUSH	HL		; Save address
	LD	BC,10
	ADD	HL,BC		; Move past header
	EX	DE,HL		; Switch registers
	LD	HL,(DSTART)	; Start of data
	LD	BC,118
; HL => data, DE => disk buffer
$DWO0	LDIR			; Transfer
	EX	(SP),HL
	LD	C,(HL)
	INC	HL
	SET	7,(HL)		; Mark in use
	LD	B,(HL)
	DEC	HL
	EX	(SP),HL
	RES	7,B		; Eliminate in use bit
	LD	($NXTBW),BC	; Move "next block" into buffer
	LD	DE,(DEND)	; End of data
	PUSH	HL		; Save data area
	OR	A
	SBC	HL,DE
	PUSH	HL		; Move count
	POP	BC		; to BC
	POP	HL		; Restore
; HL => data
	POP	DE		; Restore DE
	JR	NC,$DWO1	; Ahead if self-contained
	LD	BC,($NXTBW)	; See if nothing
	LD	A,B
	OR	C
	JP	Z,$DRT000	; Jump into new if no space
; Now move to next block
	EX	DE,HL
; DE => data, HL => disk buffer
$DWDO1	CALL	DRBLKW		; Read next block
	RET	NZ		; Ahead if error
	PUSH	HL
	EX	DE,HL
	INC	DE		; Past "next block"
	INC	DE
	LD	BC,126		; Fill buffer
	JR	$DWO0
; End of file
$DWO1	LD	A,C
	OR	A
	JR	Z,$DWO9		; Ahead if zero
	PUSH	DE		; Save address
	LD	A,E
	XOR	10000000B
	LD	E,A
	XOR	A
$DWO8	DEC	E
	LD	(DE),A		; Zero buffer
	DEC	C
	JR	NZ,$DWO8
	POP	DE
$DWO9	EX	DE,HL
	XOR	A		; End the chain
	LD	(HL),A
	INC	HL
	LD	(HL),A
	SET	7,(HL)		; Signal in use
	EX	DE,HL
; Remove space allocated to later blocks
$DW004	LD	BC,$-$		; See if no later blocks
$NXTBW	EQU	$-2
	CALL	DWDEL		; Delete blocks
	JP	DWFLUSH		; Flush buffer
; Delete blocks
DWDEL	LD	A,B
	OR	C
	RET	Z
	LD	HL,(FFBLK)	; First free block
	OR	A
	SBC	HL,BC		; Subtract
	JR	C,$DWDEL1	; Ahead if greater
	LD	(FFBLK),BC	; Store free block number
$DWDEL1	CALL	DRBLKW		; Read block
	PUSH	AF
	LD	C,(HL)		; Put block number
	INC	HL
; Mark as not in use
	RES	7,(HL)
	LD	B,(HL)		; into "$NXTBW"
	LD	($NXTBW),BC	; Move "next block" into buffer
	POP	AF
	RET	NZ
	JR	DWDEL		; Loop until done
;---
; Write data to disk (old blocks)
;---
DWDATAO	LD	(SBLOCK),BC	; Store starting block
	LD	DE,(DSTART)	; Start of data
	JR	$DWDO1
;---
; Write data to disk
;---
DWDATA	LD	(SBLOCK),BC	; Store starting block
	LD	DE,(DSTART)	; Start of data
	JR	$DWDN1
;---
; Write subsequent page of form (new blocks)
;---
DWPAGE	LD	(SBLOCK),BC	; Store starting block
	CALL	DRBLKW		; Read block
	RET	NZ
	PUSH	HL
	EX	DE,HL		; Switch registers
	LD	HL,NXTBLK	; Next block
	LD	BC,6
	LDIR			; Transfer header
	LD	HL,(DSTART)	; Data to transfer
	LD	BC,122		; Fill buffer
	JR	$DRT0
;---
; Write first page of form (new blocks)
; (DSTART) => start of data to write
; (DEND) => end of data to write
; BC => block number
;---
DWFORM	LD	(SBLOCK),BC	; Store starting block
	CALL	DRBLKW		; Read block
	RET	NZ
	PUSH	HL
	EX	DE,HL		; Switch registers
	LD	HL,NXTBLK	; Next block
	LD	BC,10
	LDIR			; Transfer header
	LD	HL,$-$		; Data to transfer
DSTART	EQU	$-2
	LD	BC,118		; Fill buffer
$DRT0	LDIR
	LD	DE,$-$
DEND	EQU	$-2
	PUSH	HL		; Save data area
	OR	A
	SBC	HL,DE
	PUSH	HL		; Move count
	POP	BC		; to BC
	POP	HL		; Restore
	POP	DE		; Restore DE
	JR	NC,$DRT1	; Ahead if self-contained
$DRT000	CALL	DFREE		; Reserve more space
	JR	NZ,$DRT0E	; Ahead if error
; No error
	EX	DE,HL
	LD	(HL),C
	INC	HL
	LD	(HL),B
	SET	7,(HL)		; Signal in use
; Now write other blocks
$DWDN1	CALL	DRBLKW		; Read block
	RET	NZ
	PUSH	HL
	EX	DE,HL
	XOR	A
	LD	(DE),A
	INC	DE
	LD	A,80H		; Signal as in use
	LD	(DE),A
	INC	DE
	LD	BC,126		; Fill buffer
	JR	$DRT0
; Flush WBUFF buffer
$DRT1	LD	A,C
	OR	A
	JR	Z,$DRO9		; Ahead if zero
	PUSH	DE		; Save address
	LD	A,E
	XOR	10000000B
	LD	E,A
	XOR	A
$DRO8	DEC	E
	LD	(DE),A		; Zero buffer
	DEC	C
	JR	NZ,$DRO8
	POP	DE
$DRO9	CALL	DWFLUSH		; Flush buffer
	RET
; Disk error - possibly during extend
$DRT0E	PUSH	AF		; Save error
	CP	27		; Disk space full
	JR	Z,$DRT0DE
	CP	30		; Directory full - cannot extend file
	JR	Z,$DRT0DE
	POP	AF		; Restore A
	RET			; Return with error
; Error during extend
$DRT0DE	LD	(EXTENDE),A	; Store error
	LD	BC,(SBLOCK)	; Starting block
	CALL	DWDEL		; Delete blocks
	CALL	DWFLUSH		; Flush buffer
	POP	AF		; Restore error
	RET
;---
; Find first free block
; BC <= block
;---
DFREE	RPUSH	DE,HL		; Save registers
	LD	BC,(FFBLK)	; First free block
	PUSH	BC		; Save BC too
	SRL	B		; Divide by two
	RR	C
	LD	L,0		; Generate proper low order
	RR	L
	LD	A,C		; Mask out upper bits
	AND	00000011B
	LD	H,A		; Store in H
	PUSH	HL		; Save HL
	LD	A,C		; Mask out lower bits
	AND	11111100B
	LD	C,A
; See if already in write buffer
	LD	HL,(WREC)	; Records in write buffer
	LD	A,C		; See if same
	CP	L
	JR	NZ,$DFBL2	; Ahead if not
	LD	A,B
	CP	H		; Compare
	JR	NZ,$DFBL2	; Ahead if not same
; Records are in write buffer
	LD	A,.HIGH.WBUFF	; Look at write buffer
	JR	$DFBL00		; Jump ahead
; Is already loaded
$DFBL0	LD	A,.HIGH.DSCAN	; Disk scan buffer
$DFBL00	RPOP	HL,BC		; Restore data
	ADD	A,H		; Make correct MSB
	LD	H,A		; Put in H
; Now find free block
	INC	HL		; Next byte
	BIT	7,(HL)		; See if in use
	RPOP	HL,DE		; Restore registers
	RET	Z		; Return if not in use
; Block is in use
	INC	BC		; Next block
	LD	(FFBLK),BC	; Increase first free
	JR	DFREE		; Loop until done
; See if loaded in disk scan buffer
$DFBL2	LD	HL,(DSREC)	; Records in disk scan buffer
	LD	A,C		; See if same
	CP	L
	JR	NZ,$DFBL3	; Ahead if not
	LD	A,B
	CP	H		; Compare
	JR	Z,$DFBL0	; Jump back if same
; Not loaded in either one
$DFBL3	CALL	DPOSN1		; Position to record
	JR	NZ,$DFBERR	; Ahead if error
	LD	A,.HIGH.DSCAN	; Change buffer to read into
	LD	(FCB1+4),A
	LD	(DSREC),BC	; Store record number
; See if past end
	LD	HL,(FCB1+12)	; Get ending record number
	OR	A
	SBC	HL,BC		; See if same
	JR	NZ,$DFBL4	; Ahead if not
; Create new records
	CALL	BUFFCLR		; Clear buffer
	LD	HL,0FFFFH	; Eliminate record counter
	LD	(DSREC),HL
	LD	HL,(FCB1+12)	; Load ending record number
	CALL	DWRITE		; Write records
	JR	Z,$DFBL0	; Loop if no error
	LD	(FCB1+12),HL	; Restore old ending record number
	JR	$DFBERR		; Error
; Read old records
$DFBL4	CALL	DREAD		; Read records
	JR	Z,$DFBL0	; Loop if not error
$DFBERR	RPOP	HL,BC,HL,DE	; Restore stack
	RET			; Return
;---
; Flush record 0
;---
FREC0	RPUSH	BC,DE,HL
	LD	BC,0
	LD	DE,FCB1		; Write FCB
	SVC	@POSN
	JR	NZ,$FRE
	LD	A,.HIGH.HEADER
	LD	(FCB1+4),A
	SVC	@WRITE		; Write record
	PUSH	AF
	LD	A,.HIGH.WBUFF	; Restore
	LD	(FCB1+4),A
	POP	AF
$FRE	RPOP	HL,DE,BC
	RET
;---
; Flush WBUFF buffer
;---
DWFLUSH	RPUSH	BC,DE,HL	; Save registers
	LD	BC,(WREC)	; Record to write
	PUSH	BC
	LD	HL,(DSREC)	; Disk scan record
	OR	A
	SBC	HL,BC		; See if same
	JR	NZ,$DWF
	LD	HL,WBUFF	; Write buffer
	LD	DE,DSCAN	; Disk scan buffer
	LD	BC,1024
	LDIR			; Move to disk scan buffer
$DWF	POP	BC
	LD	A,(WDIRT)	; See if dirty
	OR	A
	JR	Z,$DWF1		; Ahead if not
	CALL	DPOSN
	RPOP	HL,DE,BC	; Restore registers
	RET	NZ
	CALL	DWRITE		; Write records
	RET	NZ
	XOR	A
	LD	(WDIRT),A	; Not "dirty"
	RET
$DWF1	RPOP	HL,DE,BC	; Restore registers
	RET
;---
; Delete form
; BC = block of form
;---
DDFORM	LD	A,B		; See if nothing
	OR	C
	RET	Z
	LD	A,B		; Return if bit 7 set
	XOR	10000000B
	AND	10000000B
	RET	Z
DDFORM1	PUSH	BC		; Save block
	CALL	DRBLK		; Read first block
	POP	BC
	RET	NZ
	INC	L		; Past word
	RES	7,(HL)		; Make deleted
	INC	L
	PUSH	BC
	LD	DE,PVPAGE	; Start of structure
	LD	BC,4		; Bytes to transfer
	LDIR
	POP	BC
	CALL	DWDEL		; Delete page
	RET	NZ
	LD	BC,(NXPAGE)	; Get next page
	LD	A,B		; See if last
	OR	C
	JR	NZ,DDFORM1	; Continue with deletion
	RET
;=============
; Data buffer
;=============
;===
; File header
;===
FHEAD	DB	'D'+128,'M'+128,'4'+128
	DB	VERSION
FHEADC	EQU	$-FHEAD
;===
; Form reading/writing structure
;===
FMBLK	DW	0		; Block to read from/write to
NXTBLK	DW	8000H		; Next block
PVPAGE	DW	0		; Previous page
NXPAGE	DW	0		; Next page
PVFORM	DW	0		; Previous form
NXFORM	DW	0		; Next form
; Alternate structure
AFMBLK	DW	0
ANXTBLK	DW	8000H
APVPAGE	DW	0
ANXPAGE	DW	0
APVFORM	DW	0
ANXFORM	DW	0
;
SBLOCK	DW	0		; Starting block
EXTENDE	DB	0		; Extend error
;===
; FCB
;===
FCB1	DS	32		; Main FCB
WREC	DW	0FFFFH		; Starting record in write buffer
WDIRT	DB	0		; WBUFF "dirty" value
FCB2	DS	32		; Secondary FCB (used for COPY)
WREC2	DW	0FFFFH		; Alternate record in write buffer
WDIRT2	DB	0		; Alternate "dirty" value
DSREC	DW	0FFFFH		; Starting record in disk scan
AHEADER	DS	256		; Alternate header
	ORG	$-1<-8+1<8
FFBLK	EQU	$+4
FRSTF	EQU	$+72
LSTF	EQU	$+74
ACTF	EQU	$+76
	ORG	$-1<-8+1<8
;
HEADER	DS	130		; Header
UKEYB	DB	0
	DS	125
DSCAN	DS	1024		; Disk scan buffer
WBUFF	DS	1024		; Buffer for writing
