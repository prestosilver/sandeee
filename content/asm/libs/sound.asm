_squareWave:
    push 22050                  ; x x 128
    div                         ; x x
    push 2
    mod
    push 255
    mul
    ret

_playSound:
    push "/fake/snd/play"       ; cont path
    sys 3                       ; cont handle
    dup 0                       ; cont handle handle
    dup 2                       ; cont handle handle cont
    sys 5                       ; cont handle
    sys 7                       ; cont
    disc 0                      ;
    push 0
    ret