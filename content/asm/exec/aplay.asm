main:
    push 1
    sys 8                       ; get file arg
    copy 0
    jz error                    ; jump if zero
    sys 3                       ; open file
    copy 0                      ; duplacte file handle
    push 1
    sys 8                       ; get file arg
    sys 19                      ; get size of file 
    sys 4                       ; read
    call play_sound
    sys 1

play_sound:
    push "/fake/snd/play"      ; cont path
    sys 3                      ; cont handle
    dup 0                      ; cont handle handle
    dup 2                      ; cont handle handle cont
    sys 5                      ; cont handle
    sys 7                      ; cont
    disc 0                     ;
    ret

error:
    push "expected file"
    sys 18
