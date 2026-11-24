; drive.asm - Harbour Drive
; NASM / 8086 / DOS .COM / VGA mode 13h
;
; 1 Highway   2 Parking   3 Phase 1 exhibit   Esc menu/exit
; Up throttle   Space brake   Down reverse from rest
; Left/Right change highway lane or steer while parking
; V camera   I ignition   N night   H headlights   W wipers
; R rain     X hazards    C cruise  P pause       Enter dismiss result

cpu 8086
bits 16
org 100h
jmp start

; The original 8086 has only short conditional branches. Use a nearby
; inverted path and an unconditional near jump for distant destinations.
%macro GO 2
    %1 short %%taken
    jmp short %%past
%%taken:
    jmp near %2
%%past:
%endmacro

; AX=x, BX=y, CX=width, DX=height, SI=palette index
%macro BOX 5
    mov ax,%1
    mov bx,%2
    mov cx,%3
    mov dx,%4
    mov si,%5
    call rect
%endmacro

; Text coordinates are BIOS-style character cells, 40 columns x 25 rows.
%macro SAY 4
    mov di,buffer+(%2)*4*160+(%1)*4
    mov si,%3
    mov dl,%4
    call lettering
%endmacro

%macro NUM 5
    mov ax,%3
    call decimal
    SAY %1,%2,digits+5-(%4),%5
%endmacro

%macro TOGGLE 2
    mov bx,%1
    call edge
    jz %%skip
    xor byte [%2],1
%%skip:
%endmacro

oldIRQ dd 0
oldMode db 3
held times 128 db 0
pressed times 128 db 0
skip db 0
last dw 0
best dw 0
mode db 0

; Cleared as a unit on level entry. Camera changes never enter this path.
state:
engine db 0
night db 0
lights db 0
wiper db 0
rain db 0
hazard db 0
chase db 0
paused db 0
reverse db 0
cruise db 0
outcome db 0
speed dw 0
rpm dw 0
temp dw 0
fuel dw 0
timer dw 0
ticks dw 0
trip dw 0
furthest dw 0
odo dw 0                         ; quarter metres
score dw 0
hits dw 0
tickets dw 0
flash dw 0
signal db 0                      ; 0 red, 1 green, 2 amber
junction dw 0
fraction dw 0
carX dw 0
target dw 0
steer dw 0
px dw 0
py dw 0
gap dw 0
traffic times 4 dw 0
stateEnd:

; All renderer scratch lives outside the simulation state.
cam dw 0
zval dw 0
factor dw 0
baseY dw 0
midX dw 0
screenX dw 0
widthV dw 0
heightV dw 0
style dw 0
indexV dw 0
side dw 0
blockNo dw 0
blockZ dw 0
leftX dw 0
topY dw 0
colour dw 0
newX dw 0
newY dw 0
clearance dw 0
lx dw 0
ly dw 0
ex dw 0
ey dw 0
ddx dw 0
ddy dw 0
ix dw 0
iy dw 0
err dw 0
digits db '00000',0

lanes dw -32,0,32,-64
periods dw 3,4,5,2
cars dw 12,3,9,14,23
; Inclusive parking rectangles: left, right, top, bottom.
obs dw 16,30,13,32, 65,81,14,34, 17,30,53,70
    dw 36,38,35,38, 58,60,35,38
bay dw 40,12,56,12,56,34,40,34,40,12
; Custom palette indices 16..31:
; sky, pavement, asphalt, brick, plaster, glass, dash, orange,
; grass, lamp, distant tower, shadow, steel, light glass, wet road, paint.
day db 26,44,60, 40,42,44, 25,26,28, 43,26,20
    db 48,41,29, 16,28,39, 14,20,27, 63,28,4
    db 16,35,19, 62,52,23, 29,40,49, 9,11,15
    db 35,40,45, 42,54,59, 20,25,30, 57,58,55
dark db 3,5,13, 10,13,19, 7,8,13, 12,10,16
     db 12,15,21, 40,34,15, 7,12,17, 47,19,3
     db 4,13,9, 63,47,18, 8,12,21, 2,3,6
     db 22,29,36, 38,40,30, 8,13,21, 29,32,36

; Readable 3x5 glyphs. Two logical rows share a text cell boundary,
; so UI labels below are kept at least two character rows apart.
font db 7,5,5,5,7, 2,6,2,2,7, 7,1,7,4,7, 7,1,7,1,7
     db 5,5,7,1,1, 7,4,7,1,7, 7,4,7,5,7, 7,1,1,1,1
     db 7,5,7,5,7, 7,5,7,1,7
     db 2,5,7,5,5, 6,5,6,5,6, 7,4,4,4,7, 6,5,5,5,6
     db 7,4,6,4,7, 7,4,6,4,4, 7,4,5,5,7, 5,5,7,5,5
     db 7,2,2,2,7, 1,1,1,5,7, 5,5,6,5,5, 4,4,4,4,7
     db 5,7,7,5,5, 5,7,7,7,5, 7,5,5,5,7, 7,5,7,4,4
     db 7,5,5,7,1, 6,5,6,5,5, 7,4,7,1,7, 7,2,2,2,2
     db 5,5,5,5,7, 5,5,5,5,2, 5,5,7,7,5, 5,5,2,5,5
     db 5,5,2,2,2, 7,1,2,4,7
title db 'HARBOUR DRIVE',0
subTitle db 'DR DRIVING LITE',0
m1 db '1   HIGHWAY',0
m2 db '2   MARINA PARKING',0
m3 db '3   PHASE ONE EXHIBIT',0
m4 db 'ESC EXIT',0
help1 db 'UP GAS   SPACE BRAKE   DOWN REVERSE',0
help2 db 'ARROWS STEER   V CAMERA   P PAUSE',0
help3 db 'I ENGINE  H LIGHTS  N NIGHT  R RAIN',0
help4 db 'W WIPERS   X HAZARDS   C CRUISE',0
sTime db 'TIME',0
sDist db 'DIST',0
sScore db 'PTS',0
sPark db 'PARKING L2',0
sGap db 'GAP',0
sCell db 'CELLS',0
sFpp db 'FPP',0
sTpp db 'TPP',0
sDemo db 'EXHIBIT',0
sSpeed db 'KM/H',0
sRpm db 'RPM',0
sTemp db 'TEMP',0
sFuel db 'E    F',0
sGas db 'GAS',0
sBrake db 'BRAKE',0
sIgn db 'IGN',0
sLight db 'HL',0
sHaz db 'HAZ',0
sD db 'D',0
sR db 'R',0
sP db 'P',0
sHit db 'IMPACT',0
sRed db 'RED LIGHT',0
sPause db 'PAUSED',0
sWin db 'MISSION COMPLETE',0
sTimeout db 'TIME EXPIRED',0
sEmpty db 'OUT OF FUEL',0
sOdo db 'ODO M',0
sHits db 'IMPACTS',0
sTickets db 'RED LIGHTS',0
sBest db 'BEST',0
sBack db 'ENTER FOR MENU',0
shops dw cafe,hotel,auto,med
cafe db 'CAFE',0
hotel db 'INN',0
auto db 'AUTO',0
med db 'MED',0

start:
    push cs
    pop ds
    cld
    mov ah,0Fh
    int 10h
    mov [oldMode],al
    mov ax,13h
    int 10h
    mov ax,3509h
    int 21h
    mov [oldIRQ],bx
    mov [oldIRQ+2],es
    mov dx,keyboard
    mov ax,2509h
    int 21h

menu:
    mov byte [night],0
    call palette
    call clearEdges
    BOX 0,0,160,100,22
    BOX 0,0,160,25,16
    BOX 0,24,160,2,23
    BOX 15,29,130,40,27
    SAY 13,1,title,0
    SAY 12,4,subTitle,15
    SAY 8,8,m1,15
    SAY 8,10,m2,15
    SAY 8,12,m3,14
    SAY 8,15,m4,7
    SAY 2,18,help1,15
    SAY 2,20,help2,15
    SAY 2,22,help3,7
    call present
.wait:
    mov bx,1
    call edge
    GO jnz,quit
    mov bx,2
    call edge
    mov al,1
    jnz begin
    inc bx
    call edge
    mov al,2
    jnz begin
    inc bx
    call edge
    mov al,3
    jz .wait

begin:
    mov [mode],al
    push ds
    pop es
    mov di,state
    xor ax,ax
    mov cx,stateEnd-state
    rep stosb
    mov byte [engine],1
    mov word [rpm],800
    mov word [temp],30
    mov word [fuel],1000
    mov word [timer],2184
    mov word [junction],160
    mov word [px],48
    mov word [py],78
    mov word [traffic],45
    mov word [traffic+2],115
    mov word [traffic+4],78
    mov word [traffic+6],94
    cmp byte [mode],2
    jne .demo
    mov word [score],500
    mov ax,[px]
    mov [newX],ax
    mov ax,[py]
    mov [newY],ax
    call measure
    mov ax,[clearance]
    mov [gap],ax
.demo:
    cmp byte [mode],3
    jne .ready
    mov word [speed],78
    mov word [trip],420
    mov word [odo],1680
    mov word [score],4793
    mov word [fuel],500
    mov word [rpm],2750
    mov word [temp],76
    mov word [timer],1092
    mov word [junction],560
.ready:
    call clearEdges
    call palette
    call frame
    call clockRead
    mov [last],ax

main:
    mov bx,1
    call edge
    GO jnz,menu
    cmp byte [mode],3
    GO je,main
    mov bx,19h
    call edge
    jz .clock
    xor byte [paused],1
    call clearEdges
    call frame
    call clockRead
    mov [last],ax
.clock:
    call clockRead
    mov dx,ax
    sub ax,[last]
    GO jz,main
    mov [last],dx
    cmp byte [paused],0
    GO jne,main
    cmp ax,18
    jbe .tick
    mov ax,1
.tick:
    push ax
    call controls
    call simulate
    pop ax
    cmp byte [outcome],0
    GO jne,summary
    dec ax
    jnz .tick
    call frame
    jmp main

keyboard:
    push ax
    push bx
    push ds
    push cs
    pop ds
    in al,60h
    cmp byte [skip],0
    je .prefix
    dec byte [skip]
    jmp short .ack
.prefix:
    cmp al,0E1h
    jne .extended
    mov byte [skip],5
    jmp short .ack
.extended:
    cmp al,0E0h
    je .ack
    xor bx,bx
    mov bl,al
    and bl,7Fh
    test al,80h
    jnz .up
    cmp byte [held+bx],0
    jne .ack
    mov byte [held+bx],1
    mov byte [pressed+bx],1
    jmp short .ack
.up:
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

edge:
    xor al,al
    xchg al,[pressed+bx]
    or al,al
    ret

clearEdges:
    pushf
    cli
    push ds
    pop es
    mov di,pressed
    xor ax,ax
    mov cx,128
    rep stosb
    popf
    ret

clockRead:
    push es
    mov ax,40h
    mov es,ax
    mov ax,[es:6Ch]
    pop es
    ret

palette:
    mov si,day
    cmp byte [night],0
    je .load
    mov si,dark
.load:
    mov dx,3C8h
    mov al,16
    out dx,al
    inc dx
    mov cx,48
.write:
    lodsb
    out dx,al
    loop .write
    ret

controls:
    TOGGLE 2Fh,chase
    TOGGLE 23h,lights
    TOGGLE 11h,wiper
    TOGGLE 13h,rain
    TOGGLE 2Dh,hazard
    mov bx,31h
    call edge
    jz .ign
    xor byte [night],1
    call palette
.ign:
    mov bx,17h
    call edge
    jz .cruise
    xor byte [engine],1
    mov byte [cruise],0
.cruise:
    mov bx,2Eh
    call edge
    jz .gear
    cmp byte [mode],1
    jne .gear
    cmp byte [engine],1
    jne .gear
    cmp byte [reverse],0
    jne .gear
    cmp word [speed],0
    je .gear
    xor byte [cruise],1
.gear:
    mov bx,50h
    call edge
    jz .steering
    cmp word [speed],0
    jne .steering
    cmp byte [engine],1
    jne .steering
    cmp byte [held+39h],0
    jne .steering
    mov byte [reverse],1
    mov word [speed],6
.steering:
    mov bx,4Bh
    call edge
    mov ah,al
    mov bx,4Dh
    call edge
    cmp byte [mode],2
    je .lot
    sub al,ah
    cbw
    mov bx,32
    imul bx
    add ax,[target]
    cmp ax,-32
    jge .right
    mov ax,-32
.right:
    cmp ax,32
    jle .save
    mov ax,32
.save:
    mov [target],ax
    mov word [steer],0
    sub ax,[carX]
    jz .done
    mov bx,2
    jg .move
    neg bx
.move:
    add [carX],bx
    mov [steer],bx
.done:
    ret
.lot:
    mov al,[held+4Dh]
    sub al,[held+4Bh]
    cbw
    mov [steer],ax
    ret

simulate:
    inc word [ticks]
    dec word [timer]
    jnz .live
    mov byte [outcome],2
    ret
.live:
    cmp word [flash],0
    je .pedals
    dec word [flash]
.pedals:
    mov ax,[speed]
    cmp byte [held+39h],0
    je .throttle
    mov byte [cruise],0
    sub ax,4
    jnc .save
    xor ax,ax
    jmp short .save
.throttle:
    cmp byte [engine],0
    je .coast
    cmp byte [held+48h],0
    je .coast
    or ax,ax
    jnz .limit
    mov byte [reverse],0
.limit:
    mov bx,200
    cmp byte [mode],2
    jne .rev
    mov bx,20
.rev:
    cmp byte [reverse],0
    je .accelerate
    mov bx,12
.accelerate:
    cmp ax,bx
    jae .save
    test word [ticks],1
    jnz .save
    cmp ax,110
    jb .add
    test word [ticks],3
    jnz .save
.add:
    inc ax
    jmp short .save
.coast:
    cmp byte [cruise],0
    jne .save
    test word [ticks],15
    jnz .save
    or ax,ax
    jz .save
    dec ax
.save:
    mov [speed],ax
    or ax,ax
    jnz .motor
    mov word [fraction],0
.motor:
    call motor
    cmp word [fuel],0
    jne .world
    mov byte [outcome],3
    ret
.world:
    cmp byte [mode],2
    je .travel
    call trafficTick
    call highwayHit
.travel:
    mov ax,[speed]
    add [fraction],ax
    mov bx,65
    cmp byte [mode],2
    jne .steps
    mov bx,16
.steps:
    cmp [fraction],bx
    jb .end
    sub [fraction],bx
    push bx
    cmp byte [mode],2
    je .lot
    call highwayStep
    jmp short .next
.lot:
    call parkStep
.next:
    pop bx
    cmp byte [outcome],0
    je .steps
.end:
    cmp byte [mode],2
    jne .done
    cmp word [speed],0
    jne .done
    cmp word [px],43
    jb .done
    cmp word [px],53
    ja .done
    cmp word [py],18
    jb .done
    cmp word [py],28
    ja .done
    cmp word [gap],0
    jle .done
    mov byte [outcome],1
.done:
    ret

motor:
    xor ax,ax
    cmp byte [engine],0
    je .rpm
    mov ax,[speed]
    mov bx,23
    mul bx
    add ax,800
    cmp byte [held+48h],0
    je .rpm
    add ax,400
.rpm:
    mov [rpm],ax
    test word [ticks],7
    jnz .done
    mov bx,30
    cmp byte [engine],0
    je .thermal
    mov bx,82
    cmp word [speed],0
    jne .consume
    test word [ticks],31
    jnz .thermal
.consume:
    dec word [fuel]
    cmp ax,4000
    jb .thermal
    mov bx,110
    cmp word [fuel],0
    je .thermal
    dec word [fuel]
.thermal:
    cmp [temp],bx
    je .done
    jb .warmer
    dec word [temp]
    ret
.warmer:
    inc word [temp]
.done:
    ret

trafficTick:
    mov ax,[ticks]
    xor dx,dx
    mov bx,216
    div bx
    mov byte [signal],0
    cmp dx,70
    jb .cars
    mov byte [signal],1
    cmp dx,186
    jb .cars
    mov byte [signal],2
.cars:
    xor di,di
.car:
    mov ax,[ticks]
    xor dx,dx
    div word [periods+di]
    or dx,dx
    jnz .next
    cmp di,6
    je .incoming
    ; Car front bumper must respect the same stop line drawn on screen.
    mov ax,[trip]
    add ax,[traffic+di]
    add ax,3
    mov bx,[junction]
    sub bx,ax
    cmp bx,1
    ja .forward                 ; unsigned also covers already past line
    cmp byte [signal],1
    jne .next
.forward:
    inc word [traffic+di]
    cmp word [traffic+di],195
    jbe .next
    mov word [traffic+di],155
    jmp short .next
.incoming:
    dec word [traffic+di]
    jns .next
    mov word [traffic+di],175
.next:
    add di,2
    cmp di,8
    jb .car
    ret

highwayStep:
    cmp byte [reverse],0
    jne .back
    inc word [trip]
    mov ax,[trip]
    cmp ax,[furthest]
    jbe .junction
    mov [furthest],ax
    add word [score],5
.junction:
    cmp ax,[junction]
    jb .front
    add word [junction],200
    cmp byte [signal],0
    jne .front
    inc word [tickets]
    mov ax,75
    call deduct
    mov word [flash],18
.front:
    xor di,di
.traffic:
    dec word [traffic+di]
    jns .advance
    mov word [traffic+di],175
.advance:
    add di,2
    cmp di,8
    jb .traffic
    jmp short .moved
.back:
    cmp word [trip],0
    jne .reverseStep
    mov word [speed],0
    mov word [fraction],0
    ret
.reverseStep:
    dec word [trip]
    xor di,di
.away:
    cmp word [traffic+di],195
    jae .n
    inc word [traffic+di]
.n:
    add di,2
    cmp di,8
    jb .away
.moved:
    add word [odo],4
    call highwayHit
    cmp word [trip],1000
    jb .done
    mov byte [outcome],1
.done:
    ret

highwayHit:
    xor di,di
.next:
    cmp word [traffic+di],6
    ja .advance
    mov ax,[lanes+di]
    sub ax,[carX]
    jns .width
    neg ax
.width:
    cmp ax,13
    ja .advance
    mov word [traffic+di],175
    call crash
.advance:
    add di,2
    cmp di,6
    jb .next
    ret

deduct:
    sub [score],ax
    jnc .done
    mov word [score],0
.done:
    ret

crash:
    mov word [speed],0
    mov word [fraction],0
    mov byte [cruise],0
    cmp word [flash],18
    ja .done
    mov ax,50
    call deduct
    inc word [hits]
    mov word [flash],45
.done:
    ret

parkStep:
    mov ax,[px]
    mov bx,[py]
    mov dx,[steer]
    cmp byte [reverse],0
    jne .back
    add ax,dx
    dec bx
    jmp short .check
.back:
    sub ax,dx
    inc bx
.check:
    mov [newX],ax
    mov [newY],bx
    call measure
    cmp word [clearance],0
    jle .hit
    mov ax,[newX]
    mov [px],ax
    mov ax,[newY]
    mov [py],ax
    mov ax,[clearance]
    mov [gap],ax
    inc word [odo]
    ret
.hit:
    call crash
    ret

; Minimum square clearance from full vehicle footprint to obstacles/walls.
measure:
    mov ax,[newX]
    sub ax,3
    mov [clearance],ax
    mov ax,93
    sub ax,[newX]
    call minimum
    mov ax,[newY]
    sub ax,6
    call minimum
    mov ax,90
    sub ax,[newY]
    call minimum
    xor di,di
.obj:
    mov ax,[obs+di]
    sub ax,[newX]
    sub ax,3
    mov bx,[newX]
    sub bx,3
    sub bx,[obs+di+2]
    cmp ax,bx
    jge .gx
    mov ax,bx
.gx:
    mov cx,ax
    mov ax,[obs+di+4]
    sub ax,[newY]
    sub ax,6
    mov bx,[newY]
    sub bx,6
    sub bx,[obs+di+6]
    cmp ax,bx
    jge .gy
    mov ax,bx
.gy:
    cmp ax,cx
    jge .min
    mov ax,cx
.min:
    call minimum
    add di,8
    cmp di,40
    jb .obj
    ret
minimum:
    cmp ax,[clearance]
    jge .done
    mov [clearance],ax
.done:
    ret

; --------------------------- Drawing primitives -------------------------
rect:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    push ds
    pop es
    test ax,ax
    jns .x
    add cx,ax
    xor ax,ax
.x:
    test bx,bx
    jns .y
    add dx,bx
    xor bx,bx
.y:
    cmp ax,160
    jae .done
    cmp bx,100
    jae .done
    mov di,160
    sub di,ax
    cmp cx,di
    jle .w
    mov cx,di
.w:
    mov di,100
    sub di,bx
    cmp dx,di
    jle .h
    mov dx,di
.h:
    or cx,cx
    jle .done
    or dx,dx
    jle .done
    mov di,ax
    push dx
    mov ax,160
    mul bx
    add di,ax
    add di,buffer
    pop dx
    mov bp,160
    sub bp,cx
    mov ax,si
.row:
    push cx
    rep stosb
    pop cx
    add di,bp
    dec dx
    jnz .row
.done:
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

line:
    mov [lx],ax
    mov [ly],bx
    mov [ex],cx
    mov [ey],dx
    mov word [ix],1
    sub cx,ax
    jns .dx
    neg cx
    mov word [ix],-1
.dx:
    mov [ddx],cx
    mov word [iy],1
    sub dx,bx
    jns .dy
    neg dx
    mov word [iy],-1
.dy:
    neg dx
    mov [ddy],dx
    add cx,dx
    mov [err],cx
.dot:
    mov ax,[lx]
    mov bx,[ly]
    mov cx,1
    mov dx,1
    call rect
    cmp ax,[ex]
    jne .step
    cmp bx,[ey]
    je .done
.step:
    mov ax,[err]
    shl ax,1
    mov di,ax
    cmp di,[ddy]
    jl .vertical
    mov ax,[ddy]
    add [err],ax
    mov ax,[ix]
    add [lx],ax
.vertical:
    cmp di,[ddx]
    jg .dot
    mov ax,[ddx]
    add [err],ax
    mov ax,[iy]
    add [ly],ax
    jmp .dot
.done:
    ret

%macro LINE 5
    mov ax,%1
    mov bx,%2
    mov cx,%3
    mov dx,%4
    mov si,%5
    call line
%endmacro

decimal:
    mov di,digits+4
    mov cx,5
    mov bx,10
.digit:
    xor dx,dx
    div bx
    add dl,'0'
    mov [di],dl
    dec di
    loop .digit
    ret

; DI points to a logical pixel in the buffer. Each glyph is clipped at
; the screen's right edge. Dynamic shop signs are checked before entry.
lettering:
    push bp
    mov bp,di
    sub bp,buffer
    mov ax,bp
    push dx
    xor dx,dx
    mov bx,160
    div bx
    mov bp,160
    sub bp,dx
    pop dx
.char:
    cmp bp,3
    jb .done
    lodsb
    or al,al
    jz .done
    cmp al,'/'
    jne .lookup
    mov [di+2],dl
    mov [di+161],dl
    mov [di+321],dl
    mov [di+480],dl
    jmp short .next
.lookup:
    cmp al,'0'
    jb .next
    cmp al,'9'
    jbe .digit
    cmp al,'A'
    jb .next
    cmp al,'Z'
    ja .next
    sub al,'A'-10
    jmp short .glyph
.digit:
    sub al,'0'
.glyph:
    xor ah,ah
    mov bx,ax
    shl ax,1
    shl ax,1
    add bx,ax
    push di
    mov cx,5
.row:
    mov al,[font+bx]
    test al,4
    jz .mid
    mov [di],dl
.mid:
    test al,2
    jz .right
    mov [di+1],dl
.right:
    test al,1
    jz .down
    mov [di+2],dl
.down:
    inc bx
    add di,160
    loop .row
    pop di
.next:
    add di,4
    sub bp,4
    jc .done
    jmp .char
.done:
    pop bp
    ret

present:
    mov ax,0A000h
    mov es,ax
    mov si,buffer
    xor di,di
    mov bx,100
.row:
    mov cx,160
.pixel:
    lodsb
    mov ah,al
    mov [es:di+320],ax
    stosw
    loop .pixel
    add di,320
    dec bx
    jnz .row
    ret

; ----------------------------- World renderer ---------------------------
frame:
    BOX 0,0,160,100,16
    BOX 0,40,160,60,17
    cmp byte [night],0
    jne .moon
    BOX 87,12,7,6,14
    BOX 60,18,12,2,15
    BOX 64,16,5,2,15
    jmp short .city
.moon:
    BOX 87,12,7,6,15
    BOX 90,11,5,5,16
.city:
    BOX 58,29,10,12,26
    BOX 69,24,8,17,26
    BOX 79,30,12,11,26
    BOX 93,26,9,15,26
    cmp byte [mode],2
    je .parking
    mov ax,[carX]
    cmp byte [chase],0
    je .cam
    sar ax,1
.cam:
    mov [cam],ax
    call streets
    call road
    call crossing
    call drawTraffic
    jmp short .view
.parking:
    call parkingView
.view:
    call weather
    cmp byte [chase],0
    je .cockpit
    call exterior
    jmp short .hud
.cockpit:
    call cockpit
.hud:
    call hud
    cmp byte [paused],0
    je .show
    BOX 38,43,84,14,27
    SAY 17,12,sPause,14
.show:
    call present
    ret

; AX = distance ahead. In chase view the virtual eye trails the player.
; BX = baseline; CX = road half-width on that scanline.
project:
    cmp byte [chase],0
    je .depth
    add ax,12
.depth:
    add ax,22
    mov bx,ax
    mov ax,1000
    xor dx,dx
    div bx
    mov bx,36
    add bx,ax
    mov cx,bx
    sub cx,40
    shl cx,1
    add cx,12
    ret

roadCentre:
    push dx
    push cx
    mov ax,[cam]
    add ax,16
    imul cx
    mov cx,64
    idiv cx
    neg ax
    add ax,80
    pop cx
    pop dx
    ret

streets:
    mov ax,[trip]
    xor dx,dx
    mov bx,40
    div bx
    add ax,4
    mov [blockNo],ax
    mov ax,160
    sub ax,dx
    mov [blockZ],ax
.block:
    mov ax,[blockZ]
    call project
    mov [baseY],bx
    mov [factor],cx
    call roadCentre
    mov [midX],ax
    mov word [side],0
.side:
    mov ax,[factor]
    shr ax,1
    add ax,5
    mov [widthV],ax
    mov dx,[blockNo]
    add dx,[side]
    and dx,3
    shl dx,1
    shl dx,1
    add dx,ax
    mov [heightV],dx
    mov ax,[midX]
    cmp word [side],0
    jne .right
    sub ax,[factor]
    sub ax,[widthV]
    sub ax,3
    jmp short .facade
.right:
    add ax,[factor]
    add ax,3
.facade:
    mov [leftX],ax
    mov bx,[baseY]
    sub bx,dx
    mov [topY],bx
    mov cx,[widthV]
    mov si,19
    mov di,[blockNo]
    add di,[side]
    test di,1
    jz .paint
    mov si,20
.paint:
    call rect
    add ax,2
    add bx,2
    sub cx,4
    mov dx,2
    mov si,21
    call rect
    add bx,4
    call rect
    add bx,4
    call rect
    mov ax,[leftX]
    inc ax
    mov bx,[baseY]
    sub bx,6
    mov cx,[widthV]
    sub cx,2
    mov dx,5
    mov si,27
    call rect
    ; Only near, sufficiently wide shopfronts get lettering.
    cmp cx,18
    jb .lamp
    cmp ax,0
    jl .lamp
    cmp ax,141
    ja .lamp
    push ax
    mov ax,bx
    mov cx,160
    mul cx
    mov di,ax
    pop ax
    add di,ax
    add di,buffer
    mov bx,[blockNo]
    add bx,[side]
    and bx,3
    shl bx,1
    mov si,[shops+bx]
    mov dl,31
    call lettering
.lamp:
    mov ax,[midX]
    cmp word [side],0
    jne .lampRight
    sub ax,[factor]
    sub ax,2
    jmp short .pole
.lampRight:
    add ax,[factor]
    add ax,2
.pole:
    mov dx,[factor]
    shr dx,1
    add dx,2
    mov bx,[baseY]
    sub bx,dx
    mov cx,1
    mov si,22
    call rect
    mov cx,3
    mov dx,1
    mov si,28
    cmp byte [night],0
    je .head
    mov si,25
.head:
    call rect
    inc word [side]
    cmp word [side],2
    GO jb,.side
    dec word [blockNo]
    sub word [blockZ],40
    GO jns,.block
    ret

road:
    mov word [baseY],40
.scan:
    mov bx,[baseY]
    mov cx,bx
    sub cx,40
    shl cx,1
    add cx,12
    mov [factor],cx
    call roadCentre
    mov [midX],ax
    sub ax,cx
    shl cx,1
    inc cx
    mov dx,1
    mov si,18
    cmp byte [rain],0
    je .surface
    mov si,30
.surface:
    call rect
    cmp byte [night],0
    je .marks
    cmp byte [lights],0
    je .marks
    cmp bx,50
    jb .marks
    ; Keep the illuminated strip inside the actual carriageway.
    mov cx,[factor]
    shr cx,1
    mov ax,[midX]
    sub ax,cx
    shl cx,1
    mov si,8
    call rect
.marks:
    mov ax,[midX]
    sub ax,[factor]
    mov cx,1
    mov si,31
    call rect
    mov ax,[midX]
    add ax,[factor]
    call rect
    mov ax,[factor]
    shr ax,1
    mov cx,[midX]
    sub cx,ax
    mov ax,cx
    mov cx,1
    mov si,14
    call rect
    sub ax,2
    call rect
    mov ax,[baseY]
    sub ax,[trip]
    test ax,4
    jnz .next
    mov ax,[midX]
    mov si,31
    call rect
    mov cx,[factor]
    shr cx,1
    add ax,cx
    mov cx,1
    call rect
.next:
    inc word [baseY]
    cmp word [baseY],95
    GO jb,.scan
    ret

crossing:
    mov ax,[junction]
    sub ax,[trip]
    cmp ax,145
    GO ja,.done
    call project
    mov [baseY],bx
    mov [factor],cx
    call roadCentre
    mov [midX],ax
    mov dx,cx
    shr dx,1
    sub ax,dx
    add cx,dx
    mov dx,1
    mov si,31
    call rect
    mov ax,[midX]
    add ax,[factor]
    inc ax
    mov dx,[factor]
    shr dx,1
    add dx,4
    sub bx,dx
    mov cx,1
    mov si,22
    call rect
    dec ax
    sub bx,5
    mov cx,3
    mov dx,6
    mov si,0
    call rect
    inc ax
    mov cx,1
    mov dx,1
    mov si,12
    cmp byte [signal],0
    je .bulb
    add bx,2
    mov si,14
    cmp byte [signal],2
    je .bulb
    add bx,2
    mov si,10
.bulb:
    call rect
.done:
    ret

drawTraffic:
    ; Far vehicles first. A four-entry stable insertion sort keeps a
    ; near vehicle from disappearing behind a distant one when steering.
    mov word [order],0
    mov word [order+2],2
    mov word [order+4],4
    mov word [order+6],6
    mov bx,2
.sort:
    mov si,[order+bx]
    mov ax,[traffic+si]
    mov di,bx
.shift:
    cmp di,0
    je .insert
    mov si,[order+di-2]
    cmp [traffic+si],ax
    jae .insert
    mov [order+di],si
    sub di,2
    jmp short .shift
.insert:
    mov [order+di],bx           ; original entry is its byte index
    add bx,2
    cmp bx,8
    jb .sort
    mov word [indexV],0
.car:
    mov di,[indexV]
    mov di,[order+di]
    mov ax,[traffic+di]
    cmp ax,144
    ja .next
    call project
    mov [baseY],bx
    mov [factor],cx
    mov ax,[lanes+di]
    sub ax,[cam]
    imul cx
    mov cx,64
    idiv cx
    add ax,80
    mov bx,[baseY]
    mov cx,[factor]
    shr cx,1
    shr cx,1
    add cx,2
    shr di,1
    call vehicle
.next:
    add word [indexV],2
    cmp word [indexV],8
    jb .car
    ret

order times 4 dw 0

; AX centre X, BX tyre baseline, CX width, DI vehicle type.
vehicle:
    mov [screenX],ax
    mov [baseY],bx
    mov [widthV],cx
    mov [style],di
    shl di,1
    mov si,[cars+di]
    mov [colour],si
    mov dx,cx
    shr dx,1
    sub ax,dx
    mov [leftX],ax
    cmp word [style],2
    jne .roof
    add dx,3
.roof:
    sub bx,dx
    mov [topY],bx
    call rect
    inc ax
    sub bx,2
    sub cx,2
    mov dx,3
    call rect
    inc ax
    inc bx
    sub cx,2
    mov dx,[widthV]
    shr dx,1
    shr dx,1
    inc dx
    mov si,21
    call rect
    cmp word [style],2
    jne .trim
    mov ax,[screenX]
    mov cx,1
    mov si,28
    call rect
.trim:
    mov ax,[leftX]
    mov bx,[baseY]
    dec bx
    mov cx,[widthV]
    mov dx,1
    mov si,28
    call rect
    dec bx
    mov cx,2
    mov si,4
    cmp word [style],3
    jne .rear
    mov si,25
    jmp short .lamps
.rear:
    cmp byte [night],0
    je .lamps
    mov si,12
.lamps:
    call rect
    add ax,[widthV]
    sub ax,2
    call rect
    mov bx,[baseY]
    mov si,0
    call rect
    mov ax,[leftX]
    call rect
    ret

; Parking: north-up elevated exterior view or a bumper-relative windscreen.
parkingView:
    BOX 0,29,41,12,19
    BOX 2,31,25,7,27
    SAY 1,8,auto,15
    BOX 0,40,160,55,18
    cmp byte [chase],0
    GO jne,.map
    xor di,di
.edge:
    push di
    mov ax,[bay+di]
    mov bx,[bay+di+2]
    call parkProject
    mov [leftX],ax
    mov [topY],bx
    pop di
    push di
    mov ax,[bay+di+4]
    mov bx,[bay+di+6]
    call parkProject
    mov cx,ax
    mov dx,bx
    mov ax,[leftX]
    mov bx,[topY]
    mov si,10
    call line
    pop di
    add di,4
    cmp di,16
    jb .edge
    mov ax,48
    mov bx,23
    call parkProject
    jc .objects
    cmp ax,155
    ja .objects
    push ax
    mov ax,bx
    mov cx,160
    mul cx
    mov di,ax
    pop ax
    add di,ax
    add di,buffer
    mov si,sP
    mov dl,15
    call lettering
.objects:
    mov word [indexV],0
.obj:
    mov di,[indexV]
    mov ax,[obs+di]
    add ax,[obs+di+2]
    shr ax,1
    mov bx,[obs+di+4]
    add bx,[obs+di+6]
    shr bx,1
    call parkProject
    jc .next
    mov di,[indexV]
    cmp di,24
    jae .cone
    push ax
    mov ax,[obs+di+2]
    sub ax,[obs+di]
    mul word [factor]
    mov cx,64
    div cx
    mov cx,ax
    add cx,2
    pop ax
    shr di,1
    shr di,1
    shr di,1
    call vehicle
    jmp short .next
.cone:
    mov cx,3
    mov dx,3
    mov si,23
    call rect
    inc ax
    dec bx
    mov cx,1
    mov dx,2
    mov si,15
    call rect
.next:
    add word [indexV],8
    cmp word [indexV],40
    GO jb,.obj
    ret
.map:
    BOX 29,6,102,88,17
    BOX 32,7,96,85,18
    ; Static objects and the player use the same vertical map scale.
    BOX 72,17,17,20,2
    SAY 20,5,sP,15
    xor di,di
.slot:
    mov ax,32
    add ax,di
    mov bx,8
    mov cx,1
    mov dx,28
    mov si,7
    call rect
    add di,16
    cmp di,96
    jb .slot
    xor di,di
.block:
    mov ax,[obs+di]
    add ax,32
    mov bx,[obs+di+4]
    call mapY
    push bx
    mov bx,[obs+di+6]
    call mapY
    mov dx,bx
    pop bx
    sub dx,bx
    inc dx
    mov cx,[obs+di+2]
    sub cx,[obs+di]
    inc cx
    mov si,9
    cmp di,24
    jb .paint
    mov si,23
.paint:
    call rect
    add di,8
    cmp di,40
    jb .block
    ret

mapY:
    push ax
    push cx
    push dx
    mov ax,bx
    mov cx,7
    mul cx
    mov cx,8
    div cx
    mov bx,ax
    add bx,7
    pop dx
    pop cx
    pop ax
    ret

parkProject:
    mov si,ax
    mov ax,[py]
    sub ax,bx
    cmp byte [reverse],0
    je .depth
    neg ax
.depth:
    xor di,di
    or ax,ax
    jns .clip
    inc di
    xor ax,ax
.clip:
    cmp ax,80
    jbe .scale
    mov ax,80
.scale:
    mov cx,96
    sub cx,ax
    mov [factor],cx
    shr ax,1
    mov bx,80
    sub bx,ax
    mov ax,si
    sub ax,[px]
    cmp byte [reverse],0
    je .x
    neg ax
.x:
    imul cx
    mov cx,64
    idiv cx
    add ax,80
    or di,di
    jz .visible
    stc
    ret
.visible:
    clc
    ret

exterior:
    cmp byte [mode],2
    je .lot
    ; The player is 12 m ahead of the exterior eye. Use exactly the
    ; same projection as a traffic vehicle at zero relative distance.
    xor ax,ax
    call project
    mov [factor],cx
    mov [baseY],bx
    mov ax,[carX]
    sub ax,[cam]
    imul cx
    mov cx,64
    idiv cx
    add ax,80
    mov cx,[factor]
    shr cx,1
    shr cx,1
    add cx,3
    mov bx,[baseY]
    mov di,4
    call vehicle
    jmp short .details
.lot:
    mov ax,[px]
    add ax,32
    mov bx,[py]
    call mapY
    sub ax,3
    sub bx,5
    mov cx,7
    mov dx,11
    mov si,23
    call rect
    mov [leftX],ax
    mov word [widthV],7
    inc ax
    add bx,2
    mov cx,5
    mov dx,3
    mov si,21
    call rect
    add bx,8
    mov [baseY],bx
.details:
    mov ax,[leftX]
    mov bx,[baseY]
    mov cx,2
    mov dx,1
    mov si,0
    test word [odo],8
    jz .wheel
    mov si,8
.wheel:
    call rect
    add ax,[widthV]
    sub ax,2
    call rect
    sub bx,2
    mov si,4
    cmp byte [held+39h],0
    je .reverse
    mov si,12
.reverse:
    cmp byte [reverse],0
    je .brake
    mov si,15
.brake:
    call rect
    mov ax,[leftX]
    call rect
    test word [ticks],4
    jz .done
    dec bx
    mov si,14
    cmp byte [hazard],0
    jne .both
    cmp word [steer],0
    je .done
    jl .left
    jmp short .right
.both:
    call rect
.right:
    add ax,[widthV]
    sub ax,2
.left:
    call rect
.done:
    ret

weather:
    cmp byte [rain],0
    je .blade
    xor di,di
.drop:
    mov ax,di
    mov bx,19
    mul bx
    add ax,[ticks]
    and ax,127
    add ax,14
    push ax
    mov ax,di
    mov bx,11
    mul bx
    add ax,[ticks]
    and ax,63
    add ax,6
    mov bx,ax
    pop ax
    cmp byte [chase],0
    jne .paint
    cmp byte [wiper],0
    je .paint
    test word [ticks],8
    jz .paint
    cmp ax,36
    jb .paint
    cmp ax,102
    jb .next
.paint:
    mov cx,1
    mov dx,2
    mov si,7
    call rect
.next:
    inc di
    cmp di,24
    jb .drop
.blade:
    cmp byte [chase],0
    jne .done
    cmp byte [wiper],0
    je .done
    mov ax,[ticks]
    and ax,31
    cmp ax,16
    jb .angle
    mov bx,31
    sub bx,ax
    mov ax,bx
.angle:
    shl ax,1
    shl ax,1
    mov cx,ax
    add cx,12
    mov ax,51
    mov bx,71
    mov dx,48
    mov si,0
    call line
.done:
    ret

cockpit:
    ; Bonnet and pillars frame the windshield across its full width.
    BOX 47,69,66,1,6
    BOX 32,70,96,2,23
    BOX 17,72,126,2,23
    BOX 3,74,154,3,23
    LINE 0,53,6,77,0
    LINE 159,53,153,77,0
    LINE 39,75,54,70,6
    LINE 120,75,106,70,6
    LINE 56,70,100,70,14
    BOX 0,77,160,23,22
    BOX 0,77,160,1,28

    ; Left wheel and moving spokes.
    LINE 10,77,16,71,0
    LINE 16,71,29,71,0
    LINE 29,71,36,78,0
    LINE 36,78,36,90,0
    LINE 36,90,29,97,0
    LINE 29,97,16,97,0
    LINE 16,97,9,90,0
    LINE 9,90,9,78,0
    mov ax,10
    mov bx,84
    sub bx,[steer]
    mov cx,35
    mov dx,84
    add dx,[steer]
    mov si,28
    call line
    LINE 23,84,23,96,28
    BOX 20,81,7,6,27
    cmp byte [reverse],0
    jne .rev
    SAY 10,21,sD,10
    jmp short .instruments
.rev:
    SAY 10,21,sR,14
.instruments:
    BOX 48,79,46,20,0
    SAY 13,20,sSpeed,7
    NUM 19,20,[speed],3,14
    SAY 13,23,sRpm,7
    mov ax,[rpm]
    xor dx,dx
    mov bx,320
    div bx
    mov cx,ax
    mov ax,67
    mov bx,93
    mov dx,3
    mov si,10
    cmp word [rpm],5000
    jb .rpm
    mov si,12
.rpm:
    call rect

    BOX 96,79,27,20,27
    SAY 25,20,sHaz,7
    cmp byte [hazard],0
    je .ign
    test word [ticks],4
    jz .ign
    SAY 25,20,sHaz,12
.ign:
    mov dl,4
    cmp byte [engine],0
    je .ignInk
    mov dl,10
.ignInk:
    mov di,buffer+88*160+100
    mov si,sIgn
    call lettering
    cmp byte [lights],0
    je .fuel
    SAY 28,22,sLight,11
.fuel:
    BOX 125,79,33,8,27
    SAY 32,20,sFuel,7
    mov ax,[fuel]
    xor dx,dx
    mov bx,40
    div bx
    mov cx,ax
    mov ax,128
    mov bx,85
    mov dx,1
    mov si,10
    cmp word [fuel],200
    ja .bar
    mov si,12
.bar:
    call rect

    ; Pedal faces recess when their respective keys are held.
    BOX 123,90,21,9,28
    BOX 146,88,13,11,28
    mov bx,91
    mov si,8
    cmp byte [held+39h],0
    je .brake
    inc bx
    mov si,12
.brake:
    mov ax,124
    mov cx,19
    mov dx,6
    call rect
    mov bx,89
    mov si,8
    cmp byte [held+48h],0
    je .gas
    inc bx
    mov si,10
.gas:
    mov ax,147
    mov cx,11
    mov dx,8
    call rect
    SAY 31,23,sBrake,0
    SAY 37,23,sGas,0
    test word [ticks],4
    jz .done
    mov si,10
    cmp byte [hazard],0
    jne .both
    cmp word [steer],0
    je .done
    jl .left
    jmp short .right
.both:
    BOX 13,79,3,2,10
.right:
    BOX 30,79,3,2,10
    ret
.left:
    BOX 13,79,3,2,10
.done:
    ret

hud:
    BOX 0,0,160,7,27
    cmp byte [mode],2
    GO je,.parking
    SAY 1,0,sTime,7
    mov ax,[timer]
    xor dx,dx
    mov bx,18
    div bx
    NUM 6,0,ax,3,15
    SAY 11,0,sDist,7
    NUM 16,0,[trip],4,15
    SAY 22,0,sScore,7
    NUM 26,0,[score],5,14
    ; Moving progress marker at the left edge.
    BOX 2,11,3,50,27
    mov ax,[trip]
    mov bx,48
    mul bx
    mov bx,1000
    div bx
    mov dx,ax
    mov bx,60
    sub bx,dx
    mov ax,3
    mov cx,1
    mov si,23
    call rect
    BOX 120,9,30,9,27
    mov word [indexV],0
.arrow:
    mov di,[indexV]
    mov ax,[lanes+di]
    sub ax,[carX]
    jns .abs
    neg ax
.abs:
    mov si,8
    cmp ax,15
    ja .ink
    mov si,23
.ink:
    mov ax,di
    shl ax,1
    shl ax,1
    add ax,126
    mov bx,11
    mov cx,1
    mov dx,5
    call rect
    dec ax
    inc bx
    mov cx,3
    mov dx,1
    call rect
    add word [indexV],2
    cmp word [indexV],6
    jb .arrow
    jmp near .common
.parking:
    SAY 1,0,sPark,15
    SAY 13,0,sGap,7
    NUM 17,0,[gap],2,14
    SAY 20,0,sCell,7
    SAY 27,0,sScore,7
    NUM 31,0,[score],4,14
    BOX 55,8,23,3,27
    mov cx,[gap]
    cmp cx,21
    jbe .length
    mov cx,21
.length:
    mov ax,56
    mov bx,9
    mov dx,1
    mov si,10
    cmp word [gap],8
    ja .sensor
    mov si,14
    cmp word [gap],3
    ja .sensor
    mov si,12
.sensor:
    call rect
.common:
    cmp byte [chase],0
    jne .outside
    SAY 36,0,sFpp,10
    jmp near .warning
.outside:
    SAY 36,0,sTpp,23
    BOX 0,94,160,6,22
    SAY 1,23,sSpeed,15
    NUM 6,23,[speed],3,14
    SAY 11,23,sRpm,7
    NUM 15,23,[rpm],4,15
    SAY 22,23,sTemp,7
    NUM 27,23,[temp],3,14
.warning:
    cmp byte [mode],3
    jne .impact
    SAY 15,3,sDemo,14
.impact:
    cmp word [flash],0
    je .done
    cmp word [flash],18
    jbe .notice
    BOX 59,19,40,8,4
    SAY 17,5,sHit,15
    ret
.notice:
    ; A short flash is also the tail of a collision cooldown.
    ; Only show the ticket message on the junction itself.
    mov ax,[junction]
    sub ax,[trip]
    cmp ax,195
    jb .done
    cmp word [tickets],0
    je .done
    SAY 15,5,sRed,12
.done:
    ret

summary:
    mov ax,[score]
    cmp ax,[best]
    jbe .draw
    mov [best],ax
.draw:
    BOX 0,0,160,100,22
    BOX 14,13,132,75,27
    BOX 14,13,132,2,23
    mov si,sWin
    mov dl,10
    cmp byte [outcome],1
    je .title
    mov si,sTimeout
    mov dl,12
    cmp byte [outcome],2
    je .title
    mov si,sEmpty
.title:
    mov di,buffer+21*160+47
    call lettering
    SAY 7,9,sScore,7
    NUM 26,9,[score],5,14
    SAY 7,11,sOdo,7
    mov ax,[odo]
    shr ax,1
    shr ax,1
    NUM 26,11,ax,5,15
    SAY 7,13,sHits,7
    NUM 26,13,[hits],3,15
    SAY 7,15,sTickets,7
    NUM 26,15,[tickets],3,15
    SAY 7,17,sBest,7
    NUM 26,17,[best],5,14
    SAY 13,20,sBack,15
    call present
    call clearEdges
.wait:
    mov bx,1Ch
    call edge
    GO jnz,menu
    mov bx,1
    call edge
    GO jnz,menu
    jmp short .wait

quit:
    mov dx,[oldIRQ]
    mov ax,[oldIRQ+2]
    mov ds,ax
    mov ax,2509h
    int 21h
    push cs
    pop ds
    xor ah,ah
    mov al,[oldMode]
    int 10h
    mov ax,4C00h
    int 21h

buffer times 16000 db 0