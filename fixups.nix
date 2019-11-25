{ pkgs, python }:
self: super:
let
  addBuildInputs = deps: drv: drv.overrideAttrs (
    old: {
      buildInputs = (old.buildInputs or []) ++ deps;
    }
  );
  addNativeBuildInputs = deps: drv: drv.overrideAttrs (
    old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ deps;
    }
  );
  addSetupTools = addBuildInputs [
    (self.setuptools_scm or python.pkgs.setuptools_scm)
  ];
in
{
  astroid = addBuildInputs [ self.pytest-runner ] super.astroid;
  importlib-metadata = addSetupTools super.importlib-metadata;
  lazy-object-proxy = addSetupTools super.lazy-object-proxy;
  maya = addSetupTools super.maya;
  mccabe = addBuildInputs [ self.pytest-runner ] super.mccabe;
  pluggy = addSetupTools super.pluggy;
  py = addSetupTools super.py;
  pylint = addBuildInputs [ self.pytest-runner ] super.pylint;
  pytest = addSetupTools super.pytest;
  pytest-pylint = addBuildInputs [ self.pytest-runner ] super.pytest-pylint;
  pytest-runner = addSetupTools super.pytest-runner;
  python-dateutil = addSetupTools super.python-dateutil;
  zipp = addSetupTools super.zipp;
}
