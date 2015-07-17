#
# Docker Aliases
#

# Figure out if we need to use sudo for docker commands
if id -nG "$USER" | grep -qw "docker"; then
    DSUDO=''
else
    DSUDO='sudo'
fi

docker_mem() {
    if [ -f /sys/fs/cgroup/memory/docker/"$1"/memory.usage_in_bytes ]; then
        echo $(( $(cat /sys/fs/cgroup/memory/docker/"$1"/memory.usage_in_bytes) / 1024 / 1024 )) 'MB'
    else
        echo 'n/a'
    fi
}

docker_ip() {
    echo $($DSUDO docker inspect --format="{{.NetworkSettings.IPAddress}}" "$1")
}

#
# Enhanced version of 'docker ps' which outputs two extra columns:
#
# IP  : The private IP address of the container
# RAM : The amount of RAM the processes inside the container are using
#
# Usage: same as 'docker ps', but 'dps', so 'dps -a', etc...
#
dps() {
    tmp=$($DSUDO docker ps "$@")
    headings=$(echo "$tmp" | head --lines=1)
    max_len=$(echo "$tmp" | wc --max-line-length)
    dps=$(echo "$tmp" | tail --lines=+2)

    printf "%-${max_len}s %-15s %10s\n" "$headings" IP RAM

    while read -r line; do
        container_short_hash=$( echo "$line" | cut -d' ' -f1 );
        container_long_hash=$( $DSUDO docker inspect --format="{{.Id}}" "$container_short_hash" );
        container_name=$( echo "$line" | rev | cut -d' ' -f1 | rev )
        if [ -n "$container_hash" ]; then
            ram=$(docker_mem "$container_long_hash");
            ip=$(docker_ip "$container_name");
            printf "%-${max_len}s %-15s %10s\n" "$line" "$ip" "${ram}";
        fi
    done <<< "$dps"
}