FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    novnc \
    websockify \
    wget \
    net-tools \
    python3 \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Download Ubuntu Server ISO
RUN wget -q https://cdimage.ubuntu.com/ubuntu-server/noble/daily-live/current/noble-live-server-amd64.iso -O /ubuntu.iso

# Create blank VM disk
RUN qemu-img create -f qcow2 /disk.qcow2 20G

# Startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
qemu-system-x86_64 \\\n\
  -enable-kvm \\\n\
  -m 4096 \\\n\
  -smp 2 \\\n\
  -vga virtio \\\n\
  -cdrom /ubuntu.iso \\\n\
  -drive file=/disk.qcow2,format=qcow2,if=virtio \\\n\
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \\\n\
  -device virtio-net,netdev=net0 \\\n\
  -vnc :0 &\n\
\n\
sleep 5\n\
websockify --web /usr/share/novnc/ 6080 localhost:5900 &\n\
\n\
echo "================================================"\n\
echo " 🖥️  Access the installer: http://localhost:6080"\n\
echo " 🔧 Proceed with full Ubuntu install"\n\
echo " ✅ Set your own username and password manually"\n\
echo "================================================"\n\
\n\
tail -f /dev/null\n' > /start.sh && chmod +x /start.sh

EXPOSE 6080 2222

CMD ["/start.sh"]
