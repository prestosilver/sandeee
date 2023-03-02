main:
    call create_win             ; create window
    call create_tex             ; create a texture
    call read_texture
    dup 2
    call upload_tex
    call render

    sys 9
    push 10000                  ; 10 seconds
    add
loop:
    sys 9
    dup 1
    lt
    jnz loop
    disc 0

    call destroy_tex
    call destroy_win
    sys 1

render:
    push "/fake/win/render"     ; win tex | path
    sys 3                       ; win tex | handle
    dup 0                       ; win tex | handle handle
    dup 2                       ; win tex | handle handle tex
    dup 4                       ; win tex | handle handle tex win
    cat                         ; win tex | handle handle tex_win
    push 0
    push 0
    push 500
    push 500
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

read_texture:
    push "/cont/imgs/bar.eia"   ; path
    sys 3                       ; open
    dup 0                       ; handle
    push 100000000
    sys 4                       ; read
    dup 1
    sys 7
    disc 1
    ret

create_win:
    push "/fake/win/new"        ; path
    sys 3                       ; open
    dup 0                       ; handle
    push 1                      ; size
    sys 4                       ; read
    dup 1                       ; file handle
    sys 7                       ; flush
    disc 1                      ; file handle
    ret

destroy_win:
    push "/fake/win/destroy"
    sys 3
    dup 0
    dup 2
    sys 5
    sys 7
    disc 0
    ret

create_tex:
    push "/fake/gfx/new"        ; path
    sys 3                       ; open
    dup 0                       ; handle
    push 1                      ; size
    sys 4                       ; read
    dup 1                       ; file handle
    sys 7                       ; flush
    disc 1                      ; file handle
    ret

upload_tex:
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
    ret

destroy_tex:
    push "/fake/gfx/destroy"
    sys 3
    dup 0
    dup 2
    sys 5                       ; write
    sys 7
    disc 0
    ret
