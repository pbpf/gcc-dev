#!/bin/bash
#
# CentOS 7.9 离线安装 GCC 11 (devtoolset-11)
# 使用方法: sudo bash install_gcc11.sh
#

RPM_DIR="$(dirname "$(readlink -f "$0")")/rpms/all"
INSTALL_LOG="/var/log/install_gcc11.log"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

if [[ $EUID -ne 0 ]]; then
    error "请以 root 身份运行: sudo bash install_gcc11.sh"
    exit 1
fi
if [[ ! -d "$RPM_DIR" ]] || [[ -z "$(ls -A "$RPM_DIR"/*.rpm 2>/dev/null)" ]]; then
    error "未找到 RPM 包目录: $RPM_DIR"
    exit 1
fi

echo "" | tee -a "$INSTALL_LOG"
info "=== GCC 11 离线安装 === $(date)" | tee -a "$INSTALL_LOG"
info "RPM 目录: $RPM_DIR" | tee -a "$INSTALL_LOG"
echo "" | tee -a "$INSTALL_LOG"

install_one() {
    local pattern="$1" desc="$2"
    local pkg_file
    pkg_file=$(find "$RPM_DIR" -name "$pattern" -type f 2>/dev/null | head -1)
    [[ -z "$pkg_file" ]] && { warn "  [$desc] 未找到: $pattern"; return 1; }
    local pkg_name
    pkg_name=$(rpm -qp --queryformat '%{NAME}' "$pkg_file" 2>/dev/null)
    [[ -z "$pkg_name" ]] && { warn "  [$desc] 无法读取: $pkg_file"; return 1; }
    if rpm -q "$pkg_name" &>/dev/null; then
        info "  [$desc] 已安装, 跳过"
        return 0
    fi
    info "  [$desc] 安装: $(basename "$pkg_file")"
    rpm -Uvh --quiet "$pkg_file" >> "$INSTALL_LOG" 2>&1
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        info "  [$desc] 完成"
    else
        warn "  [$desc] 失败 (rpm exit=$rc)"
        return $rc
    fi
}

batch_install_dts() {
    local rpms=("$@")
    local tmpfile
    tmpfile=$(mktemp)
    echo "${rpms[@]}" | tr ' ' '\n' > "$tmpfile"
    local count
    count=$(wc -l < "$tmpfile")
    echo "  共 $count 个包"
    rpm -Uvh --quiet --nodeps $(cat "$tmpfile") >> "$INSTALL_LOG" 2>&1
    local rc=$?
    rm -f "$tmpfile"
    return $rc
}

# ========== 1: 基础依赖 ==========
info "--- 步骤 1/5: 基础依赖包 ---"
install_one "scl-utils-20130529-*.rpm"          "scl-utils" || true
install_one "gmp-6.0.0-*.rpm"                   "gmp" || true
install_one "mpfr-3.1.1-*.rpm"                  "mpfr" || true
install_one "libmpc-1.0.1-*.rpm"                "libmpc" || true
install_one "make-3.82-*.rpm"                   "make" || true

# ========== 2: SCL 仓库配置 ==========
info "--- 步骤 2/5: SCL 仓库配置 ---"
# centos-release-scl-rh 必须先于 centos-release-scl 安装
install_one "centos-release-scl-rh-2-*.noarch.rpm"  "centos-release-scl-rh" || true
install_one "centos-release-scl-2-*.noarch.rpm"     "centos-release-scl" || true

# 修复 SCL 仓库 URL
for repo_file in /etc/yum.repos.d/CentOS-SCLo-scl*.repo; do
    if [[ -f "$repo_file" ]]; then
        cp -n "$repo_file" "${repo_file}.bak" 2>/dev/null || true
        sed -i 's|^mirrorlist=.*|#mirrorlist=disabled|' "$repo_file"
        sed -i 's|^#baseurl=http://mirror.centos.org/centos|baseurl=https://vault.centos.org/centos|' "$repo_file"
        info "  已修复: $(basename "$repo_file")"
    fi
done

# ========== 3: devtoolset-11 核心包 ==========
info "--- 步骤 3/5: devtoolset-11 (核心编译器) ---"
# 排除 devtoolset-11 元包 (依赖未下载的 -perftools/-toolchain)
# 使用 --nodeps: SCL 包自包含于 /opt/rh/, 交叉依赖和自引用依赖在离线安装中
# 由 --nodeps 安全处理, 实际运行不受影响.
for pkg in \
    "devtoolset-11-runtime-*.rpm" \
    "devtoolset-11-binutils-*.rpm" \
    "devtoolset-11-gcc-11.2*.rpm" \
    "devtoolset-11-libstdc++-devel-*.rpm" \
    "devtoolset-11-gcc-c++-*.rpm" \
    "devtoolset-11-make-*.rpm"; do
    pkg_file=$(find "$RPM_DIR" -name "$pkg" -type f 2>/dev/null | head -1)
    [[ -z "$pkg_file" ]] && { warn "  跳过 (未找到): $pkg"; continue; }
    pkg_name=$(rpm -qp --queryformat '%{NAME}' "$pkg_file" 2>/dev/null)
    if rpm -q "$pkg_name" &>/dev/null; then
        info "  已安装: $pkg_name"
        continue
    fi
    info "  安装: $(basename "$pkg_file")"
    rpm -Uvh --quiet --nodeps "$pkg_file" >> "$INSTALL_LOG" 2>&1 || \
        warn "  失败: $(basename "$pkg_file") (exit $?)"
done

# ========== 4: 附加运行时和开发包 ==========
info "--- 步骤 4/5: 附加运行时/开发库 (可选) ---"
for pkg in \
    "libasan6-*.rpm" \
    "libubsan1-*.rpm" \
    "liblsan-*.rpm" \
    "libtsan-*.rpm" \
    "devtoolset-11-libasan-devel-*.rpm" \
    "devtoolset-11-libubsan-devel-*.rpm" \
    "devtoolset-11-liblsan-devel-*.rpm" \
    "devtoolset-11-libtsan-devel-*.rpm" \
    "devtoolset-11-libatomic-devel-*.rpm" \
    "devtoolset-11-libitm-devel-*.rpm" \
    "devtoolset-11-libquadmath-devel-*.rpm" \
    "devtoolset-11-gcc-gdb-plugin-*.rpm" \
    "devtoolset-11-gcc-gfortran-*.rpm" \
    "devtoolset-11-gcc-plugin-devel-*.rpm"; do
    pkg_file=$(find "$RPM_DIR" -name "$pkg" -type f 2>/dev/null | head -1)
    [[ -z "$pkg_file" ]] && { info "  跳过 (未下载): $pkg"; continue; }
    pkg_name=$(rpm -qp --queryformat '%{NAME}' "$pkg_file" 2>/dev/null)
    if rpm -q "$pkg_name" &>/dev/null; then
        info "  已安装: $pkg_name"
        continue
    fi
    info "  安装: $(basename "$pkg_file")"
    rpm -Uvh --quiet --nodeps "$pkg_file" >> "$INSTALL_LOG" 2>&1 || \
        warn "  失败: $(basename "$pkg_file") (exit $?)"
done

# ========== 5: CUDA 12.4 nvcc 工具链 ==========
info "--- 步骤 5/6: CUDA 12.4 nvcc 工具链 ---"

CUDA_DIR="/usr/local/cuda-12.4"
CUDA_PKGS=(
    "cuda-compiler-12-4-*.rpm"
    "cuda-nvcc-12-4-*.rpm"
    "cuda-crt-12-4-*.rpm"
    "cuda-nvvm-12-4-*.rpm"
    "cuda-cudart-12-4-*.rpm"
    "cuda-cudart-devel-12-4-*.rpm"
    "cuda-cccl-12-4-*.rpm"
    "cuda-driver-devel-12-4-*.rpm"
    "cuda-cuobjdump-12-4-*.rpm"
    "cuda-cuxxfilt-12-4-*.rpm"
    "cuda-nvprune-12-4-*.rpm"
    "cuda-profiler-api-12-4-*.rpm"
    "cuda-toolkit-12-4-config-common-*.rpm"
    "libcublas-12-4-*.rpm"
    "libcublas-devel-12-4-*.rpm"
    "libnccl-2.21*.rpm"
    "libnccl-devel-2.21*.rpm"
)

for pattern in "${CUDA_PKGS[@]}"; do
    pkg_file=$(find "$RPM_DIR" -name "$pattern" -type f 2>/dev/null | head -1)
    [[ -z "$pkg_file" ]] && { info "  跳过 (未下载): $pattern"; continue; }
    pkg_name=$(rpm -qp --queryformat '%{NAME}' "$pkg_file" 2>/dev/null)
    if rpm -q "$pkg_name" &>/dev/null; then
        info "  已安装: $pkg_name"
        continue
    fi
    info "  安装: $(basename "$pkg_file")"
    rpm -Uvh --quiet --nodeps "$pkg_file" >> "$INSTALL_LOG" 2>&1 || \
        warn "  失败: $(basename "$pkg_file") (exit $?)"
done

# CUDA 环境变量脚本
cat > /etc/profile.d/cuda-12.4.sh << 'EOF'
#!/bin/bash
export CUDA_HOME=/usr/local/cuda-12.4
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$CUDA_HOME/lib:$LD_LIBRARY_PATH
EOF
chmod +x /etc/profile.d/cuda-12.4.sh

# 软链接到 /usr/local/bin
for tool in nvcc nvprune cuobjdump cuxxfilt; do
    src="/usr/local/cuda-12.4/bin/$tool"
    dst="/usr/local/bin/$tool"
    [[ -x "$src" ]] && ln -sf "$src" "$dst"
done

# 检查 nvcc
NVC="/usr/local/cuda-12.4/bin/nvcc"
if [[ -x "$NVC" ]]; then
    nvcc_ver=$("$NVC" --version | tail -1)
    echo "  CUDA 路径: $CUDA_DIR" | tee -a "$INSTALL_LOG"
    echo "  nvcc 版本: $nvcc_ver" | tee -a "$INSTALL_LOG"
else
    warn "  nvcc 未安装成功" | tee -a "$INSTALL_LOG"
fi

# ========== 6: 验证 + 环境配置 ==========
info "--- 步骤 6/6: 验证 & 配置 ---"

echo "  验证关键包:" | tee -a "$INSTALL_LOG"
ALL_OK=true
for pkg in devtoolset-11-runtime devtoolset-11-gcc devtoolset-11-gcc-c++ \
           devtoolset-11-binutils devtoolset-11-libstdc++-devel devtoolset-11-make; do
    if rpm -q "$pkg" &>/dev/null; then
        echo "    OK  $pkg" | tee -a "$INSTALL_LOG"
    else
        echo "    FAIL $pkg" | tee -a "$INSTALL_LOG"
        ALL_OK=false
    fi
done

for pkg in cuda-nvcc-12-4 cuda-cudart-devel-12-4; do
    if rpm -q "$pkg" &>/dev/null; then
        echo "    OK  $pkg" | tee -a "$INSTALL_LOG"
    else
        echo "    FAIL $pkg" | tee -a "$INSTALL_LOG"
    fi
done

# 环境配置
cat > /etc/profile.d/devtoolset-11.sh << 'EOF'
#!/bin/bash
if [[ -f /opt/rh/devtoolset-11/enable ]]; then
    source /opt/rh/devtoolset-11/enable
fi
EOF
chmod +x /etc/profile.d/devtoolset-11.sh

for tool in gcc g++ c++ gcc-ar gcc-nm gcc-ranlib gcov gcov-dump gcov-tool; do
    src="/opt/rh/devtoolset-11/root/usr/bin/$tool"
    dst="/usr/local/bin/$tool"
    [[ -x "$src" ]] && ln -sf "$src" "$dst"
done

echo "" | tee -a "$INSTALL_LOG"
echo "==========================================" | tee -a "$INSTALL_LOG"
echo "  GCC 11 + CUDA 12.4 安装完成!" | tee -a "$INSTALL_LOG"
echo "==========================================" | tee -a "$INSTALL_LOG"
echo "" | tee -a "$INSTALL_LOG"

DEVTOOLSET_GCC="/opt/rh/devtoolset-11/root/usr/bin/gcc"
if [[ -x "$DEVTOOLSET_GCC" ]]; then
    gcc_ver=$("$DEVTOOLSET_GCC" --version | head -1)
    echo "  GCC 路径: $DEVTOOLSET_GCC" | tee -a "$INSTALL_LOG"
    echo "  GCC 版本: $gcc_ver" | tee -a "$INSTALL_LOG"
fi
if [[ -x "$NVC" ]]; then
    nvcc_ver=$("$NVC" --version | tail -1)
    echo "  nvcc 路径: $NVC" | tee -a "$INSTALL_LOG"
    echo "  nvcc 版本: $nvcc_ver" | tee -a "$INSTALL_LOG"
fi
echo "" | tee -a "$INSTALL_LOG"
echo "编译 llama.cpp 示例:" | tee -a "$INSTALL_LOG"
echo "  source /etc/profile.d/devtoolset-11.sh" | tee -a "$INSTALL_LOG"
echo "  source /etc/profile.d/cuda-12.4.sh" | tee -a "$INSTALL_LOG"
echo "  git clone https://github.com/ggml-org/llama.cpp" | tee -a "$INSTALL_LOG"
echo "  cd llama.cpp && mkdir build && cd build" | tee -a "$INSTALL_LOG"
echo '  cmake .. -DGGML_CUDA=ON -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++' | tee -a "$INSTALL_LOG"
echo "  make -j\$(nproc)" | tee -a "$INSTALL_LOG"
echo "" | tee -a "$INSTALL_LOG"

$ALL_OK && echo "=== 安装成功 ===" | tee -a "$INSTALL_LOG" || echo "=== 安装有失败, 请查看上方 FAIL 项 ===" | tee -a "$INSTALL_LOG"
