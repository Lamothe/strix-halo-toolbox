set -e

cd llama.cpp

if [ ! -d build ]; then
	cmake -B build -DGGML_VULKAN=ON
	cmake --build build --config Release -j
fi

build/bin/llama-server -m /mnt/data/Models/Qwen3-Coder-Next/Q8_0/Qwen3-Coder-Next-Q8_0-00001-of-00003.gguf -ngl 99 --ctx-size 65536
