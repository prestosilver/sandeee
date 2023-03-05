    call main
    sys 1

readb:
    push 1
    sys 4
    getb
    ret

load_lib_funcs:
    copy 0                      ; handle | handle
    call readb                  ; handle | libsize
    call get_lib_data_handle    ; handle | libhandle
    copy 1                      ; handle | libhandle handle
    call readb                  ; handle | libhandle count
loop:

    push 1
    sub
    jnz loop
    disc 0
    disc 0
    ret

verify_lib_header:
    copy 0                      ; handle | handle
    push 4                      ; handle | handle header_len
    sys 4                       ; handle | header
    push "elib"                 ; handle | header expected
    eq                          ; handle | equal
    jz error                    ; handle |
    ret                         ; handle |

get_lib_handle:
    copy 0                      ; args[1] *args[1]
    jz error                    ; args[1]
    sys 3                       ; handle
    ret

get_lib_data_handle:
    copy 0                      ; args[1] *args[1]
    jz error                    ; args[1]
    sys 3                       ; handle
    copy 1
    sys 4
    disc 1
    ret

main:
    call get_lib_handle         ; handle
    call verify_lib_header      ; handle
    call load_lib_funcs
    push "loading library"
    sys 0
    ret

error:
    disc 0
    push "Error: expected library file"
    sys 0
    sys 1
