{ buildNpmPackage, nodejs_22 }:
buildNpmPackage {
  pname = "keyfarm-pw";
  version = "0.1.0";
  src = ../pw;
  nodejs = nodejs_22;
  npmDepsHash = "sha256-MwYL4KTLYHQLIERyu3W/fI0h493ZKtUvYPH+ibAJLV4=";
  dontNpmBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib
    cp -r . $out/lib/
    runHook postInstall
  '';
}
