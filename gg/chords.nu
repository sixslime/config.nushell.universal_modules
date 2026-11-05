
use ../ergo *;
use lib.nu *;

export def w [--push (-p), ...message: string]: nothing -> oneof<nothing, record> {
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
            $in
            | default {}
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
    print -e $"(ansi green)Pulling from (getUpstream)...(ansi reset)";
    let super: string = ^git pull | complete | get stdout;
    ^git submodule update --recursive --init -q;
    let gitModulesFile: string = [(git rev-parse --show-toplevel), ".gitmodules"] | path join;
    let submodules = getSubmodules true
    | each {|submodule|
        cd $submodule.cdPath;
        print -e $"(ansi blue)[($submodule.modulePath)](ansi reset)";
        let branch = ^git branch --show-current
        | complete
        | get stdout
        | if ($in | is-empty) {
            let configBranch = ^git config -f $gitModulesFile $"submodules.($submodule.modulePath).branch" | complete | get stdout;
            let switchBranch = if ($configBranch | is-empty) { "main" } else { $configBranch };
            git switch -qC $switchBranch;
            print -e $"(ansi green)Created local tracking branch '($switchBranch)'.(ansi reset)";
            $switchBranch
        };
        print -e $"(ansi green)Fetching...(ansi reset)";
        ^git fetch -q;
        let upstream = getUpstream;
        let revCompare = revCompare HEAD $upstream;
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

export def st []: nothing -> record {
    let branch = getBranch;
    let upstreamSource = getUpstream;
    let remote = if ($upstreamSource | is-not-empty) {
        {
            source: $upstreamSource,
            status: (revCompare $upstreamSource HEAD)
        }
    };
    let dirty = getDiff 'HEAD' | mapv { get changes -o };
    { branch: $branch }
    | insertv remote $remote
    | if ($dirty | is-not-empty) {
        insert dirty $dirty
    } else {
        insert clean true
    }
}

export def stt []: nothing -> record {
    let super = st;
    let submodules = getSubmodules true
    | each {|submodule|

    }
}
