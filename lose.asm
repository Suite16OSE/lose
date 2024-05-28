; lose.asm - Load the Suite16 Operating System Environment.

bits 16
[org 0x100]  
section .data
    s_new:          db 'New$'
    s_old:          db 'Old$'
    s_cmdline:      db ' command line: $'
    s_newline:      db 0x0D, 0x0A, '$'
    s_suite16:      db 'Suite16$'
    s_windows:      db 'Windows$'
    s_wfw:          db 'Windows for Workgroups$'
    s_running:      db 'Suite16 is already running in $'
    s_realmode:     db 'Real$'
    s_standardmode: db 'Standard$'
    s_enhancedmode: db '386 Enhanced$'
    s_mode:         db ' mode.$'
    s_modesel:      db 'Mode requested: n.$'
    s_wrongdos:     db 'Incorrect DOS version.$'
    s_help:         db 'LOSE.COM: Launch Suite16.$'
    s_help2:        db 'Usage:$'
    s_help3:        db '   /R        $'
    s_help4:        db '   /S or /2  $'
    s_help5:        db '   /3        $'
    s_help6:        db '   /?        Displays this help.$'
    s_help7:        db 'Submit bug reports or patches at https://github.com/Suite16OSE/lose$'
    s_helps:        db 'Starts Suite16 in $'
    s_errmem:       db 'Error reallocating memory!$'
    s_dosx:         db 'SYSTEM\\DOSX.EXE', 0
    s_wswap:        db 'SYSTEM\\WSWAP.EXE', 0
    s_krnl386:      db 'SYSTEM\\KRNL386.EXE', 0
    k_krnl286:      db 'SYSTEM\\KRNL286.EXE', 0
    s_win386:       db 'SYSTEM\\WIN386.EXE', 0
    s_30rkrnl:      db 'SYSTEM\\KERNEL.EXE', 0
    s_slowkrnl:     db 'KERNEL.EXE', 0
    s_win1boot:     db 'WIN100.BIN', 0
    s_win2boot:     db 'WIN200.BIN', 0
    s_suite16krnl:  db 'S16KRNL.EXE', 0

section .bss
    np_psp:         resw 2
    i_mode:         resb 1
    i_dosminor:     resb 1
    i_dosmajor:     resb 1
    s_numtemp:      resb 10
    f_int23orig:    resb 4  ; ctrl-c interrupt original handler address

section .text
start:
    xor ax, ax              ; ensure AX (and AL) are zero
    call check_dos_version  ; we need at least 3.1
    call init_memory        ; initialize LOSE.COM memory
    call print_cmdline      ; print initial command line, AL=0 for "Old", 1 for "New"
    ; start parsing the command line 
    mov ah, [0x80]          ; strlen(GetCommandLine())
parse_flags:
    xor cx, cx              ; zero our counter
    xor bh, bh
    mov bl, 0x81            ; load command line string base address
    lea si, [bx]
.checklength:
    test ah, ah                 ; is length zero?
    jz .end                     ; skip command line processing if so. 
    .loop:    
        lodsb                   ; read a byte
        inc cl                  ; increment counter     
        cmp al, 0x0d            ; is it a carriage return?
        je .end                 ; if it is, it's the end of the command line.
        cmp al, '/'             ; is it a flag? 
        jne .afterflag          ; if not, skip.
    .flag:
        lodsb                   ; load the flag
        inc cl                  ; increment the counter
    .test386:
        cmp al, '3'             ; /3 - is it 386 mode? 
        jne .test286
        mov byte [i_mode], 3    ; set mode to 386 Enhanced
        jmp .closeflag
    .test286:                   ; test for standard mode
        cmp al, 's'             ; /s 
        je .smodewanted
        cmp al, 'S'             ; /S
        je .smodewanted
        cmp al, '2'             ; /2
        jne .test86
    .smodewanted:
        mov byte [i_mode], 2    ; set mode to Standard (286) mode
        jmp .closeflag
    .test86:
        cmp al, 'r'             ; /r
        je .rmodewanted
        cmp al, 'R'             ; /R
        jne .afterflag          ; not our flag, leave it for KERNEL
    .rmodewanted:
        mov byte [i_mode], 0    ; set mode to Real (8086) mode
    .closeflag:
        call .spaceflag         ; if our flag, clear it out
        jmp .afterflag
    .spaceflag:
        mov byte [si-2], 0x20   ; replace flag with spaces for KERNEL 
        mov byte [si-1], 0x20   ; two byte movs to avoid alignment issues
        ret
    .afterflag:
        cmp al, '?'             ; /? 
        je show_help            ; if so, show help and exit            
        cmp ah, cl              ; does our current character position equal the string length? are we at the end?
        jne .loop               ; if not, re-run the loop.
.end:
    call print_mode         ; print final decided mode
    mov al, 1
    call print_cmdline      ; print modified command line passed to KERNEL 
    call exit               ; exit LOSE.COM

print_mode:
    push dx                ; save stack
    push ax
    mov dl, [i_mode]       ; move mode into dl 
    add dl, 0x30           ; turn into ASCII digit
    mov byte [s_modesel+0x10], dl  ; inset digit into string
    mov dx, s_modesel      ; The "Mode selected: " string
    mov ah, 9              ; DOS print string
    int 0x21               ; call DOS
    call print_newline     ; finish with newline
    pop ax
    pop dx                 ; restore stack         
    ret

print_cmdline:
    push bx                 ; save registers
    push dx 
    mov dx, s_old           ; load "Old" string
    cmp ax, 0               ; new or old command line? old is zero.
    je .print_rest          ; print it and go
.print_new:
    mov dx, s_new           ; load "New" string instead
.print_rest:
    mov ah, 9               ; write string to stdout
    int 0x21                ; call DOS
    mov dx, s_cmdline       ; rest of string
    int 0x21                ; call DOS
.print_cmdchars:
    xor bh, bh              ; zero b-high
    mov bl, [0x80]          ; read length of command line from dos. max of 127
    add bl, 0x81            ; add 0x81 (start of cmdline in PSP) to length to get end marker
    mov byte [bx], '$'      ; replace with $ for DOS print call
    push bx                 ; save address so DOS doesn't mangle it
    mov dx, 0x81            ; set address of string to print to PSP command line
    int 0x21                ; ah=0x09, print string to stdout
    pop bx                  ; restore address to terminator character
    mov byte [bx], 0x0d     ; restore original 0x0d terminator
    call print_newline      ; and add the newline at the end.
    pop dx                  ; restore registers
    pop bx 
    ret

print_newline:
    push ax                 ; save registers
    push dx
    mov ah, 9               ; write string to stdout
    mov dx, s_newline       ; newline
    int 0x21                ; call DOS
    pop dx                  ; restore registers
    pop ax  
    ret

show_help:                  ; Only shown on /? and doesn't return.
    mov ah, 9               ; print string call, we're gonna be making a bunch of these and bailing.
    mov dx, s_help          ; Print the line showing what the program does
    int 0x21                ; call DOS
    call print_newline
    call print_newline      
    mov dx, s_help2         ; prints "Usage:"
    int 0x21
    call print_newline
    call print_newline
    mov dx, s_help3
    int 0x21
    mov dx, s_realmode
    call .opthelper
    mov dx, s_help4
    int 0x21
    mov dx, s_standardmode
    call .opthelper
    mov dx, s_help5
    int 0x21
    mov dx, s_enhancedmode
    call .opthelper
    mov dx, s_help6
    int 0x21
    call print_newline
    call print_newline
    mov dx, s_help7
    int 0x21
    call print_newline
    call exit
.opthelper:             ; ah is already 9 = DOS print string
    push dx             ; save the mode string pointer
    mov dx, s_helps     ; print the "Start Suite16 in " string
    int 0x21
    pop dx              ; restore mode string pointer
    int 0x21            ; print it 
    mov dx, s_mode      ; print the "mode ." string
    int 0x21
    call print_newline  ; finish with newline
    ret

check_dos_version:
    push ax                 ; save registers
    push dx
    mov ax, 0x3001          ; get DOS version
    int 0x21                ; call DOS
    mov byte [i_dosmajor], al ; DOS major version
    mov byte [i_dosminor], ah ; DOS minor version
    cmp al, 3               ; check DOS major
    jnl .end                ; if not less than 3, finish function, else error and quit
    mov dx, s_wrongdos      ; load "incorrect DOS version" string
    mov ah, 9               ; print string
    int 0x21                ; call DOS
    call print_newline      
    test al, al             ; is major version zero? (because DOS 1.x doesn't have this call) 
    jz .dos1exit            ; Can't use AH=4Ch on DOS 1.x
    call exit
.end:                       ; DOS is at least 3.x, keep going
    pop dx                  ; restore registers
    pop ax
    ret
.dos1exit:
    int 0x20                ; DOS 1.x exit

init_memory:
    mov byte [i_mode], al   ; set mode to zero (initialize memory)
    pop bx                  ; grab return pointer
    mov sp, 0x2000          ; move stack pointer
    mov bp, sp              ; base pointer from stack pointer
    push bx                 ; restore return pointer to stack
    mov bx, bp              ; move base pointer into bx
    shr bx, 4               ; shift right four bits to divide by 16 and get number of paragraphs
    push ax
    mov ah, 0x4a            ; set memory block size
    int 0x21                ; call DOS
    pop ax
    jc .errmsg              ; if failed, error and exit
    ret                     ; return
.errmsg:
    mov dx, s_errmem        ; failure message into memory
    mov ah, 9               ; print string
    int 0x21
    call print_newline
    call exit
    ret

exit:
    ; Terminate program, value in al
    mov ah, 0x4C  ; DOS function 4Ch - terminate program
    int 0x21      ; Call DOS interrupt
    nop           ; end of .text canary - data follows!
