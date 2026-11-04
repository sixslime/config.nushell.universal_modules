
export def w [--push (-p), ...message: string]: nothing -> oneof<nothing, record<branch: string, hash: string, message: string, diff: list<string>, summary: string>> {
    let message = $message | parseMessageArgs;
    let commitResult = do {
        ^git add -A;
        let branch = ^git branch --no-color --show-current;
        let diff = getDiff '--staged' 'HEAD';
        if ($diff | is-empty) {
            print -e $"(ansi yellow)No changes to commit. \(($branch))(ansi reset)";
            return null;
        };
        print -e $"(ansi green)Committing to ($branch)...(ansi reset)";
        ^git commit -qam $message;
        let hash = ^git rev-parse HEAD;
        {
            summary: $diff.summary,
            diff: $diff.changes,
            branch: $branch,
            hash: $hash,
            message: $message,
        }
    };
    $commitResult
    | if not $push { $in } else {
        let push = doPush;
        $in
        | if $push == null { $in } else {
            default {}
            | insert push $push
        }
    }
}

export alias wp = w --push;

export def wr [--push (-p), ...message: string]: nothing -> record<super: oneof<record, nothing>, submodules: table<path: string, result: record>> {
    let message = $message | parseMessageArgs;
    let submodules = getSubmodules true
    | each {|submodule|
        cd $submodule.cdPath;
        print -e $"(ansi blue)[($submodule.modulePath)](ansi reset)";
        let result = w --push=$push '[submodule]' $message;
        if $result == null { null } else { { path: $submodule.modulePath, result: $result } }
    };
    print -e $"(ansi blue_bold)[SUPER](ansi reset)";
    let super = w --push=$push $message;
    {
        submodules: $submodules,
        super: $super,
    }
}

export alias wrp = wr --push;

export def fr [--pull-submodules (-u)] {
    print -e $"(ansi blue_bold)[SUPER](ansi reset)";
    print -e $"(ansi green)Pulling from (get-upstream)...(ansi reset)";
    let super: string = ^git pull | complete | get stdout;
    ^git submodule update --recursive --init;
    let gitModulesFile: string = [(git rev-parse --show-toplevel), ".gitmodules"] | path join;
    let submodules = getSubmodules true
    | each {|submodule|
        cd $submodule.cdPath;
        let branch = ^git branch --show-current
        | complete
        | get stdout
        | if ($in | is-empty) {
            let configBranch = ^git config -f $gitModulesFile $"submodules.($submodule.modulePath).branch" | complete | get stdout;
            let switchBranch = if ($configBranch | is-empty) { "main" } else { $configBranch };
            git switch -C $switchBranch;
            $switchBranch
        };
        print -e $"(ansi blue)[($submodule.modulePath)](ansi reset)";
        print -e $"(ansi green)Fetching...(ansi reset)";
        ^git fetch -q;
        let upstream = get-upstream;
        let revCompare = rev-compare HEAD $upstream;
        let result = {
            upstream: $upstream,
            this: $revCompare,
        } | if $pull_submodules {
            let pull = if ($revCompare.synced) {
                print -e $"(ansi yellow)Already up to date with ($upstream).(ansi reset)"
                "Already up to date."
            } else {
                print -e $"(ansi green)Pulling from ($upstream)...(ansi reset)";
                ^git pull | complete | get stdout
            };
            $in | insert pull $pull
        } else { $in }
        { path: $submodule.modulePath, result: $result }
    };
    {
        super: $super,
        submodules: $submodules,
    }
}

export alias fru = fr --pull-submodules;

export def get-upstream []: nothing -> string {
    ^git rev-parse --abbrev-ref --symbolic-full-name @{u}
}

export def get-submodules [--recursive (-r)]: nothing -> table<modulePath: string, cdPath: string> {
    getSubmodules $recursive
}

export def rev-compare [from: string, to: string]: nothing -> record {
    let compare = git rev-list --left-right --count $"($from)...($to)"
    | parse -r "(?<behind>[0-9]+)\\s+(?<ahead>[0-9])"
    | first;
    let compare = {
        behind: ($compare.ahead | into int),
        ahead: ($compare.behind | into int),
    };
    $compare | insert synced (($compare.ahead == 0) and ($compare.behind == 0))
}

def parseMessageArgs []: list<string> -> string {
    if not ($in | is-empty) {
        $in | str join ' '
    } else {
        '-'
    }
}
def getSubmodules [recursive: bool]: nothing -> table<modulePath: string, cdPath: string> {
    ^git submodule -q foreach (if $recursive {'--recursive'} else {''}) "echo $sm_path , $displaypath"
    | lines
    | each {
        match ($in | split row ' , ' -n 2) {
            [$modulePath, $cdPath] => { modulePath: $modulePath, cdPath: $cdPath }
        }
    }
    | sort-by -r { get modulePath | path split | length }
}

def getDiff [from: string, to: string]: nothing -> oneof<nothing, record<changes: list<string>, summary: string>> {
    let diffOut = ^git diff $from $to --stat --no-color | lines;
    if ($diffOut | is-empty) { null } else {
        {
            changes: ($diffOut | slice ..(-2)),
            summary: ($diffOut | last),
        }
    }
}

def doPush []: nothing -> oneof<nothing, record, record<remote: string, diff: list<string>, summary: string>> {
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

