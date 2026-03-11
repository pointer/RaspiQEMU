# RaspiQEMU
Raspberry Pi OS Trixie (Testing) on QEMU 8.2.2

Summarizing our troubleshooting journey and the technical hurdles encountered while emulating Raspberry Pi OS Trixie on QEMU.

---

# Emulating Raspberry Pi 3B (ARM64) on QEMU: Troubleshooting Log

This document summarizes the technical challenges and solutions found while attempting to run **Raspberry Pi OS Trixie (Debian 13 Testing)** on **QEMU 8.2.2**.

## 1. Project Overview

* **Host Machine:** Ubuntu (ThinkStation P520).
* **Target Architecture:** aarch64 (ARM64).
* **Emulated Hardware:** Raspberry Pi 3 Model B+ (`-M raspi3b`).
* **Software Stack:**
* **Kernel:** `kernel8.img` (Linux version 6.12.47+rpt-rpi-v8).
* **OS Image:** `2025-12-04-raspios-trixie-arm64-lite.img`.
* **Firmware:** `rpi3b.dtb`.



## 2. Key Challenges & Technical Hurdles

### Graphical Glitches vs. Headless Mode

* **Issue:** Initial boots using default graphical settings resulted in "yellow artifact" glitches and a frozen screen with four raspberries.
* **Solution:** Switched to `-nographic` mode to bypass the emulated framebuffer and use the terminal as the primary display.

### The "Invisible" Boot (Output Buffering)

* **Issue:** When running QEMU via a script or piping to `tee`, the terminal remained blank even though the system was booting in the background.
* **Observation:** Text only "flushed" to the terminal when the QEMU process was terminated (e.g., via `Ctrl+A, X` or System Monitor).
* **Root Cause:** Standard output (stdout) buffering in Linux pipes prevented real-time logging.

### Console Mapping Failures

* **Issue:** The kernel often reported `Warning: unable to open an initial console`.
* **Fix:** Added specific serial parameters to the `-append` string: `console=ttyAMA0,115200` and `earlycon=pl011,0x3f201000` to force output to the virtual serial port.

### Entropy & Randomness

* **Issue:** The boot process frequently stalled during `systemd` initialization while waiting for the Random Number Generator (RNG) to seed.
* **Attempted Fix:** Tried `-device virtio-rng-pci`, which failed because the `raspi3b` machine model does not support a PCI bus.

## 3. Final Critical Failure: Kernel Panic

Despite reaching the late stages of boot, the system ultimately failed with a **Kernel Panic**:

* **Error:** `Kernel panic - not syncing: Attempted to kill init! exitcode=0x00000000`.
* **Disk Corruption:** The logs showed persistent filesystem errors: `EXT4-fs error ... bad block bitmap checksum`.
* **Init Conflict:** Using `init=/bin/bash` as an emergency bypass failed because the shell crashed immediately, likely due to the corrupted filesystem or missing dependencies in the "Testing" (Trixie) image.

## 4. Successful QEMU Configuration Template

The most stable command achieved during testing was:

```bash
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
  -netdev user,id=net0,hostfwd=tcp::"$PORT"-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-rng-pci \
  -nographic -serial mon:stdio

```

## 5. Lessons & Next Steps

1. **Avoid Pipes for Debugging:** Do not use `| tee` when troubleshooting boot issues; it hides real-time errors.
2. **Use Stable Releases:** Raspberry Pi OS "Trixie" is a testing branch and showed significant filesystem instability in emulation.
3. **Pivot:** The project is moving to **Raspberry Pi OS Bookworm (Stable)** for a more reliable development environment.


### **Quick Start" steps:**

  Start the VM: ./boot-arm64.sh

  Mount the Project (Run inside VM):
        
    sudo mount -t 9p -o trans=virtio,version=9p2000.L,access=any host_share /mnt
