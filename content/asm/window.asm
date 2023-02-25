main:
    call create_win             ; create window

    sys 9
    push 10000
    add
loop:
    sys 9
    dup 1
    lt
    jnz loop
    disc 0

    call destroy_win
    sys 1

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
