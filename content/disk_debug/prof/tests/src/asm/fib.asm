    call main
    sys 1
print:
    dup 0
    sys 0
    ret
fib:
    copy 0
    push 2
    lt
    jz block_0_alt
    copy 0
    disc 1
    ret
    jmp block_0_end
block_0_alt:
block_0_end:
    copy 0
    push 1
    sub
    call fib
    copy 1
    push 2
    sub
    call fib
    add
    disc 1
    ret
printfib:
    copy 0
    call fib
    copy 1
    call print
    disc 0
    push ": "
    call print
    disc 0
    copy 0
    call print
    disc 0
    push "\n"
    call print
    disc 0
    push 0
    disc 1
    disc 1
    ret
main:
    push 10
    call printfib
    disc 0
    ret
