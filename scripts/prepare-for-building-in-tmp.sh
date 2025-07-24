export ROOT_DIR=/mnt
mkdir -p $ROOT_DIR/podman-var-lib-containers
mkdir -p /var/lib/containers/
mount --bind $ROOT_DIR/podman-var-lib-containers /var/lib/containers/

mkdir -p $ROOT_DIR/podman-run-containers
mkdir -p /run/containers
mount --bind $ROOT_DIR/podman-run-containers /run/containers

mkdir -p $ROOT_DIR/aosp_mirror
mkdir -p $ROOT_DIR/adevtool_cache
mkdir -p $ROOT_DIR/ota


mkdir -p /dev/shm/graphene-keys/android

apt update -y
apt install -y podman tree iotop

podman load -i $ROOT_DIR/builrom.tar
