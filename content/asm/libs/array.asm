_ArrayCreate:                   ; size
    getb                        ; size
    push 0                      ; size len
    getb                        ; size len
    cat                         ; size_len (array)
    ret

_ArrayGetLen:                   ; array
    push 1                      ; array 1
    add                         ; array[len]
    getb                        ; array_len
    ret

_ArrayGetItemSize:              ; array
    getb                        ; array_itemsize
    ret

_ArrayGetData:                  ; array
    push 2                      ; array 2
    add                         ; array[data]
    ret

_ArrayAppend:                   ; array item |
    copy 1                      ; array item | array
    call "ArrayGetLen"          ; array item | arraylen
    push 1                      ; array item | arraylen 1
    add                         ; array item | _arraylen
    getb                        ; array item | _arraylen
    copy 2                      ; array item | _arraylen _array
    call "ArrayGetItemSize"     ; array item | _arraylen arrayitem
    getb                        ; array item | _arraylen _result
    copy 1                      ; array item | _arraylen _result _arraylen
    disc 2                      ; array item | _result _arraylen
    cat                         ; array item | _result
    copy 2                      ; array item | _result _array
    call "ArrayGetData"         ; array item | _result _arraydata
    disc 3                      ; item | _result _arraydata
    copy 2                      ; item | _result _arraydata item
    disc 3                      ; _result _arraydata item
    cat                         ; _result _arraydata
    cat                         ; _result
    ret
