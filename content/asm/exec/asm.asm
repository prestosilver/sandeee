    call main
    sys 1

process_args:
    push 1
    sys 8
    jz error_file
    ret

open_file:
    push 1
    sys 8
    sys 3
    ret

strip_line:
    dup 0
    disc 1
strip_loop:                     ; line
    copy 0                      ; line line
    jz end_strip                ; line
    push 1                      ; line 1
    add                         ; line
    copy 0                      ; line line
    getb                        ; line first
    push 32                     ; line first space
    eq                          ; line isspace
    jnz strip_loop              ; line
end_strip:
    ret

get_line_enum:
    push 0                      ; line enum
    copy 1                      ; line enum line
    push "nop"                  ; line enum line "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 1                      ; line enum
    copy 1                      ; line enum line
    push "sys"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 2                      ; line enum
    copy 1                      ; line enum line
    push "push"                 ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 3                      ; line enum
    copy 1                      ; line enum line
    push "add"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 4                      ; line enum
    copy 1                      ; line enum line
    push "sub"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 5                      ; line enum
    copy 1                      ; line enum line
    push "copy"                 ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 6                      ; line enum
    copy 1                      ; line enum line
    push "jmp"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 7                      ; line enum
    copy 1                      ; line enum line
    push "jz"                   ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 8                      ; line enum
    copy 1                      ; line enum line
    push "jnz"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 9                      ; line enum
    copy 1                      ; line enum line
    push "jmpf"                 ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 10                     ; line enum
    copy 1                      ; line enum line
    push "mul"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 11                     ; line enum
    copy 1                      ; line enum line
    push "div"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 12                     ; line enum
    copy 1                      ; line enum line
    push "and"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 13                     ; line enum
    copy 1                      ; line enum line
    push "or"                   ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 14                     ; line enum
    copy 1                      ; line enum line
    push "not"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 15                     ; line enum
    copy 1                      ; line enum line
    push "eq"                   ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 16                     ; line enum
    copy 1                      ; line enum line
    push "getb"                 ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 17                     ; line enum
    copy 1                      ; line enum line
    push "ret"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 18                     ; line enum
    copy 1                      ; line enum line
    push "call"                 ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 19                     ; line enum
    copy 1                      ; line enum line
    push "neg"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 19                     ; line enum
    copy 1                      ; line enum line
    push "xor"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 20                     ; line enum
    copy 1                      ; line enum line
    push "xor"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 21                     ; line enum
    copy 1                      ; line enum line
    push "disc"                 ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 22                     ; line enum
    copy 1                      ; line enum line
    push "set"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 23                     ; line enum
    copy 1                      ; line enum line
    push "dup"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 24                     ; line enum
    copy 1                      ; line enum line
    push "lt"                   ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 25                     ; line enum
    copy 1                      ; line enum line
    push "gt"                   ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 26                     ; line enum
    copy 1                      ; line enum line
    push "cat"                  ; line enum "nop"
    call "StringStartsWith"     ; line enum isnop
    jnz line_enum_ret           ; line enum
    disc 0                      ; line

    push 255
line_enum_ret:
    ret

get_line_data:
    push 0                      ; line len
line_data_loop:
    push 1
    add
    copy 1
    copy 1
    add
    dup 0
    jz line_data_bad
    getb
    push " "
    getb
    eq
    jz line_data_loop
    push 1
    add
    add                         ; linedata
    dup 0                       ; linedata linedata
    getb                        ; linedata linefirst
    push 34                     ; linedata linefirst quote
    eq                          ; linedata isquote
    dup 1                       ; linedata isquote linedata
    call "StringLast"           ; linedata isquote linelast
    push 34                     ; linedata isquote linelast quote
    eq                          ; linedata isquote isquote
    and                         ; linedata isquote
    jnz line_data_string
    jmp line_data_num

line_data_string:
    push 1                      ; linedata 1
    sub                         ; linedata
    push 1                      ; linedata 1
    add                         ; linedata
    push 0                      ; linedata 0
    getb                        ; linedata result
    cat                         ; result
    push 2                      ; result 2
    getb                        ; result 2
    dup 1                       ; result 2 result
    cat                         ; result result
    disc 1                      ; result
    ret

line_data_num:
    push 1                      ; linedata result
    getb                        ; linedata result
    dup 1                       ; linedata result linedata
    disc 2                      ; result
    call "StringToNum"          ; linedata result linedat
    cat                         ; linedata result
    ret

line_data_bad:
    disc 0
    disc 0
    disc 0
    push 0
    getb
    ret

process_line:                   ; handle outhandle line next
    dup 1                       ; handle outhandle line next line
    call strip_line             ; handle outhandle line next stripped
    copy 0                      ; handle outhandle line next stripped
    jnz process_some
    disc 0                      ; handle outhandle line next
    ret
process_some:
    call get_line_enum          ; handle outhandle line next stripped enum
    copy 0
    push 255
    eq
    jnz error_unknown

    getb                        ; handle outhandle line next stripped _enum
    copy 4                      ; handle outhandle line next stripped _enum outhandle
    copy 1                      ; handle outhandle line next stripped _enum outhandle _enum
    disc 2                      ; handle outhandle line next stripped outhandle _enum
    sys 5                       ; handle outhandle line next stripped

    call get_line_data          ; handle outhandle line next _data
    copy 3                      ; handle outhandle line next _data outhandle
    copy 1                      ; handle outhandle line next _data outhandle _data
    disc 2                      ; handle outhandle line next outhandle _data
    sys 5                       ; handle outhandle line next

    disc 1                      ; handle outhandle next
    push ""                     ; handle outhandle next line
    copy 1                      ; handle outhandle next line next
    disc 2                      ; handel outhandle line next
    ret

process_file:                   ; handle outhandle
    copy 0
    push "EEEp"
    sys 5
    push ""                     ; handle outhandle line
process_loop:
    copy 2                      ; handle outhandle line handle
    push 1                      ; handle outhandle line handle 1
    sys 4                       ; handle outhandle line next
    push "\n"                   ; handle outhandle line next "\n"
    dup 1                       ; handle outhandle line next "\n" next
    eq                          ; handle outhandle line next isnl
    jz skip_process_line        ; handle outhandle line next
    call process_line           ; handle outhandle line next
    disc 0                      ; handle outhandle line
    jmp process_loop
skip_process_line:
    dup 0                       ; handle outhandle line next "" next
    jnz append                  ; handle outhandle line next
    jmp end_process             ; handle outhandle line next
append:
    cat                         ; handle outhandle line
    jmp process_loop

end_process:
    call process_line
    disc 0
    disc 0                      ; handle outhandle
    ret

main:
    call setup_load

    push "/libs/string.ell"
    call "libload"

    call process_args
    call open_file              ; handle
    push "out.eep"                ; handle out
    dup 0
    sys 2
    sys 3                       ; handle outhandle
    call process_file
    sys 7
    sys 7
    push "Wrote '"
    sys 0
    push "out.eep"
    sys 0
    push "'"
    sys 0

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

error_file:
    push "Error: expected file"
    sys 0
    sys 1

error_unknown:
    push "Error: bad token '"
    sys 0
    disc 0
    sys 0
    push "'"
    sys 0
    sys 1
