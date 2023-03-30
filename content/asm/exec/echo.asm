    push 1

loop_args:
    dup 0
    sys 8
    copy 0
    jz end
    call process_arg
    push 1
    add
    jmp loop_args

process_arg:
    sys 0
    push " "
    sys 0
    ret

end:
    disc 0
    disc 0
    sys 1
