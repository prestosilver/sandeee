    call main
    sys 1

main:
    call setup_load

    push "/libs/string.ell"
    call "libload"
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
