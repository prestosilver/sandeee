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
    sys 17
    ret

_WindowTitle:
    dup 1
    copy 1
    cat
    disc 1
    disc 1
    push "/fake/win/title"
    sys 3
    dup 0
    dup 2
    sys 5
    sys 7
    ret

_WindowSize:
    push "/fake/win/size"       ; path
    sys 3                       ; open
    dup 0                       ; handle
    push 4                      ; size
    sys 4                       ; read
    dup 1                       ; file handle
    sys 7                       ; flush
    disc 1                      ; file handle
    ret

_WindowHeight:
    disc 0
    call WindowSize
    dup 0
    push 2
    add
    getb
    dup 1
    push 3
    add
    getb
    push 256
    mul
    add
    disc 1
    push 36
    sub
    ret

_WindowWidth:
    disc 0
    call WindowSize
    dup 0
    push 0
    add
    getb
    dup 1
    push 1
    add
    getb
    push 256
    mul
    add
    disc 1
    push 4
    sub
    ret
