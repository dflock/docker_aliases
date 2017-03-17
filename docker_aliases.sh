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

# Simple Docker aliases
alias di='$DSUDO docker images'

#
#  List the RAM used by a given container.
#  Used by dps().
#
#  docker_mem <container name|id>
#
function docker_mem() {
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
function docker_id() {
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
function docker_up() {
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
function docker_ip() {
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
function docker_ps() {
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
alias dps='docker_ps'

#
#  List the volumes for a given container:
#
#  docker_vol <container name|id>
#
function docker_vol() {
  vols=$($DSUDO docker inspect --format="{{.HostConfig.Binds}}" "$1")
  vols=${vols:1:-1}
  for vol in $vols
  do
    echo "$vol"
  done
}


#
# Remove any dangling images & exited containers
#
function docker_clean() {
  echo "Removing dangling images:"
  $DSUDO docker rmi "$(docker images -f "dangling=true" -q)"
  echo "Removing exited containers:"
  $DSUDO docker rm -v "$(docker ps -a -q -f status=exited)"
}
alias dclean='docker_clean'

#
#  List the links for a given container:
#
#  docker_links <container name|id>
#
docker_links() {
  links=$($DSUDO docker inspect --format="{{.HostConfig.Links}}" "$1")
  # links=${vols:1:-1}
  for link in $links
  do
    echo "$link"
  done
}
alias dlinks='docker_links'

#
# Returns the systems init type as a string:
#
# 'upstart', 'systemd', 'sysv'
#
# Call like this:
#
# VAR_INIT_TYPE=$(init_type)
#
function init_type() {
  if [[ $(/sbin/init --version &>/dev/null) =~ upstart ]]; then
    echo 'upstart';
  elif [[ $(systemctl) =~ -\.mount ]]; then
    echo 'systemd';
  elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then
    echo 'sysv';
  else
    echo '';
  fi
}

#
# Stops, starts or restarts the docker daemon.
# Should work on both upstart, systemd init systems.
#
# @1  The action to perform: start|stop|restart
#
docker_ctl() {
  local action="$1"
  local init=$(init_type)

  case $init in
    upstart)
      case $action in
        start )
          sudo start docker
          ;;
        stop )
          sudo stop docker
          ;;
        restart )
          sudo restart docker
          ;;
      esac
    ;;
    systemd)
      case $action in
        start )
          sudo systemctl start docker.service
          ;;
        stop )
          sudo systemctl stop docker.service
          ;;
        restart )
          sudo systemctl restart docker.service
          ;;
      esac
    ;;
  esac
}

#
#  Delete all containers & images,
#  reset dockers container linking DB and restart docker.
#  The nuclear option.
#
#  NB: Does not prompt for confirmation.
#
docker_wipe() {
  $DSUDO docker rm -f $(docker ps -a -q)
  $DSUDO docker rmi -f $(docker images -q)

  docker_ctl 'stop'

  sudo rm -f /var/lib/docker/linkgraph.db
  sudo rm -rf /var/lib/docker/aufs/diff/*
  sudo rm -rf /var/lib/docker/network/*
  sudo rm -rf /var/lib/docker/containers/*

  docker_ctl 'start'
}

#
#  Perform a docker cmd on all docker containers
#
#  docker_all <cmd>
#
function docker_all() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 start|stop|pause|unpause|<any valid docker cmd>"
  fi

  for c in $($DSUDO docker ps -a | awk '{print $1}' | sed "1 d")
  do
    $DSUDO docker "$1" "$c"
  done
}
alias dall='docker_all'
