; Screen-space flock with staggered positions and wingbeats.
draw_birds:
 mov di,birdFlock
 mov bp,5
.next:
 ; Two pixels per tick, with the half-tick boundary between frames.
 mov ax,[frameFraction]
 shl ax,1
 mov al,ah
 xor ah,ah
 mov dx,[ticks]
 shl dx,1
 add ax,dx
 add ax,[di]
 xor dx,dx
 mov bx,384
 div bx
 mov ax,dx
 sub ax,32
 mov bx,[di+2]
 mov cx,[ticks]
 add cx,[di]
 and cx,7
 cmp cx,4
 jb .wings
 add bx,2
.wings:
 ; The outer tips alternate above and below the centre.
 push ax
 push bx
 mov cx,2
 mov dx,1
 mov si,17
 call rectangle
 pop bx
 pop ax
 push ax
 push bx
 add ax,5
 mov cx,2
 mov dx,1
 mov si,17
 call rectangle
 pop bx
 pop ax
 mov bx,[di+2]
 inc bx
 inc ax
 mov cx,5
 mov dx,1
 mov si,17
 call rectangle
 add di,4
 dec bp
 jnz .next
 ret
birdFlock dw 120,12, 96,17, 73,12, 49,21, 31,16

