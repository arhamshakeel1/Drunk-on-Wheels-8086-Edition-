; Each vehicle is assembled from a silhouette-specific profile in local
; units. Origin is the centre of the tyre contact patch at ground level.
; A profile row encodes left offset, height above ground, width, height, ink.
; Ink 255 follows the selected body paint.
vehicle_sprite:
 cmp byte [screen],PLAY
 je .model
 mov ax,[spriteW]
 mov cl,4
 shl ax,cl
 mov [widthQ4],ax
 mov ax,[spriteX]
 mov cl,3
 shl ax,cl
 mov [spriteXQ3],ax
 mov ax,[spriteY]
 shl ax,cl
 mov [spriteYQ3],ax
.model:
 mov bx,[shape]
 shl bx,1
 mov di,[models+bx]
draw_profile:
 ; Reject profiles beyond the side edges before expanding individual parts.
 mov ax,[spriteW]
 add ax,2
 mov bx,[spriteX]
 add bx,ax
 js .outside
 mov bx,[spriteX]
 sub bx,ax
 cmp bx,319
 jg .outside
 jmp .visible
.outside:
 ret
.visible:
 push bp
 cmp word [farBlend],0
 jne .next
 cmp word [spriteW],6
 jb .next
 mov cx,[spriteW]
 mov ax,cx
 shr ax,1
 mov bx,[spriteX]
 sub bx,ax
 mov ax,bx
 mov bx,[spriteY]
 mov dx,2
 mov si,2
 call rectangle
.next:
 cmp byte [di],127
 jne short .branch_continue_1780
 jmp near .end
.branch_continue_1780:
 mov al,[di]
 cbw
 call profile_x
 mov [partX],ax
 mov al,[di+1]
 cbw
 call profile_y
 mov [partY],ax
 ; Scale shared boundaries together to avoid hairline gaps between panels.
 mov al,[di]
 add al,[di+2]
 cbw
 call profile_x
 sub ax,[partX]
 jnz .width
 jmp near .nextPart
.width:
 mov bp,ax
 mov al,[di+1]
 sub al,[di+3]
 cbw
 call profile_y
 mov dx,ax
 sub dx,[partY]
 jnz .height
 jmp near .nextPart
.height:
 mov al,[di+4]
 call resolve_material
 mov ax,[partX]
 mov bx,[partY]
 mov cx,bp
 call rectangle
.nextPart:
 add di,5
 jmp .next
.end:
 pop bp
 ret
resolve_material:
 cmp al,255
 jne .ink
 mov al,[bodyInk]
.ink:
 cmp al,254
 jne .reverseLight
 mov al,10
 cmp byte [brakeHeld],0
 jne short .view_continue_2238
 jmp near .resolved
.view_continue_2238:
 mov al,13
 jmp .resolved
.reverseLight:
 cmp al,253
 jne .indicators
 mov al,5
 cmp word [gear],0
 jle short .view_continue_2246
 jmp near .resolved
.view_continue_2246:
 mov al,15
 jmp .resolved
.indicators:
 cmp al,251
 jae short .polish_continue_3685
 jmp near .resolved
.polish_continue_3685:
 mov ah,al
 mov al,10
 test byte [ticks],4
 jz .resolved
 cmp byte [hazard],0
 jne .lit
 cmp word [blinkLeft],0
 je .resolved
 cmp ah,252
 jne .rightLamp
 cmp word [signal],0
 jge .resolved
 jmp .lit
.rightLamp:
 cmp word [signal],0
 jle .resolved
.lit:
 mov al,9
.resolved:
 xor ah,ah
 mov si,ax
 ret
widthQ4 dw 0
profile_x:
 call profile_offset
 add ax,[spriteXQ3]
 jmp round_profile
profile_y:
 call profile_offset
 neg ax
 add ax,[spriteYQ3]
round_profile:
 add ax,4
 mov cl,3
 sar ax,cl
 ret
profile_offset:
 imul word [widthQ4]
 ; Signed 32-bit product divided by 64, yielding eighths of a pixel.
 mov cl,6
 mov ch,al
 shr ch,cl
 mov al,ah
 mov ah,dl
 shl ax,1
 shl ax,1
 or al,ch
 ret
scale_part:
 imul word [widthQ4]
 add ax,256
 adc dx,0
 mov al,ah
 mov ah,dl
 sar ax,1
 ret
models dw carModel,sportModel,hatchModel,suvModel,bikeModel,rickModel,pickupModel,vanModel,busModel,truckModel
