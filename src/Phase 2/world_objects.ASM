; Each queue entry is (world x, z relative to player, object type, payload).
; Insertion order resolves equal depths; paint distant objects first.
enqueue:
 push di
 push si
 mov si,bx
 add si,[camBack]
 cmp si,9
 jge short .view_continue_1167
 jmp near .done
.view_continue_1167:
 cmp si,2680
 jle short .view_continue_1169
 jmp near .done
.view_continue_1169:
 mov di,[queueUsed]
 cmp di,80*8
 jb short .view_continue_1172
 jmp near .done
.view_continue_1172:
 add word [queueUsed],8
.insert:
 or di,di
 jnz short .polish_continue_2195
 jmp near .write
.polish_continue_2195:
 cmp bx,[drawQueue+di-6]
 jle .write
 push ax
 mov ax,[drawQueue+di-8]
 mov [drawQueue+di],ax
 mov ax,[drawQueue+di-6]
 mov [drawQueue+di+2],ax
 mov ax,[drawQueue+di-4]
 mov [drawQueue+di+4],ax
 mov ax,[drawQueue+di-2]
 mov [drawQueue+di+6],ax
 pop ax
 sub di,8
 jmp .insert
.write:
 mov [drawQueue+di],ax
 mov [drawQueue+di+2],bx
 mov [drawQueue+di+4],cx
 mov [drawQueue+di+6],dx
.done:
 pop si
 pop di
 ret
roadside:
 ; Anchor features to absolute world distances so they pass smoothly in
 ; both directions. Opposite pavements have staggered houses and lamps.
 mov ax,[pz]
 xor dx,dx
 mov bx,240
 div bx
 dec ax
 mov [blockNo],ax
 mov bp,13
.block:
 mov ax,[blockNo]
 mov bx,240
 imul bx
 sub ax,[pz]
 mov [blockZ],ax
 mov si,76
 cmp byte [level],PARKING
 jne .side
 mov si,103
.side:
 mov ax,si
 add ax,62
 mov bx,[blockZ]
 mov cx,2
 mov dx,[blockNo]
 and dx,1
 call enqueue
 neg ax
 sub ax,15
 add bx,120
 xor dx,1
 call enqueue
 test byte [blockNo],1
 jnz .nextBlock
 mov ax,si
 sub ax,12
 mov bx,[blockZ]
 add bx,44
 mov cx,3
 xor dx,dx
 call enqueue
 neg ax
 add bx,240
 inc dx
 call enqueue
.nextBlock:
 inc word [blockNo]
 dec bp
 jz short .view_continue_1247
 jmp near .block
.view_continue_1247:
 ret
%include "src/phase_3_parking/parking_objects_queue.ASM"
draw_queue:
 mov di,0
.loop:
 cmp di,[queueUsed]
 jb .item
 mov byte [hazeBase],0
 mov word [farBlend],0
 ret
.item:
 mov bx,[drawQueue+di+2]
 add bx,[camBack]
 mov [objDepth],bx
 mov word [farBlend],0
 cmp bx,1800
 jb .project
 ; At the visibility limit the first pixels inherit the actual road or
 ; sky behind them. Increase optical density over the next 90 metres.
 mov ax,bx
 sub ax,1800
 mov cl,7
 shr ax,cl
 cmp ax,7
 jb .fade
 jmp near .skipObject
.fade:
 mov ah,al
 xor al,al
 add ax,blendRows
 mov [farBlend],ax
.project:
 mov ax,bx
 call set_haze
 call bend_offset
 mov bx,[objDepth]
 shl bx,1
 shl bx,1
 shl bx,1
 mov ax,[drawQueue+di+4]
 or ax,ax
 jnz .fixed
 mov si,[drawQueue+di+6]
 sub si,trafficCars
 mov cl,3
 shr si,cl
 add bx,[gapFractions+si]
 jmp .depthReady
.fixed:
 cmp ax,1
 je .depthReady
 sub bx,[playerZFraction]
.depthReady:
 mov [objDepthQ3],bx
 mov ax,[drawQueue+di]
 sub ax,[camX]
 mov cl,3
 shl ax,cl
 sub ax,[cameraXFraction]
 ; Reject objects far beyond either edge before the signed divide.
 mov cx,ax
 sar cx,1
 cmp cx,bx
 jg .skipObject
 neg cx
 cmp cx,bx
 jg .skipObject
 mov cx,FOCAL*8
 imul cx
 idiv bx
 add ax,160*8
 add ax,[bendSubpixels]
 mov [spriteXQ3],ax
 add ax,4
 mov cl,3
 sar ax,cl
 mov [spriteX],ax
 mov ax,[camFocalY]
 mov cx,64
 mul cx
 div bx
 add ax,HORIZON*8
 mov [spriteYQ3],ax
 add ax,4
 mov cl,3
 shr ax,cl
 mov [spriteY],ax
 mov bx,[drawQueue+di+4]
 shl bx,1
 mov si,[drawQueue+di+6]
 push di
 call word [drawFns+bx]
 pop di
.skipObject:
 add di,8
 jmp .loop
drawFns dw draw_traffic,draw_player,draw_house,draw_lamp,draw_parked,draw_cone,draw_p,draw_coin
size_object:
 mov bx,FOCAL*128
 mul bx
 div word [objDepthQ3]
 mov [widthQ4],ax
 add ax,8
 mov cl,4
 shr ax,cl
 or ax,ax
 jnz .size
 inc ax
.size:
 mov [spriteW],ax
 ret
draw_traffic:
 mov ax,[si+KIND]
 mov [shape],ax
 mov ax,[si+PAINTID]
 mov [bodyInk],al
 mov ax,[si+WIDE]
 shl ax,1
 call size_object
 cmp word [farBlend],0
 jne .simple
 cmp word [widthQ4],56
 jb short .polish_continue_2377
 jmp near .full
.polish_continue_2377:
.simple:
 mov bx,[shape]
 xor ax,ax
 mov al,[trafficHeights+bx]
 call scale_part
 or ax,ax
 jnz .silhouette
 ret
.silhouette:
 mov dx,ax
 mov bx,[spriteY]
 sub bx,ax
 mov cx,[spriteW]
 mov ax,cx
 shr ax,1
 sub ax,[spriteX]
 neg ax
 mov si,17
 jmp rectangle
.full:
 mov bx,[shape]
 shl bx,1
 mov di,[rearProfiles+bx]
 jmp draw_profile
trafficHeights db 22,17,27,31,53,41,32,34,41,40
draw_player:
 mov ax,[halfW]
 shl ax,1
 call size_object
 mov bx,[paint]
 mov al,[paints+bx]
 mov [bodyInk],al
 mov bx,[vehicle]
 cmp bx,PICKUP
 jne .sampled
 mov di,rearPickup
 jmp draw_profile
.sampled:
 shl bx,1
 mov di,[chaseArt+bx]
 ; A soft shadow anchors the rear art to the ground.
 mov cx,[spriteW]
 mov ax,cx
 shr ax,1
 neg ax
 add ax,[spriteX]
 mov bx,[spriteY]
 mov dx,2
 mov si,2
 call rectangle
.run:
 cmp byte [di],127
 jne short .polish_continue_2422
 jmp near .done
.polish_continue_2422:
 mov al,[di+3]
 call resolve_material
 mov al,[di]
 cbw
 add ax,[spriteX]
 push ax
 mov al,[di+1]
 cbw
 add ax,[spriteY]
 mov bx,ax
 pop ax
 xor cx,cx
 mov cl,[di+2]
 mov dx,1
 call rectangle
 add di,4
 jmp .run
.done:
 ret
draw_house:
 mov ax,88
 call size_object
 cmp word [farBlend],0
 je .detailCheck
 jmp draw_far_house
.detailCheck:
 cmp word [spriteW],10
 jae .detail
 mov di,distantHouse
 mov byte [bodyInk],19
 or si,si
 jz .draw
 mov di,distantShop
 mov byte [bodyInk],20
 jmp .draw
.detail:
 mov di,houseBrick
 mov byte [bodyInk],19
 or si,si
 jz .draw
 mov di,houseShop
 mov byte [bodyInk],20
.draw:
 jmp draw_profile
; One footprint for each far building. Roof and windows resolve nearer.
draw_far_house:
 mov di,farHouse
 jmp draw_profile
farHouse db -15,30,30,30,17,127
draw_lamp:
 mov ax,18
 call size_object
 cmp word [spriteW],5
 jb short .polish_continue_2476
 jmp near .detail
.polish_continue_2476:
 mov ax,[spriteW]
 mov dx,ax
 shl dx,1
 add dx,ax
 mov ax,[spriteX]
 mov bx,[spriteY]
 sub bx,dx
 push ax
 push bx
 mov cx,1
 mov si,4
 call rectangle
 pop bx
 pop ax
 cmp word [farBlend],0
 jne .done
 mov cx,2
 mov dx,1
 mov si,21
 jmp rectangle
.detail:
 mov di,lampRight
 or si,si
 jz .draw
 mov di,lampLeft
.draw:
 jmp draw_profile
.done:
 ret
%include "src/phase_3_parking/parking_objects_draw.ASM"
camX dw 0
camBack dw 14
camHeight dw 18
camFocalY dw FOCAL*18
floorEnd dw 134
chase db 0
groundScale dw 0
beamHalf dw 0
blockNo dw 0
blockZ dw 0
queueUsed dw 0
objDepth dw 0
drawQueue times 80*8 db 0

skyline dw 0,29,17, 19,34,12, 34,24,11, 46,38,20, 71,19,6, 79,28,12, 94,33,23, 121,36,8, 138,29,10, 154,34,18, 178,25,9, 190,34,21, 216,38,18, 259,33,11, 274,25,14, 291,31,22,-1
trafficPaint db 25,13,28,27,24,12,6,8,25,30,27,14,26,7,8,13
ink db 0
numbuf times 7 db 0
rowY dw 0
scaleY dw 0
roadWidth dw 0
roadMid dw 0
stripe dw 0
depthZ dw 0
bayLeft dw 0
bayRight dw 0
pmark db 'P',0

