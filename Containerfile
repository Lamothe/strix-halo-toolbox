# Start from the official Fedora 43 Toolbox image
FROM registry.fedoraproject.org/fedora-toolbox:43

# Add the official AMD ROCm 7.2.1 repository
RUN cat <<EOF > /etc/yum.repos.d/rocm.repo
[rocm]
name=ROCm 7.2.1 repository
baseurl=https://repo.radeon.com/rocm/rhel10/7.2.1/main
enabled=1
priority=50
gpgcheck=1
gpgkey=https://repo.radeon.com/rocm/rocm.gpg.key
EOF

# Install system dependencies. 
# The cache mount prevents re-downloading these RPMs on subsequent image builds.
RUN --mount=type=cache,target=/var/cache/libdnf5 \
    dnf install -y \
    python3.12 \
    python3.12-devel \
    python3-pip \
    util-linux \
    git \
    gcc-c++ \
    glibc-devel \
    rocm7.2.1 \
    rocm-hip-sdk \
    hipify-clang \
    eigen3-devel \
    miopen-hip \
    vulkan-loader-devel \
    vulkan-headers \
    glslc \
    cmake \
    openssl-devel \
    && dnf clean all
