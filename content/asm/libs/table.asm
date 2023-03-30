_TableCreate:                   ; keysize valuesize
    dup 1                       ; keysize valuesize keysize
    getb                        ; keysize valuesize _keysize
    disc 2                      ; valuesize _keysize
    dup 1                       ; valuesize _keysize valuesize
    getb                        ; valuesize _keysize _valuesize
    disc 2                      ; _keysize _valuesize
    cat                         ; _keysize_valuesize
    push 0                      ; _keysize_valuesize len
    getb                        ; _keysize_valuesize _len
    cat                         ; _keysize_valuesize_len
    ret

_TableLen:                      ; table
    push 2
    add
    getb
    ret

_TableValueSize:                ; table
    push 1
    add
    getb
    ret

_TableKeySize:                  ; table
    push 0
    add
    getb
    ret

_TableGetEntry:                 ; table idx
    copy 1                      ; table idx table
    call "TableKeySize"         ; table idx keysize
    copy 2                      ; table idx keysize table
    call "TableValueSize"       ; table idx keysize valuesize
    add                         ; table idx entrysize
    copy 2                      ; table idx entrysize table
    copy 2                      ; table idx entrysize table idx
    copy 2                      ; table idx entrysize table idx entrysize
    mul                         ; table idx entrysize table entrystart
    add                         ; table idx entrysize entry
    disc 2                      ; table entrysize entry
    disc 2                      ; entrysize entry
    dup 0                       ; entrysize entry entry
    call "StringLength"         ; entrysize entry entrylen
    copy 2                      ; entrysize entry entrylen entrysize
    sub                         ; entrysize entry entrylen
    sub                         ; entrysize entry
    disc 1                      ; entry
    ret

_TablePut:                      ; table key value
    copy 0                      ; table key value value
    copy 3                      ; table key value value table
    call "TableValueSize"       ; table key value value valuesize
    eq                          ; table key value test
    jz putErr                   ; table key value
    copy 1                      ; table key value key
    copy 3                      ; table key value key table
    call "TableKeySize"         ; table key value key keysize
    eq                          ; table key value test
    jz putErr                   ; table key value
    push 0                      ; table key value idx
putLoop:
    copy 3                      ; table key value idx table
    copy 1                      ; table key value idx table idx
    call "TableGetEntry"        ; table key value idx entry
    sys 0

    push 1
    ret
putErr:
    push "Error adding entry to table"
    push 0
    ret
