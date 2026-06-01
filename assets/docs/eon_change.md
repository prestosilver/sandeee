# Eon throughout the years

Eon has gone through many changes throughout the years. Since it initially was only meant for internal use the team didnt often worry about full syntactical refactors.

## Early eon
Initially eon was untyped, and looked alot like js

```eon
#include "/libs/incl/sys.eon"

function main() {
    print("Hello World!");
    return 0;
}
```

## Libraries

The eon devs got sick of using `#include "/lib/incl/libload.eon"` with `loadLib(x)`, so a `#import` keyword was added. They also introduced some helpful aliases like void = 0.

```eon
#import "/libs/sys.ell"

function main() {
    var joe_name = "Joe";
    var joe_age = 16;

    print(joe_name + toString(joe_age));

    return void;
}
```

## Types

After a while, the eon devs noticed structs from c were quite nice. They riffed it with what they called "contracts".

```eon
#import "/libs/sys.ell"

contract Person :: (age, name);

function PersonToString(person) {
    return person.Person:name & " " & person.Person:age & "years old";
}

function main() {
    var joe = new Person;

    joe.Person:name = "Joe";

    print(PersonToString(joe));

    return void;
}
```

## Annotations

Later they realized it might be nice to force types to avoid repetition.

```eon
#import "/libs/sys.ell"

contract Person :: (age, name) where
    name: any,
    age: number;

function PersonToString(person) -> any where
    person: Person {
    return person.name & " " & person.age & "years old";
}

function main() {
    var joe: Person = new Person;
    
    joe.name = "Joe";

    print(PersonToString(joe));

    return void;
}
```

## Methods

They also realized it may be nice to associate functions with contracts. There was some restructuring with that but that finished eons base syntax up, and it was never changed since.

```eon
#import "/libs/sys.ell"

contract Person :: (age, name) where {
    age: number;
    name: stirng;

    function toString(person) -> any where
        person: Person {
        return person.name & " " & person.age & "years old";
    }
}

function main() {
    var joe: Person = new Person;
    
    joe.name = "Joe";

    print(joe.toString(joe));

    return void;
}
```