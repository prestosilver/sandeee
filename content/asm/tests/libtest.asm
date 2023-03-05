    call setup_load
    push "/libs/hash.ell"
    call "libload"
    call "TEST_FN"
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
