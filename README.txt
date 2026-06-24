CentOS 7.9 离线安装 GCC 11 + CUDA 12.4 (nvcc)
================================================

硬件环境:
  CPU: Intel Xeon Gold 6348 (Ice Lake-SP, 28C/56T, AVX-512)
  GPU: NVIDIA A100 80G x 6
  驱动: NVIDIA 12.4 (已安装)

文件结构:
  install_gcc11.sh         - 一键安装脚本 (GCC 11 + CUDA 12.4)
  rpms/all/*.rpm           - 44 个 RPM 包 (共 1.1GB)

使用方法:
  1. 将整个 gcc-dev 目录复制到 U 盘或刻录到 DVD
  2. 在目标机上挂载:
       mount /dev/sr0 /mnt           # DVD
       mount /dev/sdb1 /mnt          # U 盘
  3. 执行安装脚本:
       sudo bash /mnt/gcc-dev/install_gcc11.sh

安装内容:
  GCC 11.2.1 (devtoolset-11):
    - gcc / g++ 编译器      - binutils 2.36.1
    - GNU Make 4.3          - libstdc++ 头文件
    - ASan / UBSan / LSan / TSan

  CUDA 12.4:
    - nvcc 编译器           - cuBLAS 运行时 + 开发库
    - CUDA 运行时库         - CUDA 驱动开发头文件
    - NCCL (多 GPU 通信)    - NVVM 编译器
    - CCCL (CUB/Thrust/libcu++)

 编译 llama.cpp (Xeon 6348 + 6 x A100 80G):

    source /etc/profile.d/devtoolset-11.sh
    source /etc/profile.d/cuda-12.4.sh

    git clone https://github.com/ggml-org/llama.cpp
    cd llama.cpp && mkdir build && cd build

    cmake .. \
      -DGGML_CUDA=ON \
      -DCMAKE_CUDA_ARCHITECTURES=80 \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_COMPILER=gcc \
      -DCMAKE_CXX_COMPILER=g++ \
      -DCMAKE_CUDA_COMPILER=/usr/local/cuda-12.4/bin/nvcc \
      -DLLAMA_NATIVE=ON

    make -j$(nproc)

  LLAMA_NATIVE=ON 会启用 Ice Lake 的 AVX-512 指令集优化.
  make -j$(nproc) 利用 56 线程并行编译.

注意事项:
  - 系统需预装 NVIDIA 驱动 (12.4)
  - Minimal 安装缺 glibc-devel / kernel-headers 时:
      yum --disablerepo='*' --enablerepo=c7-media install \
        glibc-devel glibc-headers kernel-headers
  - 运行时多 GPU 使用: ./llama-cli --n-gpu-layers 999 --main-gpu 0 ...
