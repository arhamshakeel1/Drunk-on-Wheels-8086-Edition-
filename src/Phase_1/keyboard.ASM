; Latch make edges as well as held keys, independently of typematic.
keyboard:
 push ax
 push bx
 push ds
 push cs
 pop ds
 in al,60h
 cmp al,0e0h
 jae .ack
 mov bl,al
 and bx,007fh
 test al,80h
 jnz .release
 cmp byte [held+bx],0
 jne .ack
 mov byte [edges+bx],1
 mov byte [held+bx],1
 jmp .ack
.release:
 mov byte [held+bx],0
.ack:
 in al,61h
 mov ah,al
 or al,80h
 out 61h,al
 mov al,ah
 out 61h,al
 mov al,20h
 out 20h,al
 pop ds
 pop bx
 pop ax
 iret
input_frame:
 push ds
 pop es
 mov si,edges
 mov di,press
 mov cx,64
 cli
 cld
 rep movsw
 xor ax,ax
 mov di,edges
 mov cx,64
 rep stosw
 sti
 ret

