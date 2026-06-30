{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
  sources,
}:
let
  inherit (stdenv) hostPlatform;
  pname = "cursor-agent";
  version = sources.agent.version;
  releaseSet = sources.agent.version;
  systemSource =
    sources.agent.tarball.${hostPlatform.system}
      or (throw "Cursor Agent is not available for ${hostPlatform.system}");
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    inherit (systemSource) url hash;
  };

  buildInputs = lib.optionals hostPlatform.isLinux [
    zlib
  ];

  nativeBuildInputs = lib.optionals hostPlatform.isLinux [
    autoPatchelfHook
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    runHook preUnpack
    mkdir source
    tar -xzf "$src" -C source --strip-components=1
    sourceRoot=source
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/cursor-agent
    cp -r . $out/share/cursor-agent/
    ln -s $out/share/cursor-agent/cursor-agent $out/bin/cursor-agent
    ln -s $out/share/cursor-agent/cursor-agent $out/bin/agent

    runHook postInstall
  '';

  passthru = {
    cursorAgentComponent = "agent";
    cursorAgentVersion = version;
    cursorAgentReleaseSet = releaseSet;
  };

  meta = {
    description = "Cursor Agent CLI";
    homepage = "https://cursor.com/cli";
    license = lib.licenses.unfree;
    mainProgram = "agent";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
