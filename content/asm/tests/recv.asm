main:
    push "/fake/net/recv"
    sys 3
    dup 0
    push 10
    getb
    push "127.0.0.1"
    cat
    sys 5
    sys 7

    push "/fake/net/recv"
    sys 3
    dup 0
    push 10000
    sys 4
    sys 0
