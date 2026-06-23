#!/bin/bash
set -e
cd /work

echo "=== Running install_gcc11.sh ==="
bash install_gcc11.sh

echo ""
echo "=== Verify GCC version ==="
/opt/rh/devtoolset-11/root/usr/bin/gcc --version
/usr/local/bin/gcc --version

echo ""
echo "=== C11 test ==="
printf '#include <stdio.h>\nint main(void) { printf("C11: OK\\n"); return 0; }\n' > /tmp/c_test.c
/opt/rh/devtoolset-11/root/usr/bin/gcc -std=c11 -o /tmp/c_test /tmp/c_test.c
/tmp/c_test

echo ""
echo "=== C++11 test ==="
printf '#include <iostream>\nint main() { std::cout << "C++11: OK" << std::endl; return 0; }\n' > /tmp/cpp11.cpp
/opt/rh/devtoolset-11/root/usr/bin/g++ -std=c++11 -o /tmp/cpp11 /tmp/cpp11.cpp
/tmp/cpp11

echo ""
echo "=== C++17 test ==="
printf '#include <iostream>\n#include <string_view>\nint main() {\n    constexpr std::string_view msg = "C++17: OK";\n    std::cout << msg << std::endl;\n    return 0;\n}\n' > /tmp/cpp17.cpp
/opt/rh/devtoolset-11/root/usr/bin/g++ -std=c++17 -o /tmp/cpp17 /tmp/cpp17.cpp
/tmp/cpp17

echo ""
echo "=== C++20 test (concepts) ==="
printf '#include <iostream>\n#include <concepts>\ntemplate<typename T> requires std::integral<T>\nT add(T a, T b) { return a + b; }\nint main() {\n    std::cout << "C++20 concepts: " << add(3, 4) << std::endl;\n    return 0;\n}\n' > /tmp/cpp20.cpp
/opt/rh/devtoolset-11/root/usr/bin/g++ -std=c++20 -o /tmp/cpp20 /tmp/cpp20.cpp
/tmp/cpp20

echo ""
echo "=== C++20 test (span) ==="
printf '#include <iostream>\n#include <span>\n#include <vector>\nint main() {\n    std::vector<int> v = {1, 2, 3, 4, 5};\n    std::span<int> s(v);\n    int sum = 0;\n    for (auto x : s) sum += x;\n    std::cout << "C++20 span sum: " << sum << std::endl;\n    return 0;\n}\n' > /tmp/span.cpp
/opt/rh/devtoolset-11/root/usr/bin/g++ -std=c++20 -o /tmp/span /tmp/span.cpp
/tmp/span

echo ""
echo "=== Installed RPMs ==="
rpm -qa | grep devtoolset-11 | sort

echo ""
echo "=== Symlinks ==="
ls -la /usr/local/bin/ | grep -E "gcc|g++|c++|gcov"
