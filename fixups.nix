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
  addSetupTools = addBuildInputs [ self.setuptools-scm ];
  withoutFixups = pkgName: super.lockfilePkgs.${pkgName};
in
{
  inherit addBuildInputs addNativeBuildInputs addPropagatedBuildInputs addSetupTools withoutFixups;

  astroid = addBuildInputs [ self.pytest-runner ] super.astroid;
  black = addSetupTools super.black;
  cffi = addBuildInputs [ pkgs.libffi ] super.cffi;
  cryptography = addBuildInputs [ pkgs.openssl ] super.cryptography;
  flake8-print = addBuildInputs [ self.pytest-runner ] super.flake8-print;
  intreehooks = addPropagatedBuildInputs [ super.pytoml ] super.intreehooks;
  importlib-metadata = addSetupTools super.importlib-metadata;
  jsonschema = addSetupTools super.jsonschema;
  keyring = addSetupTools super.keyring;
  lazy-object-proxy = addSetupTools super.lazy-object-proxy;
  lockfile = addPropagatedBuildInputs [ self.pbr ] super.lockfile;
  maya = addSetupTools super.maya;
  mccabe = addBuildInputs [ self.pytest-runner ] super.mccabe;
  pbr = super.pbr or super.python.pkgs.pbr;
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
