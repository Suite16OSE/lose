; lose.asm - Load the Suite16 Operating System Environment.

[org 0x100]  
section .data
    s_new:          db 'New$'
    s_old:          db 'Old$'
    s_cmdline:      db ' command line: $'
    s_newline:      db 0x0D, 0x0A, '$'
    s_running:      db 'Suite16 is already running in $'
    s_realmode:     db 'Real$'
    s_standardmode: db 'Standard$'
    s_enhancedmode: db '386 Enhanced$'
    s_mode:         db ' mode.$'

section .bss
    np_psp:       resw 2
    i_mode:       resb 1


section .text
start:
    xor ax, ax
    call print_cmdline

    ; start parsing the command line 
    mov ah, [0x80]          ; strlen(GetCommandLine())
parse_flags:
    xor cx, cx              ; zero our counter
    xor bh, bh
    mov bl, 0x81            ; load command line string base address
    lea si, [bx]
    .loop:    
        lodsb                   ; read a byte
        inc cl                  ; increment counter     
        cmp al, '/'             ; is it a flag? 
        jne .afterflag          ; if not, skip.
    .flag:
        lodsb                   ; load the flag
        inc cl                  ; increment the counter

        mov byte [si-2], 0x20   ; replace flag with spaces for KERNEL 
        mov byte [si-1], 0x20  
    .afterflag:            
        cmp ah, cl
        jne .loop
.end:
    mov al, 1
    call print_cmdline      ; print modified command line passed to KERNEL 
    call exit               ; exit LOSE.COM

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
    ret

print_newline:
    push ax
    push dx
    mov ah, 9
    mov dx, s_newline       ; newline
    int 0x21                ; call DOS
    pop dx                  ; restore registers
    pop ax
    ret


show_help:
    ret

exit:
    ; Terminate program, value in al
    mov ah, 0x4C  ; DOS function 4Ch - terminate program
    int 0x21      ; Call DOS interrupt
    nop           ; end of .text canary - data follows!
