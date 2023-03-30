main:
    push "/fake/net/recv"
    sys 3
    dup 0
    push 10
    getb
    push "192.168.1.114"
    cat
    sys 5
    sys 7

    push "/fake/net/recv"
    sys 3
    dup 0
    push 5
    sys 4
    sys 0
