;  Clipped filled rectangle AX/BX top-left, CX/DX size, SI palette entry.
rectangle:
 push di
 push bp
 push es
 add cx,ax
 add dx,bx
 cmp ax,0
 jge .x
 xor ax,ax
.x:
 cmp bx,0
 jge .y
 xor bx,bx
.y:
 cmp cx,320
 jle .r
 mov cx,320
.r:
 cmp dx,200
 jle .b
 mov dx,200
.b:
 sub cx,ax
 jg short .branch_continue_731
 jmp near .out
.branch_continue_731:
 sub dx,bx
 jg short .route_continue_1129
 jmp near .out
.route_continue_1129:
 mov di,bx
 shl di,1
 shl di,1
 add di,bx
 mov bx,cx
 mov cl,6
 shl di,cl
 add di,ax
 mov bp,320
 sub bp,bx
 mov es,[canvas]
 mov ax,si
 cmp al,32
 jae .native
 add al,[hazeBase]
.native:
 cld
 cmp word [farBlend],0
 je .row
 push si
 mov si,bx
 mov bx,[farBlend]
.softRow:
 mov cx,si
.softPixel:
 mov al,[es:di]
 xlat
 stosb
 loop .softPixel
 add di,bp
 dec dx
 jnz .softRow
 pop si
 jmp .out
.row:
 mov ah,al
 mov cx,bx
 shr cx,1
 rep stosw
 test bl,1
 jz .even
 stosb
.even:
 add di,bp
 dec dx
 jnz .row
.out:
 pop es
 pop bp
 pop di
 ret
; BIOS ROM 8x8 glyphs, transparent background. Caller keeps strings on-screen.
label8:
 push es
 push di
 push bp
 mov [ink],dl
 mov di,bx
 shl di,1
 shl di,1
 add di,bx
 mov cl,6
 shl di,cl
 add di,ax
 mov es,[canvas]
 cld
.char:
 lodsb
 or al,al
 jnz short .branch_continue_776
 jmp near .end
.branch_continue_776:
 xor ah,ah
 shl ax,1
 shl ax,1
 shl ax,1
 add ax,[fontOff]
 mov bp,ax
 push ds
 mov dl,[ink]
 mov ds,[fontSeg]
 mov bx,8
.rows:
 mov al,[ds:bp]
 inc bp
 mov cx,8
.bits:
 shl al,1
 jnc .clear
 mov [es:di],dl
.clear:
 inc di
 loop .bits
 add di,312
 dec bx
 jnz .rows
 pop ds
 sub di,2552
 jmp .char
.end:
 pop bp
 pop di
 pop es
 ret
decimal:
 mov si,numbuf+6
 mov byte [si],0
 mov cx,ax
 or ax,ax
 jns .abs
 neg ax
.abs:
 mov bx,10
.d:
 xor dx,dx
 div bx
 add dl,'0'
 dec si
 mov [si],dl
 or ax,ax
 jnz .d
 test cx,8000h
 jz .end
 dec si
 mov byte [si],'-'
.end:
 ret
