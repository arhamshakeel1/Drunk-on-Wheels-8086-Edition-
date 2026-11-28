; Slots are kept in nearest-to-farthest order by the circular head index.
; Each slot owns its lane, speed and collision latch for its whole approach.
%define GAP 0
%define KIND 2
%define WORLDX 4
%define WIDE 6
%define LONGIT 8
%define FORWARD_STEP 10
%define PAINTID 12
%define TOUCHED 14
%define CAR_SIZE 16
; Direction stays in gear (+1/-1) for the signed odometer. Forward ratios
; are independent so selecting fifth never multiplies distance by five.
ratio dw 1
manual db 0
gearLimits db 24,43,63,82,100
revPercent dw 12

; AX = ratio 1..5. Return its redline road speed for the equipped vehicle.
ratio_limit:
 mov bx,ax
 xor ax,ax
 mov al,[gearLimits+bx-1]
 mul word [topSpeed]
 mov bx,100
 div bx
 ret

transmission:
 cmp byte [press+50],0        ; M: automatic / manual
 je .direction
 xor byte [manual],1
.direction:
 cmp word [gear],0
 jg .forward
 mov word [ratio],1
 ret
.forward:
 cmp byte [level],HIGHWAY
 je .highway
 mov word [ratio],1
 ret
.highway:
 cmp byte [press+31],0        ; S: upshift and take manual control
 je .checkDown
 mov byte [manual],1
 cmp word [ratio],5
 jb short .dash_continue_604
 jmp near .done
.dash_continue_604:
 inc word [ratio]
 ret
.checkDown:
 cmp byte [press+30],0        ; A: downshift with over-rev protection
 je .auto
 mov byte [manual],1
 cmp word [ratio],1
 ja short .dash_continue_612
 jmp near .done
.dash_continue_612:
 mov ax,[ratio]
 dec ax
 call ratio_limit
 cmp [speed],ax
 jbe short .dash_continue_617
 jmp near .done
.dash_continue_617:
 dec word [ratio]
 ret
.auto:
 cmp byte [manual],0
 je short .dash_continue_622
 jmp near .done
.dash_continue_622:
 mov ax,[ratio]
 call ratio_limit
 mov bx,ax
 shr bx,1
 shr bx,1
 shr bx,1
 sub ax,bx
 cmp [speed],ax
 jb .lower
 cmp word [ratio],5
 jae .done
 inc word [ratio]
 ret
.lower:
 cmp word [ratio],1
 jbe .done
 mov ax,[ratio]
 dec ax
 call ratio_limit
 shr ax,1
 cmp [speed],ax
 ja .done
 dec word [ratio]
.done:
 ret

read_revs:
 mov ax,[ratio]
 call ratio_limit
 cmp word [gear],0
 jg .range
 mov ax,12
.range:
 mov bx,ax
 mov ax,[speed]
 mov cx,84
 mul cx
 div bx
 add ax,12
 cmp byte [gasForward],0
 jne .load
 cmp byte [gasReverse],0
 je .limit
.load:
 add ax,4
.limit:
 cmp ax,100
 jbe .store
 mov ax,100
.store:
 mov [revPercent],ax
 ret

