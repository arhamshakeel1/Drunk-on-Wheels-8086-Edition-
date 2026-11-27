start:
 cld
 cli
 mov ax,cs
 mov ss,ax
 mov sp,stack_end
 sti
 mov ds,ax
 mov es,ax
 mov bx,(stack_end-$$+100h+15)/16
 mov ah,4ah
 int 21h
 jnc short .branch_continue_51
 jmp near memory_error
.branch_continue_51:
 mov bx,4000
 mov ah,48h
 int 21h
 jnc short .branch_continue_55
 jmp near memory_error
.branch_continue_55:
 mov [canvas],ax
 mov ax,0013h
 int 10h
 mov ax,1130h
 mov bh,3
 int 10h
 mov [fontSeg],es
 mov [fontOff],bp
 call palette
 call mouse_init
 mov ax,3509h
 int 21h
 mov [old9],bx
 mov [old9+2],es
 mov dx,keyboard
 mov ax,2509h
 int 21h
 ; Keep the standard 65536-count BIOS period. Mode 2 lets us read
 ; the fractional tick on an 8253 for presentation interpolation.
 cli
 mov al,34h
 out 43h,al
 xor al,al
 out 40h,al
 out 40h,al
 sti
 call update_dash_clock
 call clock16
 mov [lastTick],ax
.main:
 call clock16
 sub ax,[lastTick]
 jz .frame
 cmp ax,5
 jbe .step
 call clock16
 mov [lastTick],ax
 dec word [lastTick]
.step:
 inc word [lastTick]
 inc word [ticks]
 test byte [ticks],15
 jnz .input
 call update_dash_clock
.input:
 call remember_positions
 call input_frame
 call dispatch
 cmp byte [quit],0
 je .sound
 jmp near shutdown
.sound:
 call audio_tick
 jmp .main
.frame:
 cmp byte [screen],PLAY
 je .playFrame
 mov byte [frameReady],0
 mov byte [inRetrace],0
 mov ax,[lastTick]
 cmp ax,[shownTick]
 jne .menuPaint
 sti
 hlt
 jmp .main
.menuPaint:
 mov [shownTick],ax
 call render
 call present
 jmp .main
.playFrame:
 ; Present the completed canvas at the start of vertical retrace.
 ; Draw the next canvas while the VGA scans the one just presented.
 mov dx,03dah
 in al,dx
 test al,8
 jnz .retrace
 mov byte [inRetrace],0
 jmp .main
.retrace:
 cmp byte [inRetrace],0
 jne .main
 xor al,al
 out 43h,al
 in al,40h
 mov ah,al
 in al,40h
 xchg al,ah
 neg ax
 xor bx,bx
 mov bl,ah
 call clock16
 cmp ax,[lastTick]
 jne .main
 mov [frameFraction],bx
 mov byte [inRetrace],1
 cmp byte [frameReady],0
 je .drawNext
 call present
.drawNext:
 call render
 mov byte [frameReady],1
 jmp .main

present:
 mov ds,[canvas]
 mov ax,0a000h
 mov es,ax
 xor si,si
 xor di,di
 mov cx,32000
 cld
 rep movsw
 push cs
 pop ds
 ret

shownTick dw 0ffffh
frameFraction dw 0
frameReady db 0
inRetrace db 0

clock16:
 push es
 mov ax,40h
 mov es,ax
 mov ax,[es:6ch]
 pop es
 ret
shutdown:
 cli
 mov al,36h
 out 43h,al
 xor al,al
 out 40h,al
 out 40h,al
 sti
 call silent
 lds dx,[old9]
 mov ax,2509h
 int 21h
 push cs
 pop ds
 ; No buffered DOS keystrokes should follow the game back to the prompt.
 mov ax,40h
 mov es,ax
 cli
 mov ax,[es:1ch]
 mov [es:1ah],ax
 sti
 mov ax,3
 int 10h
 mov ax,4c00h
 int 21h
memory_error:
 mov dx,memmsg
 mov ah,9
 int 21h
 mov ax,4c01h
 int 21h
