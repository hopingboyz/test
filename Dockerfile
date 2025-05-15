# Use Ubuntu 24.04 as base with minimal footprint
FROM ubuntu:24.04 as builder

# Install only essential dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Download the Ubuntu Server ISO (stable release instead of daily)
RUN wget -q https://cdimage.ubuntu.com/ubuntu-server/noble/daily-live/current/noble-live-server-amd64.iso -O /ubuntu.iso

# Create final minimal image
FROM ubuntu:24.04

# Install only necessary packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    python3 \
    novnc \
    websockify \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy the ISO from builder stage
COPY --from=builder /ubuntu.iso /ubuntu.iso

# Create startup script
RUN echo '#!/bin/bash\n\
\n\
# Create blank disk image if not exists\n\
if [ ! -f /disk.qcow2 ]; then\n\
    qemu-img create -f qcow2 /disk.qcow2 20G\n\
fi\n\
\n\
# Start QEMU with KVM acceleration if available\n\
KVM_ACCEL="-enable-kvm"\n\
if [ ! -e /dev/kvm ]; then\n\
    KVM_ACCEL=""\n\
    echo "Warning: KVM acceleration not available, falling back to slower emulation"\n\
fi\n\
\n\
qemu-system-x86_64 \\\n\
    ${KVM_ACCEL} \\\n\
    -cdrom /ubuntu.iso \\\n\
    -drive file=/disk.qcow2,format=qcow2 \\\n\
    -m 4G \\\n\
    -smp 4 \\\n\
    -device virtio-net,netdev=net0 \\\n\
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \\\n\
    -vnc 0.0.0.0:0 \\\n\
    -nographic &\n\
\n\
# Start noVNC\n\
websockify --web /usr/share/novnc/ 6080 localhost:5900 &\n\
\n\
echo "================================================"\n\
echo "Ubuntu Server Installation Starting..."\n\
echo "1. Connect to VNC: http://localhost:6080/vnc.html"\n\
echo "2. Complete the interactive installation"\n\
echo "3. Set your username/password when prompted"\n\
echo "4. After reboot, SSH will be available on port 2222"\n\
echo "================================================"\n\
\n\
wait\n\
' > /start-vm.sh && chmod +x /start-vm.sh

# Health check to verify services are running
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ps aux | grep -q "[q]emu-system-x86_64" && ps aux | grep -q "[w]ebsockify"

EXPOSE 6080 2222

CMD ["/start-vm.sh"]
