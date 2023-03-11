;========================================================
;  EQUATES/ASM: a list of useful equates for the Model 4
;========================================================
*LIST OFF
;
SVC		MACRO	#NUM
		LD	A,#NUM
		RST	28H
		ENDM
;
@IPL		EQU	00H	; re-boot system
@KEY		EQU	01H	; wait for key press
@DSP		EQU	02H	; display character
@GET		EQU	03H	; get byte from device
@PUT		EQU	04H	; write byte to device
@CTL		EQU	05H	; make control request
@PRT		EQU	06H	; send character to printer
@WHERE		EQU	07H	; locate origin of CALL
@KBD		EQU	08H	; scan keyboard
@KEYIN		EQU	09H	; accept line of input
@DSPLY		EQU	0AH	; display message line
@LOGER		EQU	0BH	; log message
@LOGOT		EQU	0CH	; display and log message
@MSG		EQU	0DH	; message line handler
@PRINT		EQU	0EH	; print message line
@VDCTL		EQU	0FH	; control video display
@PAUSE		EQU	10H	; wait for delay
@PARAM		EQU	11H	; parse parameters
@DATE		EQU	12H	; get system date
@TIME		EQU	13H	; get system time
@CHNIO		EQU	14H	; pass control downstream
@ABORT		EQU	15H	; abort program execution
@EXIT		EQU	16H	; return to LS-DOS
@CMNDI		EQU	18H	; execute command
@CMNDR		EQU	19H	; execute command, return
@ERROR		EQU	1AH	; post error message
@DEBUG		EQU	1BH	; enter DEBUG
@CKTSK		EQU	1CH	; check task slot
@ADTSK		EQU	1DH	; add task
@RMTSK		EQU	1EH	; remove task
@RPTSK		EQU	1FH	; replace task
@KLTSK		EQU	20H	; remove current task
@CKDRV		EQU	21H	; check drive availability
@DODIR		EQU	22H	; do a directory
@RAMDIR		EQU	23H	; get directory records
@DCSTAT		EQU	28H	; test if drive assigned
@SLCT		EQU	29H	; select new drive
@DCINIT		EQU	2AH	; initialize FDC
@DCRES		EQU	2BH	; reset FDC
@RSTOR		EQU	2CH	; issue FDC RESTORE
@STEPI		EQU	2DH	; issue FDC STEP IN
@SEEK		EQU	2EH	; seek a cylinder
@RSLCT		EQU	2FH	; test drive for busy-ness
@RDHDR		EQU	30H	; read sector header
@RDSEC		EQU	31H	; read sector
@VRSEC		EQU	32H	; verify sector
@RDTRK		EQU	33H	; read track
@HDFMT		EQU	34H	; hard disk format
@WRSEC		EQU	35H	; write sector
@WRSSC		EQU	36H	; write system sector
@WRTRK		EQU	37H	; write track
@RENAM		EQU	38H	; rename file
@REMOV		EQU	39H	; remove file or device
@INIT		EQU	3AH	; open new or existing file
@OPEN		EQU	3BH	; open existing file
@CLOSE		EQU	3CH	; close file
@BKSP		EQU	3DH	; backspace one log. rec.
@CKEOF		EQU	3EH	; check for end-of-file
@LOC		EQU	3FH	; calculate LRN
@LOF		EQU	40H	; calculate EOF LRN
@PEOF		EQU	41H	; position to EOF
@POSN		EQU	42H	; position file to LRN
@READ		EQU	43H	; read record from file
@REW		EQU	44H	; rewind file to beginning
@RREAD		EQU	45H	; re-read current sector
@RWRIT		EQU	46H	; re-write current sector
@SEEKSC		EQU	47H	; seek specified sector
@SKIP		EQU	48H	; skip next record
@VER		EQU	49H	; write and verify record
@WEOF		EQU	4AH	; write EOF
@WRITE		EQU	4BH	; write record to file
@LOAD		EQU	4CH	; load program file
@RUN		EQU	4DH	; run program file
@FSPEC		EQU	4EH	; parse filename
@FEXT		EQU	4FH	; set up default extension
@FNAME		EQU	50H	; get filename/extension
@GTDCT		EQU	51H	; get drive code table
@GTDCB		EQU	52H	; get device control block
@GTMOD		EQU	53H	; find module in memory
@RDSSC		EQU	55H	; read system sector
@DIRRD		EQU	57H	; read directory record
@DIRWR		EQU	58H	; write directory record
@MUL8		EQU	5AH	; multiply 8 by 8
@MUL16		EQU	5BH	; multiply 16 by 8
@DIV8		EQU	5DH	; divide 8 by 8
@DIV16		EQU	5EH	; divide 16 by 8
@HEXD		EQU	5FH	; hex to decimal ASCII
@DECHEX		EQU	60H	; decimal ASCII to hex
@HEXDEC		EQU	61H	; hex to decimal ASCII
@HEX8		EQU	62H	; 1-byte to hex
@HEX16		EQU	63H	; 2-byte to hex
@HIGH$		EQU	64H	; get or set HIGH$
@FLAGS$		EQU	65H	; get system flags
@BANK		EQU	66H	; memory banking
@BREAK		EQU	67H	; get or set <BREAK> vector
@SOUND		EQU	68H	; beep through speaker
@VDCLS		EQU	69H	; clear video screen
@CKBRKC		EQU	6AH	; check and reset <BREAK>
@VDPRT		EQU	6BH	; screen print
@EXMEM		EQU	6CH	; extended memory control
@MOUSE		EQU	78H	; mouse control
@WAM		EQU	7CH	; PRO-WAM
@PEXMEM		EQU	7DH	; extended memory control
;
ETX		EQU	3	; soft end of line
LF		EQU	10	; line-feed
CR		EQU	13	; hard end of line
;
VAL		EQU	80H	; @PARAM switches
SW		EQU	40H
STR		EQU	20H
ABR		EQU	10H
;
*LIST ON
