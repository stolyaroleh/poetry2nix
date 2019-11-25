{ lib, poetry, yj }:
# Given a parsed pyproject.toml, return an overlay that contains
# a single package, defined there.
{ pyproject
, path
, files
, transitiveDependency ? true
, ...
}@args:
let
  inherit (pyproject.tool.poetry) name version description license;

  dependencies = pyproject.tool.poetry.dependencies or {};
  dev-dependencies =
    if transitiveDependency
    then {}
    else pyproject.tool.poetry.dev-dependencies or {};

  # Path dependencies (`{"path": "../foo"}`) will not be available when building
  # because Nix is building packages in a sandbox.
  # Instead, builder will get them in `propagatedBuildInputs`.
  # We patch `pyproject.toml` to make prevent `poetry build` from resolving them using paths.
  patchedPyproject =
    let
      patch =
        name: dep:
          if builtins.isAttrs dep && builtins.hasAttr "path" dep
          then
            (builtins.removeAttrs dep [ "path" ]) // { version = "*"; }
          else
            dep;
    in
      pyproject // {
        tool.poetry = pyproject.tool.poetry // {
          dependencies = builtins.mapAttrs patch dependencies;
          dev-dependencies = builtins.mapAttrs patch dev-dependencies;
        };
      };
in
self: super:
  {
    "${lib.toLower name}" = super.buildPythonPackage (
      {
        pname = name;
        inherit version;
        format = "pyproject";
        src = lib.sourceByRegex path files;

        nativeBuildInputs = (args.nativeBuildInputs or []) ++ [ poetry ];
        propagatedBuildInputs = (args.propagatedBuildInputs or []) ++ (
          builtins.map
            (dep: self.${lib.toLower dep})
            (builtins.attrNames dependencies)
        );
        checkInputs = (args.checkInputs or []) ++ (
          builtins.map
            (dep: self.${lib.toLower dep})
            (builtins.attrNames dev-dependencies)
        );

        buildPhase = ''
          runHook preBuild
          echo '${builtins.toJSON patchedPyproject}' | ${yj}/bin/yj -jt > pyproject.toml
          export HOME=$(pwd)
          poetry build -f wheel -vv
          runHook postBuild
        '';

        # prevent pipShellHook from running
        shellHook = args.shellHook or ":";

        meta.description = description;
      }
      // (
        builtins.removeAttrs args [
          "path"
          "files"
          "pyproject"
          "nativeBuildInputs"
          "propagatedBuildInputs"
          "checkInputs"
        ]
      )
    );
  }
