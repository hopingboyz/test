# Use Debian 10 (Buster) as base
FROM debian:10-slim

# Install minimal dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    wget \
    python3 \
    novnc \
    websockify \
    && rm -rf /var/lib/apt/lists/*

# Download Debian 10.13 netinst ISO
RUN wget -q https://archive.debian.org/debian-cd/10.13.0/amd64/iso-cd/debian-10.13.0-amd64-netinst.iso -O /debian.iso && \
    [ -s /debian.iso ] || { echo "ISO download failed"; exit 1; }

# Create startup script (non-KVM version)
RUN echo '#!/bin/bash\n\
\n\
# Create blank 20GB disk image\n\
qemu-img create -f qcow2 /disk.qcow2 20G\n\
\n\
# Start QEMU without KVM acceleration\n\
qemu-system-x86_64 \\\n\
    -cdrom /debian.iso \\\n\
    -drive file=/disk.qcow2,format=qcow2 \\\n\
    -m 4G \\\n\
    -smp 4 \\\n\
    -device virtio-net,netdev=net0 \\\n\
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \\\n\
    -vnc :0 \\\n\
    -usb -device usb-tablet \\\n\
    -daemonize\n\
\n\
# Start noVNC with proper path\n\
websockify --web /usr/share/novnc 6080 localhost:5900 &\n\
\n\
echo "================================================"\n\
echo "Debian 10 Installation Starting..."\n\
echo "1. Connect to VNC: http://localhost:6080/vnc.html"\n\
echo "2. Complete the interactive installation"\n\
echo "3. Set your username/password when prompted"\n\
echo "4. After reboot, SSH will be available on port 2222"\n\
echo "================================================"\n\
\n\
tail -f /dev/null\n\
' > /start-vm.sh && chmod +x /start-vm.sh

EXPOSE 6080 2222

CMD ["/start-vm.sh"]
