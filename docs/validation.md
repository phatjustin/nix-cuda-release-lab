# Validation record

Validated on November 15, 2026, from an Apple Silicon Mac using an emulated
`linux/amd64` Docker container and Nix 2.35.6. No NVIDIA GPU was available.

## Passed

- Flake evaluation with the committed lock file and `--no-update-lock-file`.
  Nix fetched the pinned source and accepted its content hash.
- CUDA compilation, installation, ELF fixup, and the installed-output test via:

  ```sh
  nix --extra-experimental-features 'nix-command flakes' \
    --option sandbox false --option filter-syscalls false \
    flake check --print-build-logs --no-update-lock-file
  ```

  Result: `all checks passed!`; the installed test reported
  `PASS: installed version, help, and argument validation (no GPU required)`.
- `nix build --no-update-lock-file`, followed by the installed executable's
  `--version`: `cuda-vector-add 0.1.0`.
- `nix fmt -- --check flake.nix nix/package.nix`.
- GitHub Actions workflow syntax and shell checks using actionlint 1.7.12 from
  the pinned Nixpkgs input.
- Runtime closure inspection: 69,592,440 bytes (about 66.4 MiB), including
  CUDA runtime 12.8.90. The CUDA compiler is not in the runtime closure.

The compiler redistributable is NVCC 12.8.93; differing component patch versions
within the CUDA 12.8 package set are expected.

## Environment limitation

A default build initially failed before compilation:

```text
unable to load seccomp BPF program: Invalid argument
```

Disabling only the Nix sandbox did not resolve it. Disabling both the inner
sandbox and syscall filter allowed this emulated-container validation to run.
Those switches were used only for local verification and are absent from the
flake and CI workflow. The container remained the isolation boundary. A build
with normal Nix sandboxing still needs verification on native x86_64 Linux;
the GitHub workflow is configured to perform that check.

The disposable validation image was `nixos/nix:latest`, resolved to image digest
`sha256:b49cb33f3a7e5cf3933ad8774529de0e3807ec5cf54987aa7ccdfb49f2fc55ed`.
This image is a record of the local environment, not a project dependency.

## Not yet verified

- GPU execution, numerical correctness on hardware, and driver compatibility.
- Actual GitHub-hosted workflow execution; the repository has not been pushed.
- Bit-for-bit reproducibility across independent builders.
- Additional systems, CUDA versions, and GPU architectures.

The source contains a GPU correctness test, but its existence is not evidence
that a hardware run has passed. Record the GPU model, compute capability, host
OS, driver version, command, exit status, and output when that run occurs.
