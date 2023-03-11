    call setup_load
    push "/libs/string.ell"
    call "libload"
    push "/libs/table.ell"
    call "libload"

    push "Create table "
    sys 0
    push 2
    push 2
    call "TableCreate"
    push "Success!\nPut table"
    sys 0
    dup 0
    push "lo"
    push "no"
    call "TablePut"
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
