
export def mapv [
    func: closure,
    --empty (-e),
]: any -> any {
    let condition = if $empty {
        { not ($in | is-empty) }
    } else {
        { $in != null }
    };
    $in | mapv-if $condition $func
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

export def chain [modifier: closure]: closure -> closure {
    let prev = $in;
    { ($in | do $prev) | do $modifier }
}

export def flag-args [flagMap: record]: nothing -> list<string> {
    ($flagMap
    | items {|flag, switch|
        if $switch { $flag } else { null }
    }
    | where { is-not-empty })
}