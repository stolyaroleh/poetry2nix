{ fetchurl
, lib
}:
# Given a parsed poetry.lock, return an overlay that contains its packages.
lockfile:
self: super:
let
  /*
  [
    {
      name = "pytest-pylint";
      version = "0.14.1";
      description = "pytest plugin to check source code with pylint";
      category = "dev" or "main";

      # optional
      dependencies = {
        "pytest" = "version_bounds" or {
          python = "python_version_bounds";
          version = "version_bounds";
        }
      }
    }
  ]
  */
  packages = lockfile.package;

  /*
  {
    "pytest-pylint" = [
      {
        file = "pytest-pylint-0.14.1.tar.gz";
        hash = "sha256:...";
      }
    ]
  }
  */
  hashes = lockfile.metadata.files;

  # The following functions try to find an entry in `hashes` for a given `pkgName`.
  getUniversalWheel = pkgName:
    lib.lists.findFirst
      (pkgSrc: lib.strings.hasSuffix "py2.py3-none-any.whl" pkgSrc.file)
      null
      hashes.${pkgName};
  getSourceTarball = pkgName:
    lib.lists.findFirst
      (pkgSrc: lib.strings.hasSuffix ".tar.gz" pkgSrc.file)
      null
      hashes.${pkgName};

  # The following functions take an entry returned above and try to fetch the source
  # by guessing the package URL. The derivation they return contains a `format`
  # attribute that we pass to `buildPythonPackage`.
  pythonHosted = "https://files.pythonhosted.org";
  fetchSourceTarball = pkgName: pkgSrc:
    let
      firstLetter = builtins.substring 0 1 pkgName;
      url = "${pythonHosted}/packages/source/${firstLetter}/${pkgName}/${pkgSrc.file}";
    in
      (
        fetchurl {
          inherit url;
          inherit (pkgSrc) hash;
        }
      ) // {
        format = "setuptools";
      };
  /* FIXME
  For some reason, not all wheel URL's are predictable.
  https://files.pythonhosted.org/packages/py2.py3/a/atomicwrites/atomicwrites-1.3.0-py2.py3-none-any.whl does not work while
  https://files.pythonhosted.org/packages/py2.py3/a/attrs/attrs-19.3.0-py2.py3-none-any.whl does.
  Looking up package metadata for atomicwrites (and other packages) in
  https://pypi.org/pypi/${package}/json
  shows that they have content-addressable URLs that look like this:
  https://files.pythonhosted.org/packages/52/90/6155aa926f43f2b2a22b01be7241be3bfd1ceaf7d0b3267213e8127d41f4/atomicwrites-1.3.0-py2.py3-none-any.whl
  That is a BLAKE2-256 hash, which we don't have in the lockfile.
  It is also not supported by Nix.
  */
  fetchWheel = pythonVersionTag: pkgName: pkgSrc:
    let
      firstLetter = builtins.substring 0 1 pkgName;
      url = "${pythonHosted}/packages/${pythonVersionTag}/${firstLetter}/${pkgName}/${pkgSrc.file}";
    in
      (
        fetchurl {
          inherit url;
          inherit (pkgSrc) hash;
        }
      ) // {
        format = "wheel";
      };
  fetchUniversalWheel = fetchWheel "py2.py3";

  choose = a: b: if a == null then b else a;
  anyOf = lib.foldr choose null;

  getSourceOrDie = pkgName:
    let
      src = anyOf [
        (lib.mapNullable (fetchSourceTarball pkgName) (getSourceTarball pkgName))
        (lib.mapNullable (fetchUniversalWheel pkgName) (getUniversalWheel pkgName))
      ];
    in
      assert
      lib.assertMsg
        (src != null)
        "Unsupported sources for ${pkgName}: ${
        lib.concatMapStringsSep ", " (pkgHash: pkgHash.file) hashes.${pkgName}
        }";
      src;

  makePackage = pkgMeta:
    let
      src = getSourceOrDie pkgMeta.name;
    in
      super.buildPythonPackage {
        pname = pkgMeta.name;
        version = pkgMeta.version;
        inherit src;
        inherit (src) format;

        # Lockfile does not contain dev-dependencies of other packages.
        # This means that we can't run their tests.
        doCheck = false;

        propagatedBuildInputs =
          let
            deps = builtins.attrNames (pkgMeta.dependencies or {});
          in
            builtins.map (dep: self.${dep}) deps;

        meta.description = pkgMeta.description;
      };
in
builtins.listToAttrs (
  builtins.map (
    pkgMeta: rec {
      name = pkgMeta.name;
      value = makePackage pkgMeta;
    }
  ) packages
)
