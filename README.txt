CentOS 7.9 离线安装 GCC 11 + CUDA 12.4 (nvcc)
================================================

文件结构:
  install_gcc11.sh         - 一键安装脚本 (GCC 11 + CUDA 12.4)
  rpms/all/*.rpm           - 41 个 RPM 包 (共 174MB)

使用方法:
  1. 将整个 gcc-dev 目录复制到 U 盘或刻录到 DVD (174MB > CD 容量)
  2. 在 CentOS 7.9 目标机上挂载:
       mount /dev/sr0 /mnt           # DVD
       mount /dev/sdb1 /mnt          # U 盘
  3. 执行安装脚本:
       sudo bash /mnt/gcc-dev/install_gcc11.sh

安装内容:
  GCC 11.2.1:
    - gcc (C 编译器)       - g++ (C++ 编译器)
    - binutils 2.36.1      - GNU Make 4.3
    - libstdc++ 头文件     - AddressSanitizer / UBSan / LSan / TSan

  CUDA 12.4:
    - nvcc (CUDA 编译器)   - cuBLAS 运行时 (可选, 需另行下载)
    - CUDA 运行时库        - CUDA 驱动开发头文件
    - NVVM 编译器          - CCCL (CUB/Thrust/libcu++)

编译 llama.cpp:
  source /etc/profile.d/devtoolset-11.sh
  source /etc/profile.d/cuda-12.4.sh
  git clone https://github.com/ggml-org/llama.cpp
  cd llama.cpp && mkdir build && cd build
  cmake .. -DGGML_CUDA=ON -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++
  make -j$(nproc)

注意事项:
  - 系统需预装 NVIDIA 驱动 (已确认安装 nv12.4 驱动)
  - 如系统为 Minimal 安装, 缺少 glibc-devel / kernel-headers 时:
      yum --disablerepo='*' --enablerepo=c7-media install \
        glibc-devel glibc-headers kernel-headers
  - 如需 cuBLAS 支持 (GGML_CUBLAS=ON), 从 NVIDIA 官网下载:
      libcublas-12-4 + libcublas-devel-12-4 (共 746MB)
