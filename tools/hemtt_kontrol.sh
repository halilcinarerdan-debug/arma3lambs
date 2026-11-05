#!/bin/bash
# HEMTT sozdizimi / lint kontrolu (v8.332). Depoda script_component.hpp / config.cpp'nin tamami yok (ust LAMBS deposunda); bu betik GECICI bir proje kurar:
# macro taslaklari (GVAR / QGVAR / FUNC / EFUNC ...) + addons/*/functions kopyasi + CfgVehicles.hpp. Cikti: error sayisi ve hata ayrintilari (SPE2 = ayristirilamayan SQF).
# Kullanim: tools/hemtt_kontrol.sh [hemtt_yolu]   (hemtt yoksa GitHub releases'ten indirilir)
set -e
KOK="$(cd "$(dirname "$0")/.." && pwd)"
HEMTT="${1:-$(command -v hemtt || true)}"
if [ -z "$HEMTT" ]; then
  mkdir -p /tmp/hemtt_bin && curl -sSL -o /tmp/hemtt.zip https://github.com/BrettMayson/HEMTT/releases/latest/download/linux-x64.zip && unzip -o -q /tmp/hemtt.zip -d /tmp/hemtt_bin && chmod +x /tmp/hemtt_bin/hemtt
  HEMTT=/tmp/hemtt_bin/hemtt
fi
P="$(mktemp -d)"
mkdir -p "$P/.hemtt" "$P/addons/danger" "$P/addons/main"
printf 'name = "LAMBS test"\nprefix = "lambs"\nauthor = "test"\nmainprefix = "z"\n\n[version]\nmajor = 1\nminor = 0\npatch = 0\nbuild = 0\ngit_hash = 0\n' > "$P/.hemtt/project.toml"
cat > "$P/addons/danger/script_component.hpp" <<'HPP'
#define DOUBLES(a,b) a##_##b
#define TRIPLES(a,b,c) a##_##b##_##c
#define QUOTE(x) #x
#define ADDON DOUBLES(lambs,danger)
#define GVAR(x) DOUBLES(lambs_danger,x)
#define QGVAR(x) QUOTE(GVAR(x))
#define EGVAR(m,x) TRIPLES(lambs,m,x)
#define QEGVAR(m,x) QUOTE(EGVAR(m,x))
#define FUNC(x) TRIPLES(lambs_danger,fnc,x)
#define QFUNC(x) QUOTE(FUNC(x))
#define EFUNC(m,x) TRIPLES(lambs,m,fnc_##x)
#define QEFUNC(m,x) QUOTE(EFUNC(m,x))
#define CSTRING(x) QUOTE(TRIPLES($STR,lambs_danger,x))
#define ECSTRING(m,x) QUOTE(TRIPLES($STR,lambs_##m,x))
#define VERSION_CONFIG version = 1; versionStr = "1"
#define COMPONENT_NAME "test"
#define REQUIRED_VERSION 2.0
#define PATHTOF2_SYS(p,c,f) f
#define PREFIX lambs
#define COMPONENT danger
HPP
cp "$P/addons/danger/script_component.hpp" "$P/addons/main/script_component.hpp"
cp -r "$KOK/addons/danger/functions" "$P/addons/danger/functions"
cp -r "$KOK/addons/main/functions" "$P/addons/main/functions"
for d in $(find "$P/addons" -type d -path "*functions*"); do [ -e "$d/script_component.hpp" ] || cp "$P/addons/danger/script_component.hpp" "$d/"; done   # -n: depoda kendi script_component.hpp si olan klasorlere (Eden) dokunma
# CfgVehicles.hpp: taban siniflar
# v8.362: CfgVehicles.hpp artik Logic / Module_F (AttributesBase) tanimini kendisi yapar; 3DEN modulleri CfgVehiclesEden.hpp icinde
cp "$KOK/addons/danger/CfgVehicles.hpp" "$P/addons/danger/CfgVehicles.hpp"
cp "$KOK/addons/danger/CfgVehiclesEden.hpp" "$P/addons/danger/CfgVehiclesEden.hpp"
printf '#include "script_component.hpp"\nclass CfgPatches { class ADDON { name = COMPONENT_NAME; units[] = {}; weapons[] = {}; requiredVersion = 2.22; requiredAddons[] = {}; VERSION_CONFIG; }; };\n#include "CfgVehicles.hpp"\n' > "$P/addons/danger/config.cpp"
printf 'class CfgPatches { class lambs_main { units[]={}; weapons[]={}; requiredVersion=2.22; requiredAddons[]={}; }; };\n' > "$P/addons/main/config.cpp"
for a in danger main; do printf 'prefix = "%s"\n' "$a" > "$P/addons/$a/addon.toml"; printf 'z\\lambs\\addons\\%s' "$a" > "$P/addons/$a/\$PBOPREFIX\$"; done
# XEH_PREP.hpp'yi SQF olarak ayristir
{ echo '#include "script_component.hpp"'; echo '#define PREP(x)'; echo '#define SUBPREP(a,b)'; cat "$KOK/addons/danger/XEH_PREP.hpp"; } > "$P/addons/danger/functions/fnc_zz_xehprep.sqf"
cd "$P"
"$HEMTT" check 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$P/cikti.txt" || true
if grep '^ERROR' "$P/cikti.txt" | grep -qv 'check for updates'; then echo "KONTROL CALISMADI (HEMTT hatasi):"; grep -A3 '^ERROR' "$P/cikti.txt" | grep -v 'check for updates'; exit 2; fi
echo "HATA (error) sayisi: $(grep -c '^error' "$P/cikti.txt")"
grep -A10 '^error' "$P/cikti.txt" | head -60
echo "Tam cikti: $P/cikti.txt  (L-S29 'Undefined Function' uyarilari PREP'in test projesinde olmamasindan gelir, yok sayilir)"
# v8.364: HEMTT 'error' disinda GERCEK HATA adayi uyarilar (eskiden gozden kaciyordu: L-S12 'reverse' deger dondurmez -> forEach (reverse ...) 8 yerde calismiyordu)
n12=$(grep -c 'warning\[L-S12\]' "$P/cikti.txt" || true)
echo "L-S12 (gecersiz arguman tipi) uyari sayisi: $n12  (0 olmali)"
if [ "$n12" != "0" ]; then grep -A4 'warning\[L-S12\]' "$P/cikti.txt" | head -40; fi
# v8.364: statik tutarlilik denetimi (PREP / olay / ayar / degisken / kapanis kapsami / surum)
python3 "$KOK/tools/tutarlilik_denetimi.py" > "$P/tutarlilik.txt" || true
tail -15 "$P/tutarlilik.txt"
# v8.500: CI icin cikis kodu - HEMTT 'error' ya da tutarlilik 'HATA' varsa 1
n_err=$(grep -c '^error' "$P/cikti.txt" || true)
n_tut=$(grep -c '^  HATA' "$P/tutarlilik.txt" || true)
if [ "$n_err" != "0" ] || [ "$n_tut" != "0" ] || [ "$n12" != "0" ]; then echo "KONTROL BASARISIZ: hemtt error=$n_err, L-S12=$n12, tutarlilik HATA=$n_tut"; exit 1; fi
echo "KONTROL BASARILI"
