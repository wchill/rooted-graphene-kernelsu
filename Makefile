.PHONY: all build clean push-ota

# optional inputs for CPU and memory limits (defaults to 100% of available resources)
GRAPHENE_BRANCH ?= stable
KEYS_DIR ?= /dev/shm/graphene-keys
MAX_CPU_PERCENT ?= 100
MAX_MEM_PERCENT ?= 100

CPU_LIMIT := $(shell echo $$(( $(shell nproc --all) * $(MAX_CPU_PERCENT) / 100 )))
MEM_LIMIT := $(shell echo "$$(( $(shell free -m | awk '/^Mem:/{print $$2}') * $(MAX_MEM_PERCENT) / 100 ))m")

REPO_MIRROR     ?= /tmp/aosp_mirror          # read‑only Git mirror
ADEV_CACHE      ?= /tmp/adevtool_cache       # factory‑image ZIPs


COMMON_PODMAN_FLAGS := \
	--rm \
	--cpus="$(CPU_LIMIT)" \
	--memory="$(MEM_LIMIT)" \
	--pids-limit=0 \
	-v "$(PWD)":/src:Z \
	-v "$(KEYS_DIR)":/dev/shm/graphene-keys:Z \
	-v "$(REPO_MIRROR)":/aosp_mirror:Z \
	-v "$(ADEV_CACHE)":/adevtool_dl_cache:Z \
	-v "$(WEB_DIR)":/web \
	-e REPO_MIRROR_INSIDE=/aosp_mirror \
	-e ADEV_CACHE_INSIDE=/adevtool_dl_cache \
	-e USE_CCACHE=0 \
	-w /src


# Default target must be first
all:
	$(call check_device)
	$(call check_web_dir)
	$(MAKE) clean
	$(MAKE) build-podman-image
	$(MAKE) generate-keys
	$(MAKE) check-versions
	$(MAKE) pull-repo
	$(MAKE) build-kernel
	$(MAKE) build-rom
	$(MAKE) push-ota

# Check required variables
check_device = $(if $(DEVICE),,$(error DEVICE is required))
check_web_dir = $(if $(WEB_DIR),,$(error WEB_DIR is required))

# Build podman image
build-podman-image:
	podman build -t buildrom .

# Generate all the keys in a RAM fs
generate-keys:
	$(call check_device)
	podman run $(COMMON_PODMAN_FLAGS) buildrom \
		/bin/bash /src/scripts/0b_keys.sh $(DEVICE)

# Build kernel using podman
build-kernel:
	$(call check_device)
	podman run $(COMMON_PODMAN_FLAGS) buildrom \
		/bin/bash /src/scripts/2_build_kernel.sh $(DEVICE)

# Build rom using podman
build-rom:
	$(call check_device)
	podman run $(COMMON_PODMAN_FLAGS) buildrom \
		/bin/bash /src/scripts/3_build_rom.sh $(DEVICE)

# Check versions
check-versions:
	podman run $(COMMON_PODMAN_FLAGS) buildrom \
		/bin/bash /src/scripts/1_check_versions.sh $(DEVICE) $(GRAPHENE_BRANCH)

# Pull repo updates
pull-repo:
	git reset --hard
	git pull

# Push OTA update
push-ota:
	$(call check_device)
	$(call check_web_dir)
	podman run $(COMMON_PODMAN_FLAGS) buildrom \
		/bin/bash /src/scripts/4_push_ota.sh $(DEVICE)

# Clean build directories
clean:
	rm -rfv "data/*_build_*.txt" device_tmp/ kernel/ kernel_out/ rom/
