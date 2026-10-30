; ALI5DMA.EXE - enables CD/DVD bus-master DMA on ALi M5229 IDE controllers
; (ALi M1543/M1543C southbridge: Aladdin IV+, Aladdin V, Aladdin Pro II)
;
; Some BIOSes (e.g. ASUS P5A) leave bit 0 of M5229 config register 53h
; ("CD-ROM DMA enable") cleared. The Windows 9x driver sets it, DOS drivers
; such as UIDE/UDVD2 do not, which results in "General failure" on CD/DVD
; access in DMA mode. This tool sets the bit. The setting lasts until reset.
;
; The file works both as a program and as a device driver:
;   CONFIG.SYS:    DEVICE=C:\DOS\ALI5DMA.EXE [/Q]   (before UIDE/UDVD2)
;   command line:  ALI5DMA [/Q]
; As a driver it stays resident with a few bytes only (header + stubs).
;
; /Q = quiet, no output unless an error occurs
;
; Requires a 386 or newer CPU (PCI configuration mechanism #1).
; Build:  nasm -f bin -o ALI5DMA.EXE ALI5DMA.ASM
; License: MIT (see LICENSE)

        cpu 386

; ------------------------------------------------------------------
; MZ header (32 bytes)
; ------------------------------------------------------------------
        section mzhdr start=0
FILESIZE equ 32 + img_len
        db 'MZ'
        dw FILESIZE % 512               ; bytes in last page
        dw (FILESIZE + 511) / 512       ; pages
        dw 0                            ; relocations
        dw 2                            ; header size in paragraphs
        dw 20h                          ; min extra paragraphs (stack)
        dw 20h                          ; max extra paragraphs
        dw (img_len + 15) / 16          ; SS (relative)
        dw 200h                         ; SP
        dw 0                            ; checksum
        dw exe_entry                    ; IP
        dw 0                            ; CS (relative)
        dw 1Ch                          ; relocation table offset
        dw 0                            ; overlay
        times 32 - ($ - $$) db 0

; ------------------------------------------------------------------
; load image, offset 0 = device header
; ------------------------------------------------------------------
        section image follows=mzhdr vstart=0
img_start:

; --- device header ---
        dd -1
        dw 8000h                        ; character device
        dw strategy
        dw interrupt
        db 'ALI5DMA$'

reqptr  dd 0

strategy:
        mov [cs:reqptr], bx
        mov [cs:reqptr+2], es
        retf

interrupt:
        push ax
        push bx
        push es
        les bx, [cs:reqptr]
        cmp byte [es:bx+2], 0           ; command 0 = init
        jne .other
        call dev_init                   ; not resident, only called once
        jmp .done
.other:
        mov word [es:bx+3], 8103h       ; error: unknown command
.done:
        pop es
        pop bx
        pop ax
        retf

resident_end:                           ; everything below is discarded

; ------------------------------------------------------------------
; device driver init (ES:BX = request header)
; ------------------------------------------------------------------
dev_init:
        pushad
        push ds
        push es
        push cs
        pop ds
        mov [devreq], bx
        mov [devreq+2], es
        ; parameter string: far pointer at request+12h, ends with CR/LF/0
        lds si, [es:bx+12h]
        call parse_q
        push cs
        pop ds
        call do_work                    ; prints its own messages
        les bx, [devreq]
        mov word [es:bx+0Eh], resident_end
        mov [es:bx+10h], cs
        mov word [es:bx+3], 0100h       ; done
        pop es
        pop ds
        popad
        ret

; ------------------------------------------------------------------
; program entry (DS = ES = PSP)
; ------------------------------------------------------------------
exe_entry:
        mov si, 81h                     ; DS:SI = command tail (ends with CR)
        push cs
        pop es                          ; parse_q writes to CS: variables
        call parse_q
        push cs
        pop ds
        call do_work
        mov ah, 4Ch                     ; AL = exit code
        int 21h

; ------------------------------------------------------------------
; parse_q: DS:SI = string, sets [cs:quiet] if "/Q" found
; ------------------------------------------------------------------
parse_q:
.l:     lodsb
        cmp al, 0
        je .e
        cmp al, 13
        je .e
        cmp al, 10
        je .e
        cmp al, '/'
        jne .l
        lodsb
        and al, 0DFh
        cmp al, 'Q'
        jne .l
        mov byte [cs:quiet], 1
        jmp .l
.e:     ret

; ------------------------------------------------------------------
; do_work: DS = CS. Returns AL = 0 ok, 1 no M5229, 2 bit not settable
; ------------------------------------------------------------------
do_work:
        mov dx, msg_title
        call say

        mov esi, 80000000h              ; bus 0-7, all devices/functions
.f:     mov eax, esi
        mov dx, 0CF8h
        out dx, eax
        mov dx, 0CFCh
        in eax, dx
        cmp eax, 522910B9h              ; ALi M5229
        je .found
        add esi, 100h
        cmp esi, 80080000h
        jb .f
        mov byte [quiet], 0
        mov dx, msg_nf
        call say
        mov al, 1
        ret

.found:
        mov [addr], esi
        mov cl, 53h
        call rdb
        mov [old53], al
        test al, 01h
        jz .set
        mov dx, msg_already
        call say
        jmp .show
.set:
        or al, 01h
        call wrb
        mov cl, 53h
        call rdb
        test al, 01h
        jnz .ok
        mov byte [quiet], 0
        mov dx, msg_fail
        call say
        mov al, 2
        ret
.ok:
        mov dx, msg_done
        call say
.show:
        cmp byte [quiet], 0
        jne .ret
        mov dx, msg_reg
        call say
        mov al, [old53]
        call hex8
        mov dx, msg_arrow
        call say
        mov cl, 53h
        call rdb
        call hex8
        mov dx, msg_crlf
        call say
.ret:   xor al, al
        ret

; write config address for offset CL, return DX = data port
setaddr:
        mov eax, [addr]
        movzx edx, cl
        and dl, 0FCh
        or eax, edx
        mov dx, 0CF8h
        out dx, eax
        mov dx, 0CFCh
        push cx
        and cl, 3
        add dl, cl
        pop cx
        ret
rdb:    push dx
        push ax
        call setaddr
        pop ax
        in al, dx
        pop dx
        ret
wrb:    push dx
        push ax
        call setaddr
        pop ax
        out dx, al
        pop dx
        ret

say:    cmp byte [quiet], 0
        jne .q
        push ax
        mov ah, 09h
        int 21h
        pop ax
.q:     ret
putc:   push ax
        mov ah, 02h
        int 21h
        pop ax
        ret
hex8:   push ax
        push dx
        push ax
        shr al, 4
        call nib
        pop ax
        call nib
        pop dx
        pop ax
        ret
nib:    and al, 0Fh
        add al, '0'
        cmp al, '9'
        jbe .o
        add al, 7
.o:     mov dl, al
        call putc
        ret

msg_title   db 'ALI5DMA 1.1 - ALi M5229 CD/DVD DMA enabler',13,10,'$'
msg_nf      db 'ALI5DMA: no ALi M5229 IDE controller found.',13,10,'$'
msg_fail    db 'ALI5DMA: could not set register 53h bit 0!',13,10,'$'
msg_already db 'CD/DVD DMA was already enabled.',13,10,'$'
msg_done    db 'CD/DVD DMA enabled.',13,10,'$'
msg_reg     db 'M5229 register 53h: $'
msg_arrow   db ' -> $'
msg_crlf    db 13,10,'$'

addr   dd 0
devreq dd 0
old53  db 0
quiet  db 0

img_end:
img_len equ img_end - img_start
