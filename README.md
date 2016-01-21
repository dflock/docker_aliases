# docker_aliases

Docker bash aliases - new bash shell commands to make working with Docker containers & images easier.

## Installation

Save the `docker_aliases.sh` file to your home directory. Rename it to `.docker_aliases` and add this to your `~/.bashrc` file somewhere:

```bash
if [ -f ~/.docker_aliases ]; then
  source ~/.docker_aliases
fi
```

Then either close & re-open your terminal windows or do this in each one to make it refresh:

```console
$ . ~/bashrc
```

## Usage

Installing `docker_aliases` will get you some new commands to use in your bash terminal:

### dps

Like `docker ps`, but with two extra columns on the end, showing the containers local IP address and it's current RAM usage. Looks like this:

```console
  $ dps

  CONTAINER ID        IMAGE           ... NAMES                 IP              RAM       
  0a3359f50829        23f1a66316b3    ... container-one         172.17.0.139         57 MB
  63a1b8ab9fb5        037e0afb42e4    ... container-two         172.17.0.137        490 MB
  c9bbee45d255        872fb65cee6d    ... container-three       172.17.0.135       1696 MB
```

Accepts the same command line switches as `docker ps` - i.e. `dps -a` works.

### docker_wipe

Delete all containers & images, reset dockers container linking DB and restart docker. The nuclear option.

**NB: Does not prompt for confirmation.**

```console
$ docker_wipe
```

### dvol

List the volumes for a given container:

```console
$ dvol <container name|id>
```
