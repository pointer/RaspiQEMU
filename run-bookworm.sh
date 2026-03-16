#!/bin/bash

# --- Configuration ---
VM_NAME="debian-bookworm-arm64"
IMAGE="debian-12-generic-arm64.qcow2"
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"
MEM="2G"
CPUS="2"
PORT="2222"
SHARE_DIR="./shared_project"  # The directory on your host


# --- 1. Shared Directory Check ---
if [ ! -d "$SHARE_DIR" ]; then
    echo "📂 Creating shared directory: $SHARE_DIR"
    mkdir -p "$SHARE_DIR"
    # Optional: Put your project files in there automatically if they exist locally
    cp loop.cpp CMakeLists.txt CMakePresets.json "$SHARE_DIR/" 2>/dev/null
else
    echo "✅ Shared directory '$SHARE_DIR' found."
fi

# --- 1. Dependencies Check ---
for cmd in qemu-system-aarch64 wget genisoimage uuidgen; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Error: $cmd not found. Please install it."
        exit 1
    fi
done

# --- 2. Image Download ---
if [ ! -f "$IMAGE" ]; then
    echo "📥 Downloading Debian 12 ARM64..."
    wget -O "$IMAGE" "$IMAGE_URL"
fi

# --- 3. Create Cloud-Init Seed ISO (Fixes Login) ---
# This satisfies the 404 errors seen in your log
cat <<EOF > user-data
#cloud-config
password: debian
chpasswd: { expire: False }
ssh_pwauth: True
EOF

echo "instance-id: $(uuidgen)" > meta-data

# Create the UEFI auto-boot script
cat <<EOF > startup.nsh
FS0:
cd EFI\debian
grubaa64.efi
EOF

# Package the config into a virtual CD-ROM
genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data startup.nsh

# --- 4. UEFI Firmware Check ---
EFI_CODE="/usr/share/AAVMF/AAVMF_CODE.fd"
EFI_VARS="varstore.fd"
[ ! -f "$EFI_VARS" ] && cp /usr/share/AAVMF/AAVMF_VARS.fd "$EFI_VARS"

# Add this line before the qemu-system-aarch64 command
rm -f varstore.fd && cp /usr/share/AAVMF/AAVMF_VARS.fd varstore.fd

# --- 5. Launch ---
echo "🚀 Booting ARM64 VM... Login: debian / Password: debian"
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
  -virtfs local,path="./shared_project",mount_tag=host_share,security_model=none,id=virtfs0 \
  -netdev user,id=net0,hostfwd=tcp::"$PORT"-:22,hostfwd=tcp::9090-:9090 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-rng-pci \
  -nographic -serial mon:stdio


# sudo mount -t 9p -o trans=virtio,version=9p2000.L,access=any host_share /mnt/shared_project


# #!/bin/bash

# # --- Config ---
# VM_NAME="debian-bookworm-arm64"
# IMAGE="debian-12-generic-arm64.qcow2"
# IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"
# MEM="2G"
# CPUS="2"
# PORT="2222"

# # --- 1. Dependencies Check ---
# if ! command -v genisoimage &> /dev/null; then
#     echo "❌ Error: 'genisoimage' is required. Install: sudo apt install genisoimage"
#     exit 1
# fi

# # --- 2. Image Download ---
# if [ ! -f "$IMAGE" ]; then
#     echo "📥 Downloading Debian 12 ARM64..."
#     wget -O "$IMAGE" "$IMAGE_URL"
# fi

# # --- 3. Create Cloud-Init Seed ISO (The Login Fix) ---
# # This tells cloud-init: "Don't look at the network, use these local credentials."
# cat <<EOF > user-data
# #cloud-config
# password: debian
# chpasswd: { expire: False }
# ssh_pwauth: True
# EOF

# echo "instance-id: $(uuidgen || echo "id-12345")" > meta-data

# genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data

# # --- 4. UEFI Firmware Check ---
# EFI_CODE="/usr/share/AAVMF/AAVMF_CODE.fd"
# EFI_VARS="varstore.fd"
# [ ! -f "$EFI_VARS" ] && cp /usr/share/AAVMF/AAVMF_VARS.fd "$EFI_VARS"

# # --- 5. Launch ---
# qemu-system-aarch64 \
#   -name "$VM_NAME" \
#   -machine virt \
#   -cpu cortex-a57 \
#   -smp "$CPUS" \
#   -m "$MEM" \
#   -accel tcg \
#   -drive if=pflash,format=raw,unit=0,file="$EFI_CODE",readonly=on \
#   -drive if=pflash,format=raw,unit=1,file="$EFI_VARS" \
#   -drive file="$IMAGE",if=virtio \
#   -drive file=seed.iso,format=raw,if=virtio \
#   -netdev user,id=net0,hostfwd=tcp::"$PORT"-:22 \
#   -device virtio-net-pci,netdev=net0 \
#   -device virtio-rng-pci \
#   -nographic -serial mon:stdio