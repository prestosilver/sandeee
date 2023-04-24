main:
    push 1
    sys 8                       ; get file arg
    copy 0
    jz error                    ; jump if zero
    sys 3                       ; open file

loop:
    copy 0                      ; duplacte file handle
    push 1000000                ; read size
    sys 4                       ; read
    copy 0                      ; duplicate read
    sys 0                       ; print
    jnz loop                    ; reloop
    sys 1

error:
    push "expected file"
    sys 18
