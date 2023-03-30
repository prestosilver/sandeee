main:
    push "/fake/net/send"
    sys 3
    dup 0
    push 10
    getb
    push 1
    sys 8
    cat
    sys 5
    sys 6
