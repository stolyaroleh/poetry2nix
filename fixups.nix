{ pkgs }:
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
  addPropagatedBuildInputs = deps: drv: drv.overrideAttrs (
    old: {
      propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ deps;
    }
  );
  addSetupTools = addBuildInputs [
    (self.setuptools_scm or super.python.pkgs.setuptools_scm)
  ];
in
{
  inherit addBuildInputs addNativeBuildInputs addPropagatedBuildInputs addSetupTools;

  astroid = addBuildInputs [ self.pytest-runner ] super.astroid;
  black = addSetupTools super.black;
  flake8-print = addBuildInputs [ self.pytest-runner ] super.flake8-print;
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
  setuptools = super.setuptools or super.python.pkgs.setuptools;
  tenacity = addSetupTools super.tenacity;
  zipp = addSetupTools super.zipp;
}
