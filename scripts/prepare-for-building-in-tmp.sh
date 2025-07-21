mkdir -p /tmp/podman-var-lib-containers
mkdir -p /var/lib/containers/
mount --bind /tmp/podman-var-lib-containers /var/lib/containers/

mkdir -p /tmp/podman-run-containers
mkdir -p /run/containers
mount --bind /tmp/podman-run-containers /run/containers

mkdir -p /tmp/aosp_mirror
mkdir -p /tmp/adevtool_cache


mkdir -p /dev/shm/graphene-keys
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cp "$SCRIPT_DIR/passwords.sh" /dev/shm/graphene-keys

apt update -y
apt install -y podman tree

