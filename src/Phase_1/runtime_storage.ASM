canvas dw 0
fontSeg dw 0
fontOff dw 0
old9 dd 0
held times 128 db 0
edges times 128 db 0
press times 128 db 0
ticks dw 0
lastTick dw 0
screen db MENU
level db HIGHWAY
quit db 0
memmsg db 'Drunk on Wheels needs another 64 KB of conventional memory.',13,10,'$'
align 2
times 1024 db 0
stack_end:
