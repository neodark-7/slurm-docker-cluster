# Slurm Docker Cluster

This is a multi-container Slurm cluster using docker-compose.  The compose file
creates named volumes for persistent storage of MySQL data files as well as
Slurm state and log directories.

## Containers and Volumes

The compose file will run the following containers:

* mysql
* slurmdbd
* slurmctld
* c1 (slurmd)
* c2 (slurmd)

The compose file will create the following named volumes:

* etc_munge         ( -> /etc/munge     )
* etc_slurm         ( -> /etc/slurm     )
* slurm_jobdir      ( -> /data          )
* var_lib_mysql     ( -> /var/lib/mysql )
* var_log_slurm     ( -> /var/log/slurm )

## Building the Docker Image

Build the image locally:

```console
docker build -t slurm-docker-cluster:23.02.5.1 .
```

Build a different version of Slurm using Docker build args and the Slurm Git
tag:

```console
docker build --build-arg SLURM_TAG="slurm-23-02-5-1" -t slurm-docker-cluster:23.02.5.1 .
```

Or equivalently using `docker-compose`:

```console
SLURM_TAG=slurm-23-02-5-1 IMAGE_TAG=23.02.5.1 docker-compose build
```


## Starting the Cluster

Run `docker-compose` to instantiate the cluster:

```console
docker-compose up -d
```

## Register the Cluster with SlurmDBD

To register the cluster to the slurmdbd daemon, run the `register_cluster.sh`
script:

```console
./register_cluster.sh
```

> Note: You may have to wait a few seconds for the cluster daemons to become
> ready before registering the cluster.  Otherwise, you may get an error such
> as **sacctmgr: error: Problem talking to the database: Connection refused**.
>
> You can check the status of the cluster by viewing the logs: `docker-compose
> logs -f`

## Accessing the Cluster

Use `docker exec` to run a bash shell on the controller container:

```console
docker exec -it slurmctld bash
```

From the shell, execute slurm commands, for example:

```console
[root@slurmctld /]# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up 5-00:00:00      2   idle c[1-2]
```

## Submitting Jobs

The `slurm_jobdir` named volume is mounted on each Slurm container as `/data`.
Therefore, in order to see job output files while on the controller, change to
the `/data` directory when on the **slurmctld** container and then submit a job:

```console
[root@slurmctld /]# cd /data/
[root@slurmctld data]# sbatch --wrap="uptime"
Submitted batch job 2
[root@slurmctld data]# ls
slurm-2.out
```

## Stopping and Restarting the Cluster

```console
docker-compose stop
docker-compose start
```

## Deleting the Cluster

To remove all containers and volumes, run:

```console
docker-compose stop
docker-compose rm -f
docker volume rm slurm-docker-cluster_etc_munge slurm-docker-cluster_etc_slurm slurm-docker-cluster_slurm_jobdir slurm-docker-cluster_var_lib_mysql slurm-docker-cluster_var_log_slurm
```


## Slurm Rest Header
```
X-SLURM-USER-NAME=[username]
X-SLURM-USER-TOKEN=[JWT TOKEN]
```
```
sconsole token [username]
SLURM_JWT=[JWT TOKEN]
```

## Trouble shooting
slurmd: debug:  CPUs has been set to match sockets per node instead of threads CPUs=1:16(hw)
slurmd: error: Node configuration differs from hardware: CPUs=1:16(hw) Boards=1:1(hw) SocketsPerBoard=1:1(hw) CoresPerSocket=1:8(hw) ThreadsPerCore=1:2(hw)
slurmd: error: Couldn't find the specified plugin name for cgroup/v2 looking at all files
slurmd: error: cannot find cgroup plugin for cgroup/v2
slurmd: error: cannot create cgroup context for cgroup/v2
slurmd: error: Unable to initialize cgroup plugin
slurmd: error: slurmd initialization failed


- Node configuration differs from hardware: CPUs=1:16(hw) Boards=1:1(hw) SocketsPerBoard=1:1(hw) CoresPerSocket=1:8(hw) ThreadsPerCore=1:2(hw)
```
sudo dmidecode -t processor | grep -E '(Core Count|Thread Count)'
	Core Count: 8
	Thread Count: 16


It looks like you have hyper-threading turned on, but haven’t defined the ThreadsPerCore=2. You either need to turn off Hyper-threading in the BIOS or changed the definition of ThreadsPerCore in slurm.conf.

# Disable HT:
echo 0 | sudo tee /sys/devices/system/cpu/cpu{9..15}/online



echo 0 | sudo tee /sys/devices/system/cpu/cpu{1..15}/online
=======>
slurmd: error: Couldn't find the specified plugin name for cgroup/v2 looking at all files
slurmd: error: cannot find cgroup plugin for cgroup/v2
slurmd: error: cannot create cgroup context for cgroup/v2
slurmd: error: Unable to initialize cgroup plugin
slurmd: error: slurmd initialization failed

```
- Couldn't find the specified plugin name for cgroup/v2 looking at all files
```
dnf -y install dbus-devel

```


## ETC
Compute pods
*  systemd in a container /usr/lib/systemd/systemd --system
*  share paths: /tmp /run /sys/fs/cgroup (ro)

Volume
* /etc/slurm/slurm.conf (configmap)
empty dir
* /var/run/munge
ceph pvc
* /etc/munge
* /var/pool/slurmd
* /scratch

munge configuration
*  init container
*  folder permissions and ownership on /etc/munge /run/munge

Pod == Node
* Compute pod: slurmcn munge
* Control pod: slurmctl
* Accounting pod: slurmdb mariadb

