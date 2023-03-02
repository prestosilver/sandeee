main:
    push 1
    sys 8                       ; get file arg
    dup 0
    jz error                    ; jump if zero
    sys 3                       ; open file

loop:
    dup 0                       ; duplacte file handle
    push 128                    ; read size
    sys 4                       ; read
    dup 0                       ; duplicate read
    sys 0                       ; print
    jnz loop                    ; reloop
    sys 1

error:
    disc 0
    push "Error: expected file"
    sys 0
    sys 1
