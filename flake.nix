{
  description = "Selector UI simulator in D, drawn with the CUI C library";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # CUI is a CMake project without a flake.
    cui = {
      url = "github:gizmomogwai/CUI/borderless-window";
      flake = false;
    };

    # Provides fuzzed.model and fuzzed.algorithm; only those two modules are compiled.
    fuzzed = {
      url = "github:gizmomogwai/fuzzed";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, cui, fuzzed }:
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
        # The selector executable; compiled with ldc2 directly so no dub package fetching is needed.
        cui-selector = pkgs.stdenv.mkDerivation {
          pname = "cui-selector";
          version = "git";
          src = self;
          nativeBuildInputs = [ pkgs.ldc ];
          buildInputs = runtimePackages pkgs;
          dontConfigure = true;
          buildPhase = ''
            runHook preBuild
            ldc2 -O -of=cui-selector \
              -P-I${cui}/include -L-L${cui}/lib -L-lcui \
              -Isource -I${fuzzed}/source \
              source/app.d source/cui_c.c source/cui_util.d \
              source/selector/model.d source/selector/window.d \
              ${fuzzed}/source/fuzzed/model.d ${fuzzed}/source/fuzzed/algorithm.d \
              ${if pkgs.stdenv.hostPlatform.isDarwin
                then "-L-framework -LCocoa -L-framework -LQuartzCore -L-framework -LOpenGL"
                else "-L-lX11 -L-ldl -L-lm -L-lpthread"}
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            install -D cui-selector $out/bin/cui-selector
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
