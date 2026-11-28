camera_setup:
 mov ax,[px]
 mov word [camBack],14
 mov word [camHeight],18
 mov word [camFocalY],FOCAL*18
 mov word [floorEnd],134
 cmp byte [chase],0
 jne .chase
 cmp word [vehicle],4
 jne .store
 ; The open cockpit leaves the road visible below the handlebars.
 mov word [floorEnd],199
 jmp .store
.chase:
 mov word [camBack],76
 mov word [camHeight],32
 mov word [camFocalY],FOCAL*32
 mov word [floorEnd],180
.store:
 mov [camX],ax
 jmp prepare_bend
scene:
 call camera_setup
 BOX 0,0,320,26,18
 BOX 0,26,320,10,19
 BOX 0,36,320,13,20
 BOX 239,18,19,18,21
 call draw_birds
 mov di,skyline
.build:
 mov ax,[di]
 cmp ax,-1
 je .ground
 mov bx,[di+2]
 mov cx,[di+4]
 mov dx,50
 sub dx,bx
 mov si,17
 call rectangle
 add di,6
 jmp .build
.ground:
 BOX 0,44,320,156,22
 mov word [rowY],44
.scan:
 mov ax,[rowY]
 sub ax,HORIZON
 mov [scaleY],ax
 mov bx,256
 mul bx
 div word [camHeight]
 mov [groundScale],ax
 mov ax,[camFocalY]
 xor dx,dx
 div word [scaleY]
 push ax
 call set_haze
 call bend_offset
 pop ax
 sub ax,[camBack]
 add ax,[pz]
 mov [depthZ],ax
 cmp byte [hazeBase],0
 je .land
 BOX 0,[rowY],320,1,22
.land:
 xor ax,ax
 call ground_x
 mov [roadMid],ax
 cmp byte [level],PARKING
 jne short .view_continue_994
 jmp near .lot
.view_continue_994:
 ; Concrete slabs extend beyond narrow striped curbs.
 mov ax,76
 mov si,5
 call ground_band
 mov ax,56
 mov si,6
 ; Alternate in world space. Keep unresolved sections pale near the horizon.
 cmp word [scaleY],10
 jb .curb
 test word [depthZ],64
 jz .curb
 mov si,13
.curb:
 call ground_band
 mov ax,54
 mov si,3
 call ground_band
 call light_road
 cmp word [scaleY],12
 jb .view_continue_1015
 test word [depthZ],32
 jz short .view_continue_1015
 jmp near .advance
.view_continue_1015:
 mov ax,-18
 call lane_paint
 mov ax,18
 call lane_paint
 jmp .advance
.lot:
 mov ax,100
 mov si,5
 call ground_band
 mov ax,90
 mov si,4
 call ground_band
 call light_road
 mov ax,[depthZ]
 cmp ax,83
 jge short .view_continue_1031
 jmp near .advance
.view_continue_1031:
 cmp ax,151
 jle short .view_continue_1033
 jmp near .advance
.view_continue_1033:
 cmp ax,86
 jle .cross
 cmp ax,148
 jge .cross
 mov ax,18
 call paint_stripe
 mov ax,52
 call paint_stripe
 jmp .advance
.cross:
 mov ax,52
 call ground_x
 push ax
 mov ax,18
 call ground_x
 pop cx
 sub cx,ax
 inc cx
 mov bx,[rowY]
 mov dx,1
 mov si,27
 call rectangle
.advance:
 inc word [rowY]
 mov ax,[floorEnd]
 cmp [rowY],ax
 ja .objects
 jmp near .scan
.objects:
 mov word [queueUsed],0
 call roadside
 cmp byte [level],PARKING
 jne .highway
 call queue_lot
 jmp .player
.highway:
 call queue_coins
 mov di,trafficCars
.cars:
 mov ax,[di+WORLDX]
 mov bx,[di+GAP]
 sub bx,[di+LONGIT]
 mov cx,0
 mov dx,di
 call enqueue
 add di,CAR_SIZE
 cmp di,trafficEnd
 jb .cars
.player:
 cmp byte [chase],0
 je .paint
 mov ax,[px]
 xor bx,bx
 sub bx,[halfL]
 mov cx,1
 xor dx,dx
 call enqueue
.paint:
 jmp draw_queue

