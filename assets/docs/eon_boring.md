# Eon update plans

Ive lately noticed that Eon is not really that attractive of a language. Like yea its funcional, but with things like the UI library I just havent made it because its way too cumbersome.

There are a few things I need to fix this:
- Some sort of classes
- Add a fast array type
- Include .ell and .eon files

These are currently possible without modifying the vm.

# Classes

This is the one im the most undecided on, as is it the most difficult. In theory I could store layout for eon objects as a comptime thing, and then on emission have addr expressions that can get the slide. The downside is that this adds either a type system that I would need to track, though I can just have this export names and use the current calling convs.

This also brings way to for each loops, which can just auto call `iter = dup(collection)` and then `iter = iter.Group:last` every iter until its `== ""`.

After a bit of thought though, the layout should be like a toc, offset*entrys, then entries. each length being an offset from the object start. This means a default object is `repeat(<object fields>**8,<object feilds>)`

Heres a protype of this in action
```eon
group Example is a,b,c;
// fetch a
var tmp = new Example;
print(tmp.Example:c);
// emits as:
// dup [tmp]
// push 16 <- c is the third entry
// add
// <to u64>
// dup [tmp]
// swap
// add
// since c is the last entry I dont need to se the length
//     if it werent I would do that here 
// print

// assignments are a bit wacky ill have to reconstruct the object
tmp.Example:b = "5";
// emits as:
// dup [tmp]
// push 8 // b offset
// add
// <to u64>
// dup [tmp]
// push 24 // total size size
// add
// swap
// push 8 // b offset
// sub
// setlen
// push "5"
// cat
// Then concat other entries manually
```

This would look something like this for a structure like tables
```eon
group TableEntry is key,value,next;

fn TableCreate() {
    return new TableEntry;
}

fn TablePut(table, key, value) {
    var entry = table;
    while (true) {
        if (entry.TableEntry:key == key) {
            entry.TableEntry:value = value;
            // normally entry shouldnt be valid but since its the last element this dosent effect offsets.

            return 0;
        }

        // end of while loop
        if (entry.TableEntry:next == "") {
            entry.TableEntry:next = new TableEntry;
            entry.TableEntry:next.TableEntry:key = key;
            entry.TableEntry:next.TableEntry:value = value;

            return 0;
        }

        entry = entry.TableEntry:next;
    }
}

fn TableGet(table, key) {
    foreach (TableEntry entry in table) {
        if (entry.TableEntry:key == key) {
            return entry.TableEntry:value;
        }
    }

    return "";
}
```

This system shouldnt be too hard to implement in the zig->eon compiler. And since it improves the ergonomics so much itll make its way into the game quite easily. The only clear temporal downside is documentation.

Something that comes up with this is how child objects are set
```eon
group Foo is bar;
group Bar is baz;
group Baz is a;

var foo = new Foo; // good so far
foo.Foo:bar = new Bar; // ok.

foo.Foo:bar.Bar:Baz = new Baz; // Weird behaviour terretory
```
In this example foo.bar is a substring, so it has to be a dup of foo.
This means setting foo.bar.bas is like:
```eon
var tmp = setlen(dup(foo+0), 8)
tmp.bar = new Baz;
```

To fix this "I dont think":tm: I will need to modify the vm. If I make eon treat refs differently I should be able to store these as offsets on the stack, and then reify if I need to get, or append if I need to set. Though this is quite cumbersome, and it may make more sense to put a ref slice function into the vm.

# Arrays

This is similar to classes Ill just add a [] operator that can work with arrays. And then a `new [Length]` function for init. Like classes the set is slow, and the concat would not work with this.

```eon
main() {
    var a = new [10];
    
    a[5] = 7;
    // see the class assign.
    
    print(tonum(a[5]));
    // emits as:
    // 
    // dup [tmp]
    // push 5*8 <- c is the 8th entry
    // add
    // <to u64>
    // dup [tmp]
    // swap
    // add
    // I will need to setlen here, ez math tho.
    // print

    return 0;
}
```

# Includes

Luckily this last one is easy. Eon can just emit the .ell import code, along with auto calling it.