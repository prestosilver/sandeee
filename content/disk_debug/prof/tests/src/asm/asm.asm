    call main
    sys 1
setupLibLoad:
    push "/libs/libload.eep"
    sys 3
    copy 0
    push 4
    sys 4
    disc 0
    copy 0
    push 100000
    sys 4
    push "libload"
    sys 12
    sys 7
    push 0
    dup 0
    disc 1
    ret
loadLib:
    dup 0
    call "libload"
    push 0
    disc 1
    dup 0
    disc 1
    ret
tableCreate:
    copy 1
    getb
    copy 1
    getb
    push 0
    getb
    cat
    cat
    disc 1
    disc 1
    dup 0
    disc 1
    ret
tableLen:
    copy 0
    push 2
    add
    copy 0
    getb
    disc 1
    disc 1
    dup 0
    disc 1
    ret
tableValueSize:
    copy 0
    push 1
    add
    copy 0
    getb
    disc 1
    disc 1
    dup 0
    disc 1
    ret
tableKeySize:
    copy 0
    push 0
    add
    copy 0
    getb
    disc 1
    disc 1
    dup 0
    disc 1
    ret
tableEntrySize:
    copy 0
    call dup
    call tableKeySize
    copy 1
    call dup
    call tableValueSize
    add
    disc 1
    dup 0
    disc 1
    ret
setSize:
    copy 1
    call "StringLength"
    push 2
    sub
    copy 2
    push 3
    add
    copy 3
    copy 2
    sub
    copy 4
    copy 1
    copy 5
    getb
    copy 4
    cat
    cat
    set
    disc 0
    push 0
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
tableGetEntry:
    copy 1
    call dup
    call tableEntrySize
    copy 0
    copy 2
    mul
    copy 3
    copy 1
    push 3
    add
    add
    copy 0
    call "StringLength"
    copy 3
    sub
    copy 1
    copy 1
    sub
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
tableRemoveEntry:
    copy 1
    call "StringLength"
    copy 2
    call tableValueSize
    copy 3
    call tableKeySize
    add
    copy 0
    copy 3
    mul
    push 3
    add
    copy 2
    copy 1
    sub
    copy 5
    copy 1
    sub
    copy 3
    copy 6
    mul
    push 3
    copy 5
    add
    add
    copy 5
    copy 1
    sub
    copy 8
    copy 1
    add
    copy 3
    copy 1
    cat
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
tablePut:
    copy 2
    call dup
    call tableKeySize
    copy 2
    call "StringLength"
    eq
    not
    jz block_12_alt
    push 0
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
    jmp block_12_end
block_12_alt:
block_12_end:
    copy 2
    call dup
    call tableValueSize
    copy 1
    call "StringLength"
    eq
    not
    jz block_13_alt
    push 0
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
    jmp block_13_end
block_13_alt:
block_13_end:
    copy 2
    call dup
    call tableLen
    copy 3
    call dup
    call tableValueSize
    copy 4
    call dup
    call tableKeySize
    push 0
    push ""
    push ""
    copy 2
    push 0
    set
    disc 0
block_14_loop:
    copy 2
    copy 6
    lt
    jz block_14_end
    copy 1
    copy 9
    copy 4
    call tableGetEntry
    set
    disc 0
    copy 0
    copy 2
    copy 6
    sub
    set
    disc 0
    copy 0
    copy 8
    eq
    jz block_15_alt
    copy 8
    copy 3
    call tableRemoveEntry
    disc 0
    copy 8
    copy 9
    copy 9
    copy 9
    cat
    cat
    set
    disc 0
    push 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
    jmp block_15_end
block_15_alt:
block_15_end:
    copy 2
    copy 3
    push 1
    add
    set
    disc 0
    jmp block_14_loop
block_14_end:
    copy 8
    copy 6
    push 1
    add
    call setSize
    disc 0
    copy 8
    copy 9
    copy 9
    copy 9
    cat
    cat
    set
    disc 0
    push 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
tableGet:
    copy 1
    call dup
    call tableKeySize
    copy 1
    call "StringLength"
    eq
    not
    jz block_16_alt
    push 0
    disc 1
    disc 1
    dup 0
    disc 1
    ret
    jmp block_16_end
block_16_alt:
block_16_end:
    copy 1
    call dup
    call tableLen
    copy 2
    call dup
    call tableValueSize
    copy 3
    call dup
    call tableKeySize
    push 0
    push ""
    push ""
    copy 2
    push 0
    set
    disc 0
block_17_loop:
    copy 2
    copy 6
    lt
    jz block_17_end
    copy 1
    copy 8
    call dup
    copy 4
    call tableGetEntry
    set
    disc 0
    copy 0
    copy 2
    call dup
    copy 6
    sub
    set
    disc 0
    copy 0
    copy 7
    eq
    jz block_18_alt
    copy 1
    copy 8
    call dup
    copy 4
    call tableGetEntry
    set
    disc 0
    copy 1
    call dup
    copy 4
    add
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
    jmp block_18_end
block_18_alt:
block_18_end:
    copy 2
    copy 3
    push 1
    add
    set
    disc 0
    jmp block_17_loop
block_17_end:
    push 0
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
getArg:
    sys 8
    ret
print:
    sys 0
    push 0
    ret
quit:
    sys 1
open:
    sys 3
    ret
createOpen:
    dup 0
    sys 2
    sys 3
    ret
close:
    sys 7
    push 0
    ret
write:
    sys 5
    push 0
    ret
read:
    sys 4
    ret
dup:
    dup 0
    disc 1
    ret
error:
    push "Error: "
    copy 1
    cat
    call print
    disc 0
    call quit
    disc 0
processArgs:
    push 1
    call getArg
    copy 0
    push 0
    eq
    jz block_19_alt
    push "Bad Argument"
    call error
    disc 0
    jmp block_19_end
block_19_alt:
block_19_end:
    copy 0
    disc 1
    dup 0
    disc 1
    ret
stripLine:
    push 0
    copy 0
    copy 2
    getb
    set
    disc 0
block_20_loop:
    copy 0
    push 32
    eq
    jz block_20_end
    copy 1
    copy 2
    push 1
    add
    set
    disc 0
    copy 0
    copy 2
    getb
    set
    disc 0
    jmp block_20_loop
block_20_end:
    copy 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
getLineEnum:
    copy 0
    push "nop"
    call "StringStartsWith"
    jz block_21_alt
    push 0
    disc 1
    dup 0
    disc 1
    ret
    jmp block_21_end
block_21_alt:
    copy 0
    push "sys"
    call "StringStartsWith"
    jz block_22_alt
    push 1
    disc 1
    dup 0
    disc 1
    ret
    jmp block_22_end
block_22_alt:
    copy 0
    push "push"
    call "StringStartsWith"
    jz block_23_alt
    push 2
    disc 1
    dup 0
    disc 1
    ret
    jmp block_23_end
block_23_alt:
    copy 0
    push "add"
    call "StringStartsWith"
    jz block_24_alt
    push 3
    disc 1
    dup 0
    disc 1
    ret
    jmp block_24_end
block_24_alt:
    copy 0
    push "sub"
    call "StringStartsWith"
    jz block_25_alt
    push 4
    disc 1
    dup 0
    disc 1
    ret
    jmp block_25_end
block_25_alt:
    copy 0
    push "copy"
    call "StringStartsWith"
    jz block_26_alt
    push 5
    disc 1
    dup 0
    disc 1
    ret
    jmp block_26_end
block_26_alt:
    copy 0
    push "jmpf"
    call "StringStartsWith"
    jz block_27_alt
    push 9
    disc 1
    dup 0
    disc 1
    ret
    jmp block_27_end
block_27_alt:
    copy 0
    push "jmp"
    call "StringStartsWith"
    jz block_28_alt
    push 6
    disc 1
    dup 0
    disc 1
    ret
    jmp block_28_end
block_28_alt:
    copy 0
    push "jz"
    call "StringStartsWith"
    jz block_29_alt
    push 7
    disc 1
    dup 0
    disc 1
    ret
    jmp block_29_end
block_29_alt:
    copy 0
    push "jnz"
    call "StringStartsWith"
    jz block_30_alt
    push 8
    disc 1
    dup 0
    disc 1
    ret
    jmp block_30_end
block_30_alt:
    copy 0
    push "mul"
    call "StringStartsWith"
    jz block_31_alt
    push 10
    disc 1
    dup 0
    disc 1
    ret
    jmp block_31_end
block_31_alt:
    copy 0
    push "div"
    call "StringStartsWith"
    jz block_32_alt
    push 11
    disc 1
    dup 0
    disc 1
    ret
    jmp block_32_end
block_32_alt:
    copy 0
    push "and"
    call "StringStartsWith"
    jz block_33_alt
    push 12
    disc 1
    dup 0
    disc 1
    ret
    jmp block_33_end
block_33_alt:
    copy 0
    push "or"
    call "StringStartsWith"
    jz block_34_alt
    push 13
    disc 1
    dup 0
    disc 1
    ret
    jmp block_34_end
block_34_alt:
    copy 0
    push "not"
    call "StringStartsWith"
    jz block_35_alt
    push 14
    disc 1
    dup 0
    disc 1
    ret
    jmp block_35_end
block_35_alt:
    copy 0
    push "eq"
    call "StringStartsWith"
    jz block_36_alt
    push 15
    disc 1
    dup 0
    disc 1
    ret
    jmp block_36_end
block_36_alt:
    copy 0
    push "getb"
    call "StringStartsWith"
    jz block_37_alt
    push 16
    disc 1
    dup 0
    disc 1
    ret
    jmp block_37_end
block_37_alt:
    copy 0
    push "ret"
    call "StringStartsWith"
    jz block_38_alt
    push 17
    disc 1
    dup 0
    disc 1
    ret
    jmp block_38_end
block_38_alt:
    copy 0
    push "call"
    call "StringStartsWith"
    jz block_39_alt
    push 18
    disc 1
    dup 0
    disc 1
    ret
    jmp block_39_end
block_39_alt:
    copy 0
    push "neg"
    call "StringStartsWith"
    jz block_40_alt
    push 19
    disc 1
    dup 0
    disc 1
    ret
    jmp block_40_end
block_40_alt:
    copy 0
    push "xor"
    call "StringStartsWith"
    jz block_41_alt
    push 20
    disc 1
    dup 0
    disc 1
    ret
    jmp block_41_end
block_41_alt:
    copy 0
    push "disc"
    call "StringStartsWith"
    jz block_42_alt
    push 21
    disc 1
    dup 0
    disc 1
    ret
    jmp block_42_end
block_42_alt:
    copy 0
    push "set"
    call "StringStartsWith"
    jz block_43_alt
    push 22
    disc 1
    dup 0
    disc 1
    ret
    jmp block_43_end
block_43_alt:
    copy 0
    push "dup"
    call "StringStartsWith"
    jz block_44_alt
    push 23
    disc 1
    dup 0
    disc 1
    ret
    jmp block_44_end
block_44_alt:
    copy 0
    push "lt"
    call "StringStartsWith"
    jz block_45_alt
    push 24
    disc 1
    dup 0
    disc 1
    ret
    jmp block_45_end
block_45_alt:
    copy 0
    push "gt"
    call "StringStartsWith"
    jz block_46_alt
    push 25
    disc 1
    dup 0
    disc 1
    ret
    jmp block_46_end
block_46_alt:
    copy 0
    push "cat"
    call "StringStartsWith"
    jz block_47_alt
    push 26
    disc 1
    dup 0
    disc 1
    ret
    jmp block_47_end
block_47_alt:
block_47_end:
block_46_end:
block_45_end:
block_44_end:
block_43_end:
block_42_end:
block_41_end:
block_40_end:
block_39_end:
block_38_end:
block_37_end:
block_36_end:
block_35_end:
block_34_end:
block_33_end:
block_32_end:
block_31_end:
block_30_end:
block_29_end:
block_28_end:
block_27_end:
block_26_end:
block_25_end:
block_24_end:
block_23_end:
block_22_end:
block_21_end:
    push 255
    disc 1
    dup 0
    disc 1
    ret
getLineData:
    push 0
    copy 0
    copy 2
    getb
    set
    disc 0
block_48_loop:
    copy 0
    push 32
    eq
    not
    jz block_48_end
    copy 1
    copy 2
    push 1
    add
    set
    disc 0
    copy 1
    call "StringLength"
    push 0
    eq
    jz block_49_alt
    push 0
    getb
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
    jmp block_49_end
block_49_alt:
block_49_end:
    copy 0
    copy 2
    getb
    set
    disc 0
    jmp block_48_loop
block_48_end:
    copy 1
    copy 2
    push 1
    add
    set
    disc 0
    copy 1
    getb
    push 34
    eq
    copy 2
    call "StringLast"
    push 34
    eq
    copy 1
    copy 1
    and
    jz block_50_alt
    copy 3
    copy 4
    push 1
    add
    set
    disc 0
    copy 3
    copy 4
    push 1
    sub
    set
    disc 0
    push 2
    getb
    copy 4
    push 0
    getb
    cat
    cat
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
    jmp block_50_end
block_50_alt:
block_50_end:
    copy 3
    call "StringToNum"
    push ""
    copy 0
    copy 6
    call dup
    set
    disc 0
block_51_loop:
    copy 0
    call "StringLength"
    push 20
    lt
    jz block_51_end
    copy 0
    copy 1
    push 0
    getb
    cat
    set
    disc 0
    push 0
    disc 0
    jmp block_51_loop
block_51_end:
    copy 6
    copy 1
    call tableGet
    jz block_52_alt
    copy 1
    copy 7
    copy 2
    call tableGet
    getb
    set
    disc 0
    jmp block_52_end
block_52_alt:
block_52_end:
    copy 1
    push 256
    lt
    jz block_53_alt
    push 3
    getb
    copy 2
    getb
    cat
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
    jmp block_53_end
block_53_alt:
block_53_end:
    push 1
    getb
    copy 2
    cat
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
processLine:
    copy 0
    call stripLine
    copy 0
    call getLineEnum
    copy 0
    push 255
    eq
    jz block_54_alt
    push "Invalid Instruction "
    copy 2
    cat
    call error
    disc 0
    jmp block_54_end
block_54_alt:
block_54_end:
    copy 3
    copy 2
    call getLineData
    copy 1
    getb
    copy 1
    cat
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
processFile:
    copy 0
    push "EEEp"
    call write
    disc 0
    push ""
    copy 2
    push 1
    call read
    copy 0
    copy 1
    set
    disc 0
block_55_loop:
    copy 0
    push ""
    eq
    not
    jz block_55_end
    copy 0
    getb
    push 92
    eq
    jz block_56_alt
    copy 0
    copy 4
    push 1
    call read
    set
    disc 0
    copy 0
    getb
    push 110
    eq
    jz block_57_alt
    copy 1
    copy 2
    push 10
    getb
    cat
    set
    disc 0
    jmp block_57_end
block_57_alt:
    copy 1
    copy 2
    copy 2
    cat
    set
    disc 0
block_57_end:
    jmp block_56_end
block_56_alt:
    copy 0
    getb
    push 10
    eq
    jz block_58_alt
    copy 1
    call "StringLast"
    push 58
    eq
    not
    jz block_59_alt
    copy 2
    copy 5
    copy 3
    call processLine
    call write
    disc 0
    jmp block_59_end
block_59_alt:
block_59_end:
    copy 1
    push ""
    set
    disc 0
    jmp block_58_end
block_58_alt:
    copy 1
    copy 2
    copy 2
    cat
    set
    disc 0
block_58_end:
block_56_end:
    copy 0
    copy 4
    push 1
    call read
    set
    disc 0
    jmp block_55_loop
block_55_end:
    push 0
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
processConsts:
    push ""
    copy 1
    push 1
    call read
    push ""
    push 0
    copy 2
    copy 3
    set
    disc 0
block_60_loop:
    copy 2
    push ""
    eq
    not
    jz block_60_end
    copy 2
    getb
    push 92
    eq
    jz block_61_alt
    copy 2
    copy 5
    push 1
    call read
    set
    disc 0
    copy 2
    getb
    push 78
    eq
    jz block_62_alt
    copy 3
    copy 4
    push 10
    getb
    cat
    set
    disc 0
    jmp block_62_end
block_62_alt:
    copy 3
    copy 4
    copy 4
    cat
    set
    disc 0
block_62_end:
    jmp block_61_end
block_61_alt:
    copy 2
    getb
    push 10
    eq
    jz block_63_alt
    copy 3
    call "StringLast"
    push 58
    eq
    jz block_64_alt
    copy 1
    copy 4
    call dup
    push 1
    sub
    set
    disc 0
block_65_loop:
    copy 1
    call "StringLength"
    push 20
    lt
    jz block_65_end
    copy 1
    copy 2
    push 0
    getb
    cat
    set
    disc 0
    push 0
    disc 0
    jmp block_65_loop
block_65_end:
    copy 5
    copy 2
    copy 2
    getb
    call tablePut
    disc 0
    jmp block_64_end
block_64_alt:
    copy 0
    copy 1
    push 1
    add
    set
    disc 0
block_64_end:
    copy 3
    push ""
    set
    disc 0
    jmp block_63_end
block_63_alt:
    copy 3
    copy 4
    copy 4
    cat
    set
    disc 0
block_63_end:
block_61_end:
    copy 2
    copy 5
    push 1
    call read
    set
    disc 0
    jmp block_60_loop
block_60_end:
    push 0
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    disc 1
    dup 0
    disc 1
    ret
main:
    call setupLibLoad
    disc 0
    push "/libs/string.ell"
    call loadLib
    disc 0
    push 20
    push 1
    call tableCreate
    push "out.eep"
    copy 0
    call createOpen
    call processArgs
    copy 0
    call open
    copy 1
    call open
    push "READ: "
    copy 3
    push "\n"
    cat
    cat
    call print
    disc 0
    copy 5
    copy 2
    call processConsts
    disc 0
    copy 1
    call close
    disc 0
    push "ASM: "
    copy 3
    push "\n"
    cat
    cat
    call print
    disc 0
    copy 5
    copy 1
    copy 5
    call processFile
    disc 0
    push "Wrote: '"
    copy 5
    push "'\n"
    cat
    cat
    call print
    disc 0
    copy 0
    call close
    disc 0
    copy 3
    call close
    disc 0
    ret
