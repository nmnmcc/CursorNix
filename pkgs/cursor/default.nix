{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  buildVscode,
  sources,
}:
let
  inherit (stdenv) hostPlatform;

  pname = "cursor";
  version = sources.cursor.version;
  vscodeVersion = sources.cursor.vscodeVersion or "1.121.0";
  systemSource =
    sources.cursor.deb.${hostPlatform.system}
      or (throw "Cursor deb package is not available for ${hostPlatform.system}");

  fetched = fetchurl {
    inherit (systemSource) url hash;
  };
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

  src = fetched;

  sourceRoot = "usr/share/cursor";

  extraNativeBuildInputs = [
    dpkg
  ];

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
}).overrideAttrs
  (oldAttrs: {
    passthru = (oldAttrs.passthru or { }) // {
      cursorVersion = version;
      cursorVscodeVersion = vscodeVersion;
      cursorCommitSha = sources.cursor.commitSha or null;
    };

    unpackPhase = ''
      runHook preUnpack
      ${dpkg}/bin/dpkg-deb --fsys-tarfile "$src" | tar --no-same-owner --no-same-permissions -xf -
      runHook postUnpack
    '';

    autoPatchelfIgnoreMissingDeps =
      (oldAttrs.autoPatchelfIgnoreMissingDeps or [ ])
      ++ lib.optionals (!hostPlatform.isMusl) [
        "libc.musl-*.so.*"
      ];

    preFixup = (oldAttrs.preFixup or "") + ''
      # Match upstream .deb desktop entries for workspace files and cursor:// URLs.
      ensureDesktopMime() {
        local desktop="$1"
        local mime="$2"

        if grep -q '^MimeType=' "$desktop"; then
          if ! grep '^MimeType=' "$desktop" | grep -Fq "$mime"; then
            sed -i "/^MimeType=/ s|;*$|;$mime;|" "$desktop"
          fi
        elif grep -q '^Keywords=' "$desktop"; then
          sed -i "/^Keywords=/a MimeType=$mime;" "$desktop"
        else
          sed -i "/^\[Desktop Entry\]/a MimeType=$mime;" "$desktop"
        fi
      }

      ensureDesktopMime "$out/share/applications/cursor.desktop" \
        "application/x-cursor-workspace"

      if grep -q '^MimeType=' "$out/share/applications/cursor-url-handler.desktop"; then
        sed -i 's|^MimeType=.*|MimeType=x-scheme-handler/cursor;|' \
          "$out/share/applications/cursor-url-handler.desktop"
      else
        sed -i '/^Keywords=/a MimeType=x-scheme-handler/cursor;' \
          "$out/share/applications/cursor-url-handler.desktop"
      fi
    '';

    postInstall = (oldAttrs.postInstall or "") + ''
      install -Dm644 ${./mime/cursor-workspace.xml} \
        $out/share/mime/packages/cursor-workspace.xml
    '';
  })
