_TextureRead:
    sys 3                       ; open
    dup 0                       ; handle
    push 100000000
    sys 4                       ; read
    dup 1
    sys 7
    disc 1
    ret

_TextureCreate:
    push "/fake/gfx/new"        ; path
    sys 3                       ; open
    dup 0                       ; handle
    push 1                      ; size
    sys 4                       ; read
    dup 1                       ; file handle
    sys 7                       ; flush
    disc 1                      ; file handle
    ret

_TextureUpload:
    push "/fake/gfx/upload"     ; path
    sys 3                       ; open
    dup 0                       ; handle
    dup 2                       ; idx
    dup 4                       ; data
    cat
    sys 5                       ; write
    sys 7
    disc 0
    disc 0
    push 0
    ret

_TextureDestroy:
    push "/fake/gfx/destroy"
    sys 3
    dup 0
    dup 2
    sys 5                       ; write
    sys 7
    disc 0
    ret

_TextureHeight:
    dup 0
    disc 1
    push 6
    add
    getb
    ret

_TextureWidth:
    dup 0
    disc 1
    push 4
    add
    getb
    ret