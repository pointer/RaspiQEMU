#!/bin/bash

# 1. Check GCC Version
echo "--- Checking Compiler Version ---"
GCC_VER=$(g++ -dumpfullversion)
echo "Found g++ version: $GCC_VER"

# Compare version (requires 10.1+)
if [[ $(echo -e "$GCC_VER\n10.1" | sort -V | head -n1) == "10.1" ]]; then
    echo "✅ Compiler version is sufficient (10.1+)."
else
    echo "❌ Compiler version is too old for std::atomic_ref. You need g++ 10.1 or higher."
fi

# 2. Try to compile a minimal std::atomic_ref snippet
echo -e "\n--- Testing std::atomic_ref Compilation ---"
cat <<EOF > test_atomic_ref.cpp
#include <atomic>
#include <iostream>

int main() {
    int plain_val = 42;
    std::atomic_ref<int> r(plain_val);
    r.store(100);
    if (plain_val == 100 && r.is_lock_free()) {
        std::cout << "SUCCESS: std::atomic_ref is working!" << std::endl;
        return 0;
    }
    return 1;
}
EOF

# Attempt compilation
g++ -std=c++20 test_atomic_ref.cpp -o test_atomic_ref -latomic 2>/dev/null

if [ $? -eq 0 ]; then
    ./test_atomic_ref
    rm test_atomic_ref test_atomic_ref.cpp
else
    echo "❌ Compilation failed. std::atomic_ref is not recognized or -std=c++20 is not supported."
    rm test_atomic_ref.cpp
fi