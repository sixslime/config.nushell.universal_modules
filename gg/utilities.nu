
use ../ergo *;
use lib.nu *;

export def get-upstream []: nothing -> oneof<nothing, string> {
    getUpstream
}

export def get-submodules [--recursive (-r)]: nothing -> table<modulePath: string, cdPath: string> {
    getSubmodules $recursive
}

export def get-branch []: nothing -> string {
    getBranch
}

export def rev-compare [
    from: string,
    to: string,
    --verbose (-v),
]: nothing -> record {
    revCompare $from $to --verbose=$verbose
}

export def get-diff [from: string= 'HEAD', to?: string]: nothing -> oneof<nothing, record<changes: list<string>, summary: string>> {
    getDiff $from $to
}
