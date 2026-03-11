#!/bin/bash

# --- 1. Configuration ---
VM_NAME="debian-bookworm-arm64"
IMAGE="debian-12-generic-arm64.qcow2"
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"
SHARE_DIR="./shared_project"
SSH_PORT="2222"
MEM="2G"
CPUS="2"

# --- 2. Prerequisites & Folder Check ---
mkdir -p "$SHARE_DIR"
if [ ! -f "$IMAGE" ]; then
    echo "📥 Downloading Debian 12 ARM64 image..."
    wget -O "$IMAGE" "$IMAGE_URL"
fi

# --- 3. Generate Boot & Login Assets ---
# Reset UEFI variables to ensure clean boot order
rm -f varstore.fd
cp /usr/share/AAVMF/AAVMF_VARS.fd varstore.fd

# Create Login Credentials (Cloud-Init)
cat <<EOF > user-data
#cloud-config
password: debian
chpasswd: { expire: False }
ssh_pwauth: True
EOF
echo "instance-id: $(uuidgen)" > meta-data

# Create UEFI Auto-Boot Script
cat <<EOF > startup.nsh
FS0:
cd EFI\debian
grubaa64.efi
EOF

# Package everything into the Seed ISO
genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data startup.nsh

# --- 4. Launch QEMU ---
echo "🚀 Booting $VM_NAME..."
echo "📂 Shared folder '$SHARE_DIR' available as 'host_share'"
echo "🔑 Login: debian / Password: debian"

qemu-system-aarch64 \
  -name "$VM_NAME" \
  -machine virt \
  -cpu cortex-a57 \
  -smp "$CPUS" -m "$MEM" \
  -accel tcg \
  -drive if=pflash,format=raw,unit=0,file="/usr/share/AAVMF/AAVMF_CODE.fd",readonly=on \
  -drive if=pflash,format=raw,unit=1,file="varstore.fd" \
  -drive file="$IMAGE",if=virtio \
  -drive file=seed.iso,format=raw,if=virtio \
  -virtfs local,path="$SHARE_DIR",mount_tag=host_share,security_model=none,id=virtfs0 \
  -netdev user,id=net0,hostfwd=tcp::"$SSH_PORT"-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-rng-pci \
  -nographic -serial mon:stdio
