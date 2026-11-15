# Nix CUDA Release Lab

A small CUDA application packaged as a Nix derivation, with checks against the
installed executable and a separate GPU correctness test.

The first milestone focuses on packaging: explicit dependencies, pinned inputs,
a compatible host compiler, a runtime library search path, and tests that can run
without a GPU. This is a learning and portfolio project, not an NVIDIA product.

## Build and check

Requires **x86_64 Linux**, Nix with `nix-command` and `flakes` enabled, network
access for initial dependency downloads, and enough disk space for the CUDA
compiler closure. CUDA compilation does not require a GPU. macOS is not a
supported build or execution target; use an x86_64 Linux machine or a Linux VM
with x86_64 emulation.

```sh
nix build --no-update-lock-file
./result/bin/cuda-vector-add --version
nix flake check --print-build-logs --no-update-lock-file
nix fmt -- --check flake.nix nix/package.nix
```

`nix flake check` builds the application and then tests the final installed output
in a separate derivation. The tests exercise its version, help, invalid options,
and unexpected arguments without invoking a CUDA operation. They clear
`LD_LIBRARY_PATH` to avoid accidentally relying on a developer's environment.

The package uses CUDA 12.8 from the locked Nixpkgs revision. Nixpkgs handles
fetching and patching the CUDA redistributables; this repository packages its
own application, not a replacement CUDA toolkit. CUDA dependencies are unfree
and allowed explicitly in `flake.nix`. The MIT license covers this repository's
code, not NVIDIA's dependencies.

## Run the GPU correctness test

On an x86_64 Linux host with an NVIDIA GPU and a suitable installed driver:

```sh
nix run . -- --gpu-test
```

The application adds 4,099 pairs of values on device 0 and checks every result
against a CPU reference. The non-multiple block size also exercises the kernel's
bounds check. Non-finite or incorrect results fail the test.

| Exit status | Meaning |
| --- | --- |
| `0` | All results match |
| `1` | Driver, allocation, kernel, transfer, or numerical failure |
| `2` | Invalid command line |
| `77` | No visible CUDA device; explicitly skipped, not passed |

A missing or incompatible driver can return status `1` rather than `77`. A GPU
validation job must treat `77` as an unmet hardware requirement, never as success.
There is no GPU job in the initial public CI workflow.

The package emits native code for compute capability 7.5 and PTX for compatible
newer GPUs. Older GPUs are outside this initial scope. The host driver must
support the selected CUDA runtime and the GPU; PTX JIT may require a newer
driver than the minimum for CUDA minor-version compatibility. Consult
[NVIDIA's compatibility documentation](https://docs.nvidia.com/deploy/cuda-compatibility/).
No driver/GPU combination has been validated yet.

On NixOS, configure the NVIDIA driver on the host. On other Linux distributions,
the driver library search path may require a tool such as
[nixGL](https://github.com/nix-community/nixGL). This flake does not install a
kernel driver or configure GPU access in containers.

## Packaging decisions

- **Reusable derivation:** `nix/package.nix` accepts dependencies through
  `callPackage`. The flake selects the package set and exposes build, run, and
  check entry points.
- **Compiler compatibility:** `cudaPackages.backendStdenv` selects the host
  compiler supported by this CUDA package set, instead of whichever GCC happens
  to be installed on the machine.
- **Small dependency selection:** `cuda_nvcc` is a build tool;
  `cuda_cudart` supplies runtime headers and libraries. The build uses neither a
  global `/usr/local/cuda` installation nor a full toolkit bundle.
- **Explicit runtime linking:** the executable links shared cudart with a Nix
  store RPATH. Installation tests run after Nix fixup, so a missing runtime
  library should fail even when the build itself succeeds.
- **Host-owned driver:** the CUDA scope disables `cuda_compat`. Driver updates and
  device access belong to the host; this example does not silently add a
  forward-compatibility driver library.
- **Pinned inputs:** `flake.lock` identifies the Nixpkgs source and content hash.
  Pinning inputs is not a claim of independently verified bit-for-bit output
  reproducibility.
- **Hardware boundary:** metadata checks belong in sandboxed builds. Actual
  CUDA execution is an explicit operation outside the build sandbox.

See the [Nixpkgs CUDA guide](https://github.com/NixOS/nixpkgs/blob/d33369954a67ae3322177dc9a3d564092912120c/doc/languages-frameworks/cuda.section.md)
for the conventions used here.

## Repository map

```text
flake.nix                  Package-set configuration and public outputs
flake.lock                 Pinned Nixpkgs input
nix/package.nix            Build, installation, and installed-output test
src/vector_add.cu          Small application with explicit diagnostics
VERSION                    Application version, checked against the derivation
tests/check_installed.py   Hardware-free executable checks
.github/workflows/ci.yml   Linux build and installed-output checks
docs/validation.md         What has actually been verified
docs/roadmap.md            Deliberately deferred release automation
```

## Validation and next milestone

See [validation notes](docs/validation.md) for the current evidence and limitations.
The [roadmap](docs/roadmap.md) describes release discovery and update automation;
those features are not implemented in this first milestone.

To update the dependency pin intentionally, run `nix flake update nixpkgs`, inspect
the lock diff, and rerun all checks. CUDA APIs and package names can change across
Nixpkgs revisions. To change this application's version, update both `VERSION`
and the derivation; the build rejects disagreement.
