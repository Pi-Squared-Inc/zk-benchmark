#   This is framework code for a common command-line API for building,
#   testing and running checkers. It's not a stand-alone script (thus
#   it's not executable and has a .bash extension); it should be
#   sourced by the checker/*/*/check scripts as follows:
#
#       #!/usr/bin/env bash
#       . "$(dirname "$0")/../../common/check-api.bash"
#
#   The script must also supply build(), test() and check() functions that
#   accept appropriate arguments; in standard cases these can simply call
#   the *_{build,test,check}() functions defined here. After defining
#   these, the script should then call `main "$@"`.
#
#   Note that the command line parameters passed by the user may include
#   relative paths which will not work from other than the invoker's
#   directory. When using these, you must remain in the original CWD;
#   you can find files with $CHECKER and $BUILD when necessary.
#   If you must change CWD, use a subshell (e.g. `( command cd … && … )`),
#   but relative paths given on the command line will no longer be correct.
#
#   This exports the following variables:
#   • $CHECKER: absolute path to the checker's dir,
#     e.g. /…/checker/mm/mm-risc0
#   • $BUILD: absolute path to the checker's build directory,
#     always /…/.build/checker/.
#

set -Eeuo pipefail
trap '
    echo 1>&2 "INTERNAL ERROR:" \
        "ec=$? cmd=$BASH_COMMAND line=$LINENO file=${BASH_SOURCE[0]}"
' ERR

####################################################################
#   Utility functions; clients are free to use these

die() { ec="$1"; shift; echo 1>&2 "$(basename "$0"):" "$@"; exit "$ec"; }

fail() {
    #   args: none (we presume whatever failed has printed an error)
    #   This should be used on tests or other things we expect to pass
    #   or fail to indicate we may get failure, rather than the failure
    #   being a programming error in this script.
    ec="$?"; echo 2>&1 -e "FAILED (exit code $ec)"; exit $ec
}

####################################################################
#   Configuration and setup

export CHECKER=$(command cd "$(dirname "$0")" && pwd -P)
mkdir -p "$CHECKER/../../../.build/checker"
export BUILD=$(command cd "$CHECKER/../../../.build/checker" && pwd -P)

#   XXX Since this script knows where the build dir is, we could
#   consider removing checker/.cargo/config.toml containing
#   `target-dir = "../.build/checker"` and just using
#   --manifest-file and --target-dir options. However, this would expose
#   us to random values of other Cargo config variables based on the
#   invoker's CWD, so that might not be a great idea.

#   Use Rust in $PATH, if present, otherwise from $HOME/.cargo/.
if ! rustup --version >/dev/null 2>&1; then
    $HOME/.cargo/bin/rustup --version >/dev/null 2>&1 \
        && PATH="$HOME/.cargo/bin:$PATH" \
        || die 3 'rustup not found.'
fi

####################################################################
#   Main, usage, etc.

usage() {
    echo "$(basename "$0")" '[options] command [args…]'
    echo 'Commands:'
    echo "  build   build the checker; see the checker's README for build requirements"
    echo '  test    run the checker unit tests (requires a `build` first)'
    echo '  run     run the checker (requires a `build` first)'
    echo 'Options:'
    echo '  -d,--dry-run    don't run commands, just show what would be executed
    echo '  -c,--certgen    generate ZK certificate (greatly increases runtime)'
    echo '  -r,--release    build/use release version of code'
    echo '  -h,--help       print this help message'
}

#   We have the value and its inverse for this option setting because
#   which one is more convenient to use depends on the situation.
dry=
certgen=; nocertgen=1
releasever=
main() {
    while [[ $# -gt 0 ]]; do case "$1" in
        -h|--help)      usage; exit 0;;
        -d|--dry-run)   shift; dry=echo;;
        -r|--release)   shift; releasever=1;;
        -c|--certgen)   shift; certgen=1; nocertgen=;;
        -*)             die 2 "Unknown option: '$1'";;
        *)              break;;
    esac; done
    [[ $# -gt 0 ]] || { die 2 "argument required; -h for help"; }
    command="$1"; shift
    case "$command" in
        build)      build "$@";;
        test)       test "$@";;
        run)        run "$@";;
        *)          die 3 "Bad command '$command'";;
    esac
}

####################################################################
#   Rust/Cargo command functions; clients are free to call these

#   Cargo, for some stupid reason, does not read .cargo/config.toml
#   files upwards from where the manifest (Cargo.toml) lives, but from
#   the current working directory, which means that the configuration
#   may change based on where you run it. To avoid this, we always
#   cd into the given directory so we get a consistent configuration
#   regardless of the caller's CWD. This means that any paths given
#   on the command line are relative to the dir containing Cargo.toml,
#   but there's no easy way around this, since if we left you in CWD,
#   even if we find and pass all the configuration files at or above
#   the Cargo.toml dir, other files above where you happen to be would
#   also be processed.

build_rust() {
    (command cd "$CHECKER" && $dry cargo build --locked ${releasever:+--release} "$@") \
        || fail
}

test_rust() {
    local ncg="${nocertgen:+RISC0_DEV_MODE=1}"

    #   When we are generating certs, we need not run tests in parallel
    #   because each test will use all the cores available to do the
    #   cert generation. And use lots of memory, which interacts horribly
    #   with the `cargo test` default of running the tests in parallel.
    #   (On a 32 GB machine this will run you straight into swap and
    #   quickly start up the OOM killer, probably destroying your desktop
    #   session.) So in that case we limit this to one thread.
    local topts="${certgen:+-- --test-threads=1}"

    #   XXX This is broken if someone uses -c and wants to pass their
    #   own `-- …` arguments to `cargo test`; cargo seems to use only
    #   the *last* `--` and treats everything before it as test selectors,
    #   causing no tests to be run. Probably we should figure out if there's
    #   a `--` in $@ and add our own `--` before --test-threads only if
    #   $@ doesn't already have one.

    (   command cd "$CHECKER" \
            && $dry env $ncg cargo test --locked ${releasever:+--release} "$@" $topts
    ) ||  fail
}

run_risc0() {
    #   args: name of command under $BUILD/checker/{debug,release}/ to run
    #   followed by any args to pass to it.
    local command="$1"; shift
    local ver=debug
    [[ -n $releasever ]] && ver=release

    #   XXX dup from test_rust; we should abstract this somehow
    local ncg="${nocertgen:+RISC0_DEV_MODE=1}"

    # TODO: pass --segment-limit-po2 21 if running on 4090

    $dry env $ncg "$BUILD/$ver/$command" "$@" || fail
}
