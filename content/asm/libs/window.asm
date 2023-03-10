_WindowCreate:
    push "/fake/win/new"        ; path
    sys 3                       ; open
    dup 0                       ; handle
    push 1                      ; size
    sys 4                       ; read
    dup 1                       ; file handle
    sys 7                       ; flush
    disc 1                      ; file handle
    ret

_WindowDestroy:
    push "/fake/win/destroy"
    sys 3
    dup 0
    dup 2
    sys 5
    sys 7
    disc 0
    ret

_WindowRender:
    ret

_WindowFlip:
    push "/fake/win/flip"
    sys 3
    dup 0
    dup 2
    sys 5
    sys 7
    ret
