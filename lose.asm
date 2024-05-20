; lose.asm - Load the Suite16 Operating System Environment.

[org 0x100]  
section .data
    s_new:       db 'New$'
    s_old:       db 'Old$'
    s_cmdline:   db ' command line: $'
    s_newline    db 0x0D, 0x0A, '$'

section .bss
    a_psp:       resw 2

section .text
start:
    mov ax, 0
    call print_cmdline

    ; start parsing the command line 
    mov al, [0x80]      ; strlen(GetCommandLine())
parse_flags:

print_cmdline:
    mov dx, s_old       ; load "Old" string
    cmp ax, 0           ; new or old command line? old is zero.
    je print_rest       ; print it and go
print_new:
    mov dx, s_new       ; load "New" string instead
print_rest:
    mov ah, 9           ; write string to stdout
    int 0x21            ; call DOS
    mov dx, s_cmdline   ; rest of string
    int 0x21            ; call DOS
print_cmdchars:
    xor bh, bh
    mov bl, [0x80]
    add bl, 0x81
    mov byte [bx], '$'
    push bx
    mov dx, 0x81
    int 0x21
    pop bx
    mov byte [bx], 0x0d
print_newline:
    mov dx, s_newline   ; newline
    int 0x21            ; call DOS
    ret

exit:
    ; Terminate program, value in al
    mov ah, 0x4C  ; DOS function 4Ch - terminate program
    int 0x21      ; Call DOS interrupt
    nop           ; end of .text canary
