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
      if grep -q '^MimeType=' "$out/share/applications/cursor.desktop"; then
        sed -i 's|^MimeType=.*|MimeType=application/x-cursor-workspace;|' \
          "$out/share/applications/cursor.desktop"
      else
        sed -i '/^Keywords=/a MimeType=application/x-cursor-workspace;' \
          "$out/share/applications/cursor.desktop"
      fi

      if grep -q '^MimeType=' "$out/share/applications/cursor-url-handler.desktop"; then
        sed -i 's|^MimeType=.*|MimeType=x-scheme-handler/cursor;|' \
          "$out/share/applications/cursor-url-handler.desktop"
      else
        sed -i '/^Keywords=/a MimeType=x-scheme-handler/cursor;' \
          "$out/share/applications/cursor-url-handler.desktop"
      fi

      sed -i 's|^Exec=.*|Exec=cursor --open-url %U|' \
        "$out/share/applications/cursor-url-handler.desktop"
    '';

    postFixup = (oldAttrs.postFixup or "") + ''
      cursorWrapper="$out/bin/cursor"
      cursorWrapperTmp="$cursorWrapper.tmp"

      while IFS= read -r line; do
        case "$line" in
          "exec -a \"\$0\" \"$out/bin/.cursor-wrapped\""*)
            printf '%s\n' 'if [ "''${1-}" = "--open-url" ]; then'
            printf '  exec -a "%s/lib/cursor/cursor" "%s/lib/cursor/cursor" "$@"\n' "$out" "$out"
            printf '%s\n' 'fi'
            ;;
        esac

        printf '%s\n' "$line"
      done < "$cursorWrapper" > "$cursorWrapperTmp"

      mv "$cursorWrapperTmp" "$cursorWrapper"
      chmod +x "$cursorWrapper"
    '';

    postInstall = (oldAttrs.postInstall or "") + ''
      install -Dm644 ${./mime/cursor-workspace.xml} \
        $out/share/mime/packages/cursor-workspace.xml
    '';
  })
