setupInclude:
    push "/libs/libload.eep"
    sys 3
    copy 0
    push 100000
    sys 4
    push 4
    add
    push "libload"
    sys 12
    sys 7
    ret

include:
    dup 0
    call "libload"
    ret