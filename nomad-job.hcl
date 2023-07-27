// Nomad job to test that the storage parallel task works as expected


job "userjob-jlab-storage-mount" {

  type = "service"

  group "usergroup" {
    count = 1

    network {
      port "jupyter" {
        to = 8888  # -1 will assign random port
      }
    }

    service {
      name = "userjob-jlab-storage-mount"
      port = "jupyter"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.userjob-jlab-storage-mount.entrypoints=http",
        "traefik.http.routers.userjob-jlab-storage-mount.rule=Host(`ide.userjob-jlab-storage-mount.deployments.cloud.ai4eosc.eu`)",
      ]
    }

    task "storagetask" {
      // Running task in charge of mounting storage

      driver = "docker"

      config {
        image   = "ignacioheredia/ai4-docker-storage"
        privileged = true
        // devices = [
        //   {
        //     host_path = "/dev/fuse"
        //   }
        // ]
        // cap_add = [
        //   "SYS_ADMIN"
        // ]
        // security_opt = [
        //   "apparmor:unconfined"
        // ]
        volumes = [
          "/nomad-storage/some-random-uuid:/storage:shared",
        ]
      }

      env {
        RCLONE_CONFIG = "/srv/.rclone/rclone.conf"
        RCLONE_CONFIG_RSHARE_TYPE = "webdav"
        RCLONE_CONFIG_RSHARE_URL = "https://data-deep.a.incd.pt/remote.php/webdav/"
        RCLONE_CONFIG_RSHARE_VENDOR = "nextcloud"
        RCLONE_CONFIG_RSHARE_USER="**my-nextcloud-token-user**"  ///////// FILL ME /////////
        RCLONE_CONFIG_RSHARE_PASS="**my-nextcloud-token-pass**"  ///////// FILL ME /////////
        REMOTE_PATH="rshare:/"
        LOCAL_PATH="/storage"
      }

      resources {
        # Minimum number of CPUs is 2
        cpu    = 2
        memory = 2000
        disk   = 1000
      }

    }

    task "usertask" {
      // Module task

      driver = "docker"

      config {
        image   = "deephdc/deep-oc-image-classification-tf:cpu"
        command = "deep-start"
        args    = ["--jupyter"]
        ports   = ["jupyter"]
        volumes = [
          "/nomad-storage/some-random-uuid:/storage:shared",
        ]
      }

      env {
        jupyterPASSWORD = "123456789"
      }

      resources {
        # Minimum number of CPUs is 2
        cpu    = 2
        memory = 8000
        disk   = 4000
      }
    }

    task "storagecleanup" {
      // Unmount empty storage folder and delete it from host

      lifecycle {
        hook = "poststop"
      }

      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args = ["-c", "sudo umount /nomad-storage/some-random-uuid && sudo rmdir /nomad-storage/some-random-uuid" ]

      }
    }

  }
}

