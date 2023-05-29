_StringLength:                  ; str
    len
    ret

_StringSplit:                   ; str trg
    push 0                      ; str trg idx
split_loop:
    push 1
    add                         ; str trg idx
    dup 2                       ; str trg idx _str
    copy 1
    add                         ; str trg idx offset
    size 1                      ; str trg idx char
    copy 0                      ; str trg idx char char
    len                         ; str trg idx char valid
    jz split_end                ; str trg idx char
    eq                          ; str trg idx eql
    jnz split_good              ; str trg idx
    jmp split_loop              ; str trg idx
split_good:                     ; str trg idx
    disc 1                      ; str idx
    dup 1                       ; str idx str
    copy 1                      ; str idx str idx
    add                         ; str idx end
    copy 2                      ; str idx end str
    copy 2                      ; str idx end str idx
    size                        ; str idx end start
    disc 2                      ; str end start
    disc 2                      ; end start
    ret
split_end:                      ; str trg idx
    disc 1                      ; str idx
    len                         ; start
    push ""                     ; end
    ret


_StringStartsWith:              ; str start
    copy 1                      ; str start str
    copy 2                      ; str start str str
    call "StringLength"         ; str start str strlen
    copy 2                      ; str start str strlen start
    call "StringLength"         ; str start str strlen startlen
    sub                         ; str start str strextra
    sub                         ; str start strstart
    disc 2                      ; start strstart
    eq
    ret

_StringEndsWith:                ; str start
    copy 1                      ; str start str
    copy 2                      ; str start str str
    call "StringLength"         ; str start str strlen
    copy 2                      ; str start str strlen start
    call "StringLength"         ; str start str strlen startlen
    sub                         ; str start str strextra
    add                         ; str start strstart
    disc 2                      ; start strstart
    eq
    ret

_StringLast:
    copy 0                      ; str
    call "StringLength"         ; str len
    push 1                      ; str len
    sub                         ; str len
    add                         ; last
    getb                        ; lastb
    ret

_StringIsNum:
    dup 0
    disc 1
    push 0                      ; string idx
num_loop:
    copy 1                      ; string idx string
    copy 1                      ; string idx string idx
    add                         ; string idx stringoff
    getb                        ; string idx char
    copy 0                      ; string idx char char
    push 47                     ; string idx char char /
    gt                          ; string idx char gt
    copy 1                      ; string idx char gt char
    push 58                     ; string idx char gt char :
    lt                          ; string idx char gt lt
    and                         ; string idx char anum
    disc 1                      ; string idx anum
    jz num_bad                  ; string idx
    push 1                      ; string idx 1
    add                         ; string idx
    copy 1                      ; string idx string
    copy 1                      ; string idx string idx
    add                         ; string idx stringoff
    jnz num_loop                ; string idx
    disc 0                      ; string
    disc 0                      ;
    push 1                      ; 1
    ret
num_bad:
    disc 0
    disc 0
    push 0
    ret

_StringToNum:
    push 0                      ; str result
tonum_loop:
    push 10                     ; str result 10
    mul                         ; str result
    copy 1                      ; str result 0 str
    getb                        ; str result 0 char
    push 48
    sub                         ; str result num
    add                         ; str result
    copy 1                      ; str result str
    push 1                      ; str result str 1
    add                         ; str result str
    copy 1                      ; str result str result
    disc 3                      ; result str result
    disc 2                      ; str result
    copy 1                      ; str result str
    jnz tonum_loop              ; str result
    disc 1
    ret

_StringSub:                     ; str start len
    copy 2                      ; str start len result
    copy 2                      ; str start len result start
    add                         ; str start len result
    disc 2                      ; str len result
    disc 2                      ; len result
    copy 1                      ; len result len
    size                        ; len result
    disc 1                      ; result
    ret
