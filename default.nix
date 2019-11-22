{ pkgs ? import <nixpkgs> {}
, python ? pkgs.python3
}:
let
  inherit (pkgs) lib;
  importTOML = path: builtins.fromTOML (builtins.readFile path);
in
rec {
  # Pin poetry until Nixpkgs has a better version
  poetry = pkgs.callPackage ./poetry {
    inherit python;
  };
  makeLockfileOverlay = pkgs.callPackage ./lib/makeLockfileOverlay.nix {};
  makePackageOverlay = pkgs.callPackage ./lib/makePackageOverlay.nix {
    inherit poetry;
  };
  makePoetryPackage =
    { src
    , pyprojectFile ? src + "/pyproject.toml"
    , poetrylockFile ? src + "/poetry.lock"
    , additionalFixups ? null
    , ...
    }@args:
      let
        lockfile = importTOML poetrylockFile;
        pyproject = importTOML pyprojectFile;
        name = pyproject.tool.poetry.name;

        base = self: {
          inherit python;
          inherit (python.pkgs) buildPythonPackage buildPythonApplication;
        };
        # Make an overlay containing packages from the lockfile
        lockfileOverlay = makeLockfileOverlay lockfile;

        # Fixup them (add binary dependencies, patch broken)
        fixupsOverlay = pkgs.callPackage ./fixups.nix {
          inherit python;
        };

        # Make an overlay containing the package we are building
        packageOverlay = makePackageOverlay (
          builtins.removeAttrs
            args
            [ "pyprojectFile" "poetrylockFile" "additionalFixups" ]
          // { inherit pyproject; }
        );

        # Collect all overlays in a list
        overlays = [
          lockfileOverlay
          fixupsOverlay
        ]
        # Let users provide additional fixups
        ++ lib.optional (additionalFixups != null) additionalFixups
        ++ [
          packageOverlay
        ];

        # Compose overlays together
        composed = lib.fix (
          lib.foldl' (lib.flip lib.extends) base overlays
        );
      in
        composed.${name};
}
