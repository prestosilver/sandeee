    call main
    sys 1

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
    call setup_load

    push "/libs/sound.ell"
    call "libload"

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
    call "SquareWave"
    push 2
    div

    getb
    cat

    copy 1
    push 30000
    gt
    jz loop
    disc 1

    call play_sound
    ret

setup_load:
    push "/libs/libload.eep"
    sys 3
    copy 0
    push 4
    sys 4
    disc 0
    copy 0
    push 100000
    sys 4
    push "libload"
    sys 12
    sys 7
    ret
