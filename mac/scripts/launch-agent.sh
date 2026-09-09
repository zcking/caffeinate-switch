# Shared LaunchAgent shutdown guard for install and uninstall.
# launchctl reports a missing service as exit status 3. No other bootout
# failure is safe to ignore, and even a successful bootout is verified.
bootout_launch_agent() {
    if [ "$#" -ne 1 ]; then
        echo 'Error: bootout_launch_agent requires one service target' >&2
        return 2
    fi

    local service_target="$1"
    local output=''
    local status=0
    output="$(launchctl bootout "$service_target" 2>&1)" || status=$?

    case "$status" in
        0|3) ;;
        *)
            [ -z "$output" ] || printf '%s\n' "$output" >&2
            return "$status"
            ;;
    esac

    if launchctl print "$service_target" >/dev/null 2>&1; then
        echo "Error: LaunchAgent remains loaded after bootout: $service_target" >&2
        return 1
    fi

    return 0
}
