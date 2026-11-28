%macro stateword 1
%1 dw 0
%endmacro

stateword speed
stateword gear
stateword lane
stateword px
stateword pz
stateword oldX
stateword oldZ
stateword stepZ
stateword furthest
stateword travelFrac
stateword penalty
stateword score
stateword fuel
stateword fuelFrac
stateword remaining
stateword elapsed
stateword flash
stateword signal
stateword blinkLeft
stateword wheelTurn
stateword pattern
stateword trafficGap
stateword trafficType
stateword tx
stateword tw
stateword tl
stateword trafficStep
stateword sensor
stateword drivePhase
stateword shiftBand
passed db 0
hazard db 0
headlamps db 0
reason db 0

staged db 0
lateralFrac dw 0

