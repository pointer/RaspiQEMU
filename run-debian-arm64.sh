#!/bin/bash

# --- Configuration ---
VM_NAME="debian-bookworm-arm64"
IMAGE="debian-12-generic-arm64.qcow2"
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"
MEM="2G"
CPUS="2"
SSH_PORT="2222"
USER_NAME="debian"
USER_PASS="debian"

# --- 1. Dependencies Check ---
deps=(qemu-system-aarch64 wget genisoimage uuidgen)
for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Error: $cmd is missing. Install via: sudo apt install qemu-system-arm wget genisoimage uuid-runtime"
        exit 1
    fi
done

# --- 2. Image Acquisition ---
if [ ! -f "$IMAGE" ]; then
    echo "📥 Downloading Debian 12 Bookworm ARM64..."
    wget -O "$IMAGE" "$IMAGE_URL"
fi

# --- 3. Cloud-Init Generation ---
# This ensures the 'debian' user exists with the correct password immediately
if [ ! -f "seed.iso" ]; then
    echo "🛠️ Creating Cloud-Init configuration..."
    cat <<EOF > user-data
#cloud-config
user: $USER_NAME
password: $USER_PASS
chpasswd: { expire: False }
ssh_pwauth: True
sudo: ALL=(ALL) NOPASSWD:ALL
EOF
    echo "instance-id: $(uuidgen)" > meta-data
    genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data
fi

# --- 4. UEFI Firmware setup ---
# Adjust paths if using a non-Debian/Ubuntu host
EFI_CODE="/usr/share/AAVMF/AAVMF_CODE.fd"
EFI_VARS="varstore.fd"
if [ ! -f "$EFI_VARS" ]; then
    cp /usr/share/AAVMF/AAVMF_VARS.fd "$EFI_VARS"
fi

# --- 5. Launch VM ---
echo "--------------------------------------------------------"
echo "🚀 Booting ARM64 Debian Bookworm"
echo "🔑 Login: $USER_NAME / Password: $USER_PASS"
echo "🌐 SSH: ssh $USER_NAME@localhost -p $SSH_PORT"
echo "--------------------------------------------------------"

qemu-system-aarch64 \
  -name "$VM_NAME" \
  -machine virt \
  -cpu cortex-a57 \
  -smp "$CPUS" \
  -m "$MEM" \
  -accel tcg \
  -drive if=pflash,format=raw,unit=0,file="$EFI_CODE",readonly=on \
  -drive if=pflash,format=raw,unit=1,file="$EFI_VARS" \
  -drive file="$IMAGE",if=virtio \
  -drive file=seed.iso,format=raw,if=virtio \
  -netdev user,id=net0,hostfwd=tcp::"$SSH_PORT"-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-rng-pci \
  -nographic -serial mon:stdio
