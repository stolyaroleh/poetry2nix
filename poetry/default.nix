{ stdenv
, lib
, python

, autoPatchelfHook
, gcc9

, installShellFiles

, precompileBytecode ? true
}:
let
  release-tarball = builtins.fetchTarball {
    url = "https://github.com/sdispater/poetry/releases/download/1.0.0b6/poetry-1.0.0b6-linux.tar.gz";
    sha256 = "0sliplbgvinb3qdnjd9gsarj3mk8z7dmsv85x53c53hhhmvwh06y";
  };
in
stdenv.mkDerivation {
  pname = "poetry";
  version = "1.0.0b6";

  phases = [
    "installPhase"
    "fixupPhase"
  ];

  buildInputs = [
    python

    autoPatchelfHook
    gcc9.cc.lib

    installShellFiles
  ];

  installPhase = ''
    mkdir -p $out/bin $out/lib
    cp -r ${release-tarball} $out/lib/poetry
    cp ${./poetry} $out/bin/poetry

    $out/bin/poetry completions bash > poetry.bash
    $out/bin/poetry completions fish > poetry.fish
    $out/bin/poetry completions zsh > poetry.zsh
    installShellCompletion poetry.{bash,fish,zsh}
  ''
  + lib.optionalString precompileBytecode ''
    chmod -R +w $out
    (
      cd $out/bin
      python -m compileall .
    )
    (
      cd $out/lib/poetry
      ls | grep -v _vendor | xargs -n1 python -m compileall
    )
    (
      cd $out/lib/poetry/_vendor
      version=$(python -c 'import sys; print("py{}.{}".format(sys.version_info.major, sys.version_info.minor))')
      python -m compileall "$version"
    )
  '';
}
