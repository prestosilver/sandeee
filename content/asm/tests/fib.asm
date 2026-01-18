    call main
    sys 1
fib:
    copy 0
    push 2
    lt
    jz block_0_alt
    copy 0
    disc 1
    dup 0
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
main:
    push 1
block_1_loop:
    copy 0
    push 15
    lt
    jz block_1_end
    copy 0
    call fib
    sys 0
    push "\n"
    sys 0
    copy 0
    copy 1
    push 1
    add
    set
    disc 0
    jmp block_1_loop
block_1_end:
    push "Done"
    sys 0
    dup 0
    disc 1
    ret
