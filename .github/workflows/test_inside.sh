#!/bin/bash
cd /work

echo "=== Running install_gcc11.sh ==="
bash install_gcc11.sh; rc=$?
echo "install_gcc11.sh exit code: $rc"
set -e

echo ""
echo "=== Verify GCC version ==="
/opt/rh/devtoolset-11/root/usr/bin/gcc --version
/usr/local/bin/gcc --version

c_test() {
    local file="$1" lang="$2" std="$3" label="$4"
    echo ""
    echo "=== $label ==="
    /opt/rh/devtoolset-11/root/usr/bin/"$lang" -std="$std" -o "/tmp/${file%.*}" "/tmp/$file"
    "/tmp/${file%.*}"
}

cat > /tmp/c11.c << 'EOF'
#include <stdio.h>
int main(void) {
    printf("C11: OK\n");
    return 0;
}
EOF
c_test c11.c gcc c11 "C11 test"

cat > /tmp/cpp11.cpp << 'EOF'
#include <iostream>
int main() {
    std::cout << "C++11: OK" << std::endl;
    return 0;
}
EOF
c_test cpp11.cpp g++ c++11 "C++11 test"

cat > /tmp/cpp17.cpp << 'EOF'
#include <iostream>
#include <string_view>
int main() {
    constexpr std::string_view msg = "C++17: OK";
    std::cout << msg << std::endl;
    return 0;
}
EOF
c_test cpp17.cpp g++ c++17 "C++17 test"

cat > /tmp/cpp20.cpp << 'EOF'
#include <iostream>
#include <concepts>
template<typename T> requires std::integral<T>
T add(T a, T b) { return a + b; }
int main() {
    std::cout << "C++20 concepts: " << add(3, 4) << std::endl;
    return 0;
}
EOF
c_test cpp20.cpp g++ c++20 "C++20 concepts test"

cat > /tmp/span.cpp << 'EOF'
#include <iostream>
#include <span>
#include <vector>
int main() {
    std::vector<int> v = {1, 2, 3, 4, 5};
    std::span<int> s(v);
    int sum = 0;
    for (auto x : s) sum += x;
    std::cout << "C++20 span sum: " << sum << std::endl;
    return 0;
}
EOF
c_test span.cpp g++ c++20 "C++20 span test"

echo ""
echo "=== nvcc compilation test ==="
source /etc/profile.d/cuda-12.4.sh
nvcc --version
cat > /tmp/test_cuda.cu << 'NVEOF'
__global__ void kernel() {}
int main() {
    kernel<<<1,1>>>();
    return 0;
}
NVEOF
nvcc -std=c++17 -o /tmp/test_cuda /tmp/test_cuda.cu
echo "nvcc compilation: OK (binary created, no GPU to run)"

echo ""
echo "=== llama.cpp: download & compile (A100 80G x 6) ==="
source /etc/profile.d/devtoolset-11.sh
source /etc/profile.d/cuda-12.4.sh

git clone --depth=1 https://github.com/ggml-org/llama.cpp /tmp/llama.cpp
mkdir /tmp/llama.cpp/build
cd /tmp/llama.cpp/build

cmake .. \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_ARCHITECTURES=80 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=gcc \
  -DCMAKE_CXX_COMPILER=g++ \
  -DCMAKE_CUDA_COMPILER=$(which nvcc) \
  -DLLAMA_CUDA_F16=ON \
  -DLLAMA_NATIVE=OFF

echo ""
echo "=== Building llama.cpp (up to 20 min) ==="
NPROC=$(nproc 2>/dev/null || echo 2)
make -j$(( NPROC < 4 ? NPROC : 2 )) 2>&1 | tail -30

echo ""
echo "=== Build artifacts ==="
find . -maxdepth 1 -executable -type f 2>/dev/null | head -10
ls -lh bin/ 2>/dev/null || ls -lh ./llama-cli 2>/dev/null || ls -lh ./main 2>/dev/null || echo "no standalone binary found"

echo ""
echo "=== Installed RPMs ==="
echo "--- GCC ---"
rpm -qa | grep devtoolset-11 | sort
echo "--- CUDA ---"
rpm -qa | grep cuda-12-4 | sort

echo ""
echo "=== Symlinks ==="
ls -la /usr/local/bin/ | grep -E "gcc|g\+\+|c\+\+|gcov|nvcc"
