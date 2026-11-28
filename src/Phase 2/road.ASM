; Q8 horizontal pixel/world scale shared by same-scanline features.
ground_x:
 push cx
 call ground_subpixel_x
 pop cx
 add ax,128
 adc dx,0
 mov al,ah
 mov ah,dl
 add ax,160
 ret

; Return the projected offset in DX:AX at 1/256 pixel precision.
ground_subpixel_x:
 sub ax,[camX]
 imul word [groundScale]
 push ax
 push dx
 mov ax,[cameraXFraction]
 mul word [groundScale]
 shr ax,1
 shr ax,1
 shr ax,1
 mov cx,ax
 pop dx
 pop ax
 sub ax,cx
 sbb dx,0
 push bx
 mov bx,[bendSubpixels]
 mov cl,5
 shl bx,cl
 mov cx,0
 test bx,bx
 jns .addBend
 dec cx
.addBend:
 add ax,bx
 adc dx,cx
 pop bx
 ret
ground_band:
 mul word [groundScale]
 mov [bandFrac],ah
 mov al,ah
 mov ah,dl
 mov [bandHalf],ax
 mov cx,ax
 shl cx,1
 neg ax
 add ax,[roadMid]
 cmp byte [level],PARKING
 jne short .polish_continue_2008
 jmp near .solid
.polish_continue_2008:
 cmp byte [hazeBase],0
 je short .polish_continue_2010
 jmp near .solid
.polish_continue_2010:
 cmp byte [bandFrac],64
 jae short .polish_continue_2012
 jmp near .solid
.polish_continue_2012:
 push ax
 push si
 BOX ax,[rowY],cx,1,si
 pop si
 pop ax
 mov bx,240
 ; The world palette ends at index 239. Each edge uses three quarter steps.
 cmp si,3
 jne .curb
 add bx,6
 jmp .lookup
.curb:
 cmp si,6
 jne .redCurb
 add bx,3
 jmp .lookup
.redCurb:
 cmp si,13
 jne .lookup
 mov bx,RED_CURB_EDGE
.lookup:
 mov dx,ax
 xor ax,ax
 mov al,[bandFrac]
 mov cl,6
 shr al,cl
 add bx,ax
 dec bx
 mov si,bx
 mov ax,dx
 dec ax
 push si
 BOX ax,[rowY],1,1,si
 pop si
 mov ax,[bandHalf]
 add ax,[roadMid]
 BOX ax,[rowY],1,1,si
 ret
.solid:
 mov bx,[rowY]
 mov dx,1
 jmp rectangle
bandFrac db 0
bandHalf dw 0
paint_stripe:
 call ground_x
 mov cx,[scaleY]
 shr cx,1
 shr cx,1
 shr cx,1
 shr cx,1
 inc cx
 mov bx,[rowY]
 mov dx,1
 mov si,7
 jmp rectangle
 ; Use fractional horizontal coverage at each lane stripe edge. A dim
 ; single sample replaces unresolved dash segments close to the horizon.
lane_paint:
 call ground_subpixel_x
 mov bl,al
 mov al,ah
 mov ah,dl
 add ax,160
 cmp word [scaleY],12
 jae .near
 cmp word [scaleY],4
 jae .farPixel
 ret
.farPixel:
 mov cx,1
 mov dx,1
 mov bx,[rowY]
 mov si,42
 jmp rectangle
.near:
 mov [stripeLeft],ax
 mov cl,6
 shr bl,cl
 xor bh,bh
 mov [stripePhase],bx
 push ax
 xor ax,ax
 mov al,[coverageLeft+bx]
 mov si,ax
 pop ax
 mov bx,[rowY]
 mov cx,1
 mov dx,1
 call rectangle
 mov ax,[scaleY]
 mov cl,4
 shr ax,cl
 mov [stripeCore],ax
 mov cx,ax
 mov ax,[stripeLeft]
 inc ax
 mov bx,[rowY]
 mov dx,1
 mov si,7
 call rectangle
 mov bx,[stripePhase]
 or bx,bx
 jz .done
 xor ax,ax
 mov al,[coverageRight+bx]
 mov si,ax
 mov ax,[stripeLeft]
 add ax,[stripeCore]
 inc ax
 mov bx,[rowY]
 mov dx,1
 mov cx,1
 jmp rectangle
.done:
 ret
coverageLeft db 7,44,43,42
coverageRight db 3,42,43,44
stripeLeft dw 0
stripePhase dw 0
stripeCore dw 0
light_road:
 cmp byte [headlamps],0
 jne short .view_continue_1126
 jmp near .done
.view_continue_1126:
 mov ax,[depthZ]
 sub ax,[pz]
 cmp ax,[halfL]
 jge short .view_continue_1130
 jmp near .done
.view_continue_1130:
 cmp ax,180
 jle short .view_continue_1132
 jmp near .done
.view_continue_1132:
 ; Two beams widen along the ground in front of the player's nose.
 mov cl,3
 shr ax,cl
 add ax,4
 mov [beamHalf],ax
 mov ax,[px]
 sub ax,[halfW]
 call .beam
 mov ax,[px]
 add ax,[halfW]
.beam:
 push ax
 add ax,[beamHalf]
 call ground_x
 mov cx,ax
 pop ax
 sub ax,[beamHalf]
 call ground_x
 sub cx,ax
 mov bx,[rowY]
 mov dx,1
 mov si,31
 jmp rectangle
.done:
 ret

