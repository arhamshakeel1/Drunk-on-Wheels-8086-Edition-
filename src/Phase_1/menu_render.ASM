render:
 mov al,[screen]
 cmp al,PLAY
 je short .route_continue_4157
 jmp near .menus
.route_continue_4157:
 call scene_interpolated
 cmp byte [chase],0
 jne .exterior
 call draw_wiper
 call cockpit
 jmp .overlay
.exterior:
 call chase_panel
.overlay:
 call hud
 jmp draw_pointer
.menus:
 cmp al,MENU
 jne .garage
 jmp home_view
.garage:
 cmp al,GARAGE
 jne .settings
 jmp garage_view
.settings:
 cmp al,OPTIONS
 jne .pause
 jmp settings_view
.pause:
 cmp al,PAUSE
 jne .results
 jmp pause_view
.results:
 cmp al,RESULT
 jne .help
 jmp result_view
.help:
 jmp help_view

; Large title letters use the same ROM font as the compact instruments.
big_title:
 mov [titleX],ax
 mov [titleY],bx
 mov [titleInk],dl
.glyph:
 lodsb
 or al,al
 jnz short .branch_continue_2358
 jmp near .end
.branch_continue_2358:
 xor ah,ah
 shl ax,1
 shl ax,1
 shl ax,1
 add ax,[fontOff]
 mov di,ax
 push si
 mov word [fontRow],0
.row:
 mov es,[fontSeg]
 mov al,[es:di]
 mov [fontBits],al
 mov word [fontCol],0
.bit:
 shl byte [fontBits],1
 jnc .skip
 mov ax,[fontCol]
 shl ax,1
 add ax,[titleX]
 mov bx,[fontRow]
 shl bx,1
 add bx,[titleY]
 mov cx,2
 mov dx,2
 xor si,si
 mov si,[titleInk]
 call rectangle
.skip:
 inc word [fontCol]
 cmp word [fontCol],8
 jae short .polish_continue_5758
 jmp near .bit
.polish_continue_5758:
 inc di
 inc word [fontRow]
 cmp word [fontRow],8
 jae short .branch_continue_2393
 jmp near .row
.branch_continue_2393:
 pop si
 add word [titleX],16
 jmp .glyph
.end:
 ret
%macro LARGE 4
 mov ax,%1
 mov bx,%2
 mov si,%3
 mov dl,%4
 call big_title
%endmacro
base:
 BOX 0,0,320,200,1
 BOX 0,0,320,3,8
 BOX 12,24,296,1,3
 ret
footer:
 push si
 BOX 0,181,320,19,0
 mov ax,10
 mov bx,187
 pop si
 mov dl,6
 jmp label8
; Draw the active list entry with a coloured focus rail.
; Table in DI, count in BP, top in BX.
list_view:
 mov [listY],bx
 mov word [listIndex],0
.loop:
 mov ax,[listIndex]
 cmp al,[cursor]
 jne .normal
 BOX 12,[listY],296,16,3
 BOX 12,[listY],3,16,8
.normal:
 mov bx,[listY]
 add bx,4
 mov ax,22
 mov si,[di]
 mov dl,7
 call label8
 add di,2
 add word [listY],18
 inc word [listIndex]
 dec bp
 jz short .branch_continue_2442
 jmp near .loop
.branch_continue_2442:
 ret
home_view:
 call base
 WORDS 12,10,editionName,9
 LARGE 12,32,titleDriving,15
 BOX 12,53,296,39,17
 BOX 12,76,296,16,3
 BOX 12,84,296,1,5
 WORDS 20,65,routeCaption,15
 mov ax,[vehicle]
 mov [shape],ax
 mov bx,[paint]
 mov al,[paints+bx]
 mov [bodyInk],al
 mov word [spriteX],266
 mov word [spriteY],89
 mov word [spriteW],38
 cmp word [vehicle],4
 jne .preview
 mov word [spriteW],18
.preview:
 call vehicle_sprite
 mov di,homeRows
 mov bp,5
 mov bx,93
 call list_view
 mov si,homeFoot
 jmp footer
garage_view:
 call base
 LARGE 12,31,garageTitle,15
 mov bx,[browse]
 shl bx,1
 mov si,[vehicleNames+bx]
 mov ax,12
 mov bx,55
 mov dl,9
 call label8
 BOX 12,72,125,76,2
 BOX 18,138,112,1,4
 mov ax,[browse]
 mov [shape],ax
 mov word [spriteX],75
 mov word [spriteY],137
 ; Centre each model on the same floor line and fit it inside the bay.
 mov bx,ax
 shl bx,1
 mov ax,[garagePreviewWidths+bx]
 mov [spriteW],ax
 mov bx,[swatch]
 mov al,[paints+bx]
 mov [bodyInk],al
 call vehicle_sprite
 WORDS 151,73,maxLabel,5
 WORDS 151,85,accLabel,5
 WORDS 151,97,brkLabel,5
 WORDS 151,109,handleLabel,5
 WORDS 151,121,burnLabel,5
 mov di,[browse]
 shl di,1
 NUMBER 269,73,[maxima+di],15
 NUMBER 269,85,[accels+di],15
 NUMBER 269,97,[brakes+di],15
 NUMBER 269,109,[agility+di],15
 NUMBER 269,121,[economy+di],15
 mov bx,[swatch]
 shl bx,1
 mov si,[paintNames+bx]
 mov ax,152
 mov bx,141
 mov dl,9
 call label8
 mov di,0
.sw:
 mov ax,di
 mov bx,34
 mul bx
 add ax,10
 mov bp,ax
 cmp di,[swatch]
 jne .color
 BOX bp,157,29,16,15
.color:
 add bp,2
 xor ax,ax
 mov al,[paints+di]
 mov si,ax
 BOX bp,159,25,12,si
 inc di
 cmp di,9
 jae short .branch_continue_2534
 jmp near .sw
.branch_continue_2534:
 mov si,garageFoot
 jmp footer
settings_view:
 call base
 LARGE 12,32,settingsTitle,15
 mov di,optRows
 mov bp,4
 mov bx,67
 call list_view
 mov si,onText
 cmp byte [soundOn],0
 jne .master
 mov si,offText
.master:
 mov ax,252
 mov bx,71
 mov dl,9
 call label8
 xor ax,ax
 mov al,[fxVol]
 NUMBER 260,89,ax,9
 xor ax,ax
 mov al,[bgVol]
 NUMBER 260,107,ax,9
 mov si,optFoot
 jmp footer
pause_view:
 call base
 LARGE 12,36,pauseTitle,15
 mov di,pauseRows
 mov bp,4
 mov bx,81
 call list_view
 mov si,pauseFoot
 jmp footer
result_view:
 call base
 cmp byte [reason],0
 jne .loss
 LARGE 12,34,wonTitle,12
 jmp .info
.loss:
 LARGE 12,34,lostTitle,13
.info:
 xor bx,bx
 mov bl,[reason]
 shl bx,1
 mov si,[reasons+bx]
 mov ax,12
 mov bx,60
 mov dl,7
 call label8
 BOX 12,85,296,76,2
 WORDS 23,98,distanceLabel,6
 mov ax,[pz]
 cmp byte [level],PARKING
 jne .metres
 ; Parking distance is the odometer, including reverse motion.
 mov ax,[parkOdo]
.metres:
 xor dx,dx
 mov bx,10
 div bx
 NUMBER 211,98,ax,15
 WORDS 263,98,mLabel,5
 WORDS 23,117,scoreLabel,6
 NUMBER 211,117,[score],9
 WORDS 23,137,bestLabel,5
 NUMBER 211,137,[personalBest],15
 mov si,resultFoot
 jmp footer
help_view:
 call base
 LARGE 12,32,helpTitle,15
 mov di,helpRows
 mov bp,10
 mov bx,52
.row:
 push bx
 mov ax,12
 mov dl,7
 mov si,[di]
 call label8
 pop bx
 add bx,12
 add di,2
 dec bp
 jnz .row
 mov si,backFoot
 jmp footer

titleDriving db 'DRUNK ON WHEELS',0
