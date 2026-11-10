{
  description = "Selector UI simulator in D, drawn with the CUI C library";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # CUI lives in the vendor/cui submodule; dub builds it with cmake (see dub.sdl).
    self.submodules = true;

    # Provides fuzzed.model and fuzzed.algorithm; only those two modules are compiled.
    fuzzed = {
      url = "github:gizmomogwai/fuzzed";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, fuzzed }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = function:
        nixpkgs.lib.genAttrs systems (system: function nixpkgs.legacyPackages.${system});
      # CUI's X11 backend loads X11 and OpenGL itself at runtime.
      runtimePackages = pkgs:
        pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          pkgs.libx11 pkgs.libglvnd pkgs.mesa
        ];
    in {
      packages = forAllSystems (pkgs: rec {
        # The selector executable, built by dub; dub-lock.json is generated with `nix run nixpkgs#dub-to-nix`.
        cui-selector = pkgs.buildDubPackage {
          pname = "cui-selector";
          version = self.shortRev or "dirty";
          src = self;
          dubLock = ./dub-lock.json;
          dubBuildFlags = [ "--config=application" ];
          nativeBuildInputs = [ pkgs.cmake ];
          buildInputs = runtimePackages pkgs;
          # cmake is only called from dub's preBuildCommands; the source root is no CMake project.
          dontUseCmakeConfigure = true;
          # fuzzed is a local path dependency for development; point it at the flake input.
          postPatch = ''
            cp -r ${fuzzed} fuzzed-src
            chmod -R u+w fuzzed-src
            substituteInPlace dub.sdl dub.selections.json \
              --replace-fail "../14-fuzzed" "$PWD/fuzzed-src"
          '';
          installPhase = ''
            runHook preInstall
            install -Dm755 out/main/cui-selector/cui-selector -t $out/bin
            runHook postInstall
          '';
          meta.mainProgram = "cui-selector";
        };
        default = cui-selector;
      });

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.cui-selector}/bin/cui-selector";
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.ldc pkgs.dub pkgs.cmake ]
            ++ runtimePackages pkgs;
          shellHook = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath (runtimePackages pkgs)}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          '';
        };
      });
    };
}
