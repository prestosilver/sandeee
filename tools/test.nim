import strutils
import tables
import os

var file = open("test.asm", fmRead)
var output = open("test.eep", fmWrite)

var consts: Table[string, int]
var idx: int = 0

for line in file.readall().split("\n"):
  var l = line.split(";")[0].strip()
  if l == "": continue
  if l[^1] == ':':
    consts[l[0..^2]] = idx
  else:
    idx += 1

output.write("EEEp")

file.close()

file = open("test.asm", fmRead)

for line in file.readall().split("\n"):
  var l = line.split(";")[0].strip()
  if l == "" or l[^1] == ':': continue

  var op = l.split(" ")[0]
  var code: byte = case op:
    of "nop": 0
    of "sys": 1
    of "push": 2
    of "add": 3
    of "sub": 4
    of "copy": 5
    of "jmp": 6
    of "jz": 7
    of "jnz": 8
    of "jmpf": 9
    of "mul": 10
    of "div": 11
    of "and": 12
    of "or": 13
    of "not": 14
    of "eq": 15
    of "getb": 16
    of "ret": 17
    of "call": 18
    of "neg": 19
    of "xor": 20
    of "disc": 21
    of "set": 22
    of "dup": 23
    else: 255
  if code == 255: quit "Error parsing " & op
  output.write(cast[char](code))
  if l.split(" ").len == 1:
    output.write("\x00")
  else:
    var val = l.split(" ")[1..^1].join(" ")
    if val[0] == '"' and val[^1] == '"':
      output.write("\x02")
      output.write(val.strip(chars = {'"'}).replace("\\n", "\n"))
      output.write("\x00")
    elif val in consts:
      if consts[val] < 256:
        output.write("\x03")
        output.write(cast[char](consts[val].byte))
      else:
        output.write("\x01")
        var lol = cast[array[8, char]](consts[val].uint64)
        for c in lol:
          output.write(c)
    else:
      var value = parseInt(val)
      if value < 256:
        output.write("\x03")
        output.write(cast[char](value.byte))
      else:
        output.write("\x01")
        var lol = cast[array[8, char]](value.uint64)
        for c in lol:
          output.write(c)

output.close()
