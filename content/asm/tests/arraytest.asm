    call setup_load
    push "/libs/string.ell"
    call "libload"
    push "/libs/array.ell"
    call "libload"

    push "len of "
    sys 0
    push "lolol"
    copy 0
    sys 0
    push " is: "
    sys 0
    call "StringLength"
    sys 0
    push "\n"
    sys 0

    push "Create array "
    sys 0
    push 2
    call "ArrayCreate"
    push "Success!\nlength: "
    sys 0
    copy 0
    call "ArrayGetLen"
    sys 0
    push "\nAppend array "
    sys 0
    push "lo"
    call "ArrayAppend"
    push "Success!\nlength: "
    sys 0
    call "ArrayGetLen"
    sys 0
    sys 1

setup_load:
    push "/libs/libload.eep"    ; libload
    sys 3                       ; handle
    copy 0                      ; handle handle
    push 4                      ; handle handle cont_size
    sys 4                       ; handle cont
    disc 0                      ; handle
    copy 0                      ; handle handle
    push 100000                 ; handle handle cont_size
    sys 4                       ; handle cont
    push "libload"              ; handle cont name
    sys 12                      ; handle
    sys 7
    ret
