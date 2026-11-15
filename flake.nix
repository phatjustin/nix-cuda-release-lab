{
  description = "A small, testable CUDA package built with Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        # CUDA redistributables are unfree. This does not grant redistribution rights.
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "cuda_nvcc"
            "cuda_cudart"
            "cuda_cccl"
            "cuda_nvrtc"
          ];
      };
      # Require the host's driver rather than injecting a forward-compat driver.
      cudaPackages = pkgs.cudaPackages_12_8.overrideScope (
        _final: _prev: {
          cuda_compat = null;
        }
      );
      package = pkgs.callPackage ./nix/package.nix { inherit cudaPackages; };
    in
    {
      packages.${system} = {
        default = package;
        cuda-vector-add = package;
      };
      apps.${system}.default = {
        type = "app";
        meta = package.meta;
        program = "${package}/bin/cuda-vector-add";
      };
      checks.${system}.installed = package.passthru.tests.installed;
      formatter.${system} = pkgs.nixfmt;
    };
}
