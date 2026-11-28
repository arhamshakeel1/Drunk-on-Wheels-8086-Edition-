; The DOS mouse is optional. Restore the normal text mode on exit.
mouse_init:
 mov ax,3533h
 int 21h
 mov ax,es
 or ax,bx
 jz .done
 xor ax,ax
 int 33h
 or ax,ax
 jz .done
 mov byte [mouseOK],1
 mov ax,7
 xor cx,cx
 mov dx,639
 int 33h
 mov ax,8
 xor cx,cx
 mov dx,199
 int 33h
.done:
 ret

controls_tick:
 mov al,[held+72]
 mov [gasForward],al
 mov al,[held+80]
 mov [gasReverse],al
 mov al,[held+57]
 mov [brakeHeld],al
 mov al,[press+57]
 mov [brakeEdge],al
 mov byte [controlHit],0
 mov word [buttonY],142
 cmp byte [chase],0
 je .mouse
 mov word [buttonY],171
.mouse:
 cmp byte [mouseOK],0
 jne .poll
 ret
.poll:
 mov ax,3
 int 33h
 shr cx,1
 mov [mouseX],cx
 mov [mouseY],dx
 and bl,1
 mov al,bl
 xor al,[mouseHeld]
 and al,bl
 mov [mouseEdge],al
 mov [mouseHeld],bl
 cmp cx,250
 jb short .polish_continue_1504
 jmp near .pedalHit
.polish_continue_1504:
 sub dx,[buttonY]
 cmp dx,12
 jbe short .polish_continue_1507
 jmp near .done
.polish_continue_1507:
 mov di,controlBounds
 mov al,1
.hit:
 cmp cx,[di]
 jae short .polish_continue_1512
 jmp near .done
.polish_continue_1512:
 cmp cx,[di+2]
 ja short .polish_continue_1514
 jmp near .found
.polish_continue_1514:
 add di,4
 inc al
 cmp al,4
 jbe .hit
 ret
.pedalHit:
 cmp byte [chase],0
 jne .footPedals
 cmp word [vehicle],4
 jne .footPedals
 ; On the motorcycle, the lever sits just above the throttle grip.
 cmp cx,301
 ja .done
 cmp dx,144
 jb .done
 cmp dx,153
 jb .bikeBrake
 cmp dx,166
 ja .done
 jmp .gasHit
.bikeBrake:
 mov al,5
 jmp .found
.footPedals:
 cmp dx,170
 jb .done
 cmp cx,280
 jae .gasHit
 mov al,5
 jmp .found
.gasHit:
 cmp cx,291
 jb .done
 cmp cx,318
 ja .done
 mov al,6
 jmp .found
.done:
 ret
.found:
 cmp al,4
 jne .accept
 cmp byte [chase],0
 jne .accept
 cmp word [vehicle],4
 je .done
.accept:
 mov [controlHit],al
 cmp byte [mouseHeld],0
 je .done
 cmp al,5
 je .brake
 cmp al,6
 je .gas
 cmp byte [mouseEdge],0
 je .done
 xor ah,ah
 mov bx,ax
 mov bl,[controlKeys+bx-1]
 mov byte [press+bx],1
 ret
.brake:
 mov byte [brakeHeld],1
 mov al,[mouseEdge]
 or [brakeEdge],al
 ret
.gas:
 cmp word [gear],0
 jl .reverse
 mov byte [gasForward],1
 ret
.reverse:
 mov byte [gasReverse],1
 ret

; A second tap cancels a manual indicator. Lane-change assist still uses
; its timed signal when there is no latched manual indication.
choose_signal:
 cmp ax,[signal]
 jne .on
 cmp word [blinkLeft],-1
 jne .on
 mov word [blinkLeft],0
 mov word [signal],0
 ret
.on:
 mov [signal],ax
 mov word [blinkLeft],-1
 ret
wiper_tick:
 cmp byte [press+17],0       ; W or dashboard wiper button
 je .sweep
 xor byte [wiperOn],1
.sweep:
 cmp byte [wiperOn],0
 jne .advance
 cmp word [wiperPhase],0
 je .done
.advance:
 inc word [wiperPhase]
 cmp word [wiperPhase],48
 jb .done
 mov word [wiperPhase],0
.done:
 ret
draw_wiper:
 cmp word [vehicle],4
 jne short .route_continue_1495
 jmp near .done
.route_continue_1495:
 mov bx,[wiperPhase]
 cmp bx,24
 jbe .pose
 neg bx
 add bx,48
.pose:
 shl bx,1
 shl bx,1
 mov di,bx
 mov al,[wiperPath+di]
 cbw
 add ax,179
 mov [lineX2],ax
 mov al,[wiperPath+di+1]
 cbw
 add ax,126
 mov [lineY2],ax
 mov ax,179
 mov bx,126
 mov si,4
 call line
 mov ax,[lineX2]
 mov bx,[lineY2]
 push ax
 push bx
 mov al,[wiperPath+di+2]
 cbw
 add ax,179
 mov [lineX2],ax
 mov al,[wiperPath+di+3]
 cbw
 add ax,126
 mov [lineY2],ax
 pop bx
 pop ax
 mov si,1
 call line
.done:
 ret

; Same rectangles drive hit testing, hover and drawing in either view.
controlBounds dw 176,191, 194,209, 212,227, 230,245
controlKeys db 44,47,45,17
controlIcons:
 db 10h,30h,70h,0ffh,70h,30h,10h
 db 18h,24h,24h,42h,5ah,81h,0ffh
 db 08h,0ch,0eh,0ffh,0eh,0ch,08h
 db 0,81h,81h,99h,99h,0a5h,42h
mouseOK db 0
mouseHeld db 0
mouseEdge db 0
mouseX dw 0
mouseY dw 0
controlHit db 0
gasForward db 0
gasReverse db 0
brakeHeld db 0
brakeEdge db 0
buttonY dw 142
wiperPhase dw 0
wiperOn db 0
buttonInks times 4 db 0
draw_controls:
 mov di,buttonInks
 mov cx,4
.init:
 mov byte [di],5
 inc di
 loop .init
 cmp byte [wiperOn],0
 je .blink
 mov byte [buttonInks+3],12
.blink:
 cmp byte [hazard],0
 je .turn
 mov byte [buttonInks+1],13
 test byte [ticks],4
 jz .faces
 mov byte [buttonInks],9
 mov byte [buttonInks+2],9
 jmp .faces
.turn:
 cmp word [blinkLeft],0
 je .faces
 test byte [ticks],4
 jz .faces
 cmp word [signal],0
 jl .left
 mov byte [buttonInks+2],12
 jmp .faces
.left:
 mov byte [buttonInks],12
.faces:
 xor bp,bp
 mov di,controlBounds
.face:
 mov ax,[di]
 mov cx,[di+2]
 sub cx,ax
 inc cx
 mov bx,[buttonY]
 mov dx,13
 mov si,3
 mov ax,bp
 inc ax
 cmp al,[controlHit]
 jne .shade
 mov si,4
.shade:
 mov ax,[di]
 call rectangle
 mov bx,[buttonY]
 add bx,3
 call paint_control_icon
 add di,4
 inc bp
 cmp byte [chase],0
 jne .allButtons
 cmp word [vehicle],4
 jne .allButtons
 cmp bp,3
 jb .moreButtons
 ret
.allButtons:
 cmp bp,4
 jae .pedals
.moreButtons:
 jmp near .face
.pedals:
 BOX 250,169,70,31,0
 BOX 251,169,68,1,3
 BOX 262,172,5,13,4
 BOX 300,171,4,24,4
 mov word [pedalY],178
 mov si,5
 cmp byte [brakeHeld],0
 je .brake
 add word [pedalY],3
 mov si,13
.brake:
 mov [pedalInk],si
 BOX 253,[pedalY],25,10,2
 inc word [pedalY]
 BOX 255,[pedalY],21,7,[pedalInk]
 inc word [pedalY]
 BOX 257,[pedalY],17,2,4
 add word [pedalY],3
 BOX 257,[pedalY],17,2,4
 mov word [pedalY],173
 mov si,5
 cmp byte [brakeHeld],0
 jne .gas
 mov al,[gasForward]
 or al,[gasReverse]
 jz .gas
 add word [pedalY],3
 mov si,12
.gas:
 mov [pedalInk],si
 BOX 295,[pedalY],14,22,2
 inc word [pedalY]
 BOX 297,[pedalY],10,19,[pedalInk]
 BOX 298,[pedalY],2,17,4
 BOX 303,[pedalY],2,17,4
 ret
paint_control_icon:
 push di
 push bp
 mov ax,bp
 mov si,7
 mul si
 mov si,ax
 add si,controlIcons
 ; Convert y*320+x without losing the icon source or colour index.
 mov ax,bx
 shl ax,1
 shl ax,1
 add ax,bx
 mov cl,6
 shl ax,cl
 add ax,[di]
 add ax,4
 mov di,ax
 mov dl,[ds:buttonInks+bp]
 mov es,[canvas]
 mov bp,7
.row:
 lodsb
 mov cx,8
.bit:
 shl al,1
 jnc .clear
 mov [es:di],dl
.clear:
 inc di
 loop .bit
 add di,312
 dec bp
 jnz .row
 pop bp
 pop di
 ret
pedalY dw 0
pedalInk dw 0
draw_pointer:
 cmp byte [mouseOK],0
 jne short .route_continue_1681
 jmp near .done
.route_continue_1681:
 mov bx,[mouseY]
 cmp byte [controlHit],0
 jne .visible
 sub bx,[buttonY]
 add bx,5
 cmp bx,24
 jbe short .polish_continue_1772
 jmp near .done
.polish_continue_1772:
.visible:
 mov ax,[mouseX]
 mov bx,[mouseY]
 mov cx,2
 mov dx,6
 mov si,0
 call rectangle
 mov ax,[mouseX]
 mov bx,[mouseY]
 mov cx,1
 mov dx,5
 mov si,15
 call rectangle
 mov ax,[mouseX]
 mov bx,[mouseY]
 add bx,2
 mov cx,3
 mov dx,1
 mov si,15
 jmp rectangle
.done:
 ret

wiperPath:
 db -35,-4,-84,-9
 db -34,-7,-82,-17
 db -33,-10,-80,-25
 db -32,-13,-78,-32
 db -31,-16,-74,-39
 db -29,-19,-70,-46
 db -27,-22,-65,-53
 db -25,-25,-60,-59
 db -22,-27,-54,-64
 db -20,-29,-48,-69
 db -17,-31,-41,-73
 db -14,-32,-33,-77
 db -11,-33,-26,-80
 db -8,-34,-18,-82
 db -4,-35,-10,-83
 db -1,-35,-2,-84
 db 2,-35,6,-84
 db 6,-35,14,-83
 db 9,-34,22,-81
 db 12,-33,29,-79
 db 15,-31,37,-75
 db 18,-30,44,-72
 db 21,-28,51,-67
 db 24,-26,57,-62
 db 26,-23,62,-56

