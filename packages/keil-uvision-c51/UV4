#!/bin/sh
# Wine wrapper for Keil uVision.

WINE_BIN=@wine@/bin/wine
REGEDIT_BIN=@wine@/bin/regedit
MKDIR_BIN=@coreutils@/bin/mkdir
LN_BIN=@coreutils@/bin/ln
RM_BIN=@coreutils@/bin/rm
UV4_EXE=@out@/wine/drive_c/Keil_v5/UV4/UV4.exe

# UV4.exe tries to run support tools from C:\...:
#
# --- Error: failed to execute 'C:\Keil_v5\C51\BIN\C51.EXE'
#
# Deal with that by creating a link from $WINEPREFIX to the installation files.

# Use default $WINEPREFIX (~/.wine)
if [ -z "$WINEPREFIX" ]; then
    WINEPREFIX="$HOME/.wine"
fi
dest="$WINEPREFIX/drive_c"
dest_link="$dest/Keil_v5"
"$MKDIR_BIN" -p "$dest" || exit 1
"$RM_BIN" -rf "$dest_link" || exit 1
"$LN_BIN" -sf "@out@/wine/drive_c/Keil_v5/" "$dest_link" || exit 1

# Disable all error messages that Wine usually outputs
export WINEDEBUG=err-all,fixme-all

# Stop Wine from asking about installing Mono and Gecko packages at startup
export WINEDLLOVERRIDES="mscoree,mshtml="

# Optionally import license info
for lic_file in "@out@"/wine/drive_c/Keil_v5/license-info*.reg; do
    test -f "$lic_file" || continue
    "$REGEDIT_BIN" /C "$lic_file" || exit 1
done

exec "$WINE_BIN" "$UV4_EXE" "$@"
