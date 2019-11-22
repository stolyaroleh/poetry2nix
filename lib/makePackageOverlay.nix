{ lib, poetry }:
# Given a parsed pyproject.toml, return an overlay that contains
# a single package, defined there.
{ pyproject
, src
, ...
}@args:
let
  inherit (pyproject.tool.poetry)
    name version
    dependencies dev-dependencies
    description license
    ;
in
self: super:
  {
    "${name}" = super.buildPythonApplication (
      {
        pname = name;
        inherit src version;
        format = "pyproject";

        nativeBuildInputs = [ poetry ];
        propagatedBuildInputs =
          builtins.map
            (dep: self.${lib.toLower dep})
            (builtins.attrNames dependencies);
        checkInputs =
          builtins.map
            (dep: self.${lib.toLower dep})
            (builtins.attrNames dev-dependencies);

        buildPhase = ''
          runHook preBuild
          export HOME=$(pwd)
          poetry build -f wheel -vv
          runHook postBuild
        '';

        # prevent pipShellHook from running
        shellHook = args.shellHook or ":";

        meta.description = description;
      }
      // (builtins.removeAttrs args [ "pyproject" ])
    );
  }
