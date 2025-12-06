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

_TextureExportOver:             ; tex path
    dup 0                       ; tex path path
    sys 23                      ; tex path
    push "/fake/gfx/save"       ; tex path file
    sys 3                       ; tex path handle
    dup 0                       ; tex path handle handle
    dup 3                       ; tex path handle handle tex
    dup 3                       ; tex path handle handle tex path
    cat                         ; tex path handle handle data
    sys 5                       ; tex path handle
    sys 7                       ; tex path
    disc 0                      ; tex
    disc 0                      ;
    push 0                      ; result
    ret

_TextureExport:                 ; tex path
    push "/fake/gfx/save"       ; tex path file
    sys 3                       ; tex path handle
    dup 0                       ; tex path handle handle
    dup 3                       ; tex path handle handle tex
    dup 3                       ; tex path handle handle tex path
    cat                         ; tex path handle handle data
    sys 5                       ; tex path handle
    sys 7                       ; tex path
    disc 0                      ; tex
    disc 0                      ;
    push 0                      ; result
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
    copy 0
    copy 2
    sys 5                       ; write
    sys 7
    disc 0
    push 0
    ret

_TextureHeight:
    dup 0
    disc 1
    dup 0
    push 6
    add
    getb
    dup 1
    push 7
    add
    getb
    push 255
    mul
    add
    disc 1
    ret

_TextureWidth:
    dup 0
    disc 1
    dup 0
    push 4
    add
    getb
    dup 1
    push 5
    add
    getb
    push 255
    mul
    add
    disc 1
    ret

_TextureSized:                  ; tex w h
    push "eimg"                 ; tex w h "eimg"
    dup 2                       ; tex w h "eimg" w
    getb                        ; tex w h "eimg" @w
    dup 3                       ; tex w h "eimg" @w w
    push 256                    ; tex w h "eimg" @w w 256
    div                         ; tex w h "eimg" @w w/256
    getb                        ; tex w h "eimg" @w @(w/256)
    cat                         ; tex w h "eimg" wstr
    dup 2                       ; tex w h "eimg" wstr h
    getb                        ; tex w h "eimg" wstr @h
    dup 3                       ; tex w h "eimg" wstr @h h
    push 256                    ; tex w h "eimg" wstr @h h 256
    div                         ; tex w h "eimg" wstr @h h/256
    getb                        ; tex w h "eimg" wstr @h @(h/256)
    cat                         ; tex w h "eimg" wstr hstr
    dup 4                       ; tex w h "eimg" wstr hstr w
    dup 4                       ; tex w h "eimg" wstr hstr w h
    mul                         ; tex w h "eimg" wstr hstr area
    zero                        ; tex w h "eimg" wstr hstr data
    cat
    cat
    cat                         ; tex w h data
    push "/fake/gfx/upload"     ; tex w h data path
    sys 3                       ; tex w h data handle
    dup 0                       ; tex w h data handle handle
    dup 2                       ; tex w h data handle handle data
    dup 6                       ; tex w h data handle handle data tex
    cat                         ; tex w h data handle handle writes
    sys 5                       ; tex w h data handle
    sys 7                       ; tex w h data
    disc 0                      ; tex w h 
    disc 0                      ; tex w 
    disc 0                      ; tex 
    disc 0                      ; 0
    push 0
    ret
