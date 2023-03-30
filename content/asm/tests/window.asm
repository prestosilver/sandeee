main:
    call setup_load

    push "/libs/window.ell"
    call "libload"

    call "WindowCreate"         ; create window

    sys 9
    push 1000                   ; 1 second
    add
loop:
    sys 9
    dup 1
    lt
    jnz loop
    disc 0

    call "WindowDestroy"
    sys 1

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
