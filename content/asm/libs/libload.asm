    call main
    ret

readb:
    push 1
    sys 4
    getb
    ret

load_lib_funcs:
    copy 0                      ; libname handle | handle
    call readb                  ; libname handle | libsize
    call get_lib_data_handle    ; libname handle | libhandle
    disc 2                      ; handle | libhandle
    copy 1                      ; handle | libhandle handle
    call readb                  ; handle | libhandle count
loop:
    copy 2                      ; handle | libhandle count handle
    copy 0                      ; handle | libhandle count handle handle
    call readb                  ; handle | libhandle count handle namelen
    sys 4                       ; handle | libhandle count name
    copy 2                      ; handle | libhandle count name libhandle
    copy 4                      ; handle | libhandle count name libhandle handle
    call readb                  ; handle | libhandle count name libhandle datastart
    copy 5                      ; handle | libhandle count name libhandle datastart handle
    call readb                  ; handle | libhandle count name libhandle datastart datalen
    disc 1                      ; handle | libhandle count name libhandle datalen
    sys 4                       ; handle | libhandle count name data
    copy 1                      ; handle | libhandle count name data name
    sys 12                      ; handle | libhandle count name
    disc 0                      ; handle | libhandle count
    push 1                      ; handle | libhandle count 1
    sub                         ; handle | libhandle count
    dup 0                       ; handle | libhandle count count
    jnz loop                    ; handle | libhandle count
    disc 0                      ; handle | libhandle
    sys 7                       ; handle |
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
    copy 2                      ; libname handle libsize libname
    sys 3                       ; libname handle libsize libhandle
    copy 0                      ; libname handle libsize libhandle libhandle
    copy 2                      ; libname handle libsize libhandle libhandle libsize
    sys 4                       ; libname handle libsize libhandle discardable
    disc 0                      ; libname handle libsize libhandle
    disc 1                      ; libname handle libhandle
    ret

try_init:
    push "libInit"
    sys 10                      ; exists
    jz end_init
    call "libInit"
    push "libInit"
    sys 13
end_init:
    ret

main:
    copy 0                      ; libname libname
    call get_lib_handle         ; libname libname handle
    call verify_lib_header      ; libname libname handle
    call load_lib_funcs         ; libname
    disc 0                      ;
    call try_init
    ret

error:
    disc 0
    push "Error: expected library file"
    sys 0
    sys 1
