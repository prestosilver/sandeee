    call main
    sys 1

sq_wave:
    dup 0                      ; x x
    push 128                    ; x x 128
    lt                          ; x x
    jz wave_test                ; x
    push 256
    jmp floor_end
wave_test:                      ; x floor[x]
    push 0
floor_end:
    disc 1
    ret

play_sound:
    push "/fake/snd/play"       ; cont path
    sys 3                       ; cont handle
    dup 0                       ; cont handle handle
    dup 2                       ; cont handle handle cont
    sys 5                       ; cont handle
    sys 7                       ; cont
    disc 0                      ;
    ret

main:
    push 0                      ; idx
    push ""                     ; idx wave
loop:
    copy 1
    dup 0
    push 1
    add                         ; wave idx
    set
    disc 0

    push ""                     ; idx wave ""
    dup 2
    push 1023
    mul                         ; idx wave "" idx
    call sq_wave                ; idx wave "" value
    cat                         ; idx wave str_val
    push 3                      ; idx wave str_val 3
    sub                         ; idx wave str_val
    cat

    copy 1
    push 44100
    gt
    jz loop
    copy 1
    sys 0
    disc 1

    copy 0
    sys 0
    call play_sound
    ret
