{ pkgs ? import <nixpkgs> {}
, python ? pkgs.python3
}:
let
  inherit (pkgs) lib;
  sources = import ./nix/sources.nix;
  upstream = sources.poetry2nix;
in
rec {
  # Pin poetry until Nixpkgs has a better version
  poetry = pkgs.callPackage ./poetry {
    inherit makePoetryPackage python;
  };
  evalPEP508Markers = (pkgs.callPackage "${upstream}/pep508.nix" {}) python;
  importTOML = path: builtins.fromTOML (builtins.readFile path);
  makeLockfileOverlay = pkgs.callPackage ./lib/makeLockfileOverlay.nix {
    inherit evalPEP508Markers importTOML makePackageOverlay;
  };
  makePackageOverlay = pkgs.callPackage ./lib/makePackageOverlay.nix {
    inherit poetry;
  };
  makePoetryPackage =
    { path
    , files
    , pyprojectFile ? path + "/pyproject.toml"
    , poetrylockFile ? path + "/poetry.lock"
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

        # Make an overlay with missing packages that other packages forgot to declare
        missingOverlay = makeLockfileOverlay {
          lockfile = importTOML ./missing/poetry.lock;
          path = ./missing;
        };

        # Make an overlay containing packages from the lockfile
        lockfileOverlay = makeLockfileOverlay {
          inherit lockfile path;
        };

        # Fixup them (add binary dependencies, patch broken)
        fixupsOverlay = pkgs.callPackage ./fixups.nix {};

        # Make an overlay containing the package we are building
        packageOverlay = makePackageOverlay (
          builtins.removeAttrs args [ "additionalFixups" ] // {
            inherit pyproject;
            transitiveDependency = false;
          }
        );

        # Collect all overlays in a list
        overlays = [
          missingOverlay
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
        composed.${name} // { overlay = composed; };
}
