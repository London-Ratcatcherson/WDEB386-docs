		PAGE ,150

PUBLIC SetCom

;----------------------------------------------------------------------------
;com192.asm - find all com ports and set them to 19200,n,8,1
;----------------------------------------------------------------------------
; author: percy tierney
;
; UART detection code derived from Robert L. Hummel's "UART Taxonomy",
; in PC Techniques, Oct 1993
;
; ml   /c /Fl /Fm /Sa /W3 com192.asm
; link com192 ,,, /TINY;
;
;----------------------------------------------------------------------------
;constants
;----------------------------------------------------------------------------

STDOUT			EQU     1			    ;CON stdout
TIMEOUT        EQU     3               ;seconds to try writing to port


;----------------------------------------------------------------------------
;BIOS segment (named BIOS_SEG)
;  com1 - 4 expected addresses stored here by BIOS
;----------------------------------------------------------------------------
BIOS_SEG       SEGMENT AT     0h
               ORG 0400h
Port0          dw             ?        ;COM0 port address stored here
               dw             ?
               dw             ?
               dw             ?
Par0           dw             ?        ;LPT0 port address stored here
               dw             ?
               dw             ?
BIOS_SEG       ENDS


;----------------------------------------------------------------------------
;CODE segment (named Start)
;----------------------------------------------------------------------------

Start          segment para public 'code'
assume         cs:Start, ds:Start, es:Start, ss:Start
               org 100h                ;COM programs start here

SetCom PROC							;begin SetCom PROCEDURE
		jmp		Intro   			    ;jump over data area


;----------------------------------------------------------------------------
;data area
;----------------------------------------------------------------------------

IntroMsg   	db	0dh,0ah
				db	"Com192 2.1 - "
				db	"Copyright 1993-1996 Microsoft Corp."
IntroCRLF		db	0dh,0ah
IntroEnd	    db	0

SerMsg 	    db  "  Com "
SerNum         db  "1:"
SerAdd         db  "    "
               db  "h "
SerIRQ         db  "set to "
SerBaud        db  "19200,n,8,1"
SerUART        db  " "
SerHex1        db  "                    "
SerHex2        db  "                       "
	 		    db	0dh,0ah
SerEnd	        db	0

SerBaud96      db  "9600,n,8,1 "
SerBaud96End   db  0
SerBaud48      db  "4800,n,8,1 "
SerBaud48End   db  0
SerBaud24      db  "2400,n,8,1 "
SerBaud24End   db  0
SerBaud00      db  "unchanged  "
SerBaud00End   db  0

HelpMsg        db  "  D - detect UART",0dh,0ah
               db  "  F - force standard COM1-4 BIOS addresses",0dh,0ah
               db  "  R - restore ",22h,"missing",22h," serial ports",0dh,0ah
               db  "  W - write to ports under Windows",0dh,0ah
               db  "  9 - set baud to 9600,n,8,1 (19200 is default)",0dh,0ah
               db  "  8 - set baud to 4800,n,8,1",0dh,0ah
               db  "  7 - set baud to 2400,n,8,1",0dh,0ah
               db  "  0 - do not change port settings",0dh,0ah
               db  "  1 2 3 or 4 - wait for CONNECT on COM1,2,3 or 4",0dh,0ah
               db  "  't' in output means port timed out before write",0dh,0ah
				db	0dh,0ah
HelpEnd	    db	0

BiosMsg 	    db	"BIOS Int 11h (Get Equipment List Service) lists "
SerCount       db  "0"
				db	" serial, "
ParCount       db  "0"
				db	" parallel ports."
				db	0dh,0ah
BiosEnd	    db	0

ParMsg 	    db  "  Lpt "
ParNum         db  "1:"
ParAdd         db  "    h"
	 		    db	0dh,0ah
ParEnd	        db	0

UMsg           db  ". Unknown.          "
UMsgEnd        db  ". 8250 or 8250-B.   "
               db  ". 8250A or 16450.   "
               db  ". 16550A (FIFO bug)."
               db  ". 16550AF or 16550C."
               db  ". 16552(dual 16550)."
               db  "                    "

BadPort        db	0dh,0ah
               db  "Requested connect port not present",0dh,0ah
BadPortEnd     db	0

ConnectMsg     db	0dh,0ah
               db  "Attempting to connect - press any key to cancel",0dh,0ah
ConnectMsgEnd  db	0

CompareUC      db  "CONNECT",0
CompareLC      db  "connect",0

SuccessMsg   	db	0dh,0ah
				db	"Connect established."
               db	0dh,0ah
SuccessEnd	    db	0

;assume 4 serial ports
;; SerPorts       dw  4
SerPorts       dw  1
;assume 3 parallel ports
ParPorts       dw  3
;running under Windows flag
uWin           dw  0

;UART base addresses
UARTBase       dw  3f8h,2f8h,3e8h,2e8h

;UART present - 1 for COM1 - 4 being detected
UARTpresent    db  0,0,0,0

;address of UART we are working on
UARTAddress    dw  ?

;return from UART_TYPE
UType          dw  6

;0 based current port number
uCurPort       dw  0

;command line switch table
bConnect1      db  "1"
bConnect2      db  "2"
bConnect3      db  "3"
bConnect4      db  "4"
b9600          db  "9"
b4800          db  "8"
b2400          db  "7"
b00            db  "0"
bWinwrite      db  "Ww"
bDetect        db  "Dd"
bForce         db  "Ff"
bRestart       db  "Rr"
bLastArg       db  0ffh


;----------------------------------------------------------------------------
;main code 
;----------------------------------------------------------------------------

   ;tell user who we are
   Intro:							    
       cld                             ;all str ops forward
		mov		ah,40h					;DOS WriteFile
		mov		bx,STDOUT				;write to stdout
		mov		cx,IntroEnd - IntroMsg
		mov		dx,OFFSET IntroMsg 	    ;string to write
		int		21h						;call DOS WriteFile

		mov		ah,40h					;DOS WriteFile
		mov		bx,STDOUT				;write to stdout
		mov		cx,HelpEnd - HelpMsg
		mov		dx,OFFSET HelpMsg 	    ;string to write
		int		21h						;call DOS WriteFile

       call    FindWindows
       mov     uWin,ax                 ;0 if no Win, 1 if Win

   ;BIOS int 11h:how many serial ports?
       int     11h                     ;Get Equipment List
       push    ax                      ;save the list
       mov     cl,9
       shr     ax,cl                   ;move bits 9-11 to 0-2
       and     ax,7                    ;mask all but bits 0-2
       mov     bx,offset SerCount      ;point to serial port in BIOS string
       add     [bx],al                 ;number of ports still in ax
       jz      LookforParallel         ;got com ports?

   LookforParallel:
       pop     ax                      ;fetch equip list
       mov     cl,14
       shr     ax,cl                   ;move bits 14-15 to 0-2
       and     ax,3                    ;mask all but bits 0-1
       mov     bx,offset ParCount      ;point to parallel port in BIOS string
       add     [bx],al                 ;number of ports still in ax

		mov		dx,OFFSET BiosMsg       ;string to write
		mov		cx,BiosEnd - BiosMsg

   PrintBiosPorts:
       mov		ah,40h					;DOS WriteFile
		mov		bx,STDOUT				;write to stdout
		int		21h						;call DOS WriteFile

   ;check out each port
       xor     cx,cx                   ;current port number (0)
       mov     uCurPort,cx             ;save this number
       call    Parse                   ;parse command line


   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ;LOOP through 4 com ports starts here
   GetPortAddress:
       mov     bx,uCurPort             ;next port to examine
       shl     bx,1                    ;multiply by 2 to get sizeof(WORD)

       mov     ax,BIOS_SEG             ;where com port address lives
       mov     ds,ax                   ;new DS is port address
   ASSUME      ds:BIOS_SEG             ;point to BIOS table

       mov     dl,cs:bForce            ;force address flag: yes > 0
       xor     dh,dh
       cmp     dh,dl                   ;force?
       jne     Patch                   ;yes, go write standard address in

   ;did we get a non-zero address?
       mov     dx,Port0[bx]            ;fetch port address
       cmp     dx,0                    ;is there a real address there?
       jne     CallN81                 ;yes, so skip over patching stuff

   ;restore BIOS port addresses
   ;only touch ports with 0 BIOS addresses
       mov     dl,cs:bRestart          ;patch request flag: yes > 0
       xor     dh,dh
       cmp     dh,dl                   ;patch?
       jne     Patch                   ;yes
       push    cs
       pop     ds                      ;point back to local data
       jmp     NextPort                ;done with this port

   Patch:
   ;force BIOS port addresses
   ;don't care what address is there, we're going to patch it (if asked)
       mov     dx,cs:UARTBase[bx]      ;get logical port address..
       mov     Port0[bx],dx            ;..patch into BIOS table

   CallN81:
       mov     ah,1
       shr     bx,1                    ;convert BX from WORD to BYTE
       mov     UARTpresent[bx],ah      ;mark this UART as being present
       mov     UARTAddress,dx          ;save address of current port
       call    HexDump                 ;dump current UART contents

   DetectUARTCheck:
       mov     ax,6                    ;default UART string
       mov     dx,UARTAddress          ;get UART base address
       mov     bl,cs:bDetect           ;detect request flag: yes > 0
       xor     bh,bh
       cmp     bh,bl                   ;detect?
       jz      NoDetect

       mov     bx,dx                   ;UART_TYPE wants port address in bx
       call    UART_TYPE               ;UART type returned in ax
       mov     cs:UType,ax             ;save UART type
       call    GetIRQ                  ;get IRQ for each port

   NoDetect:
       call    N81                     ;set port to 19200,n,8,1

       push    cs
       pop     ds                      ;point back to local data
   ASSUME      ds:cs

       ;put port address in string ( 1 dw to 4 db)
       mov     dx,UARTAddress          ;get address of current port
       mov     al,dh
       call    HextoAlph               
       mov     bx,offset SerAdd
       mov     [bx],ah
       inc     bx
       mov     [bx],al
       inc     bx
       mov     al,dl
       call    HextoAlph
       mov     [bx],ah
       inc     bx
       mov     [bx],al

       ;if 9600 baud flag set, change output string
       mov     bl,cs:b9600             ;9600 baud flag: yes > 0
       xor     bh,bh
       cmp     bh,bl                   
       jz      U48                     ;try 4800 baud

       ;copy baud rate string to output string..
       ;..(but we don't print it yet)
       mov		cx,SerBaud96End - SerBaud96 ;length of message

       ;set ds:si to source, es:di to dest for string move
       push    ds
       pop     es
       mov     si,offset SerBaud96     ;source
       mov     di,offset SerBaud       ;destination
       rep     movsb
       jmp     UString

   U48:
       ;if 4800 baud flag set, change output string
       mov     bl,cs:b4800             ;4800 baud flag: yes > 0
       xor     bh,bh
       cmp     bh,bl                   
       jz      U24                     ;try 2400 baud

       ;copy baud rate string to output string..
       ;..(but we don't print it yet)
       mov		cx,SerBaud48End - SerBaud48 ;length of message

       ;set ds:si to source, es:di to dest for string move
       push    ds
       pop     es
       mov     si,offset SerBaud48     ;source
       mov     di,offset SerBaud       ;destination
       rep     movsb
       jmp     UString

   U24:
       ;if 2400 baud flag set, change output string
       mov     bl,cs:b2400             ;2400 baud flag: yes > 0
       xor     bh,bh
       cmp     bh,bl                   
       jz      U00                     ;try no baud change

       ;copy baud rate string to output string..
       ;..(but we don't print it yet)
       mov		cx,SerBaud24End - SerBaud24 ;length of message

       ;set ds:si to source, es:di to dest for string move
       push    ds
       pop     es
       mov     si,offset SerBaud24     ;source
       mov     di,offset SerBaud       ;destination
       rep     movsb
       jmp     UString

   U00:
       ;if 00 baud flag set, change output string
       mov     bl,cs:b00               ;00 baud flag: yes > 0
       xor     bh,bh
       cmp     bh,bl                   
       jz      UString                 ;use 19200 baud

       ;copy baud rate string to output string..
       ;..(but we don't print it yet)
       mov		cx,SerBaud00End - SerBaud00 ;length of message

       ;set ds:si to source, es:di to dest for string move
       push    ds
       pop     es
       mov     si,offset SerBaud00     ;source
       mov     di,offset SerBaud       ;destination
       rep     movsb

   UString:
       ;copy UART type string to output string..
       ;..(but we don't print it yet)

int 3

       mov		cx,UMsgEnd - UMsg       ;length of UART messages
       mov     ax,UType                ;retrieve UART type

       mul     cx                      ;offset to string = type * str len
       mov     dx,offset UMsg          ;point dx to string table
       add     dx,ax                   ;add offset

       ;set ds:si to source, es:di to dest for string move
       push    ds
       pop     es
       mov     si,dx
       mov     di,offset SerUART       ;destination
       rep     movsb
       mov     dx,UARTAddress          ;retrieve port address

       mov     ax,uWin                 ;Windows running?
       cmp     ax,0
       jz      NoWin

       xor     ax,ax                   ;set !timeout flag
       mov     bl,cs:bWinwrite         ;force flag: yes > 0
       xor     bh,bh
       cmp     bh,bl                   ;detect?

       jz      WritePortDone           ;no write flag set

   NoWin:
       mov     ax,BIOS_SEG             ;where com port address lives
       mov     ds,ax                   ;new DS is port address
   ASSUME      ds:BIOS_SEG             ;point to BIOS table


       ;LOOP for write to port
       ;try for TIMEOUT seconds to write string to port
       xor     bx,bx                   ;ptr to next byte in string
       mov     ax,0                    ;set timer to current time
       call    WaitSec
   LookPort:
       add     dx,5                    ;point to Line Status register

   IsPortReady:
       mov     ax,TIMEOUT              ;TIMEOUT seconds passed?
       call    WaitSec
       cmp     al,0                    ;0 = NOT TIMEOUT seconds
       jnz     WritePortDone           ;stop trying after TIMEOUT seconds

       in      ax,dx                   ;read Line Status register
       and     al,20h                  ;xmit hold reg empty?
       jz      IsPortReady             ;not yet..

   WritePort:
       mov     al,cs:IntroMsg[bx]      ;get next char
       sub     dx,5                    ;Transmit buffer
       out     dx,al
       inc     bx
       xor     ax,ax                   ;set !timeout flag
       cmp     bx,cs:SerEnd - cs:IntroMsg
       jne     LookPort                ;out next char
       ;END LOOP for write to port


   WritePortDone:
       push    cs
       pop     ds                      ;point back to our data area
   ASSUME      ds:cs

   .IF (al != 0)                       ;TIMEOUT?
       mov     bx,offset SerMsg        ;yes, add a 't' to string
       mov     al,"t"
       mov     [bx],al
   .ENDIF

   PrintPortString:
       mov		ah,40h					;DOS WriteFile
		mov		bx,STDOUT				;write to stdout
		mov		cx,SerEnd - SerMsg
		mov		dx,OFFSET SerMsg        ;string to write
		int		21h						;call DOS WriteFile

   NextPort:
       mov     cx,uCurPort             ;fetch current port number
       inc     cx
       cmp     cx,SerPorts             ;any more ports?
       jge     FindParallel            ;all done, look for parallel ports

       mov     bx,offset SerNum        ;update port number
       mov     al,1                    
       add     [bx],al                 
       mov     bx,offset SerMsg        ;clear any TIMEOUT msg
       mov     al," "
       mov     [bx],al

       mov     uCurPort,cx             ;update current port number
       jmp     GetPortAddress
   ;END LOOP through 4 com ports
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ;BEGIN LOOP through 3 parallel ports
   FindParallel:
       ;fetch parallel ports
       mov     uCurPort,0              ;start with port 0
   GetParallelAddress:
       mov     bx,uCurPort             ;next port to examine
       shl     bx,1                    ;multiply by 2 to get sizeof(WORD)
       mov     ax,BIOS_SEG             ;where com port address lives
       mov     ds,ax                   ;new DS is port address
   ASSUME      ds:BIOS_SEG             ;point to BIOS table

       mov     dx,Par0[bx]             ;fetch port address
       cmp     dx,0                    ;is there a real address there?
       jz      ParLoop

       push    cs
       pop     ds                      ;point back to local data
   ASSUME      ds:cs

       ;put port address in string ( 1 dw to 4 db)
       mov     al,dh
       call    HextoAlph               
       mov     bx,offset ParAdd
       mov     [bx],ah
       inc     bx
       mov     [bx],al
       inc     bx
       mov     al,dl
       call    HextoAlph
       mov     [bx],ah
       inc     bx
       mov     [bx],al

       mov		ah,40h					;DOS WriteFile
		mov		bx,STDOUT				;write to stdout
		mov		cx,ParEnd - ParMsg
		mov		dx,OFFSET ParMsg        ;string to write
		int		21h						;call DOS WriteFile

   ParLoop:
       mov     cx,uCurPort             ;fetch current port number
       inc     cx
       cmp     cx,ParPorts             ;any more ports?
       jge     PortsDone               ;nope, all done

       mov     bx,offset ParNum        ;update port number
       mov     al,1                    
       add     [bx],al                 

       mov     uCurPort,cx             ;update current port number
       jmp     GetParallelAddress
   ;END LOOP through 3 parallel ports
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


   PortsDone:
       push    cs
       pop     ds                      ;point back to local data
   ASSUME      ds:cs

       mov     bx,0

   CheckConnect:
       mov     dl,bConnect1[bx]        ;COMx connect flag: yes > 0
       cmp     dl,0
       jnz     CheckPort               ;we have a port
       inc     bx                      
       cmp     bx,4                    ;last port?
       jnz     CheckConnect
       jmp     AllDone                 ;yes, just quit

   CheckPort:
       mov     dh,UARTpresent[bx]      ;is port present?
       mov     dl,0
       cmp     dh,dl
       jnz     PortOK

   PortNotOK:
   ;tell user requested port not present
		mov		ah,40h					;DOS WriteFile
		mov		bx,STDOUT				;write to stdout
		mov		cx,BadPortEnd - BadPort
		mov		dx,OFFSET BadPort  	    ;string to write
		int		21h						;call DOS WriteFile
       jmp     AllDone

   PortOK:
       shl     bx,1
       mov     dx,UARTBase[bx]
       mov     UARTAddress,dx          ;save address of the port we use

   ;tell user instructions
		mov		ah,40h				
		mov		bx,STDOUT			
		mov		cx,ConnectMsgEnd - ConnectMsg
		mov		dx,OFFSET ConnectMsg
		int		21h					
       mov     bx,0                    ;ptr into Compare strings

   ConnectLoopTop:
       mov     ah,0bh                  ;Check Keyboard Status
       int     21h
       cmp     al,0                    ;zero means no key pressed
       jnz     AllDone                 ;exit on keypress

       mov     dx,UARTAddress          ;fetch port address
       add     dx,5                    ;point to LineStatusRegister
       in      al,dx                   ;read LSR
       and     al,1                    ;AND with ReceiverDataReady
       jz      ConnectLoopTop          ;nothing to read
       sub     dx,5                    ;point to RX buffer
       in      al,dx
       mov     dl,al
       mov     ah,02h                  ;Display Character
       int     21h

       cmp     dl,0dh                  ;if CR found, print LF
       jnz     CompareChar
       mov     dl,0ah
       int     21h

   CompareChar:
       cmp     dl,CompareUC[bx]
       jz      CompOK
       cmp     dl,CompareLC[bx]
       jz      CompOK
       mov     bx,0                    ;no match, restart CONNECT index
       jmp     ConnectLoopTop

   CompOK:
       inc     bx
       cmp     CompareUC[bx],0
       jz      CompComplete
       jmp     ConnectLoopTop

   CompComplete:
		mov		ah,40h				
		mov		bx,STDOUT			
		mov		cx,SuccessEnd - SuccessMsg
		mov		dx,OFFSET SuccessMsg
		int		21h					

   AllDone:
		mov		ah,40h				
		mov		bx,STDOUT			
		mov		cx,IntroEnd - IntroCRLF
		mov		dx,OFFSET IntroCRLF
		int		21h					

		mov		ax,4C00h				;DOS Terminate Program
		int		21h						;call DOS

SetCom ENDP							;end SetCom PROCEDURE


;--------------------------------------------------------------------
;Parse - parse command line
;
;  parse command line
;  command line is stored in DTA from cs:81h - cs:ffh
;  number of bytes in command line in DTA at cs:81h
;  code starts at cs:100h
;  command line is raw, all parsing must be done here
;
;enter:
;  nothing
;
;exit:
;  nothing
;
;--------------------------------------------------------------------

   Parse:
       push    cs                      ;point es:di to PSP:81h
       pop     es     
       mov     bx,0
       mov     al,bConnect1[bx]

   ParseArgs:
       xor     cx,cx
       mov     cl,cs:[80h]             ;how many bytes on command line?
       cmp     cl,0
       jne     ParseSet                ;more than 0

   ParseNothing:                       ;no command line args
       mov     al,bConnect1[bx]
       cmp     al,0ffh                 ;..quit if its -1
       jz      ParseEnd
       mov     bConnect1[bx],0         ;zero out cmd line flags
       inc     bx
       jmp     ParseNothing

   ParseSet:
       mov     di,[81h]
       repnz   scasb

       jnz     ParseNo                 
       mov     bConnect1[bx],1         ;found match
       jmp     ParseNext
   ParseNo:
       mov     bConnect1[bx],0         ;no match
   ParseNext:
       inc     bx
       mov     al,bConnect1[bx]        ;get next arg..
       cmp     al,0ffh                 ;..quit if its -1
       jne     ParseArgs               ;last arg?

       ;add upper case + lower case searches
       mov     bx,0

   ParseCat:
   ;concatenate upper + lower case case searches for bWinwrite
   ;to end of arg list (alphabetic args)
       mov     al,bWinwrite[bx]
       cmp     al,0ffh                 ;..quit if its -1
       jz      ParseEnd
       add     al,bWinwrite[bx+1]
       mov     bWinwrite[bx],al
       inc     bx
       inc     bx
       jmp     ParseCat

   ParseEnd:
       ret


;--------------------------------------------------------------------
;FindWindows - determine if Windows running and print message
;enter:
;  nothing
;
;exit:
;  ax 0   : no Windows
;  ax ! 0 : Windows version
;
;--------------------------------------------------------------------

WinMessage     db	"Running under Microsoft Windows "
WinVer         db	"2.x "
				db	0dh,0ah
WinMessEnd     db	00h

   FindWindows:
       mov     ax,1600h                ;Win Enhanced Mode Install Check
       int     2fh
       test    al,7fh                  ;any Windows running?
       jnz     YesWindows              ;yes
       xor     ax,ax                   ;ret 0:no Windows
       ret                             

   YesWindows:
       push    ax                      ;save Windows ver
       cmp     al,04h
       jz      YesWin95                ;its Windows 95 (or greater)

       cmp     al,1                    ;Windows 2.x returns 1 or -1
       jz      WriteWinMessage
       cmp     al,-1
       jz      WriteWinMessage

       mov     bx,0
       add     al,'0'                  ;convert al (Major ver) to ASCII
       mov     WinVer[bx],al           ;write ver to Win string
       add     bx,2
       mov     al,ah
       call    DectoAlph
       mov     WinVer[bx],ah
       inc     bx
       mov     WinVer[bx],al
       jmp     WriteWinMessage

   YesWin95:
       mov     bx,0                    ;write out formal Windows 95
       mov     WinVer[bx],'9'
       inc     bx

       cmp     ah,00h
       jz      YesWin9595              ;its 95
       mov     WinVer[bx],'6'          ;its 96
       jmp     YesWin95Space
   YesWin9595:
       mov     WinVer[bx],'5'
   YesWin95Space:
       inc     bx
       mov     WinVer[bx],' '

   WriteWinMessage:
		mov		ah,40h					;DOS WriteFile
		mov		bx,STDOUT				;write to stdout
		mov		cx,WinMessEnd - WinMessage	;number of bytes
		mov		dx,OFFSET WinMessage	;string to write
		int		21h						;call DOS WriteFile

       pop     ax                      ;return Windows ver
       ret


;--------------------------------------------------------------------
;GetIRQ - display UART IRQ as ASCII string
;enter:
;  nothing
;
;exit:
;  nothing
;
;--------------------------------------------------------------------
   GetIRQ:

int 3

       mov     dx,UARTAddress
       mov     bx,offset SerIRQ

   IRQLoop:

   ;1. CPU interrupts are disabled.
   ;2. IER is read and value saved so it can be restored.
   ;3. All interrupts disabled by writing a zero to IER.
   ;4. MCR is read and value saved.
   ;5. MCR value written back with local loopback cleared and OUT2
   ;   set so that UART can generate an interrupt request to PIC.
   ;6. PIC interrupt mask register is read (port 21h) and saved.
   ;7. 0ah is written to port 20h (sets up interrupt request register
   ;   to be read at port 20h).
   ;8. Transmit interrupt enabled by setting TBE bit of IER.
   ;9. PIC interrupt request register is read, value is ANDed with 0fch.
   ;   Result should show a 1 where a specific IRQ is requesting service.
   ;10.More than one IRQ may be requesting service, so the transmit
   ;   interrupt is turned back off, and the PIC interrupt request register
   ;   is read again. This time the value is inverted and the result is 
   ;   ANDed with the previous result of ANDing 0fch with the value read 
   ;   from the PIC. The second time the PIC is read, it should read 
   ;   the same as it did before except that whichever IRQ the UART is 
   ;   using should now be clear. The result should be a value with just 
   ;   one bit set.
   ;11.The result is inverted and ANDed with the saved value read from the
   ;   PIC's interrupt mask register. The result of this operation is
   ;   written to port 32h, enabling that IRQ if it wasn't already enabled.
   ;12.0ch is written to port 20h, setting up the PIC's polled mode.
   ;13.Port 20h is read. The value received will have its MSB set if an
   ;   interrupt is pending, and the least significant three bits indicate
   ;   the highest priority level requesting service. This value should
   ;   have its MSB set, and the least significant bits will contain 
   ;   the UART's IRQ value. If the MSB is clear, the UART is not
   ;   connected to an IRQ.
   ;14.The LSR, receive buffer, IIR and MSR are read to clear any pending
   ;   interrupts at the UART, and the IER, LCR and MCR are restored to
   ;   their initial values.
   ;15.EOI (20h) is written to port 20h, and the interrupt mask is restored
   ;   to port 21h.
   ;16.CPU interrupts can now be enabled.


   IRQExit:

       ret


;--------------------------------------------------------------------
;HexDump - display UART contents as ASCII string
;enter:
;  nothing
;
;exit:
;  nothing
;
;--------------------------------------------------------------------
   HexDump:
       mov     dx,UARTAddress
       mov     bx,offset SerHex2

   HexDumpLoop:
       in      al,dx
       call    HextoAlph               ;ds is pointing to BIOSEG(0)
       mov     cs:[bx],ah              ;so seg override to point to string
       inc     bx
       mov     cs:[bx],al
       inc     bx
       inc     bx                      ;leave space between bytes

       mov     ax,dx
       sub     ax,UARTAddress
       cmp     ax,7
       jge     HexDumpExit

       inc     dx
       jmp     HexDumpLoop

   HexDumpExit:
       ret


;--------------------------------------------------------------------
;WaitSec
;enter:
;  al 0 : record current second
;  al x : see if x seconds have passed since last call
;
;exit:
;  al 0 : x seconds have not passed 
;  al x : x seconds have passed
;
;--------------------------------------------------------------------
SaveTime       db  0                   ;save current time here

   WaitSec:
       push    dx                      ;save regs that GetTime uses
       push    cx
       push    ax

       mov     ah,2ch                  ;what time is it?
       int     21h                     ;MSDOS Get Time

       pop     ax
       cmp     al,0                    ;set the clock?
       jne     GetClk                  ;no

       mov     SaveTime,dh             ;save current seconds
       jmp     SaveTimeExit            ;that's it

   ;if dh (current time) > al + SaveTime, ret x seconds, else ret 0
   GetClk:
       mov     cl,SaveTime
       add     cl,al                   ;add saved time + x seconds
      
   .IF (cl >= 60)                      ;time is in 00-59 units
       sub     cl,60
   .ENDIF
       cmp     dh,cl
       jg      SaveTimeExit            ;x seconds passed, ret x (still in al)
       mov     ax,0                    ;x seconds not passed, ret 0

   SaveTimeExit:
       pop     cx                      ;restore original regs
       pop     dx
       ret


;--------------------------------------------------------------------
;N81 - set UART to 19200,n,8,1
;enter:
;  dx : base UART address
;
;exit:
;  nothing
;
;--------------------------------------------------------------------

cMode          db 3                    ;wordsize, parity, stop bits (n,8,1)

uBaud115       dw 1                    ;baud rate (115000)
uBaud56        dw 2                    ;baud rate (56000)
uBaud38        dw 3                    ;baud rate (38400)
uBaud192       dw 6                    ;baud rate (19200)
uBaud96        dw 0Ch                  ;baud rate (9600)
uBaud48        dw 018h                 ;baud rate (4800)
uBaud24        dw 030h                 ;baud rate (2400)

   N81:
       mov     bl,cs:b00               ;00 baud flag: yes > 0
       xor     bh,bh
       cmp     bh,bl                   ;no baud change requested?
       jnz     BaudExit                ;exit without change

       add     dx,3                    ;Line Control Register
       mov     al,cMode
       or      al,80h                  ;enable Access Divisor latch
       out     dx,al                   ;and put cMode in LCR

       sub     dx,3                    ;Access Divisor register 0

       mov     ax,uBaud192             ;19200 baud default
       mov     bl,cs:b9600             ;9600 baud flag: yes > 0
       xor     bh,bh
       cmp     bh,bl                   ;9600 requested?
       jz      N4800
       mov     ax,uBaud96              ;set baud to 9600
       jmp     BaudSet

   N4800:
       mov     bl,cs:b4800             ;4800 baud flag: yes > 0
       xor     bh,bh
       cmp     bh,bl                   ;4800 requested?
       jz      N2400
       mov     ax,uBaud48              ;set baud to 4800
       jmp     BaudSet

   N2400:
       mov     bl,cs:b2400             ;2400 baud flag: yes > 0
       xor     bh,bh
       cmp     bh,bl                   ;2400 requested?
       jz      BaudSet    
       mov     ax,uBaud24              ;set baud to 2400

   BaudSet:
       out     dx,al                   ;low byte to Access Divisor reg 0

       inc     dx                      ;Access Divisor register 1
       xchg    ah,al                   ;get high byte of uBaud
       out     dx,al                   ;high byte to Access Divisor reg 1

       add     dx,2                    ;Line Control Register
       mov     al,cMode                ;put (n,8,1) in LCR
       out     dx,al                   ;Access Divisor latch disabled

   BaudExit:
       ret


;--------------------------------------------------------------------
;UART detection code derived from Robert L. Hummel's "UART Taxonomy",
;in PC Techniques, Oct 1993
;--------------------------------------------------------------------
;UART_TYPE
;
;entry:
;  BX = base address of UART to identify
;
;exit:
;  AX = 0: UART failed presence test
;       1: 8250, 8250-B
;       2: 8250A, 16450
;       3: 16550A (with FIFO bug)
;       4: 16550AF, 16550C
;       5: 16552 (dual 16550)
;       6: no detection
;       
;--------------------------------------------------------------------
                                       ;UART register equates
IER    equ     [bx+1]                  ;interrupt enable register
DLM    equ     [bx+1]                  ;divisor latch
FCR    equ     [bx+2]                  ;FIFO control register
IIR    equ     [bx+2]                  ;interrupt id register
AFR    equ     [bx+2]                  ;alt function register
LCR    equ     [bx+3]                  ;line control register
SCR    equ     [bx+7]                  ;scratch register

RET_TYPE       dw  0                   ;return type here

UART_TYPE  proc near
   assume  cs:Start, ds:Start, es:nothing, ss:Start

int 3

       mov     [RET_TYPE],0            ;assume not a UART

   ;verify that a UART is present by testing the dual nature of
   ;register #1.  Register 1 is 8 bits when acting as the DLM
   ;and 4 bits when acting as the IER.

       lea     dx,LCR                  ;line control register
       mov     al,80h                  ;set DLAB
       out     dx,al

       jmp     $+2                     ;I/O delay

       in      al,dx                   ;retrieve value
       cmp     al,80h                  ;must match
       jz      UT_2
       jmp     UT_EXIT                 ;no UART, just leave

   ;test width of DLM/IER register
   UT_2:
       lea     dx,DLM                  ;divisor latch (high)
       mov     al,0ffh                 ;set 8 bits
       out     dx,al

       jmp     $+2                     ;I/O delay

       in      al,dx                   ;retrieve value
       cmp     al,0ffh                 ;must match
       jnz     UT_DONE

       lea     dx,LCR                  ;line control register
       mov     al,03fh                 ;clear DLAB and set
       out     dx,al                   ;all other bits

       jmp     $+2                     ;I/O delay

       in      al,dx                   ;retrieve value
       cmp     al,03fh                 ;must match
       jnz     UT_DONE

       lea     dx,IER                  ;interrupt enable register
       mov     al,0ffh                 ;set 8 bits
       out     dx,al

       jmp     $+2                     ;I/O delay

       in      al,dx                   ;retrieve value
       push    ax                      ;save the result

       mov     al,0
       out     dx,al                   ;disable the 8 bits

       pop     ax                      ;retrieve result

       cmp     al,0fh                 	;high 4 bits should be clear
       jnz     UT_DONE

   ;test for presence of scratch pad register
       inc     [RET_TYPE]              ;assume 8250

       lea     dx,SCR                  ;scratch pad register
       mov     al,077h                 ;set bit pattern
       out     dx,al

       jmp     $+2                     ;I/O delay

       in      al,dx                   ;retrieve value
       cmp     al,077h                 ;must match
       jne     UT_DONE

   ;attempt to enable FIFO buffer
       inc     [RET_TYPE]              ;assume 16450

       lea     dx,FCR                  ;FIFO control register
       mov     al,01h                 	;enable FIFO
       out     dx,al

       jmp     $+2                     ;I/O delay

       in      al,dx                   ;check FIFO status
       and     al,0c0h                 ;bit 080h must be set (FIFO enable)
       jz      UT_DONE

       inc     [RET_TYPE]              ;assume buggy 16550A if bit 6 not set
       test    al,040h

       lea     dx,FCR                  ;FIFO control register
       mov     al,0                    ;turn off FIFOs
       out     dx,al                   ;flags are unchanged

       jnz     UT_16552A               ;jump based on test
       jmp     UT_DONE

   ;check for 16552A variant
   UT_16552A:
       inc     [RET_TYPE]              ;assume good 16550AF

       lea     dx,LCR                  ;line control register
       mov     al,80h                  ;set DLAB
       out     dx,al

       lea     dx,AFR                  ;alt function register
       mov     al,7                    ;set 3 bits
       out     dx,al

       jmp     $+2                     ;I/O delay

       in      al,dx                   ;retrieve value
       cmp     al,7                    ;must match
       jz      Type16552               ;UART is 16552

       mov     al,0                    ;clear bits in iir
       out     dx,al
       lea     dx,LCR                  ;disable DLAB
       out     dx,al                   
       jmp     UT_DONE

   Type16552:
       inc     [RET_TYPE]              ;UART is 16552

       mov     al,0                    ;clear bits in afr
       out     dx,al

       lea     dx,LCR                  ;clear DLAB
       out     dx,al

   UT_DONE:
       lea     dx,IIR                  ;interrupt id register
       mov     al,0h                   ;disable FIFO
       out     dx,al

       lea     dx,IER                  ;interrupt enable register
       mov     al,0h                   ;disable interrupts
       out     dx,al

       lea     dx,LCR                  ;line control register
       mov     al,83h                  ;enable DLAB, disable break
       out     dx,al

       sub     dx,3                    ;Access Divisor reg 0
       mov     al,30h                  ;2400 baud
       out     dx,al

       mov     al,0
       out     dx,al               
       
       lea     dx,LCR                  ;line control register
       mov     al,3h                   ;disable DLAB, disable break
       out     dx,al

   UT_EXIT:
       mov     ax,[RET_TYPE]           ;not a UART
       ret

UART_TYPE  ENDP


;--------------------------------------------------------------------
;DectoAlph - convert dec nibble to ASCII char
;
;enter
;  AL = low nibble to convert
;
;exit
;  AH = high nibble in ACSII
;  AL = low nibble in ACSII
;
;--------------------------------------------------------------------

DAlphaChar      db  '0'

   DectoAlph:
       push    dx

       and     al,0fh                  ;only convert low nibble

       mov     ah,ss:DAlphaChar
       add     al,ss:DAlphaChar
       
   DecCmp10:
   .IF (al > '9')
       sub     al,10
       inc     ah
       jmp     DecCmp10
   .ENDIF

       pop     dx
       ret


;--------------------------------------------------------------------
;HextoAlph - convert hex byte to ASCII char
;
;enter
;  AL = byte in hex
;
;exit
;  AH = high nibble in ACSII
;  AL = low nibble in ACSII
;
;--------------------------------------------------------------------

AlphaChar      db  '0'

   HextoAlph:
       push    dx
       mov     dx,ax

       mov     dh,dl
       and     dl,0f0h
       shr     dl,1
       shr     dl,1
       shr     dl,1
       shr     dl,1

       mov     ah,ss:AlphaChar
       add     ah,dl
       mov     dl,ah
   .IF (dl > '9')
       add     dl,7
   .ENDIF
       mov     ah,dl

       mov     dl,dh
       and     dl,0fh
       mov     al,ss:AlphaChar
       add     al,dl
       mov     dl,al
   .IF (dl > '9')
       add     dl,7
   .ENDIF
       mov     al,dl

       pop     dx
       ret


;--------------------------------------------------------------------
;Hexout - write byte to console in hex
;
;enter
;  AL = byte to write
;
;exit
;  nothing
;
;--------------------------------------------------------------------

Alpha          db  '0'

   HexOut:
       push    dx
       mov     dx,ax

       mov     dh,dl
       and     dl,0f0h
       shr     dl,1
       shr     dl,1
       shr     dl,1
       shr     dl,1

       mov     ah,ss:Alpha
       add     ah,dl
       mov     dl,ah
   .IF (dl > '9')
       add     dl,7
   .ENDIF
       mov     ah,2
       int     21h

       mov     dl,dh
       and     dl,0fh
       mov     ah,ss:Alpha
       add     ah,dl
       mov     dl,ah
   .IF (dl > '9')
       add     dl,7
   .ENDIF
       mov     ah,2
       int     21h

       mov     dl,20h
       int     21h

       pop     dx
       ret


;--------------------------------------------------------------------
;CRLFOut - write line feed to con
;
;enter
;  nothing
;
;exit
;  nothing
;
;--------------------------------------------------------------------

CRLF           db	0dh,0ah,'$'

   CRLFOut:
       push    ax
       push    dx

       mov     dx,offset CRLF
       mov     ah,9h
       int     21h

       pop     dx
       pop     ax

       ret


Start	ENDS							;end CODE segment (named Start)

		END		SetCom					;declare SetCom as entry point


