CentOS 7.9 离线安装 GCC 11 (devtoolset-11)
=============================================

文件结构:
  install_gcc11.sh        - 一键安装脚本
  rpms/all/*.rpm          - 29 个 RPM 包 (共 74MB)

使用方法:
  1. 将整个 gcc-dev 目录刻录到光盘或复制到 U 盘
  2. 在 CentOS 7.9 目标机上挂载:
       mount /dev/cdrom /mnt        # 光盘
       mount /dev/sdb1 /mnt         # U 盘
  3. 执行安装脚本:
       sudo bash /mnt/gcc-dev/install_gcc11.sh

安装内容:
  - GCC 11.2.1 (C 编译器)          - G++ 11.2.1 (C++ 编译器)
  - Binutils 2.36.1 (汇编/链接器)  - GNU Make 4.3
  - libstdc++ 头文件               - libasan6/libusan1/lslsan/ltsan 运行时
  - AddressSanitizer / UBSan / LSan / TSan 开发库

启用方式 (安装脚本已自动配置):
  - 全局: /etc/profile.d/devtoolset-11.sh (新终端自动生效)
  - 当前 shell: source /opt/rh/devtoolset-11/enable
  - 直接使用: /usr/local/bin/gcc (已创建软链接)

验证:
    source /opt/rh/devtoolset-11/enable
    gcc --version
    g++ --version

注意事项:
  - 需要 CentOS 7.9 x86_64 系统
  - 如系统为 Minimal 安装, 缺少 glibc-devel / kernel-headers,
    请先挂载 CentOS 7.9 安装 DVD 补充:
      yum --disablerepo='*' --enablerepo=c7-media install \
        glibc-devel glibc-headers kernel-headers
  - devtoolset-11-gcc-gfortran (Fortran 编译器) 为可选包
  - devtoolset-11-gcc-plugin-devel (GCC 插件开发) 需 gmp-devel/mpfr-devel/libmpc-devel
