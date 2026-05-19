#!/usr/bin/env nu
#
#  SPDX-License-Identifier: MIT
#  Copyright (c) 2026 Paal Øye-Strømme
#
#  drop_commit_files.nu
#  Rugzak
#
#  Remove one or more files from an arbitrary commit in git history via
#  automated non-interactive rebase.
#
#  Usage:
#    nu scripts/drop_commit_files.nu <commit> <file> [<file> ...]
#
#  Examples:
#    nu scripts/drop_commit_files.nu abc1234 vendor/secret.key
#    nu scripts/drop_commit_files.nu HEAD~3 src/foo.rs src/bar.rs
#
#  The commit ref can be anything git accepts: a full or short hash,
#  HEAD~N, a branch name, or a tag.
#
#  Safety notes:
#  - Rewrites history. Do not use on commits already pushed to a shared
#    branch without coordinating with collaborators.
#  - Requires a clean working tree before it runs.
#  - Aborts automatically if any step fails.
#

def main [
    commit: string      # Commit to modify (any git ref)
    ...files: string    # One or more file paths to remove from that commit
] {
    if ($files | is-empty) {
        error make { msg: "At least one file path is required." }
    }

    # Resolve the ref to a full SHA before the rebase shifts HEAD.
    let target_sha = (^git rev-parse $commit | str trim)
    let sha7 = ($target_sha | str substring 0..6)

    print $"Target commit : ($target_sha)"
    print $"Files to drop : ($files | str join ', ')"

    # Refuse to run with uncommitted changes — they interfere with rebase.
    let dirty = (^git status --porcelain | str trim)
    if ($dirty | str length) > 0 {
        error make { msg: "Working tree is dirty. Commit or stash changes first." }
    }

    # git checkout -- <files> restores those files to their pre-commit state,
    # then --amend re-commits without the diff.
    let file_args = ($files | str join " ")
    let exec_line = $"exec git checkout HEAD^ -- ($file_args) && git commit --amend --no-edit --allow-empty"

    # GIT_SEQUENCE_EDITOR is called by git with the todo file as the sole
    # argument. We use sed to insert an "exec" line right after the matching
    # "pick <sha>" line.
    #
    # BSD sed (macOS) requires a literal newline after `a\` — Nushell's `\n`
    # in an interpolated string provides it.
    let seq_editor = $"sed -i '' '/^pick ($sha7)/a\\\n($exec_line)'"

    print "\nRewriting history via git rebase..."

    $env.GIT_SEQUENCE_EDITOR = $seq_editor
    ^git rebase -i --no-autosquash $"($target_sha)^"

    if $env.LAST_EXIT_CODE != 0 {
        ^git rebase --abort
        error make { msg: "Rebase failed — see output above. Original HEAD restored." }
    }

    print $"\nDone. Files removed from commit ($sha7)."
    print $"Verify : git show ($sha7) --stat"
    print "Push   : git push --force-with-lease"
}
