
use ./lib.nu *;

export def mapv [
    func: closure,
    --empty (-e),
]: any -> any {
    $in | mapv-if (valuePassCondition $empty) $func
}

export def mapv-if [
    condition: closure,
    func: closure,
]: any -> any {
    if ($in | do $condition) {
        $in | do $func
    } else {
        $in
    }
}

export def insertv [
    path: cell-path,
    value: any,
    --empty (-e),
]: record -> record {
    if ($value | do (valuePassCondition $empty)) {
        insert $path $value
    } else {
        $in
    }
}

export def filter-null [
    --empty (-e)
]: list<any> -> list<any> {
    let condition = valuePassCondition $empty;
    $in | where $condition
}

export def chain [modifier: closure]: closure -> closure {
    let prev = $in;
    { ($in | do $prev) | do $modifier }
}

export def flag-args [
    flagMap: record
]: nothing -> list<string> {
    ($flagMap
    | items {|flag, switch|
        if $switch { $flag } else { null }
    }
    | where { is-not-empty })
}

export def args [
    args: list<oneof<nothing, string>>
]: nothing -> list<string> {
    $args | filter-null
}

export def is-type [
    typeMatch: string,
    --strict (-s)
]: any -> bool {
    isType $typeMatch --strict=$strict;
}

export def describe-structured []: any -> record {
    describe | parseTypeAnnotation;
}

export def type-structure []: string -> record {
    parseTypeAnnotation;
}