main:
    push 1
    sys 8                       ; get file arg
    copy 0
    jz error                    ; jump if zero
    sys 3                       ; open file

    copy 0                      ; duplacte file handle
    push 1000000                ; read size
    sys 4                       ; read
    push 4
    add
    push "main"
    sys 12

    push 17
    getb
    push 0
    getb
    cat
    push "_quit"
    sys 12

    push 0
    sys 20

    sys 9

    call "main"

    push "_quit"
    sys 13

    push 1
    sys 20
    sys 9
    copy 1
    disc 2
    sub
    sys 0
    sys 1

error:
    push "expected file"
    sys 18
