; lose.asm - Load the Suite16 Operating System Environment.

[org 0x100]  
section .data
    s_new       db 'New$'
    s_old       db 'Old$'
    s_cmdline   db ' command line: $'

section .text
start:
    ; start parsing the command line 
    mov al, [0x80]  ; strlen(GetCommandLine())
parse_flags:

print_cmdline:


exit:
    ; Terminate program, value in al
    mov ah, 0x4C  ; DOS function 4Ch - terminate program
    int 0x21      ; Call DOS interrupt
