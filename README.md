<div align="center">
  <img src="https://ai4eosc.eu/wp-content/uploads/sites/10/2022/09/horizontal-transparent.png" alt="logo" width="500"/>
</div>

# Storage container

[![Build image](https://github.com/ai4os/docker-storage/actions/workflows/build-docker.yml/badge.svg)](https://github.com/ai4os/docker-storage/actions/workflows/build-docker.yml)

This is the container that will be deployed as a side task (`storagetask`) in a
[Nomad job](https://github.com/ai4os/ai4-papi/blob/master/etc/modules/nomad.hcl).

Right now we are using [rclone](https://rclone.org/) to mount a remote file system
(therefore `privileged` permissions, or similar, are needed in the Nomad task).
In the future this same container could be adapted to use
 [Alluxio](https://www.alluxio.io/) or any other storage solution we decide to support.

 The Docker image is available in the project's Harbor registry:
 * `registry.services.ai4os.eu/ai4os/docker-storage:latest`

## Usage

When launching this Dockerfile you should pass appropriate RCLONE
configuration as ENV variables as well as mounting a volume in the
provided LOCAL_PATH

> ⚠️ If several containers are using that volume, this container has to be ran first.

Mounting a remote filesystem requires either `privileged` flag or set of little more
restrictive permissions [cap-add|device|security-opt]
([ref](https://github.com/s3fs-fuse/s3fs-fuse/issues/647#issuecomment-637458150)).

```bash
docker run \
-e RCLONE_CONFIG='/srv/.rclone/rclone.conf' \
-e RCLONE_CONFIG_RSHARE_TYPE='webdav' \
-e RCLONE_CONFIG_RSHARE_URL='https://data-deep.a.incd.pt/remote.php/webdav/' \
-e RCLONE_CONFIG_RSHARE_VENDOR='nextcloud' \
-e RCLONE_CONFIG_RSHARE_USER='**my-nextcloud-token-user**' \
-e RCLONE_CONFIG_RSHARE_PASS='**my-nextcloud-token-pass**' \
-e REMOTE_PATH='rshare:/' \
-e LOCAL_PATH='/storage' \
-v /home/iheredia/demo-data:/storage:shared \
--device /dev/fuse \
--cap-add SYS_ADMIN \
--security-opt apparmor:unconfined \
-ti ignacioheredia/ai4-docker-storage /bin/bash
```

In the example above the RCLONE mounted dir will be accessed in the host machine at
`/home/iheredia/demo-data` (root permissions needed to access).

After exiting the container, you will need to unmount the folder:
```bash
umount /home/iheredia/demo-data
rmdir /home/iheredia/demo-data
```

## Implementation notes

**RCLONE version** \
Latest RCLONE (`1.63.1`) did not work due to [bug](https://github.com/rclone/rclone/issues/7103).
We settled with (`1.62.2`).

**Base image** \
We do not start from official RCLONE images because we also need `[sh|bash|curl]` (not
provided)

**Nomad task**
* If the user inputs the wrong USER/PASS, the job still runs fine.
  Only when trying to access the storage folder from his task they will see:
  ```bash
  `ls: reading directory '/storage/': Input/output error`
  ```
  When the job finishes, you still need to unmount the folder before deleting.
* the `rclone mount` command never finishes so the job can still be run _in principle_ as type `service`. But the docker start will fail the second time (at restart) because the volume folder has already been created.

  ```bash
  Error while creating mount source path '/etc/nomad.d/storage/some-random-uuid5': mkdir /etc/nomad.d/storage/some-random-uuid5: file exists
  ```

  So we need to either:
    - use `allow_other` in RCLONE ([ref](https://stackoverflow.com/a/61686833/18471590)), still with `service` mode.
    - run it in `batch` mode (this means suboptimal placement).

  We choose the first option.
