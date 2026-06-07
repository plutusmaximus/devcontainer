{ pkgs ? import <nixpkgs> {} }:

let
  clangTools = pkgs.llvmPackages_22.clang-tools.override {
    enableLibcxx = true;
  };
in
pkgs.mkShellNoCC {
  packages = with pkgs; [
    cmake
    ninja
    git
    python3
    llvmPackages_22.clang
    clangTools
  ];

  shellHook = ''
    export CC="$(xcrun --find clang)"
    export CXX="$(xcrun --find clang++)"
    export SDKROOT="$(xcrun --show-sdk-path)"
    export CLANG_TIDY_EXE="$(which clang-tidy)"
    unset NIX_CFLAGS_COMPILE
  '';
}