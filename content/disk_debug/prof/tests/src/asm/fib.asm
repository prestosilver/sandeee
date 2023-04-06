    call 24
    sys 1
    copy 0
    push 2
    lt
    jz 11
    copy 0
    disc 1
    dup 0
    disc 1
    ret
    copy 0
    push 1
    sub
    call 2
    copy 1
    push 2
    sub
    call 2
    add
    disc 1
    dup 0
    disc 1
    ret
    push 0
    copy 0
    push 0
    set
    disc 0
    copy 0
    push 20
    lt
    jz 46
    copy 0
    call 2
    sys 0
    push 10
    getb
    sys 0
    copy 0
    copy 1
    push 1
    add
    set
    disc 0
    jmp 29
    push "Done"
    sys 0
    dup 0
    disc 1
    ret
