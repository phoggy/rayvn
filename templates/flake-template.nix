{
  description = "${projectName} - A rayvn-based project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rayvn.url = "github:phoggy/rayvn";
  };

  outputs = { self, nixpkgs, flake-utils, rayvn }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        rayvnPkg = rayvn.packages.${system}.default;

        # Runtime dependencies
        runtimeDeps = [
          pkgs.bash
          rayvnPkg
        ];

        ${projectName} = pkgs.stdenv.mkDerivation {
          pname = "${projectName}";
          version = "0.1.0";
          src = self;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Install bin/
            install -Dm755 bin/${projectName} "$out/bin/${projectName}"

            # Install lib/
            mkdir -p "$out/share/${projectName}/lib"
            cp lib/*.sh "$out/share/${projectName}/lib/"

            # Install rayvn.pkg with version metadata
            sed '/^projectVersion=/d; /^projectReleaseDate=/d; /^projectFlake=/d; /^projectBuildRev=/d; /^projectNixpkgsRev=/d' \
                rayvn.pkg > "$out/share/${projectName}/rayvn.pkg"
            cat >> "$out/share/${projectName}/rayvn.pkg" <<EOF

# Version metadata (added by Nix build)
projectVersion='$version'
projectReleaseDate='$(date "+%Y-%m-%d %H:%M:%S %Z")'
projectFlake='github:phoggy/${projectName}/v$version'
projectBuildRev='${self.shortRev or "dev"}'
projectNixpkgsRev='${nixpkgs.shortRev}'
EOF

            # Wrap ${projectName} with runtime dependencies on PATH.
            wrapProgram "$out/bin/${projectName}" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath runtimeDeps}"

            runHook postInstall
          '';

          # Restore shebangs to use env bash
          postFixup = ''
            for f in "$out/bin/.${projectName}-wrapped" "$out/share/${projectName}/lib/"*.sh; do
              if [ -f "$f" ]; then
                sed -i "1s|^#\\!.*/bin/bash.*|#!/usr/bin/env bash|" "$f"
              fi
            done
          '';

          meta = with pkgs.lib; {
            description = "${projectName} - A rayvn-based project";
            homepage = "https://github.com/phoggy/${projectName}";
            license = licenses.gpl3Only;
            platforms = platforms.unix;
          };
        };
      in
      {
        packages = {
          default = ${projectName};
          ${projectName} = ${projectName};
        };

        apps = {
          default = {
            type = "app";
            program = "${${projectName}}/bin/${projectName}";
          };
          ${projectName} = {
            type = "app";
            program = "${${projectName}}/bin/${projectName}";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = runtimeDeps ++ [
            pkgs.shellcheck
          ];
          shellHook = ''
            export PATH="${self}/bin:$PATH"
            echo "${projectName} dev shell ready"
          '';
        };
      }
    );
}
