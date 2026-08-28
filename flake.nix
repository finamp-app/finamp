{
  description = "Flutter 3.27+";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      fenix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            android_sdk.accept_license = true;
            allowUnfree = true;
          };
          overlays = [ fenix.overlays.default ];
        };
        lib = pkgs.lib;
        buildToolsVersion = "35.0.0";
        androidComposition = pkgs.androidenv.composeAndroidPackages {
          cmdLineToolsVersion = "8.0";
          toolsVersion = "26.1.1";
          buildToolsVersions = [
            buildToolsVersion
            "35.0.0"
            "34.0.0"
            "33.0.2"
            "30.0.3"
          ];
          platformVersions = [
            "36"
            "35"
            "34"
            "33"
            "32"
          ];
          abiVersions = [
            "armeabi-v7a"
            "arm64-v8a"
          ];
          includeNDK = true;
          ndkVersions = [ "27.0.12077973" ];
          cmakeVersions = [ "3.22.1" ];
        };
        androidSdk = androidComposition.androidsdk;
        rustupStub = let
          flavorName = "stable";

          # support all defaultSystems
          # https://doc.rust-lang.org/stable/rustc/platform-support.html#tier-1-with-host-tools
          arch = builtins.elemAt (builtins.split "-" system) 0;
          os = builtins.elemAt (builtins.split "-" system) 2;
          vendor = if os == "linux" then "unknown" else "apple"; # defaultSystems is linux and darwin only
          abi = lib.optionalString (os == "linux") "-gnu";

          targetName = "${arch}-${vendor}-${os}${abi}"; # string like x86_64-unknown-linux-gnu
          toolchainName = "${flavorName}-${targetName}"; # string like stable-x86_64-unknown-linux-gnu
        in pkgs.writeShellApplication {
          name = "rustup";

          # github:KRTirtho/frb_plugins flutter_discord_rpc package requires rustup instead of specific toolchain
          # let's teach it to use whatever toolchain is available in environment (in this case - fenix-built)
          #
          # It is identified it requires "stable" flavor. This script stubs toolchain query and installation and
          # directs all actions to Rust built with fenix below
          # Pros: version locking, source provenance Cons: possible compatibility issues (use default env instead then)
          text = ''
            if [[ "$1" == "toolchain" && "$2" == "list" ]]; then
              echo "${toolchainName} (active, default)"
              exit 0
            elif [[ "$1" == "run" && "$2" == "stable" ]]; then
              shift 2
              exec "$@"
            elif [[ "$1" == "target" && "$2" == "list" ]]; then
              # This handles rustup "target" "list" "--toolchain" "stable-x86_64-unknown-linux-gnu" "--installed"
              # if cross-compiling (e.g. for android), add all four targets here (idk separator though) and to fenix
              # Currently looks like discord rpc is not enabled on mobile
              echo "${targetName}"
            else
              echo "Can't run $*"
              exit 2
            fi
          '';
        };
      in {
        devShells = let
          mkFinampShell = { withFenix ? false }: with pkgs; mkShell rec {
            ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
            ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
            GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/${buildToolsVersion}/aapt2";
            FLUTTER_ROOT = "${flutter}";
            LD_LIBRARY_PATH = "${lib.makeLibraryPath [ pkgs.mpv-unwrapped ]}";
            shellHook = ''
              export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$PWD/build/linux/x64/debug/bundle/lib:$PWD/build/linux/x64/release/bundle/lib"
            '';
            buildInputs = [
              flutter
              androidSdk
              jdk17
              androidComposition.platform-tools
              cmake
              dbus
            ] ++ (if withFenix then [
              rustupStub
              (with pkgs.fenix; combine [
                stable.cargo
                stable.rustc
                # rust-src in case of any issues
              ])
            ] else [
              rustup
            ]);
          };
        in {
          default = mkFinampShell {}; # nix develop
          fenix = mkFinampShell { withFenix = true; }; # nix develop .#fenix
        };
      }
    );
}
