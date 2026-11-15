#include <cuda_runtime.h>

#include <cmath>
#include <iostream>
#include <string>
#include <vector>

#ifndef LAB_VERSION
#error "LAB_VERSION must be supplied by the package build"
#endif

namespace {
constexpr int count = 4099;  // Deliberately not a multiple of the block size.
constexpr int skip = 77;

__global__ void add(const float* a, const float* b, float* result, int n) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) result[i] = a[i] + b[i];
}

bool check(cudaError_t status, const char* operation) {
    if (status == cudaSuccess) return true;
    std::cerr << operation << ": " << cudaGetErrorString(status)
              << " (CUDA error " << static_cast<int>(status) << ")\n";
    return false;
}

// Release partially allocated buffers on every error path.
struct DeviceBuffers {
    float* a = nullptr;
    float* b = nullptr;
    float* result = nullptr;
    ~DeviceBuffers() {
        if (result) cudaFree(result);
        if (b) cudaFree(b);
        if (a) cudaFree(a);
    }
};

int gpu_test() {
    int devices = 0;
    const auto status = cudaGetDeviceCount(&devices);
    if (status == cudaErrorNoDevice || (status == cudaSuccess && devices == 0)) {
        std::cerr << "SKIP: no CUDA device is visible\n";
        return skip;
    }
    if (!check(status, "cudaGetDeviceCount")) {
        std::cerr << "Check the host NVIDIA driver and device access. "
                     "Driver errors are failures, not skipped tests.\n";
        return 1;
    }
    if (!check(cudaSetDevice(0), "cudaSetDevice")) return 1;

    std::vector<float> a(count), b(count), result(count);
    for (int i = 0; i < count; ++i) {
        a[i] = static_cast<float>(i) * 0.25f;
        b[i] = static_cast<float>(count - i) * 0.5f;
    }
    constexpr auto bytes = count * sizeof(float);
    DeviceBuffers device;
    if (!check(cudaMalloc(reinterpret_cast<void**>(&device.a), bytes), "cudaMalloc(a)") ||
        !check(cudaMalloc(reinterpret_cast<void**>(&device.b), bytes), "cudaMalloc(b)") ||
        !check(cudaMalloc(reinterpret_cast<void**>(&device.result), bytes), "cudaMalloc(result)") ||
        !check(cudaMemcpy(device.a, a.data(), bytes, cudaMemcpyHostToDevice), "copy a") ||
        !check(cudaMemcpy(device.b, b.data(), bytes, cudaMemcpyHostToDevice), "copy b")) return 1;

    add<<<(count + 255) / 256, 256>>>(device.a, device.b, device.result, count);
    if (!check(cudaGetLastError(), "launch vector-add kernel") ||
        !check(cudaDeviceSynchronize(), "execute vector-add kernel") ||
        !check(cudaMemcpy(result.data(), device.result, bytes, cudaMemcpyDeviceToHost),
               "copy result")) return 1;

    for (int i = 0; i < count; ++i) {
        const float expected = a[i] + b[i];
        if (!std::isfinite(result[i]) || std::fabs(result[i] - expected) > 1e-5f) {
            std::cerr << "FAIL: element " << i << ": expected " << expected
                      << ", got " << result[i] << '\n';
            return 1;
        }
    }
    std::cout << "PASS: " << count << " GPU results match the CPU reference\n";
    return 0;
}
}  // namespace

int main(int argc, char** argv) {
    if (argc == 2) {
        const std::string option(argv[1]);
        if (option == "--version") {
            std::cout << "cuda-vector-add " << LAB_VERSION << '\n';
            return 0;
        }
        if (option == "--help") {
            std::cout << "Usage: cuda-vector-add [--version | --help | --gpu-test]\n"
                         "--gpu-test validates vector addition on device 0.\n"
                         "Exit codes: 0 success, 1 CUDA/correctness failure, "
                         "2 usage error, 77 no visible GPU.\n";
            return 0;
        }
        if (option == "--gpu-test") return gpu_test();
    }
    std::cerr << "Usage: cuda-vector-add [--version | --help | --gpu-test]\n";
    return 2;
}
