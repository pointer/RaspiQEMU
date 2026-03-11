#!/bin/bash

# --- Configuration Variables ---
VM_NAME="debian-bookworm"
IMAGE="debian-12-generic-amd64.qcow2"
MEM="4G"
CPUS="4"
PORT="2222" # SSH port on host to map to VM

# --- Image Check ---
# Download the official cloud image if it doesn't exist
if [ ! -f "$IMAGE" ]; then
    echo "📥 Image not found. Downloading Debian 12 Bookworm Cloud Image..."
    wget -O "$IMAGE" https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
fi

# --- Performance & Hardware Optimization ---
# -enable-kvm: Use hardware acceleration (critical for performance)
# -cpu host: Pass through host CPU features
# -m: Memory allocation
# -smp: Number of CPU cores

qemu-system-x86_64 \
  -name "$VM_NAME" \
  -enable-kvm \
  -cpu host \
  -m "$MEM" \
  -smp "$CPUS" \
  -drive file="$IMAGE",if=virtio,cache=writeback \
  -netdev user,id=net0,hostfwd=tcp::"$PORT"-:22 \
  -device virtio-net-pci,netdev=net0 \
  -display none \
  -vga virtio \
  -serial mon:stdio \
  -device virtio-rng-pci \
  -boot c
