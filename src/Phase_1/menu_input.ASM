; ---- src/menus.inc ----
%define HELP 6
dispatch:
 mov al,[screen]
 cmp al,MENU
 jne .drive
 jmp main_input
.drive:
 cmp al,PLAY
 jne .pause
 cmp byte [press+1],0
 jne .pausegame
 cmp byte [press+25],0
 jne .pausegame
 jmp drive_tick
.pausegame:
 mov byte [screen],PAUSE
 jmp enter_list
.pause:
 cmp al,PAUSE
 je short .polish_continue_5443
 jmp near .garage
.polish_continue_5443:
 cmp byte [press+1],0
 je short .branch_continue_2113
 jmp near resume_game
.branch_continue_2113:
 mov bl,4
 call list_input
 cmp byte [press+28],0
 jne short .branch_continue_2117
 jmp near input_done
.branch_continue_2117:
 mov al,[cursor]
 cmp al,0
 jne short .branch_continue_2120
 jmp near resume_game
.branch_continue_2120:
 cmp al,1
 jne .settings
 jmp new_level
.settings:
 cmp al,2
 jne short .branch_continue_2126
 jmp near pause_options
.branch_continue_2126:
 jmp to_menu
.garage:
 cmp al,GARAGE
 jne .options
 jmp garage_input
.options:
 cmp al,OPTIONS
 jne .result
 jmp settings_input
.result:
 cmp al,HELP
 jne .endgame
 cmp byte [press+1],0
 je short .polish_continue_5480
 jmp near to_menu
.polish_continue_5480:
 cmp byte [press+28],0
 jne to_menu
 ret
.endgame:
 cmp byte [press+19],0
 je .back
 jmp new_level
.back:
 cmp byte [press+1],0
 jne to_menu
 cmp byte [press+28],0
 jne to_menu
 ret
resume_game:
 mov byte [screen],PLAY
 jmp enter_list
pause_options:
 mov byte [fromScreen],PAUSE
 jmp show_options
to_menu:
 mov byte [screen],MENU
enter_list:
 mov byte [cursor],0
 call reset_audio
nav_click:
 xor al,al
 jmp sound_event
input_done:
 ret
main_input:
 cmp byte [press+2],0
 je short .branch_continue_2172
 jmp near start_highway
.branch_continue_2172:
 cmp byte [press+3],0
 je short .branch_continue_2174
 jmp near start_parking
.branch_continue_2174:
 cmp byte [press+4],0
 jne show_garage
 cmp byte [press+5],0
 jne .audio
 cmp byte [press+6],0
 jne exit_game
 cmp byte [press+59],0
 je .navigate
 mov byte [screen],HELP
 jmp enter_list
.navigate:
 mov bl,5
 call list_input
 cmp byte [press+28],0
 jne short .polish_continue_5527
 jmp near input_done
.polish_continue_5527:
 mov al,[cursor]
 cmp al,0
 je start_highway
 cmp al,1
 je start_parking
 cmp al,2
 je show_garage
 cmp al,3
 jne exit_game
.audio:
 mov byte [fromScreen],MENU
show_options:
 mov byte [screen],OPTIONS
 jmp enter_list
exit_game:
 mov byte [quit],1
 ret
start_highway:
 mov byte [level],HIGHWAY
 jmp new_level
start_parking:
 mov byte [level],PARKING
 jmp new_level
show_garage:
 mov ax,[vehicle]
 mov [browse],ax
 mov ax,[paint]
 mov [swatch],ax
 mov byte [screen],GARAGE
 jmp enter_list
list_input:
 cmp byte [press+72],0
 je .down
 cmp byte [cursor],0
 jne .dec
 mov [cursor],bl
.dec:
 dec byte [cursor]
 jmp nav_click
.down:
 cmp byte [press+80],0
 je .done
 inc byte [cursor]
 cmp [cursor],bl
 jb .click
 mov byte [cursor],0
.click:
 jmp nav_click
.done:
 ret
garage_input:
 cmp byte [press+1],0
 je short .branch_continue_2235
 jmp near to_menu
.branch_continue_2235:
 cmp byte [press+28],0
 je .change
 mov ax,[browse]
 mov [vehicle],ax
 mov ax,[swatch]
 mov [paint],ax
 call load_vehicle
 jmp to_menu
.change:
 mov si,browse
 mov bx,GARAGE_COUNT
 cmp byte [press+75],0
 jne cycle_back
 cmp byte [press+77],0
 jne cycle_fwd
 mov si,swatch
 mov bx,9
 cmp byte [press+72],0
 jne cycle_back
 cmp byte [press+80],0
 jne cycle_fwd
 ret
cycle_back:
 cmp word [si],0
 jne .dec
 mov [si],bx
.dec:
 dec word [si]
 jmp nav_click
cycle_fwd:
 inc word [si]
 cmp [si],bx
 jb .done
 mov word [si],0
.done:
 jmp nav_click
settings_input:
 cmp byte [press+1],0
 je short .branch_continue_2274
 jmp near .leave
.branch_continue_2274:
 mov bl,4
 call list_input
 cmp byte [press+28],0
 jne .edit
 cmp byte [press+75],0
 jne .edit
 cmp byte [press+77],0
 jne .edit
 ret
.edit:
 mov al,[cursor]
 or al,al
 jnz .volume
 ; Left always selects OFF, right always selects ON. Enter toggles.
 cmp byte [press+75],0
 jne .off
 cmp byte [press+77],0
 jne .on
 xor byte [soundOn],1
 jmp .apply
.off:
 mov byte [soundOn],0
 jmp .apply
.on:
 mov byte [soundOn],1
.apply:
 call reset_audio
 jmp nav_click
.volume:
 mov si,fxVol
 cmp al,1
 je .adjust
 mov si,bgVol
 cmp al,2
 jne .leave
.adjust:
 cmp byte [press+75],0
 jne .less
 cmp byte [si],4
 jae .done
 inc byte [si]
 jmp nav_click
.less:
 cmp byte [si],0
 je .done
 dec byte [si]
 jmp nav_click
.leave:
 mov al,[fromScreen]
 mov [screen],al
 jmp enter_list
.done:
 ret

