main:
    push "/fake/net/send"
    sys 3
    dup 0
    push 10
    getb
    push "test\n"
    cat
    sys 5
    sys 6
