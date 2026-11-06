
export def in [
    glob: oneof<glob, string>,
    func: closure,
    --parallel (-p),
]: any -> any {
    let input = $in;
    let block = {
        cd $in;
        $input | do $func
    };
    let targetDirs: list<string> = try {
        glob $glob -F
    } catch {
        [($glob | into string)]
    };
    $targetDirs
    | if $parallel {
        par-each -k $block
    } else {
        each $block
    }
}
