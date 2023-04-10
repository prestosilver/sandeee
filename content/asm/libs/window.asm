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
    push 0
    ret

_MakeRect: ; x y w h
    push ""                     ; x y w h | res
    dup 4                       ; x y w h | res x
    cat                         ; x y w h | res
    disc 4                      ; y w h | res
    dup 3
    cat
    disc 3
    dup 2
    cat
    disc 2
    dup 1
    cat
    disc 1
    ret

_WindowRender: ; tex win source dest
    cat
    cat
    cat
    push "/fake/win/render"
    sys 3
    dup 0
    dup 2
    sys 5
    sys 7
    disc 0
    push 0
    ret

_WindowOpen:
    push "/fake/win/open"       ; path
    sys 3                       ; open
    dup 0                       ; handle
    push 1                      ; size
    sys 4                       ; read
    dup 1                       ; file handle
    sys 7                       ; flush
    disc 1                      ; file handle
    getb
    ret

_WindowFlip:
    push "/fake/win/flip"
    sys 3
    dup 0
    dup 2
    sys 5
    sys 7
    ret
