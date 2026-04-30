# Auto-switch gh auth account based on working directory.
# Mirrors the gitconfig includeIf work identity switch.
#
# One-time setup (stored in fish_variables, not the repo):
#   gh-switch setup
#
# Manual override (per session):
#   gh-switch          — show current account and override status
#   gh-switch work     — force work account (disables auto-switch this session)
#   gh-switch personal — force personal account (disables auto-switch this session)
#   gh-switch auto     — re-enable auto-switching and apply directory rule

function _gh_desired_account
    if not set -q GH_WORK_DIR; or not set -q GH_PERSONAL_ACCOUNT; or not set -q GH_WORK_ACCOUNT
        return 1
    end
    # Only relevant if work git identity is actually configured
    if not test -f ~/.gitconfig.work
        return 1
    end
    if test "$PWD" = "$GH_WORK_DIR"; or string match -q "$GH_WORK_DIR/*" $PWD
        echo $GH_WORK_ACCOUNT
    else
        echo $GH_PERSONAL_ACCOUNT
    end
end

function _gh_auth_auto --on-variable PWD
    if set -q _GH_AUTH_MANUAL
        return
    end
    set -l desired (_gh_desired_account)
    or return
    if test "$desired" != "$_GH_LAST_AUTO_ACCOUNT"
        gh auth switch --user $desired 2>/dev/null
        and set -g _GH_LAST_AUTO_ACCOUNT $desired
    end
end

function gh-switch
    switch $argv[1]
        case personal
            if not set -q GH_PERSONAL_ACCOUNT
                echo "gh-switch: not configured — run 'gh-switch setup' first"
                return 1
            end
            set -g _GH_AUTH_MANUAL 1
            gh auth switch --user $GH_PERSONAL_ACCOUNT
        case work
            if not set -q GH_WORK_ACCOUNT
                echo "gh-switch: not configured — run 'gh-switch setup' first"
                return 1
            end
            set -g _GH_AUTH_MANUAL 1
            gh auth switch --user $GH_WORK_ACCOUNT
        case auto
            set -e _GH_AUTH_MANUAL
            set -e _GH_LAST_AUTO_ACCOUNT
            _gh_auth_auto
        case setup
            read -P "Personal gh username: " -l personal
            read -P "Work gh username:     " -l work
            read -P "Work directory path:  " -l workdir
            set -Ux GH_PERSONAL_ACCOUNT $personal
            set -Ux GH_WORK_ACCOUNT $work
            set -Ux GH_WORK_DIR (string replace -r '/$' '' $workdir)
            echo "Saved. Run 'gh-switch auto' to activate."
        case ''
            if not set -q GH_PERSONAL_ACCOUNT
                echo "gh-switch: not configured — run 'gh-switch setup' first"
                return 0
            end
            set -l active (gh auth status 2>&1 | string match -r '(?<=account )\S+(?= \()' | head -1)
            echo "Active gh account : $active"
            if set -q _GH_AUTH_MANUAL
                echo "Auto-switch       : OFF (run 'gh-switch auto' to re-enable)"
            else
                echo "Auto-switch       : ON  (run 'gh-switch work|personal' to override)"
            end
        case '*'
            echo "Usage: gh-switch [personal|work|auto|setup]"
    end
end

# Apply on shell start (PWD change event won't fire at init time)
_gh_auth_auto
