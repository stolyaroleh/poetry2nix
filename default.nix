{ pkgs ? import <nixpkgs> {}
, python ? pkgs.python3
}:
let
  inherit (pkgs) lib;
  sources = import ./nix/sources.nix;
  upstream = sources.poetry2nix;
  evalPEP508Markers = (pkgs.callPackage "${upstream}/pep508.nix" {}) python;
  isPEP508Excluded = pkgMeta:
    if builtins.hasAttr "marker" pkgMeta
    then !(evalPEP508Markers pkgMeta.marker)
    else false;
  isNeeded = x: !isPEP508Excluded x;
in
rec {
  # Pin poetry until Nixpkgs has a better version
  poetry = pkgs.callPackage ./poetry {
    inherit makePoetryPackage python;
  };
  importTOML = path: builtins.fromTOML (builtins.readFile path);
  makeLockfileOverlay = pkgs.callPackage ./lib/makeLockfileOverlay.nix {
    inherit isPEP508Excluded importTOML makePackageOverlay;
  };
  makePackageOverlay = pkgs.callPackage ./lib/makePackageOverlay.nix {
    inherit poetry;
  };
  makePoetryPackage =
    { path
    , src ? path
    , pyprojectFile ? path + "/pyproject.toml"
    , poetrylockFile ? path + "/poetry.lock"
    , additionalFixups ? null
    , ...
    }@args:
      let
        lockfile = importTOML poetrylockFile;
        pyproject = importTOML pyprojectFile;
        name = pyproject.tool.poetry.name;

        packages = builtins.filter isNeeded lockfile.package;
        packageNames = builtins.map (pkgMeta: pkgMeta.name) packages;
        pep508Excluded = builtins.map (pkgMeta: pkgMeta.name) (
          builtins.filter isPEP508Excluded lockfile.package
        );
        hashes = lockfile.metadata.files;

        base = self: {
          inherit python;
          inherit (python.pkgs) buildPythonPackage buildPythonApplication;
        };

        # Make an overlay with missing packages that other packages forgot to declare
        missingOverlay =
          let
            lockfile = importTOML ./missing/poetry.lock;
            packages = builtins.filter isNeeded lockfile.package;
            pep508Excluded = builtins.filter isPEP508Excluded lockfile.package;
            hashes = lockfile.metadata.files;
          in
            makeLockfileOverlay {
              inherit packages hashes;
              lockfilePackages = packageNames;
              path = ./missing;
            };

        # Make an overlay containing packages from the lockfile
        lockfileOverlay = makeLockfileOverlay {
          inherit packages hashes path;
          lockfilePackages = packageNames;
        };

        # Fixup them (add binary dependencies, patch broken)
        fixupsOverlay = pkgs.callPackage ./fixups.nix {};

        # Make an overlay containing the package we are building
        packageOverlay = makePackageOverlay (
          builtins.removeAttrs args [ "additionalFixups" ] // {
            inherit pyproject src;
            lockfilePackages = packageNames;
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
