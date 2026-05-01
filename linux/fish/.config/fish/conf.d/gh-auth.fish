# Auto-switch gh auth account based on working directory.
# Mirrors the gitconfig includeIf work identity switch.
#
# One-time setup (stored in fish_variables, not the repo):
#   gh-switch setup
#
# Manual override (per terminal session, including child shells):
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

function _gh_set_active_account
    if test (count $argv) -eq 0
        set -e GH_ACTIVE_ACCOUNT
        return 1
    end
    set -gx GH_ACTIVE_ACCOUNT $argv[1]
end

function _gh_sync_active_account
    command -q gh
    or return 1

    set -l active (gh auth status 2>&1 | awk '
        /Logged in to github\.com account / {
            if (match($0, /account ([^ ]+) \(/, captures)) {
                account = captures[1]
            }
        }
        /Active account: true/ {
            if (account != "") {
                print account
                exit
            }
        }
    ')
    test -n "$active"
    or return 1

    _gh_set_active_account $active
end

function _gh_switch_account
    set -l account $argv[1]
    gh auth switch --user $account 2>/dev/null
    or return 1

    _gh_set_active_account $account
end

function _gh_auth_auto --on-variable PWD
    if set -q GH_AUTH_MANUAL; or set -q _GH_AUTH_MANUAL
        return
    end
    set -l desired (_gh_desired_account)
    or return
    set -l last_auto $GH_LAST_AUTO_ACCOUNT
    if not set -q GH_LAST_AUTO_ACCOUNT; and set -q _GH_LAST_AUTO_ACCOUNT
        set last_auto $_GH_LAST_AUTO_ACCOUNT
    end
    if test "$desired" != "$last_auto"
        _gh_switch_account $desired
        and set -g GH_LAST_AUTO_ACCOUNT $desired
    else
        _gh_set_active_account $desired
    end
end

function gh-switch
    switch $argv[1]
        case personal
            if not set -q GH_PERSONAL_ACCOUNT
                echo "gh-switch: not configured — run 'gh-switch setup' first"
                return 1
            end
            set -gx GH_AUTH_MANUAL 1
            set -e _GH_AUTH_MANUAL
            _gh_switch_account $GH_PERSONAL_ACCOUNT
        case work
            if not set -q GH_WORK_ACCOUNT
                echo "gh-switch: not configured — run 'gh-switch setup' first"
                return 1
            end
            set -gx GH_AUTH_MANUAL 1
            set -e _GH_AUTH_MANUAL
            _gh_switch_account $GH_WORK_ACCOUNT
        case auto
            set -e GH_AUTH_MANUAL
            set -e GH_LAST_AUTO_ACCOUNT
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
            if not set -q GH_ACTIVE_ACCOUNT
                _gh_sync_active_account >/dev/null
            end
            echo "Active gh account : $GH_ACTIVE_ACCOUNT"
            if set -q GH_AUTH_MANUAL; or set -q _GH_AUTH_MANUAL
                echo "Auto-switch       : OFF (run 'gh-switch auto' to re-enable)"
            else
                echo "Auto-switch       : ON  (run 'gh-switch work|personal' to override)"
            end
        case '*'
            echo "Usage: gh-switch [personal|work|auto|setup]"
    end
end

# Prefer GH_* state so launchers that sanitize underscore-prefixed vars still inherit it.
if set -q _GH_AUTH_MANUAL; and not set -q GH_AUTH_MANUAL
    set -gx GH_AUTH_MANUAL $_GH_AUTH_MANUAL
end
if set -q _GH_LAST_AUTO_ACCOUNT; and not set -q GH_LAST_AUTO_ACCOUNT
    set -g GH_LAST_AUTO_ACCOUNT $_GH_LAST_AUTO_ACCOUNT
end
set -e _GH_AUTH_MANUAL
set -e _GH_LAST_AUTO_ACCOUNT

# Apply on shell start (PWD change event won't fire at init time)
_gh_auth_auto
if not set -q GH_ACTIVE_ACCOUNT
    _gh_sync_active_account >/dev/null
end
