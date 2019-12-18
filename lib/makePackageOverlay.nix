{ lib, poetry, yj }:
# Given a parsed pyproject.toml, return an overlay that contains
# a single package, defined there.
{ pyproject
, path
, src
, lockfilePackages
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
self: super: let
  buildSystemInputs = {
    "intreehooks:loader" = [ super.intreehooks ];
    "poetry.masonry.api" = [ poetry ];
  }.${patchedPyproject.build-system.build-backend or (throw "Missing build system")} or (throw "Unsupported build system");
  package = super.buildPythonApplication (
    {
      pname = name;
      inherit version src;
      format = "pyproject";

      nativeBuildInputs = (args.buildInputs or []) ++ buildSystemInputs;
      propagatedBuildInputs = (args.propagatedBuildInputs or []) ++ (
        let
          # Required dependencies in pyproject.toml look like this: psycopg2 = "*"
          # Optional: psycopg2 = {version = "*", optional = true}
          isOptional = meta:
            builtins.isAttrs meta && meta.optional or false;

          tryGetDep = name: meta:
            let
              lowerName = lib.toLower name;
            in
              if !(builtins.elem lowerName lockfilePackages)
              then null
              else self.${lowerName};

          skipNull = builtins.filter (x: x != null);
        in
          skipNull (lib.mapAttrsToList tryGetDep dependencies)
      );
      checkInputs = (args.checkInputs or []) ++ (
        builtins.map
          (dep: self.${lib.toLower dep})
          (builtins.attrNames dev-dependencies)
      );

      postPatch = ''
        cat << 'EOF' | ${yj}/bin/yj -jt > pyproject.toml
        ${builtins.toJSON patchedPyproject}
        EOF
      '';

      # prevent pipShellHook from running
      shellHook = args.shellHook or ":";

      meta.description = description;
    }
    // (
      builtins.removeAttrs args [
        "path"
        "pyproject"
        "nativeBuildInputs"
        "propagatedBuildInputs"
        "checkInputs"
      ]
    )
  );
in
  {
    "${lib.toLower name}" = package;
  }
