; ALIINFO.COM - dumps the IDE registers of the ALi M5229 (M1543/M1543C)
; Read-only, changes nothing. Requires 386+ (PCI configuration mechanism #1).
; Build: nasm -f bin -o ALIINFO.COM ALIINFO.ASM
; License: MIT (see LICENSE)

        cpu 386
        org 100h

start:
        mov dx, msg_title
        call puts

        ; --- find M5229 (10B9:5229) ---
        mov ebx, 522910B9h
        call find_dev
        jc .notfound
        mov [ide_addr], eax

        mov dx, msg_found
        call puts
        call print_bdf
        call crlf

        ; Revision / Prog-IF
        mov cl, 08h
        call cfg_rdb
        mov [rev], al
        mov dx, msg_rev
        call puts
        call hex8
        mov dx, msg_progif
        call puts
        mov cl, 09h
        call cfg_rdb
        call hex8
        call crlf

        ; bus master base (BAR4, offset 20h)
        mov cl, 20h
        call cfg_rdd
        and ax, 0FFFCh
        mov [bmbase], ax
        mov dx, msg_bm
        call puts
        mov ax, [bmbase]
        call hex16
        call crlf

        ; dump registers 40h-5Fh
        mov dx, msg_dump
        call puts
        mov byte [reg], 40h
.rowloop:
        mov al, [reg]
        call hex8
        mov dl, ':'
        call putc
        mov byte [cnt], 16
.colloop:
        mov dl, ' '
        call putc
        mov cl, [reg]
        call cfg_rdb
        call hex8
        inc byte [reg]
        dec byte [cnt]
        jnz .colloop
        call crlf
        cmp byte [reg], 60h
        jb .rowloop

        ; bus master status: bit 5 = master DMA capable, bit 6 = slave
        mov dx, msg_bmst
        call puts
        mov dx, [bmbase]
        or dx, dx
        jz .nobm
        add dx, 2
        in al, dx
        call hex8
        mov dx, msg_sec
        call puts
        mov dx, [bmbase]
        add dx, 0Ah
        in al, dx
        call hex8
.nobm:
        call crlf

        ; --- evaluation ---
        call crlf
        mov al, [rev]
        cmp al, 20h
        ja .r1
        mov dx, msg_r20
        jmp .rp
.r1:    cmp al, 0C2h
        jae .r2
        mov dx, msg_rlow
        jmp .rp
.r2:    mov dx, msg_rhigh
.rp:    call puts

        mov cl, 53h
        call cfg_rdb
        test al, 1
        mov dx, msg_53on
        jnz .p53
        mov dx, msg_53off
.p53:   call puts

        mov cl, 4Bh
        call cfg_rdb
        test al, 80h
        mov dx, msg_4bon
        jnz .p4b
        mov dx, msg_4boff
.p4b:   call puts

        ; --- M1533 (10B9:1533) register 79h ---
        mov ebx, 153310B9h
        call find_dev
        jc .done
        mov [ide_addr], eax
        mov dx, msg_isa
        call puts
        mov cl, 79h
        call cfg_rdb
        call hex8
        call crlf
        jmp .done

.notfound:
        mov dx, msg_nf
        call puts
.done:
        mov ax, 4C00h
        int 21h

; ------------------------------------------------------------
; find_dev: EBX = vendor/device dword, scans bus 0-7.
; returns CF=0, EAX = config base (80000000h|bus|dev|fn)
find_dev:
        mov esi, 80000000h
.loop:
        mov eax, esi
        mov dx, 0CF8h
        out dx, eax
        mov dx, 0CFCh
        in eax, dx
        cmp eax, ebx
        je .hit
        add esi, 100h           ; next function
        cmp esi, 80080000h      ; Bus 0..7
        jb .loop
        stc
        ret
.hit:   mov eax, esi
        clc
        ret

; cfg_rdd: CL = offset (dword aligned) -> EAX
cfg_rdd:
        push dx
        mov eax, [ide_addr]
        movzx edx, cl
        and dl, 0FCh
        or eax, edx
        mov dx, 0CF8h
        out dx, eax
        mov dx, 0CFCh
        in eax, dx
        pop dx
        ret

; cfg_rdb: CL = offset -> AL
cfg_rdb:
        push cx
        push dx
        mov eax, [ide_addr]
        movzx edx, cl
        and dl, 0FCh
        or eax, edx
        mov dx, 0CF8h
        out dx, eax
        mov dx, 0CFCh
        and cl, 3
        add dl, cl
        in al, dx
        pop dx
        pop cx
        ret

print_bdf:
        mov eax, [ide_addr]
        mov dx, msg_bus
        call puts
        mov eax, [ide_addr]
        shr eax, 16
        call hex8
        mov dx, msg_dev
        call puts
        mov eax, [ide_addr]
        shr eax, 11
        and al, 1Fh
        call hex8
        mov dx, msg_fn
        call puts
        mov eax, [ide_addr]
        shr eax, 8
        and al, 7
        call hex8
        ret

; ---- output ----
puts:   push ax
        mov ah, 09h
        int 21h
        pop ax
        ret
putc:   push ax
        mov ah, 02h
        int 21h
        pop ax
        ret
crlf:   push dx
        mov dx, msg_crlf
        call puts
        pop dx
        ret
hex16:  push ax
        mov al, ah
        call hex8
        pop ax
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

; ---- data ----
msg_title db 'ALIINFO 1.0 - ALi M5229 IDE registers (read-only)',13,10,13,10,'$'
msg_found db 'M5229 found: $'
msg_bus   db 'Bus $'
msg_dev   db ', device $'
msg_fn    db ', function $'
msg_rev   db 'Revision: $'
msg_progif db '   Prog-IF: $'
msg_bm    db 'Bus master base: $'
msg_dump  db 13,10,'Registers 40h-5Fh:',13,10,'$'
msg_bmst  db 13,10,'BM status primary: $'
msg_sec   db '   secondary: $'
msg_r20   db 'Rev <= 20h: no UltraDMA, no ATAPI DMA.',13,10,'$'
msg_rlow  db 'Rev < C2h: per Linux driver rules, ATAPI only MWDMA reads.',13,10,'$'
msg_rhigh db 'Rev >= C2h: UltraDMA for CD/DVD supported.',13,10,'$'
msg_53on  db 'Reg 53h bit 0 (CD-ROM DMA enable): ON',13,10,'$'
msg_53off db 'Reg 53h bit 0 (CD-ROM DMA enable): OFF',13,10,'$'
msg_4bon  db 'Reg 4Bh bit 7 (CD-ROM DMA write): ON',13,10,'$'
msg_4boff db 'Reg 4Bh bit 7 (CD-ROM DMA write): OFF',13,10,'$'
msg_isa   db 'M1533 reg 79h: $'
msg_nf    db 'No ALi M5229 found!',13,10,'$'
msg_crlf  db 13,10,'$'

ide_addr dd 0
bmbase   dw 0
rev      db 0
reg      db 0
cnt      db 0
