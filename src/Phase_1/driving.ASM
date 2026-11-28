; ---- src/drive.inc ----
; Distances in decimetres, speed magnitude in km/h. One tick = BIOS 18.2 Hz.
; Both levels use x across the road and z along its length.
new_level:
 mov byte [wiperOn],0
 mov word [wiperPhase],0
 mov byte [gasForward],0
 mov byte [gasReverse],0
 mov byte [brakeHeld],0
 mov byte [controlHit],0
 mov byte [mouseHeld],1
 mov word [buttonY],142
 cmp byte [chase],0
 je .panelReady
 mov word [buttonY],171
.panelReady:
 mov word [ratio],1
 mov word [revPercent],12
 mov word [coinScore],0
 mov word [pickupFlash],0
 mov di,coinTaken
 mov cx,coinCount
.clearCoins:
 mov byte [di],0
 inc di
 loop .clearCoins
 call reset_audio
 mov byte [screen],PLAY
 mov byte [staged],1
 mov word [parkOdo],0
 mov word [lateralFrac],0
 mov word [speed],0
 mov word [gear],1
 mov word [lane],1
 mov word [px],0
 mov word [pz],0
 mov word [furthest],0
 mov word [travelFrac],0
 mov word [penalty],0
 mov word [score],0
 mov word [fuel],10000
 mov word [fuelFrac],0
 mov word [remaining],1638
 mov word [elapsed],0
 mov word [flash],0
 mov word [signal],0
 mov word [blinkLeft],0
 mov byte [hazard],0
 mov byte [headlamps],0
 mov word [wheelPose],0
 mov word [wheelTurn],0
 mov word [pattern],0
 mov byte [passed],0
 mov byte [reason],0
 mov word [sensor],999
 mov word [drivePhase],0
 mov word [shiftBand],1
 call traffic_init
 cmp byte [level],PARKING
 jne .ready
 mov word [pz],20
 call proximity
.ready:
 call remember_positions
 mov al,1
 jmp sound_event

drive_tick:
 cmp byte [press+46],0     ; C toggles the active driving camera.
 je .cameraReady
 xor byte [chase],1
.cameraReady:
 call controls_tick
 call wiper_tick
 inc word [elapsed]
 cmp word [flash],0
 je .lights
 dec word [flash]
.lights:
 cmp byte [press+38],0     ; L
 je .hazard
 xor byte [headlamps],1
.hazard:
 cmp byte [press+47],0     ; V
 je .motion
 xor byte [hazard],1
.motion:
 cmp byte [press+44],0     ; Z / X signal a turn in either level.
 je .manualRight
 mov ax,-1
 call choose_signal
.manualRight:
 cmp byte [press+45],0
 je .position
 mov ax,1
 call choose_signal
.position:
 mov ax,[px]
 mov [oldX],ax
 mov ax,[pz]
 mov [oldZ],ax
 inc word [drivePhase]
 mov word [wheelTurn],0
 cmp byte [level],PARKING
 jne short .branch_continue_272
 jmp near .parksteer
.branch_continue_272:
 ; Steering moves the vehicle directly, with no target lane.
 mov al,[held+75]
 or al,[press+75]
 mov bl,[held+77]
 or bl,[press+77]
 cmp al,bl
 jne .steeringInput
 jmp near .throttle
.steeringInput:
 mov ax,[handling]
 jb .steer
 neg ax
.steer:
 mov bx,54
 sub bx,[halfW]
 add ax,[px]
 cmp ax,bx
 jle .leftEdge
 mov ax,bx
.leftEdge:
 neg bx
 cmp ax,bx
 jge .storeX
 mov ax,bx
.storeX:
 mov bx,ax
 sub bx,[px]
 mov [wheelTurn],bx
 mov [px],ax
 ; Lane is informational. Trigger the assist only when crossing a divider.
 xor bx,bx
 cmp ax,-18
 jl .laneRead
 inc bx
 cmp ax,18
 jle .laneRead
 inc bx
.laneRead:
 cmp bx,[lane]
 je .throttle
 mov [lane],bx
 cmp word [blinkLeft],-1
 je .throttle
 mov ax,1
 cmp word [wheelTurn],0
 jg .indicator
 neg ax
.indicator:
 mov [signal],ax
 mov word [blinkLeft],18
 jmp .throttle
%include "src/phase_3_parking/parking_steering.ASM"
.throttle:
 call follow_steering
 call transmission
 cmp byte [brakeHeld],0
 je .accelerate
 mov ax,[braking]
 cmp [speed],ax
 ja .brake
 mov word [speed],0
 jmp .travel
.brake:
 sub [speed],ax
 jmp .travel
.accelerate:
 cmp word [speed],0
 jne .in_gear
 cmp byte [gasForward],0
 je .choose_r
 mov word [gear],1
 jmp .in_gear
.choose_r:
 cmp byte [gasReverse],0
 jne short .dash_continue_374
 jmp near .travel
.dash_continue_374:
 mov word [gear],-1
 mov word [ratio],1
.in_gear:
 mov bx,[topSpeed]
 cmp word [gear],0
 jl .reverse
 cmp byte [gasForward],0
 jne short .polish_continue_405
 jmp near .travel
.polish_continue_405:
 cmp byte [level],PARKING
 je .parkingLimit
 mov ax,[ratio]
 call ratio_limit
 mov bx,ax
 jmp .gain
.parkingLimit:
 mov bx,18
 jmp .gain
.reverse:
 cmp byte [gasReverse],0
 je .travel
 mov bx,12
.gain:
 mov ax,[accel]
 cmp word [ratio],2
 jbe .pull
 dec ax
.pull:
 add [speed],ax
 cmp [speed],bx
 jbe .travel
 mov [speed],bx
.travel:
 mov ax,[speed]
 mov bx,100
 mul bx
 add ax,[travelFrac]
 adc dx,0
 mov bx,655
 div bx
 mov [travelFrac],dx
 imul word [gear]
 mov [stepZ],ax
 add [pz],ax
 cmp byte [level],PARKING
 jne short .branch_continue_383
 jmp near .parking
.branch_continue_383:
 cmp word [pz],0
 jge .traffic
 mov word [pz],0
 mov ax,[oldZ]
 neg ax
 mov [stepZ],ax
.traffic:
 cmp byte [staged],0
 je .active
 cmp word [speed],0
 jne .begin
 ret
.begin:
 mov byte [staged],0
.active:
 call traffic_tick
 call collect_coins
 mov ax,[pz]
 cmp ax,[furthest]
 jbe .resources
 cmp ax,10000
 jbe .best
 mov ax,10000
 mov [pz],ax
.best:
 mov [furthest],ax
.resources:
 mov ax,[furthest]
 xor dx,dx
 mov bx,10
 div bx
 add ax,[coinScore]
 sub ax,[penalty]
 mov [score],ax
 dec word [remaining]
 mov ax,[speed]
 mul word [burn]
 add ax,110
 add [fuelFrac],ax
 mov ax,[fuelFrac]
 xor dx,dx
 mov bx,40
 div bx
 mov [fuelFrac],dx
 sub [fuel],ax
 cmp word [pz],10000
 jb short .branch_continue_425
 jmp near .won
.branch_continue_425:
 cmp word [fuel],0
 jg .time
 mov word [fuel],0
 mov byte [reason],2
 jmp finish
.time:
 cmp word [remaining],0
 je short .branch_continue_433
 jmp near .done
.branch_continue_433:
 mov byte [reason],1
 jmp finish
%include "src/phase_3_parking/parking_rules.ASM"
.won:
 mov byte [reason],0
 jmp finish
.done:
 ret
finish:
 cmp byte [level],HIGHWAY
 jne .result
 mov ax,[score]
 cmp ax,[personalBest]
 jle .result
 mov [personalBest],ax
.result:
 mov byte [screen],RESULT
 call reset_audio
 mov al,4
 cmp byte [reason],0
 je .sound
 mov al,5
 cmp byte [reason],3
 jne .sound
 mov al,13
.sound:
 jmp sound_event

