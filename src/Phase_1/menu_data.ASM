editionName db '8086 EDITION',0
routeCaption db 'GT ROAD',0
homeRows dw highwayRow,parkingRow,garageRow,optionsRow,exitRow
highwayRow db '1   Play Highway',0
parkingRow db '2   Parking Challenge',0
garageRow db '3   Vehicle Garage',0
optionsRow db '4   Audio Settings',0
exitRow db '5   Exit to DOS',0
homeFoot db '1-5 or Arrows / Enter   F1 controls',0
garagePreviewWidths dw 64,64,64,64,31,48,64
garageTitle db 'THE GARAGE',0
maxLabel db 'Max km/h',0
accLabel db 'Acceleration',0
brkLabel db 'Braking',0
handleLabel db 'Handling',0
burnLabel db 'Fuel use',0
garageFoot db '< > Model   Up/Dn Paint   Enter Equip',0
settingsTitle db 'AUDIO SETTINGS',0
optRows dw masterLabel,volumeLabel,bgLabel,backLabel
masterLabel db 'Game sound',0
volumeLabel db 'Effects volume (0 = off)',0
bgLabel db 'Engine volume (0 = off)',0
muteLabel db 'Master mute',0
backLabel db 'Back',0
onText db 'ON',0
offText db 'OFF',0
optFoot db 'Up/Dn Select   < > Adjust   Esc Back',0
pauseTitle db 'PAUSED',0
pauseRows dw resumeLabel,restartLabel,pauseAudioLabel,menuLabel
pauseAudioLabel db 'Audio Settings',0
resumeLabel db 'Resume drive',0
restartLabel db 'Restart level',0
menuLabel db 'Main menu',0
pauseFoot db 'Enter Select     Esc Resume',0
wonTitle db 'LEVEL COMPLETE',0
lostTitle db 'GAME OVER',0
reasons dw successText,timeText,emptyText,touchText
successText db 'Objective reached.',0
timeText db 'The highway timer expired.',0
emptyText db 'The fuel tank is empty.',0
touchText db 'Contact in the parking area.',0
distanceLabel db 'Distance',0
bestLabel db 'Best highway score',0
resultFoot db 'R Play again     Enter Main menu',0
helpTitle db 'DRIVING GUIDE',0
helpRows dw help1,help2,help3,help4,help5,help6,help7,help8,help9,help10
help1 db 'Up accelerates. Space brakes to zero.',0
help2 db 'Down selects reverse from a stop.',0
help3 db 'Highway: hold Left/Right to steer.',0
help4 db 'Parking: hold Left/Right while moving.',0
help5 db 'M Auto/manual   A Downshift  S Upshift',0
help6 db 'Stop inside P. Watch the lot plan.',0
help7 db '1000 m goal. Coin +25. Impact -50.',0
help8 db 'Z/X Signals   V Hazards   W Wiper',0
help9 db 'C View  P Pause  L Lamps  Hold H Horn',0
help10 db 'Pedals: wide brake, tall accelerator.',0
backFoot db 'Enter or Esc   Main menu',0
fromScreen db MENU
cursor db 0
browse dw 0
swatch dw 6
stateword titleX
stateword titleY
stateword titleInk
stateword fontCol
stateword fontRow
fontBits db 0
stateword listY
stateword listIndex
personalBest dw 0
parkOdo dw 0


