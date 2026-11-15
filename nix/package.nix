{
  lib,
  cudaPackages,
  python3,
  runCommand,
}:

cudaPackages.backendStdenv.mkDerivation (finalAttrs: {
  pname = "cuda-vector-add";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../src
      ../VERSION
    ];
  };

  __structuredAttrs = true;
  strictDeps = true;
  nativeBuildInputs = [ cudaPackages.cuda_nvcc ];
  buildInputs = [ cudaPackages.cuda_cudart ];
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    test "$(cat VERSION)" = "${finalAttrs.version}"
    nvcc -std=c++17 -O2 --cudart shared \
      -gencode arch=compute_75,code=sm_75 \
      -gencode arch=compute_75,code=compute_75 \
      -I${lib.getOutput "include" cudaPackages.cuda_cudart}/include \
      -L${lib.getLib cudaPackages.cuda_cudart}/lib \
      -Xlinker -rpath -Xlinker ${lib.getLib cudaPackages.cuda_cudart}/lib \
      '-DLAB_VERSION="${finalAttrs.version}"' \
      src/vector_add.cu -o cuda-vector-add
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 cuda-vector-add "$out/bin/cuda-vector-add"
    runHook postInstall
  '';

  # Test a separate consumer of the final, fixed-up output. No GPU is required.
  passthru.tests.installed =
    runCommand "cuda-vector-add-installed"
      {
        nativeBuildInputs = [ python3 ];
      }
      ''
        env -u LD_LIBRARY_PATH python3 ${../tests/check_installed.py} \
          ${finalAttrs.finalPackage}/bin/cuda-vector-add ${finalAttrs.version}
        touch "$out"
      '';

  meta = {
    description = "CUDA vector addition with explicit hardware-free and GPU checks";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "cuda-vector-add";
  };
})
