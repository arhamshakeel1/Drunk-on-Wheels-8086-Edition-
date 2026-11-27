 ; Bresenham segment. CX/DX scratch; endpoint in lineX2/lineY2.
line:
 push di
 push bp
 mov [lx],ax
 mov [ly],bx
 mov [lineInk],si
 sub ax,[lineX2]
 mov di,-1
 jns .dx
 neg ax
 mov di,1
.dx:
 mov [ldx],ax
 sub bx,[lineY2]
 mov bp,-1
 jns .dy
 neg bx
 mov bp,1
.dy:
 neg bx
 mov [ldy],bx
 add ax,bx
 mov [lerr],ax
.loop:
 mov ax,[lx]
 mov bx,[ly]
 mov cx,2
 mov dx,2
 mov si,[lineInk]
 call rectangle
 mov ax,[lx]
 cmp ax,[lineX2]
 jne .advance
 mov ax,[ly]
 cmp ax,[lineY2]
 jne short .polish_continue_3003
 jmp near .end
.polish_continue_3003:
.advance:
 mov ax,[lerr]
 shl ax,1
 cmp ax,[ldy]
 jl .onlyy
 mov bx,[ldy]
 add [lerr],bx
 add [lx],di
.onlyy:
 cmp ax,[ldx]
 jle short .branch_continue_1547
 jmp near .loop
.branch_continue_1547:
 mov bx,[ldx]
 add [lerr],bx
 add [ly],bp
 jmp .loop
.end:
 pop bp
 pop di
 ret
z0 db '0',0
z200 db '200',0
kmh db 'km/h',0
fuelLabel db 'FUEL',0
lowLabel db 'LOW',0
eLabel db 'E',0
fLabel db 'F',0
gearLabel db 'GEAR',0
driveLabel db 'D',0
reverseLabel db 'R',0
hazardGlyph db 30,0
beamLabel db 'H',0
leftGlyph db 17,0
rightGlyph db 16,0
coinsTag db 'COINS',0
parkName db 'PARKING / LEVEL 2',0
sensorLabel db 'SENSOR',0
pointLabel db '.',0
lotLabel db 'LOT PLAN',0
mLabel db 'm',0
scoreLabel db 'SCORE',0
secLabel db 'sec',0
coinMsg db 'COIN  +25',0
hitLabel db 'COLLISION   -50',0
stateword lineX2
stateword lineY2
stateword lx
stateword ly
stateword ldx
stateword ldy
stateword lerr
stateword lineInk
stateword accent
