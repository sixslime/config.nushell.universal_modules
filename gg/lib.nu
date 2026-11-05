
use ../ergo *;

export def parseMessageArgs []: list<string> -> string {
    if not ($in | is-empty) {
        $in | str join ' '
    } else {
        '-'
    }
}

export def getMessageFromArgs [
    default: string = '-',
    --no-prompt (-n)
]: list<string> -> string {
    if ($in | is-not-empty) {
        $in | str join ' '
    } else {
        let prompt = $"(ansi light_blue)[!] commit message: (ansi reset)";
        if $no_prompt {
            $default
        } else {
            input -d $default $prompt
        }
    }
}
export def getSubmodules [recursive: bool]: nothing -> table<modulePath: string, cdPath: string> {
    ^git submodule -q foreach ...(flag-args {'--recursive':$recursive}) "echo $sm_path , $displaypath"
    | lines
    | each {
        match ($in | split row ' , ' -n 2) {
            [$modulePath, $cdPath] => { modulePath: $modulePath, cdPath: $cdPath }
        }
    }
    | sort-by -r { get modulePath | path split | length }
}

export def getDiff [from: string, to?: string]: nothing -> oneof<nothing, record<changes: list<string>, summary: string>> {
    let diffOut = ^git diff ...(args [$from, $to]) --stat --no-color | lines;
    if ($diffOut | is-empty) { null } else {
        {
            changes: ($diffOut | slice ..(-2)),
            summary: ($diffOut | last),
        }
    }
}

export def doPush []: nothing -> oneof<nothing, record, record<remote: string, diff: list<string>, summary: string>> {
    let branch = ^git branch --no-color --show-current;
    let upstream = ^git rev-parse --abbrev-ref --symbolic-full-name @{u};
    let diffCode = ^git diff $branch $upstream --quiet | complete | get exit_code;
    if $diffCode == 0 {
        print -e $"(ansi yellow)No differences to push. \(($branch) == ($upstream))(ansi reset)";
        return null;
    };
    let diff = getDiff $branch $upstream;
    print -e $"(ansi green)Pushing ($branch) to ($upstream)...(ansi reset)";
    let completion = ^git push | complete;
    if ($completion.exit_code == 0) {
        {
            summary: $diff.summary,
            diff: $diff.changes,
            remote: $upstream,
        }
    } else {
        print -e $"(ansi light_red)Push failed!(ansi reset)";
        $completion
    }
}

export def revCompare [
    from: string,
    to: string,
    --verbose (-v),
]: nothing -> record {
    ^git rev-list --left-right --count $"($from)..($to)"
    | parse -r "(?<behind>[0-9]+)\\s+(?<ahead>[0-9])"
    | first
    | items {|key, strVal|
        let value = $strVal | into int;
        if (($value != 0) or $verbose) {
            {$key: $value}
        }
    }
    | filter-null
    | into record
    | let compare
    | insert synced ([$compare.ahead?, $compare.behind?] | all {($in | is-empty) or ($in == 0)})
}

export def getBranch []: nothing -> string {
    ^git branch --show-current
    | default -e {
        $"*detached \((^git rev-parse --short HEAD))"
    }
}

export def getUpstream []: nothing -> oneof<nothing, string> {
    ^git rev-parse --abbrev-ref --symbolic-full-name @{u}
    | complete
    | if $in.exit_code == 0 {
        $in.stdout | str trim -r
    } else {
        null
    }
}