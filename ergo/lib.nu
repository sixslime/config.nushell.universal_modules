
export def valuePassCondition [empty: bool]: any -> closure {
    if $empty {
        { is-not-empty }
    } else {
        { $in != null }
    }
}

export def isType [
    typeMatchStr: string,
    --strict (-s),
]: any -> bool {
    let type = $in | describe;
    if $strict {
        return ($type == $typeMatchStr);
    };
    let matchStructure = $typeMatchStr | parseTypeAnnotation;
    if ($matchStructure.inner? | is-empty) {
        return ($type | str starts-with $matchStructure.base);
    };
    let inputStructure = $type | parseTypeAnnotation;
    let mergedStructure = $inputStructure | merge deep $matchStructure;
    ($inputStructure == $mergedStructure)
}

export def parseTypeAnnotation []: string -> record {
    const streamSuffix = ' (stream)';
    let typeAnnotation = $in
    | if ($in | str ends-with $streamSuffix) {
        $in | str substring ..(0 - (($streamSuffix | str length) + 1))
    } else {
        $in
    };
    let bracketIndex = $typeAnnotation | {
        left: ($in | str index-of '<'),
        right: ($in | str index-of '>' --end),
    };
    let missingBracketCount = $bracketIndex
    | items { |k, v| $v }
    | reduce -f 0 {|index, sum| $sum + (if ($index == -1) { 1 } else { 0 })};
    match $missingBracketCount {
        2 => {
            base: $typeAnnotation,
        },
        1 => (
            error make {
                msg: $"Type annotation '($typeAnnotation)' has mismatching angle<> brackets.",
            }
        ),
        0 => (
            let base = $typeAnnotation | str substring ..($bracketIndex.left - 1);
            let innerStr = $typeAnnotation | str substring ($bracketIndex.left + 1)..($bracketIndex.right - 1);
            let inner = $innerStr
            | split row ', '
            | each {|subtypeStr|
                let raw = $subtypeStr | split column -n 2 ': ' key subtype | first;
                let key = $raw.key;
                let subtype = $raw.subtype | parseTypeAnnotation;
                { $key: $subtype }
            }
            | into record;
            { base: $base, inner: $inner }
        )
    }
}