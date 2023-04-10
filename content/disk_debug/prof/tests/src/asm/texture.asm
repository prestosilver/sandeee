main:
    call setup_load

    push "/libs/window.ell"
    call "libload"
    push "/libs/texture.ell"
    call "libload"

    call "WindowCreate"         ; create window
    call "TextureCreate"        ; create a texture
    push "/cont/imgs/wall.eia"  ; path
    call "TextureRead"
    dup 1
    call "TextureUpload"
    call render

    dup 1
    call "WindowFlip"

    sys 9
    push 1000 
    div
    push 1                  ; 1 second
loop:
    dup 3
    dup 3
    call render
    disc 0
    disc 0

    dup 3
    call "WindowFlip"
    disc 0

    call "WindowOpen"
    jnz loop
    disc 0

    call "TextureDestroy"
    call "WindowDestroy"
    sys 1

render:
    push "/fake/win/render"     ; win tex | path
    sys 3                       ; win tex | handle
    dup 0                       ; win tex | handle handle
    dup 2                       ; win tex | handle handle tex
    dup 4                       ; win tex | handle handle tex win
    cat                         ; win tex | handle handle tex_win
    push 0
    sys 9
    push 20
    div
    dup 0
    push 100
    div
    push 100
    mul
    sub
    push 512
    push 144
    call make_rect              ; win tex | handle handle tex_win rect
    cat
    push 0
    push 0
    push 1024
    push 1024
    call make_rect              ; win tex | handle handle tex_win rect
    cat                         ; win tex | handle handle tex_win_rect
    sys 5                       ; win tex | handle
    sys 7                       ; win tex
    ret

make_rect:
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
