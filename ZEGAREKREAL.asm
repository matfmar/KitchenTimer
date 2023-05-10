;-------------------POCZATEK PROGRAMU - TABLICA PRZERWAN-------------
ORG 0000H
LJMP PROGRAM_START
ORG 0003H
LJMP INT0_ISH
ORG 000BH
LJMP TIMER0_ISH
;-----------------WL. PROGRAM------------------------------------
ORG 0030H
PROGRAM_START:
MOV R6, #0  ;FLAGA BY SKOCZYC DO NOWEJ CYFRY
MOV R7, #0  ;COUNTER NSK PETLI
MOV R5, #20  ;COUNTER  DLA TIMERA
MOV 20H, #0 ;TU JEST CYFERKA
MOV P1, #0
MOV P2, #0
ACALL INIT_PAMIECI  ;30H ... 7FH (CO 8 NOWA CYFRA)
;-----------------------PRZERWANIA-----------------------
SETB INT0
SETB IT0		;EDGE-SENSE	(WYKRYWA SPADEK)
SETB EX0	;OBSLUGA INT0 WLACZONA - BEDZIE TERAZ ZARAZ MOZNA WLACZYC ZEGAR PRZYCISKIEM
CLR EX1		;OBSLUGA INT1 WYLACZONA - NA RAZIE NIE TRZEBA INNYCH MODYFIKACJI PRZED WLACZENIEM ZEGARA
CLR PT0    ;
SETB PX0     ;PRZYCISK WAZNIEJSZY
SETB EA		;INTERRUPTS MASTER KEY ENABLED
;------------RESET REJESTRU-------------------------------- (SAME OSEMKI)
;1.0=SER, 2.1=CLOCK, 2.2=LATCH 
;1.x (OPROCZ 1.0) - KLAWIATURA
MOV R7, #8
REGISTER_RESET_LOOP:
CLR P1.0
ACALL REGISTER_SHIFT
DJNZ R7, REGISTER_RESET_LOOP
ACALL REGISTER_LATCH
ACALL DELAY
ACALL DELAY
;---------------------WYSWIETL PIERWSZE 0 I WYSTARTUJ Z ZEGAREM------------
ACALL WYSWIETL
CLR TR0
MOV TMOD, #11H
MOV TH0, #3CH	;T0=3CB0H (15536) H ZEBY BYLO DOKLADNIE 50000 CYKLI
MOV TL0, #176	;B0H
CLR TF0
SETB ET0	;TIMER0 INTERRUPT = 1
SETB TR0	;TIMER 0 START
;-------------------FIRST WAITING LOOP-----------------------------
WAITING_LOOP_1:
CJNE R6, #0, REAL_TIMER0_ISH
CJNE R4, #0, REAL_INT0_ISH
MOV R7, #2
DJNZ R7, WAITING_LOOP_1
;----------------------REAL_TIMER0_ISH-----------------
REAL_TIMER0_ISH:
MOV R6, #0
MOV A, 20H
INC A
CJNE A, #10, IDZIEMY_DALEJ
MOV A, #0
IDZIEMY_DALEJ:
MOV R0, A
MOV 20H, R0
ACALL WYSWIETL
LJMP WAITING_LOOP_1
;---------------------REAL_INT0_ISH--------------------
REAL_INT0_ISH:
;KLAWIATURKA
ACALL KLAWIATURA_INPUT_LOOP
;PRZYGOTOWANIA NOWEGO TIMERA
CLR TR0
MOV TH0, #3CH	;T0=3CB0H (15536) H ZEBY BYLO DOKLADNIE 50000 CYKLI
MOV TL0, #176	;B0H
CLR TF0
;TIMER0 RUN !!!
SETB TR0
LJMP WAITING_LOOP_1
;------------------WYSWIETL-------------------------------
WYSWIETL:
MOV A, 20H
MOV B, #8
MUL AB
MOV B, #30H
CLR C
ADD A, B
MOV R0, A   ;ADRES BAZOWY JEST TERAZ W R0
MOV R2, #8  ;COUNTER
WYSWIETL_LOOP:
MOV P1, @R0
ACALL REGISTER_SHIFT
INC R0
DJNZ R2, WYSWIETL_LOOP
ACALL REGISTER_LATCH
RET
;-------------------ISH DLA TIMER 0----------------------------
TIMER0_ISH:
CLR TR0
DJNZ R5, TIMER_CONT
MOV R5, #20
MOV R6, #1
TIMER_CONT:
MOV TH0, #3CH	;T0=3CB0H (15536) H ZEBY BYLO DOKLADNIE 50000 CYKLI
MOV TL0, #176	;B0H
CLR TF0
SETB TR0	;TIMER 0 START
RETI
;-------------------ISH DLA INT0----------------------
INT0_ISH:
ACALL DELAY
MOV R4, #1
RETI
;-------------------DELAY FUNCTION (1s ON 12 MHz)---------------------------
DELAY:
PUSH 7
PUSH 6
PUSH 5
MOV R5, #13
MOV R6, #200
MOV R7, #200
DELAY_LOOP:
DJNZ R7, DELAY_LOOP
MOV R7, #200
DJNZ R6, DELAY_LOOP
MOV R6, #200
DJNZ R5, DELAY_LOOP
POP 5
POP 6
POP 7
RET
;----------------DELAY 500us FUNCTION---------------------------
DELAY_500:
PUSH 7
MOV R7, #250
DELAY_500_LOOP:
DJNZ R7, DELAY_500_LOOP
POP 7
RET
;------------------REJETR - SHIFT----------------------------
REGISTER_SHIFT:
SETB P2.1
ACALL DELAY_500
CLR P2.0
RET
;-------------------REJESTR - LATCH-----------------------
REGISTER_LATCH:
SETB P2.2
ACALL DELAY_500
CLR P2.2
RET
;======================================================================================================================
            ;WAITING NA INPUT USERA Z KLAWIATURY I OBSLUGA WCISKANYCH ZNAKOW
;======================================================================================================================
KLAWIATURA_INPUT_LOOP:
; A TERAZ WAITING NA INPUT USERA
;----------------------------------------------------------------------------------------------------------------------
LOOP_WAIT_KLAWIATURA:
MOV P1, #255	;PULL-UP WSZYSTKICH WEJSC Z KLAWIATURY, ZEBY BYLO Z CZEGO CZYTAC
CLR P1.3	;KOLUMNA 1-4-7: WYZEROWANIE TEJ KOLUMNY WYZERUJE ROWNIEZ RZAD JESLI W TYM RZEDZIE I TEJ KOLUMNIE JEST NACISNIETY PRZYCISK (IDEA DZIALANIA ALGORYTMU)
JNB P1.2, KLAW_JEDYNKA
JNB P1.7, KLAW_CZWORKA
JNB P1.6, KLAW_SIODEMKA
JNB P1.4, KLAW_GWIAZDKA
SETB P1.3
CLR P1.1	;KOLUMNA 2-5-8-0
JNB P1.2, KLAW_DWOJKA
JNB P1.7, KLAW_PIATKA
JNB P1.6, KLAW_OSEMKA
JNB P1.4, KLAW_ZERO
SETB P1.1
CLR P1.5	;KOLUMNA 3-6-9
JNB P1.2, KLAW_TROJKA
JNB P1.7, KLAW_SZOSTKA
JNB P1.6, KLAW_DZIEWIATKA
JNB P1.4, KLAW_KRATKA
SETB P1.5
SJMP LOOP_WAIT_KLAWIATURA	;Z POWROTEM DO POCZATKU SPRAWDZANIA
;----------------------------------------------------------------------------------------------------------------------
KLAW_ZERO:
MOV 20H, #0
ACALL WYSWIETL
SJMP LOOP_WAIT_KLAWIATURA
;----------------------------------------------------------------------------------------------------------------------
KLAW_JEDYNKA:
MOV 20H, #1
ACALL WYSWIETL
SJMP LOOP_WAIT_KLAWIATURA
;----------------------------------------------------------------------------------------------------------------------
KLAW_DWOJKA:
MOV 20H, #2
ACALL WYSWIETL
SJMP LOOP_WAIT_KLAWIATURA
;----------------------------------------------------------------------------------------------------------------------
KLAW_TROJKA:
MOV 20H, #3
ACALL WYSWIETL
SJMP LOOP_WAIT_KLAWIATURA
;----------------------------------------------------------------------------------------------------------------------
KLAW_CZWORKA:
MOV 20H, #4
ACALL WYSWIETL
SJMP LOOP_WAIT_KLAWIATURA
;----------------------------------------------------------------------------------------------------------------------
KLAW_PIATKA:
MOV 20H, #5
ACALL WYSWIETL
SJMP LOOP_WAIT_KLAWIATURA
;----------------------------------------------------------------------------------------------------------------------
KLAW_SZOSTKA:
MOV 20H, #6
ACALL WYSWIETL
SJMP LOOP_WAIT_KLAWIATURA
;----------------------------------------------------------------------------------------------------------------------
KLAW_SIODEMKA:
MOV 20H, #7
ACALL WYSWIETL
SJMP LOOP_WAIT_KLAWIATURA
;----------------------------------------------------------------------------------------------------------------------
KLAW_OSEMKA:
MOV 20H, #8
ACALL WYSWIETL
SJMP LOOP_WAIT_KLAWIATURA
;----------------------------------------------------------------------------------------------------------------------
KLAW_DZIEWIATKA:
MOV 20H, #9
ACALL WYSWIETL
SJMP LOOP_WAIT_KLAWIATURA
;----------------------------------------------------------------------------------------------------------------------
KLAW_KRATKA:		;KRATKA KONCZY WSZYSTKO
SJMP KONIEC_PETLI_KLAWIATURY
;----------------------------------------------------------------------------------------------------------------------
KLAW_GWIAZDKA:		;GWIAZDKA NIE ROBI NIC
SJMP LOOP_WAIT_KLAWIATURA	
;----------------------
KONIEC_PETLI_KLAWIATURY:
ACALL DELAY
ACALL DELAY
RET
;----------------------------------------------------------------------------------------------------------------------
;------------------INIT. PAMIECI-----------------------------------
INIT_PAMIECI:
;0
MOV 30H, #11111111B
MOV 31H, #11111111B
MOV 32H, #11111111B
MOV 33H, #0
MOV 34H, #0
MOV 35H, #0
MOV 36H, #0
MOV 37H, #0
;1
MOV 38H, #11111111B
MOV 39H, #11111111B
MOV 3AH, #11111111B
MOV 3BH, #11111111B
MOV 3CH, #0
MOV 3DH, #0
MOV 3EH, #11111111B
MOV 3FH, #11111111B
;2
MOV 40H, #11111111B
MOV 41H, #0
MOV 42H, #11111111B
MOV 43H, #0
MOV 44H, #0
MOV 45H, #11111111B
MOV 46H, #0
MOV 47H, #0
;3
MOV 48H, #11111111B
MOV 49H, #0
MOV 4AH, #11111111B
MOV 4BH, #0
MOV 4CH, #0
MOV 4DH, #0
MOV 4EH, #0
MOV 4FH, #11111111B
;4
MOV 50H, #11111111B
MOV 51H, #0
MOV 52H, #0
MOV 53H, #11111111B
MOV 54H, #0
MOV 55H, #0
MOV 56H, #11111111B
MOV 57H, #11111111B
;5
MOV 58H, #11111111B
MOV 59H, #11111111B
MOV 5AH, #11111111B
MOV 5BH, #0
MOV 5CH, #0
MOV 5DH, #0
MOV 5EH, #0
MOV 5FH, #0
;6
MOV 60H, #11111111B
MOV 61H, #11111111B
MOV 62H, #11111111B
MOV 63H, #11111111B
MOV 64H, #0
MOV 65H, #0
MOV 66H, #11111111B
MOV 67H, #11111111B
;7
MOV 68H, #11111111B
MOV 69H, #0
MOV 6AH, #11111111B
MOV 6BH, #0
MOV 6CH, #0
MOV 6DH, #1
MOV 6EH, #0
MOV 6FH, #0
;8
MOV 70H, #11111111B
MOV 71H, #0
MOV 72H, #11111111B
MOV 73H, #0
MOV 74H, #0
MOV 75H, #0
MOV 76H, #0
MOV 77H, #11111111B
;9
MOV 78H, #11111111B
MOV 79H, #0
MOV 7AH, #0
MOV 7BH, #11111111B
MOV 7CH, #0
MOV 7DH, #0
MOV 7EH, #11111111B
MOV 7FH, #11111111B
RET
;-------------------END OF PROGRAM-------------------------
END