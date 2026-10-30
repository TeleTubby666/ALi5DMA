; ALI5DMA.COM - enables CD/DVD bus-master DMA on ALi M5229 IDE controllers
; (ALi M1543/M1543C southbridge: Aladdin IV+, Aladdin V, Aladdin Pro II)
;
; Some BIOSes (e.g. ASUS P5A) leave bit 0 of M5229 config register 53h
; ("CD-ROM DMA enable") cleared. The Windows 9x driver sets it, DOS drivers
; such as UIDE/UDVD2 do not, which results in "General failure" on CD/DVD
; access in DMA mode. This tool sets the bit. The setting lasts until reset.
;
; Usage:  ALI5DMA        set the bit
;         ALI5DMA /Q     quiet (no output unless an error occurs)
;
; Requires a 386 or newer CPU (PCI configuration mechanism #1).
; Build:  nasm -f bin -o ALI5DMA.COM ALI5DMA.ASM
;
; License: MIT (see LICENSE)

        cpu 386
        org 100h

start:
        ; parse /Q
        mov si, 81h
        movzx cx, byte [80h]
.p:     jcxz .pdone
        lodsb
        and al, 0DFh
        cmp al, 'Q'
        jne .pn
        mov byte [quiet], 1
.pn:    dec cx
        jmp .p
.pdone:
        mov dx, msg_title
        call say

        ; find M5229 (10B9:5229) on bus 0-7
        mov esi, 80000000h
.f:     mov eax, esi
        mov dx, 0CF8h
        out dx, eax
        mov dx, 0CFCh
        in eax, dx
        cmp eax, 522910B9h
        je .found
        add esi, 100h
        cmp esi, 80080000h
        jb .f
        mov byte [quiet], 0
        mov dx, msg_nf
        call say
        mov ax, 4C01h
        int 21h

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
        mov ax, 4C02h
        int 21h
.ok:
        mov dx, msg_done
        call say

.show:
        cmp byte [quiet], 0
        jne .exit
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
.exit:
        mov ax, 4C00h
        int 21h

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

msg_title   db 'ALI5DMA 1.0 - ALi M5229 CD/DVD DMA enabler',13,10,'$'
msg_nf      db 'ALI5DMA: no ALi M5229 IDE controller found.',13,10,'$'
msg_fail    db 'ALI5DMA: could not set register 53h bit 0!',13,10,'$'
msg_already db 'CD/DVD DMA was already enabled.',13,10,'$'
msg_done    db 'CD/DVD DMA enabled.',13,10,'$'
msg_reg     db 'M5229 register 53h: $'
msg_arrow   db ' -> $'
msg_crlf    db 13,10,'$'

addr  dd 0
old53 db 0
quiet db 0
