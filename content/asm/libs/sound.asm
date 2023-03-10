_SquareWave:
    push 22050                  ; x x 128
    div                         ; x x
    push 2
    mod
    push 255
    mul
    ret
