FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /root

# Install required tools only
RUN apt update && apt install -y \
    qemu-system-x86 \
    cloud-image-utils \
    wget \
    sudo \
    openssh-server \
    net-tools \
    curl \
    && apt clean

# Download Ubuntu Cloud Image
RUN wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img -O ubuntu.img

# Create working root login cloud-init config
RUN echo '#cloud-config\n'\
'users:\n'\
'  - name: root\n'\
'    gecos: "root"\n'\
'    shell: /bin/bash\n'\
'    lock_passwd: false\n'\
'    passwd: $6$rounds=4096$abc$z9S5idDco5QnXJTuPyHbNlLw5aTZTDJJJK9s5s91a.KzHnNOUYyRIdK9dDgW0.DlyV9lM.xSmGcI6VCHUl2RW0\n'\
'    sudo: ALL=(ALL) NOPASSWD:ALL\n'\
'ssh_pwauth: true\n'\
'disable_root: false\n'\
'chpasswd:\n'\
'  expire: false\n'\
'  list: |\n'\
'    root:root\n' > user-data && \
    echo 'instance-id: iid-local01\nlocal-hostname: ubuntu-vm' > meta-data && \
    cloud-localds cloud-init.iso user-data meta-data

# Expose SSH port
EXPOSE 2222

# Start QEMU VM without KVM, headless and minimal
CMD qemu-system-x86_64 \
    -m 1024 \
    -smp 1 \
    -nographic \
    -drive file=ubuntu.img,format=qcow2,if=virtio \
    -cdrom cloud-init.iso \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net,netdev=net0 \
    -no-reboot \
    -serial mon:stdio \
    -cpu max \
    -machine accel=tcg
