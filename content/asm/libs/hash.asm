_TEST_FN:
    push "Hello"
    sys 0
    ret

_CRC32:
    push 0                      ; data
    push 1
    sub                         ; data crc32

    push 0                      ; data crc32 i
loop:
    copy 1                      ; data crc32 i *crc32 // start test
    copy 1                      ; data crc32 i *crc32 *i
    add                         ; data crc32 i *crc32[i]
    jz stop                     ; data crc32 i
    copy 1                      ; data crc32 i *crc32
    copy 3                      ; data crc32 i *crc32 *data
    dup 2                       ; data crc32 i *crc32 *data i
    add                         ; data crc32 i *crc32 *data[i]
    getb                        ; data crc32 i *crc32 data[i]
    xor                         ; data crc32 i *crc32^data[i]
    push 255                    ; data crc32 i *crc32^data[i] 255
    and                         ; data crc32 i lookupIdx
    call get_table              ; data crc32 i xors
    push 256                    ; data crc32 i xors 256
    div                         ; data crc32 i xors
    copy 1                      ; data crc32 i xors *crc32
    dup 1                       ; data crc32 i xors *crc32 xors
    xor                         ; data crc32 i xors *crc32
    disc 0                      ; data crc32 i xors
    disc 0                      ; data crc32 i

    push 1                      ; data crc32 i 1
    add                         ; data crc32 i
    jmp loop
stop:
    disc 0
    disc 1
    ret

get_table:
    push 256
    mul
    push 7
tab_loop:
    dup 0
    push 128
    and
    jnz else
    push 2
    div
    jmp done
else:
    push 2
    div
    push 79764919
    xor
done:
    push 1
    sub
    dup 0
    push 1
    add
    jnz tab_loop
    disc 0
    ret
