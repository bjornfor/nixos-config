#!/usr/bin/env bash
#
# mini-ci is a continuous integration (CI) script based on Nix (nix-build) and
# git, intended to be run as a git pre-receive hook (or gitolite VREF). It
# assumes that builds are reproducible, and thus caches the build result of
# each commit.
#
# If you have more than one check to run in your pre-receive hooks (or gitolite
# VREFs), make sure this one runs last. Because if mini-ci succeeds, it writes
# data to disk to reflect the new state of the git repository (specifically,
# which commit the new ref points to). So if a later hook aborts the push, the
# state of mini-ci and the git repo will be out of sync, wrt. the state of the
# ref that was pushed. (The state will be fixed on the next push that succeeds
# for that ref though.)
#
# mini-ci maintains one directory ($datadir) containing build logs, artifacts
# and lock files for each repo it has been told to build. (Actually, $datadir
# contains only symlinks to build artifacts, the real files are stored in
# /nix/store/.) The $datadir/repo directory is intended to be served with a
# webserver.
#
# Here is the layout of the $datadir using `tree --charset=ascii`-like syntax:
# .
# |-- locks                             # lock files
# `-- repo
#     |-- $repo1
#     `-- $repoN
#         |-- commit
#         |   |-- $commit1
#         |   `-- $commitN
#         |       |-- $buildoutput1     # symlink to /nix/store...
#         |       |-- $buildoutputN     # symlink to /nix/store...
#         |       |-- README.txt        # metadata about the build inputs
#         |       |-- status.json       # contains "PASS" or "FAIL" (w/quotes)
#         |       `-- logs
#         |           |-- nix-build.log      # overall build log
#         |           |-- $buildoutput1.log  # output of nix-store -l $buildoutput1
#         |           `-- $buildoutputN.log  # output of nix-store -l $buildoutputN
#         |-- branch
#         |   |-- $branch1              # symlink to ../commit/$commitN
#         |   `-- $branchN              # symlink to ../commit/$commitN
#         `-- tag
#             |-- $tag1                 # symlink to ../commit/$commitN
#             `-- $tagN                 # symlink to ../commit/$commitN
#
# It is important that $datadir is inside the Nix GC roots tree. This allows
# mini-ci to persist artifacts built from branches and tags by simply adding
# symlinks to Nix store paths, while pruning older non-referenced builds. Note
# that the mini-ci "gc" action does not actually remove build artifacts. It
# only removes symlinks to artifacts. When the symlinks are removed, Nix is
# free to do the real GC. In other words, after a `mini-ci gc` run you must run
# `nix-store --gc` to reclaim the store paths.
#
# What is being kept alive by the GC roots symlinks can be seen with this
# command:
# $ nix-store --gc --print-roots | grep "^/nix/var/nix/gcroots/mini-ci"
#
# Apart from periodic runs of "mini-ci gc" (and nix-store --gc), it doesn't
# need much maintenance. However, since it is generally only invoked on git
# push operations, it will not be able to clean up repos that are renamed or
# deleted. Also, it never cleans up the $datadir/locks directory. You can "rm
# -rf $datadir/locks" once in a blue moon, if you like.
#
# Author: Bjørn Forsman

set -e

# Dependencies (not listing tools from coreutils and findutils)
GIT_BIN=git
NIX_BUILD_BIN=nix-build
NIX_STORE_BIN=nix-store
FLOCK_BIN=flock
# shellcheck disable=SC2209
SED_BIN=sed

external_deps=(
"$GIT_BIN"
"$NIX_BUILD_BIN"
"$NIX_STORE_BIN"
"$FLOCK_BIN"
"$SED_BIN"
)

### Options
# This one is not really an option, but it must be set before default_datadir=
progname=mini-ci
# Where repositories are fetched from (must be a local path, since we're going
# to be used in a git pre-receive hook)
repositories=/var/lib/gitolite/repositories
# Builds, logs and data is stored under this directory. The benefit of using a
# Nix gcroots (sub)directory is that any symlink to /nix/store will keep that
# path alive. This directory must be manually created and chowned by the user
# running mini-ci (typically to the gitolite hosting user).
default_datadir="/nix/var/nix/gcroots/$progname"
# If non-empty, mini-ci will print a line at the end of the build,
# $base_url/REPO/..., where build logs and artifacts can be viewed. Don't end
# with slash.
default_base_url=
# Default number of days to keep builds that are not (directly) kept alive by a
# branch or tag. (Builds being kept alive by branch or tag refs are never
# deleted. But you may delete them manually.)
default_gc_cutoff_days=60

### Implementation
action_build=build
action_hook=hook
action_gc=gc
# 40 zeros indicate non-existing git object
nullsha=0000000000000000000000000000000000000000

usage()
{
    cat << EOF
Usage:
  $progname $action_build --repo=path/to/repo.git --newrev=1234abc [--oldrev=1234abcd] [--verbose] [--datadir=$default_datadir]
  $progname $action_hook --repo=path/to/repo.git --oldrev=1234abcd --newrev=1234abc --ref=branch-or-tag [--verbose] [--datadir=$default_datadir] [--base-url=$default_base_url]
  $progname $action_gc [--dry-run] [--gc-cutoff-days=$default_gc_cutoff_days] [--repo=path/to/repo.git] [--verbose] [--datadir=$default_datadir]

* Repositories will be fetched from $repositories/ + path/to/repo.git.
* For testing purposes --oldrev= and --newrev= can be named references
  (--oldrev=master~3) and --ref= can be unqualified (--ref=master). When
  invoked as a pre-receive hook, it will receive full commit ids and fully
  qualified refs (--ref=refs/heads/master). For create and delete events,
  --oldrev= and --newrev can be a single '0' instead of the 40 0's that a
  pre-receive hook receives.
* For testing purposes, the "build" action can be used. It does not update a
  ref symlink, so it has less side-effects than the hook action.
* Read $0 for details.
EOF
}

info()
{
    echo "$progname: $*"
}

# Convert a possibly abbreviated commit (or ref) to the full length commit id.
# Returns non-zero status if not a valid commit/ref.
# Special case, a '0' is converted to 40 0's and 40 0's are passed through.
to_long_commit_sha()
{
    case "$1" in
        0|$nullsha)
            echo "$nullsha"
            ;;
        *)
            "$GIT_BIN" rev-parse --verify "$1"
            ;;
    esac
}

# Check if a ref in the repo keeps the given commit alive.
# (Here we only treat commits that are directly pointed to by the ref, not the
# normal "is reachable" semantics of git.)
is_kept_alive_by_some_ref()
{
    local repo="$1"
    local commit="$2"
    local nrrefs=0
    local repodir="$datadir/repo/$repo"
    test -d "$repodir" || { info "Not a directory: $repodir" >&2; exit 1; }
    while read -r link; do
        points_to=$(readlink "$link")
        case "$points_to" in
            *"$commit")
                nrrefs=$((nrrefs + 1))
                info "Commit $commit is kept alive via symlink $link"
                ;;
        esac
    done < <(find "$repodir" -type l)

    if [ "$nrrefs" -gt 0 ]; then
        # is kept alive by one or more refs
        return 0
    else
        # is NOT kept alive
        return 1
    fi
}

# Set GIT_DIR to point to a copy of the original git repo (ORIG_GIT_DIR). Cache
# it for performance.
init_repo_copy()
{
    repo_copy="$tmpdir/$repo.git"
    if ! [ -d "$repo_copy" ]; then
        test "$verbose" -eq 1 && info "Initializing temporary repo: $GIT_DIR -> $repo_copy"
        mkdir -p "$(dirname "$repo_copy")"
        # Possible optimizations:
        # * Use hardlinks (cp -l) and un-hardlink .git/HEAD afterwards.
        # * Use rsync to a persistent cache dir.
        cp -r "$ORIG_GIT_DIR" "$repo_copy"
        export GIT_DIR="$repo_copy"
    fi
}

# Builds a number of commits in the current repo.
# Assumes these variables exits (in addition to the ones needed by
# do_build_commit):
# - $oldrev
# - $newrev
do_build_commit_range()
{
    if [ "x$oldrev" = "x$newrev" ]; then
        info "Old and new revison is the same, nothing to build."
        return 0
    fi
    num_commits_total=$("$GIT_BIN" rev-list "$oldrev..$newrev" | wc -l)
    this_commit_number=1
    # Build commits in chronological order (--reverse)
    # "read" skips the last line if it doesn't end with a newline.
    while read -r commit; do
        if [ "$commit" = "" ]; then
            info "Commit range $oldrev..$newrev looks like a rewind operation, nothing to build."
        else
            do_build_commit
            this_commit_number=$((this_commit_number + 1))
        fi
    done < <("$GIT_BIN" log --reverse --pretty=format:%H "$oldrev..$newrev"; printf '\n')
}

# Build the current commit in the current repo.
# Assumes these variables exits:
# - $datadir
# - $repo (relpath)
# - $commit (full)
# - $num_commits_total
# - $this_commit_number
do_build_commit()
{
    # Build in a path named the same as the git repo, to make the build similar
    # to what a user would do if running git clone on a developer machine (Nix
    # 1.x uses the basename as input for hash calculation, when doing things
    # like src = ./.).
    commitdir="$datadir/repo/$repo/commit/$commit"
    tmpbuilddir="$commitdir/_build/$(basename "$repo")"
    logdir="$commitdir/logs"
    status_json="$commitdir/status.json"

    # Add a blank line before a build, to visually separate multiple builds.
    info ""

    commit_short=$("$GIT_BIN" log -1 "$commit" --format=%h)
    commit_subject=$("$GIT_BIN" log -1 "$commit" --format=%s)
    verbose_info=
    test "$verbose" -eq 1 && verbose_info=" in $tmpbuilddir"
    info "Building commit $this_commit_number/$num_commits_total: $commit_short (\"$commit_subject\")$verbose_info"

    if [ -f "$status_json" ]; then
        buildstatus=$(cat "$status_json")
        # When invoked in a pre-receive hook, this state indicates that someone
        # is trying to push a ref that was previously rejected due to build
        # failure. Since someone is actively working on it, let's refresh the
        # timestamp to postpone GC.
        touch "$commitdir"
    else
        buildstatus=not-built
    fi

    case "$buildstatus" in
        *PASS*)
            info "Cached build success."
            return 0
            ;;
        *FAIL*)
            n_lines=100
            info "This commit previously failed, the last <=$n_lines log lines were:"
            tail -n"$n_lines" "$logdir/nix-build.log" | "$SED_BIN" "s/^/$progname: nix-build: /"
            info ""
            info "In case that was a transient failure (like exhausted resoureces), we're going to try building again."
            ;;
        *)
            # Not built before
            true
            ;;
    esac

    trap 'rm -rf "$commitdir/_build"' EXIT
    rm -rf "$commitdir"
    mkdir -p "$tmpbuilddir"
    mkdir -p "$logdir"

    # Store some metadata about the build.
    cat > "$commitdir/README.txt" << EOF
This is a build from git repo "$repo" at commit "$commit" with the command "nix-build".
EOF
    cd "$tmpbuilddir"
    # Things to watch out for when checking out the commit:
    # * "git archive $commit | tar xf -" does not handle submodules.
    # * "git clone --recursive" does not work in pre-receive hook context,
    #   because the incoming objects are not fully visible yet (objects are
    #   quarantined until the push goes through).
    # * "git --work-tree=$tmp checkout" modifies HEAD of the bare repo (bad!).
    #
    # The solution is to copy the full bare git repo and use "git
    # --work-tree=$tmp checkout && [get submodules]" on the copy.
    init_repo_copy "$ORIG_GIT_DIR"
    "$GIT_BIN" --work-tree="$tmpbuilddir" checkout --quiet --force "$commit"
    "$GIT_BIN" --work-tree="$tmpbuilddir" submodule update --quiet --init --recursive
    # Submodules leave .git *files* in the tree. They must be removed, since
    # they may contain different content depending on where the repo is checked
    # out (not reporoducible).
    find "$tmpbuilddir" -name ".git" -print0 | xargs -0 --no-run-if-empty rm -rf
    cmd="cd \"$tmpbuilddir\" && \"$NIX_BUILD_BIN\""
    test "$verbose" -eq 1 && info "$ $cmd"
    # Hide the -o $gcroot flags from the build log (it's noise /
    # implementation detail) and use sed to prefix log lines with
    # progname++.
    eval "$cmd -o $commitdir/result" |& tee "$logdir/nix-build.log" |& "$SED_BIN" --unbuffered "s/^/$progname: nix-build: /"
    exit_status="${PIPESTATUS[0]}"
    if [ "$exit_status" -ne 0 ]; then
        cd "$commitdir"

        info ""
        info "To reproduce locally, run \"nix-build\" at commit $commit_short (\"$commit_subject\")."

        # Indicate build failure. Atomic operation.
        echo "\"FAIL\"" >"$status_json.tmp"
        mv "$status_json.tmp" "$status_json"
        return "$exit_status"
    fi

    # Iterate over the result* symlinks and rename them to the
    # path they point to (HASH-PKGNAME-VERSION).
    for link in "$commitdir"/result*; do
        # skip if not symlink
        test -L "$link" || continue

        # get nix store path name, minus the hash (we want stable urls)
        name=$(basename "$(readlink -f "$link")" | cut -c 34-)

        # Create nix store path name symlink if it does not
        # already exist.
        if ! [ -L "$commitdir/$name" ]; then
            mv "$link" "$commitdir/$name"
        else
            # Destination link already exist, remove the newly
            # created result* link we unneccesarily just
            # created.
            rm "$link"
        fi
    done

    cd "$commitdir"
    # Remove the tmpbuilddir. It's just a snapshot of the source since
    # nix-build does not and can not create files there.
    rm -rf "$commitdir/_build"
    # Reset trap handler
    trap - EXIT

    # Get build log per (symlink to) store path
    for link in "$commitdir/"*; do
        if ! [ -L "$link" ]; then
            continue
        else
            "$NIX_STORE_BIN" -l "$(readlink -f "$link")" >"$logdir/$(basename "$link").log" 2>&1
        fi
    done

    # Indicate build success. Atomic operation.
    echo "\"PASS\"" >"$status_json.tmp"
    mv "$status_json.tmp" "$status_json"
}

# Convert "refs/heads/FOO" to "branch/FOO" and "refs/tags/FOO" to "tag/FOO".
to_human_ref()
{
    case "$1" in
        refs/heads/*)
            echo "branch/${1//refs\/heads\//}"
            ;;
        refs/tags/*)
            echo "tag/${1//refs\/tags\//}"
            ;;
        *)
            # assuming branch, like gitolite
            echo "branch/$1"
            ;;
    esac
}

# Assumes these variables exits: $datadir, $repo (relpath), $commit (full),
# $ref (fully qualified, e.g. refs/heads/*)
do_set_ref_symlink()
{
    human_ref="$(to_human_ref "$ref")"
    reflink="$datadir/repo/$repo/$human_ref"
    mkdir -p "$(dirname "$reflink")"
    # Another blank line for visual separation
    info ""
    # $commit might point to an annotated tag object. If so, dereference the
    # tag to get the real commit. We cannot use git rev-parse or show-ref
    # --dereference here, since the ref hasn't been integrated in the repo
    # at pre-receive hook time(!). Use some low-level git cat-file instead.
    if "$GIT_BIN" cat-file tag "$commit" 2>/dev/null >/dev/null; then
        real_commit=$("$GIT_BIN" cat-file tag "$commit" | grep object | cut -d' ' -f2)
    else
        # not annotated commit, nothing to dereference
        real_commit=$commit
    fi
    commitdir="$datadir/repo/$repo/commit/$real_commit"
    if [ ! -d "$commitdir" ]; then
        info "Attempted to create ref symlink to non-existing commitdir: $commitdir"
        exit 1
    fi
    info "Adding ref symlink $reflink -> $commitdir"
    ln -srnf "$commitdir" "$reflink"
    if [ "x$base_url" != x ]; then
        info "Build logs and artifacts: $base_url/$repo/$human_ref"
    fi
}

# Assumes these variables exits: $datadir, $repo (relpath),
# $ref (fully qualified, e.g. refs/heads/*)
do_delete_ref_symlink()
{
    human_ref="$(to_human_ref "$ref")"
    reflink="$datadir/repo/$repo/$human_ref"
    info "Removing $reflink"
    rm -f "$reflink"
}

# Get absolute path to git repo, but without the .git suffix
get_repo_abspath()
{
    case "$repo" in
        /*)
            echo "${repo/%.git/}"
            ;;
        *)
            echo "$repositories/${repo/%.git/}"

            ;;
    esac
}

# Decode oldrev/newrev and figure out if the ref is created, deleted or
# updated. Invoke builds as needed.
do_hook()
{
    if  [ "x$repo" = x ] ||
        [ "x$oldrev" = x ] ||
        [ "x$newrev" = x ] ||
        [ "x$ref" = x ]; then
        info "Wrong usage for hook action (missing --repo=, --oldrev=, --newrev= or --ref= options). See --help." >&2
        exit 1
    fi

    case "$oldrev:$newrev" in
        $nullsha:*)
            test "$verbose" -eq 1 && info "$ref gets created"
            # Get all new commit objects that are not referenced by any refs yet.
            num_commits_total=$("$GIT_BIN" rev-list "$newrev" --reverse --not --all | wc -l)
            this_commit_number=1
            ("$GIT_BIN" rev-list "$newrev" --reverse --not --all) | while read -r commit; do
                do_build_commit
                this_commit_number=$((this_commit_number + 1))
            done
            # After everything has built, update the ref
            commit="$newrev"
            do_set_ref_symlink
            ;;
        *:$nullsha)
            test "$verbose" -eq 1 && info "$ref gets deleted"
            do_delete_ref_symlink
            ;;
        *:*)
            test "$verbose" -eq 1 && info "$ref gets updated"
            do_build_commit_range
            commit="$newrev"
            # After everything has built (successfully), update the ref
            do_set_ref_symlink
    esac
}

do_collect_garbage()
{
    if [ "x$repo" != x ]; then
        gc_start_dir="$datadir/repo/$repo"
    else
        gc_start_dir="$datadir"
    fi
    # 40 [a-f0-9] matches the commit directory
    path_pattern="*/commit/[a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9]"
    info "Garbage collecting builds older than $gc_cutoff_days days in $gc_start_dir"
    while read -r p; do
        commit=$(basename "$p")
        if [ "x$repo" = x ]; then
            repo=$(echo "$p" | "$SED_BIN" -e "s|$datadir/repo/||" -e "s|/commit/$commit||")
        fi
        if is_kept_alive_by_some_ref "$repo" "$commit"; then
            info "Keeping $p"
        else
            info "Removing $p"
            if [ "$dry_run" -eq 0 ]; then
                rm -rf "$p"
            fi
        fi
    done < <(find "$gc_start_dir" -type d -not -newermt "-$gc_cutoff_days days" -path "$path_pattern" -printf '%p\n')
    # Above: for "find" debugging, use -printf "%T@ %Tc %p\n"
}

cleanup_tmpdir()
{
    rm -rf "$tmpdir"
}

main()
{
    if [ "$(id -u )" -eq 0 ]; then
        info "There is no good reason to run this as root." >&2
        exit 1
    fi

    missing_deps=0
    for dep in "${external_deps[@]}"; do
        if ! [ -x "$(command -v "$dep")" ]; then
            info "Missing or not executable: $dep" >&2
            missing_deps=1
        fi
    done

    if [ "$missing_deps" -eq 1 ]; then
        info "Missing one or more required commands. Aborting." >&2
        exit 1
    fi

    # parse arguments
    action="$1"
    repo=
    newrev=
    oldrev=
    ref=
    datadir="$default_datadir"
    base_url="$default_base_url"
    gc_cutoff_days="$default_gc_cutoff_days"
    dry_run=0
    verbose=0

    for arg in "$@"; do
        case "$arg" in
            --help)
                usage
                exit 1
                ;;
            --repo=*)
                repo="${arg#*=}"
                ;;
            --oldrev=*)
                oldrev="${arg#*=}"
                ;;
            --newrev=*)
                newrev="${arg#*=}"
                ;;
            --ref=*)
                ref="${arg#*=}"
                ;;
            --datadir=*)
                datadir="${arg#*=}"
                ;;
            --base-url=*)
                base_url="${arg#*=}"
                ;;
            --dry-run)
                dry_run=1
                ;;
            --verbose)
                verbose=1
                ;;
            --gc-cutoff-days=*)
                gc_cutoff_days="${arg#*=}"
                ;;
            $action_build|$action_hook|$action_gc)
                true  # captured elsewhere, this is just for validation
                ;;
            *)
                info "Unknown argument: $arg. See --help" >&2
                exit 1
                ;;
        esac
    done

    # normalize and validate arguments
    if [ "x$repo" != x ]; then
        # strip .git from relative repo path (it is noisy)
        repo=${repo/%.git/}
        repo_abspath=$(get_repo_abspath)
        if ! [ -d "$repo_abspath.git" ]; then
            info "Not a directory: $repo_abspath.git"
            exit 1
        fi
        # This is the repo we'll be working with
        export GIT_DIR="$repo_abspath.git"
        # We might make a copy of the repo, so save the original.
        export ORIG_GIT_DIR="$GIT_DIR"
    fi

    if [ "x$oldrev" != x ]; then
        oldrev=$(to_long_commit_sha "$oldrev")
    fi

    if [ "x$newrev" != x ]; then
        newrev=$(to_long_commit_sha "$newrev")
    fi

    # we might get called with a ref that does not exist yet
    if [ "x$ref" != x ]; then
        case "$ref" in
            refs/heads/*|refs/tags/*)
                true  # already fully qualified
                ;;
            refs/notes/*)
                #info "Ignoring operations on ref: $ref"
                exit 0
                ;;
            *)
                # assuming branch, like gitolite
                ref="refs/heads/$ref"
                ;;
        esac
    fi

    tmpdir=$(mktemp -d -t "$progname-XXXXXXXX")
    trap 'cleanup_tmpdir' EXIT

    # dispatch
    case "$action" in
        $action_build)
            # per-action argument validation
            if  [ "x$ref" != x ] ||
                [ "$dry_run" -ne 0 ] ||
                [ "x$base_url" != "x$default_base_url" ] ||
                [ "x$gc_cutoff_days" != "x$default_gc_cutoff_days" ]; then
                info "Wrong usage for action $action_build. See --help." >&2
                exit 1
            fi
            case "$oldrev:$newrev" in
                :*)
                    commit=$newrev
                    num_commits_total=1
                    this_commit_number=1
                    # do_hook runs in a subshell, due to flock. To keep trap
                    # handling sane, also run the other
                    # build-funcs-using-trap in subshells.
                    (do_build_commit)
                    ;;
                *:*)
                    # do_hook runs in a subshell, due to flock. To keep trap
                    # handling sane, also run the other
                    # build-funcs-using-trap in subshells.
                    (do_build_commit_range)
                    ;;
            esac
            ;;
        $action_hook)
            # Serialize operations against a given repo + ref with "flock".
            # Failure to do so might lead to a push being rejected after we've
            # succeeded the build, resulting in mini-ci getting out of sync
            # state wrt. the git repo.
            #
            # We use a non-blocking lock so that the 2nd push operation will
            # fail early. Rationale: if the 1st push goes through, the 2nd push
            # will probably fail anyway (because git rejects non fast-forward
            # pushes by default). Since the 2nd user / push must do a rebase
            # and try again anyway, we might as well stop early instead of
            # doing a full build for a commit that cannot be merged into the
            # current ref.
            #
            # Keep the locks out of the $datadir/repo/ tree, to not clutter up
            # the view. An attempt was made to lock the ref symlink itself,
            # inside $datadir/repo/ (saving the duplicate .../locks/ tree), but
            # flock didn't support that.
            lock="$datadir/locks/repo/$repo/$ref"
            mkdir -p "$(dirname "$datadir/locks/repo/$repo/$ref")"
            # The number 222 is an arbitrary file descriptor number. shellcheck
            # warned when using a variable, so working around it by hardcoding.
            (if "$FLOCK_BIN" --nonblock --exclusive 222; then
                 # these commands run with the lock held
                 do_hook
             else
                 info "Another push/build is already in progress for $ref. Please wait a bit and try again."
                 exit 1
             fi
            ) 222>"$lock"
            ;;
        $action_gc)
            # per-action argument validation
            if  [ "x$ref" != x ] ||
                [ "x$oldrev" != x ] ||
                [ "x$newrev" != x ] ||
                [ "x$base_url" != "x$default_base_url" ]; then
                info "Wrong usage for action $action_build. See --help." >&2
                exit 1
            fi
            do_collect_garbage
            ;;
        "")
            info "Missing arguments. Here is --help for you:" >&2
            info "" >&2
            usage
            exit 1
            ;;
        *)
            info "Wrong usage. See --help." >&2
            exit 1
            ;;
    esac
}

main "$@"
