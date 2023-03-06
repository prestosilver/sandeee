    call main
    sys 1

sq_wave:
    push 22050                  ; x x 128
    div                         ; x x
    dup 0
    push 2
    div
    push 2
    mul
    eq
    ret

play_sound:
    push "/test.era"            ; cont path
    dup 0
    sys 2
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

    dup 1
    push 440
    mul
    call sq_wave                ; idx wave value
    push 256
    mul

    getb
    cat

    copy 1
    push 30000
    gt
    jz loop
    disc 1

    call play_sound
    ret
