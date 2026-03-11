#!/bin/bash

# --- Configuration ---
VM_NAME="debian-bookworm-arm64"
IMAGE="debian-12-generic-arm64.qcow2"
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"
MEM="2G"
CPUS="2"
PORT="2222"

# --- Image Check & Download ---
if [ ! -f "$IMAGE" ]; then
    echo "📥 ARM64 Image not found. Downloading Debian 12 Bookworm..."
    wget -O "$IMAGE" "$IMAGE_URL"
fi

# --- UEFI Firmware Check ---
# ARM VMs require EFI. On Debian/Ubuntu host: sudo apt install qemu-efi-aarch64
EFI_CODE="/usr/share/AAVMF/AAVMF_CODE.fd"
EFI_VARS="varstore.fd"

if [ ! -f "$EFI_CODE" ]; then
    echo "❌ Error: UEFI firmware not found at $EFI_CODE."
    echo "Please run: sudo apt install qemu-efi-aarch64"
    exit 1
fi

if [ ! -f "$EFI_VARS" ]; then
    echo "🛠️ Creating EFI variable store..."
    cp /usr/share/AAVMF/AAVMF_VARS.fd "$EFI_VARS"
fi

# --- Execution ---
echo "🚀 Starting ARM64 VM on port $PORT..."
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
  -netdev user,id=net0,hostfwd=tcp::"$PORT"-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-rng-pci \
  -nographic
