#!/usr/bin/env bash
#
# Docker Aliases
#

# Figure out if we need to use sudo for docker commands
if id -nG "$USER" | grep -qw "docker"; then
    DSUDO=''
else
    DSUDO='sudo'
fi

#
#  List the RAM used by a given container.
#  Used by dps().
#
#  docker_mem <container name|id>
#
docker_mem() {
    if [ -f /sys/fs/cgroup/memory/docker/"$1"/memory.usage_in_bytes ]; then
        echo $(( $(cat /sys/fs/cgroup/memory/docker/"$1"/memory.usage_in_bytes) / 1024 / 1024 )) 'MB'
    else
        echo 'n/a'
    fi
}

#
# Return the ID of the container, given the name.
#
# docker_id <container_name>
#
docker_id() {
  ID=$( $DSUDO docker inspect --format="{{.Id}}" "$1" 2> /dev/null);
  if (( $? >= 1 )); then
      # Container doesn't exist
      ID=''
  fi
  echo $ID
}

#
# Return the status of the named container.
#
# docker_up <container_name>
#
docker_up() {
  UP='Y'
  ID=$( $DSUDO docker inspect --format="{{.Id}}" "$1" 2> /dev/null);
  if (( $? >= 1 )); then
    # Container doesn't exist
    UP='N'
  fi
  echo "$UP"
}

#
#  List the IP address for a given container:
#  Used by dps().
#
#  docker_ip <container name|id>
#
docker_ip() {
    IP=$($DSUDO docker inspect --format="{{.NetworkSettings.IPAddress}}" "$1" 2> /dev/null)
    if (( $? >= 1 )); then
        # Container doesn't exist
        IP='n/a'
    fi
    echo $IP
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

    if [[ -n "$dps" ]]; then
      printf "%-${max_len}s %-15s %10s\n" "$headings" IP RAM

      while read -r line; do
          container_short_hash=$( echo "$line" | cut -d' ' -f1 );
          container_long_hash=$( $DSUDO docker inspect --format="{{.Id}}" "$container_short_hash" );
          container_name=$( echo "$line" | rev | cut -d' ' -f1 | rev )
          if [ -n "$container_long_hash" ]; then
              ram=$(docker_mem "$container_long_hash");
              ip=$(docker_ip "$container_name");
              printf "%-${max_len}s %-15s %10s\n" "$line" "$ip" "${ram}";
          fi
      done <<< "$dps"
    fi
}

#
#  List the volumes for a given container:
#
#  dvol <container name|id>
#
dvol() {
    vols=$($DSUDO docker inspect --format="{{.HostConfig.Binds}}" "$1")
    vols=${vols:1:-1}
    for vol in $vols
    do
      echo "$vol"
    done
}

#
#  Wipe and reset Docker - removing all containers & images,
#  resetting the linkgraph.db & restarting docker.
#
docker_wipe() {
  $DSUDO docker rm -f $(docker ps -a -q)
  $DSUDO docker rmi -f $(docker images -q)
  sudo rm "/var/lib/docker/linkgraph.db"
  sudo restart docker
}
