
FROM ubuntu:22.04

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
         curl \
         ca-certificates \
         unzip  \
         fuse3 \
         # https://github.com/rclone/rclone/issues/6844
    && rm -rf /var/lib/apt/lists/*

# Install latest rclone
RUN curl https://rclone.org/install.sh | bash

# RCLONE authentication details
ENV RCLONE_CONFIG               ""
ENV RCLONE_CONFIG_RSHARE_TYPE   "webdav"
ENV RCLONE_CONFIG_RSHARE_URL    ""
ENV RCLONE_CONFIG_RSHARE_VENDOR ""
ENV RCLONE_CONFIG_RSHARE_USER   ""
ENV RCLONE_CONFIG_RSHARE_PASS   ""

# Path mounting
ENV REMOTE_PATH "rshare:/"
ENV LOCAL_PATH  "/storage"

# At **runtime** we need to both obscure the rclone password AND run rclone mount
# We execute both of these steps in `mount_storage.sh` script.
COPY mount_storage.sh .

CMD sh ./mount_storage.sh
