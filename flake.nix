{
  description = "Selector UI simulator in D, drawn with the CUI C library";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # CUI is a CMake project without a flake.
    cui = {
      url = "github:yappologistic/CUI";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, cui }:
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
        # Static libcui.a, headers under include/cui, and cui.pc.
        cui = pkgs.stdenv.mkDerivation {
          pname = "cui";
          version = "git";
          src = self.inputs.cui;
          nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
          buildInputs = runtimePackages pkgs;
          cmakeFlags = [
            "-DCUI_BUILD_EXAMPLES=OFF"
            "-DCUI_BUILD_TESTS=OFF"
          ];
          # The generated cui.pc joins absolute paths wrongly; dub links via CUI_PREFIX instead.
          postInstall = "rm -r $out/lib/pkgconfig";
        };
        default = cui;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.ldc pkgs.dub pkgs.cmake self.packages.${pkgs.stdenv.hostPlatform.system}.cui ]
            ++ runtimePackages pkgs;
          shellHook = ''
            export CUI_PREFIX="${self.packages.${pkgs.stdenv.hostPlatform.system}.cui}"
          '' + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath (runtimePackages pkgs)}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          '';
        };
      });
    };
}
