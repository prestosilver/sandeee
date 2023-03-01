    call main
    sys 1
get_arg:
    sys 8
    ret
print:
    dup 0
    sys 0
    ret
open_file:
    sys 3
    ret
read:
    sys 4
    ret
main:
    push 1
    call get_arg
    copy 0
    push ""
    eq
    jz block_0_alt
    push "Error: expected file"
    call print
    disc 0
    dup 0
    disc 1
    ret
    jmp block_0_end
block_0_alt:
block_0_end:
    copy 0
    call open_file
    push ""
    copy 0
    copy 2
    push 128
    call read
    set
    disc 0
block_1_loop:
    copy 0
    jz block_1_end
    copy 0
    call print
    disc 0
    copy 0
    copy 2
    push 128
    call read
    set
    disc 0
    jmp block_1_loop
block_1_end:
    disc 1
    disc 1
    dup 0
    disc 1
    ret
