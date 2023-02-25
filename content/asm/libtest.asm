    call main
    sys 1
getlen:
    dup 0
    push 0
    eq
    jz block_0_alt
    push 0
    disc 1
    dup 0
    disc 1
    ret
    jmp block_0_end
block_0_alt:
block_0_end:
    push 0
    dup 0
    push 0
    set
    disc 0
block_1_loop:
    dup 1
    dup 1
    add
    jz block_1_end
    dup 0
    dup 1
    push 1
    add
    set
    disc 0
    jmp block_1_loop
block_1_end:
    dup 0
; SOMETHING 48
    sys 0
    dup 0
    disc 1
    disc 1
    dup 0
    disc 1
    ret
getline:
    push ""
    push 0
    dup 2
    dup 0
; SOMETHING 48
    sys 0
    push 0
    disc 0
block_2_loop:
    dup 0
    getb
    push 10
    eq
    push 1
    xor
    jz block_2_end
    dup 2
    push "lol"
    set
    disc 0
    dup 2
; SOMETHING 48
    sys 0
    dup 0
    dup 1
    push 1
    add
    set
    disc 0
    jmp block_2_loop
block_2_end:
    dup 2
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
startsWith:
    dup 1
    call getlen
    dup 1
    call getlen
    lt
    jz block_3_alt
    push 0
    disc 1
    disc 1
    dup 0
    disc 1
    ret
    jmp block_3_end
block_3_alt:
block_3_end:
    push 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
fib:
    dup 0
    push 2
    lt
    jz block_4_alt
    dup 0
    disc 1
    dup 0
    disc 1
    ret
    jmp block_4_end
block_4_alt:
block_4_end:
    dup 0
    push 1
    sub
    call fib
    dup 1
    push 2
    sub
    call fib
    add
    disc 1
    dup 0
    disc 1
    ret
main:
    push "lol"
    call getlen
; SOMETHING 48
    sys 0
    dup 0
    disc 1
    ret
