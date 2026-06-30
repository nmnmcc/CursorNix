{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  buildVscode,
  sources,
}:
let
  inherit (stdenv) hostPlatform;

  pname = "cursor";
  version = sources.cursor.version;
  vscodeVersion = sources.cursor.vscodeVersion or "1.121.0";
  systemSource =
    sources.cursor.appimage.${hostPlatform.system}
      or (throw "Cursor AppImage is not available for ${hostPlatform.system}");

  fetched = fetchurl {
    inherit (systemSource) url hash;
  };

  appimageContents = appimageTools.extract {
    inherit pname version;
    src = fetched;
  };

  extractDir = "${pname}-${version}-extracted";
in
(buildVscode rec {
  inherit pname version vscodeVersion;

  commandLineArgs = "";
  updateScript = null;

  executableName = "cursor";
  longName = "Cursor";
  shortName = "cursor";
  libraryName = "cursor";
  iconName = "cursor";

  src = appimageContents;

  sourceRoot = "${extractDir}/usr/share/cursor";

  tests = { };

  dontFixup = false;
  patchVSCodePath = false;

  meta = {
    description = "AI-powered code editor built on VS Code";
    homepage = "https://cursor.com";
    changelog = "https://cursor.com/changelog";
    license = lib.licenses.unfree;
    mainProgram = "cursor";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}).overrideAttrs (oldAttrs: {
  passthru =
    (oldAttrs.passthru or { })
    // {
      cursorVersion = version;
      cursorVscodeVersion = vscodeVersion;
      cursorCommitSha = sources.cursor.commitSha or null;
    };

  autoPatchelfIgnoreMissingDeps =
    (oldAttrs.autoPatchelfIgnoreMissingDeps or [ ])
    ++ lib.optionals (!hostPlatform.isMusl) [
      "libc.musl-*.so.*"
    ];

  preFixup =
    (oldAttrs.preFixup or "")
    + ''
      # Match upstream .deb desktop entries for workspace files and cursor:// URLs.
      if ! grep -q '^MimeType=application/x-cursor-workspace;' "$out/share/applications/cursor.desktop"; then
        sed -i '/^Keywords=/a MimeType=application/x-cursor-workspace;' \
          "$out/share/applications/cursor.desktop"
      fi

      sed -i 's/^MimeType=.*/MimeType=x-scheme-handler\/cursor;/' \
        "$out/share/applications/cursor-url-handler.desktop"
    '';

  postInstall =
    (oldAttrs.postInstall or "")
    + ''
      install -Dm644 ${./mime/cursor-workspace.xml} \
        $out/share/mime/packages/cursor-workspace.xml
      rm -f $out/lib/cursor/resources/appimageupdatetool.AppImage
    '';
})
