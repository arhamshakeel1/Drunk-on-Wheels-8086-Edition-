cpu 8086
bits 16
org 100h
jmp start

%define MENU 0
%define PLAY 1
%define PAUSE 2
%define RESULT 3
%define GARAGE 4
%define OPTIONS 5
%define HIGHWAY 0
%define PARKING 1
%define PICKUP 6
%define GARAGE_COUNT 7

; Drawing calls take pixel coordinates. AX,BX,CX,DX and SI are scratch.
%macro BOX 5
 mov ax,%1
 mov bx,%2
 mov cx,%3
 mov dx,%4
 mov si,%5
 call rectangle
%endmacro
%macro WORDS 4
 mov ax,%1
 mov bx,%2
 mov si,%3
 mov dl,%4
 call label8
%endmacro
%macro NUMBER 4
 mov ax,%3
 call decimal
 mov ax,%1
 mov bx,%2
 mov dl,%4
 call label8
%endmacro
