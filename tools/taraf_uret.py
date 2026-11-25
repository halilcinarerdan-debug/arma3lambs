#!/usr/bin/env python3
# TARAF BAZLI CBA AYARI URETICISI (v8.803): BLUFOR / OPFOR / INDEPENDENT icin AYRI kategorilerde ('ELITE BLUFOR' / 'ELITE OPFOR' / 'ELITE INDEPENDENT') genel ayarlarin taraf kopyalarini uretir.
# Kaynak: addons/danger/XEH_PREP.hpp'deki genel ayarlar (aralik / ondalik); taraf kopyasi SLIDER [-1, max, -1, ondalik] ( -1 = genel ayari kullan ).
# Cikti: XEH_PREP.hpp icindeki '// ==== TARAF-AYAR-BASLA' .. 'TARAF-AYAR-BITIS ====' blogu + CBA_LAMBS_Danger_v8.*.txt en yeni preset'e eksik taraf satirlari.
# Kullanim: python3 tools/taraf_uret.py   (idempotent; fnc_ayarTaraf ile okunan her ayar TEMALAR listesinde olmali; yeni ayar eklemek = listeye adini yaz + okuyan kodu fnc_ayarTaraf'a baglamak)
import re, glob, os, sys, importlib.util
KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("kg", os.path.join(KOK, "tools", "cba_kilavuz_uret.py")); kg = importlib.util.module_from_spec(spec); spec.loader.exec_module(kg)
PREP = os.path.join(KOK, "addons", "danger", "XEH_PREP.hpp")
TEMALAR = [
    ("Beceri", ["skillIsabetMin", "skillIsabetMax", "skillIsabetCarpan", "skillTavanIsabet", "skillTitremeMin", "skillTitremeMax", "skillHizMin", "skillHizMax", "skillTavanHiz", "skillFarkMin", "skillFarkMax", "skillOptiksizCarpan", "skillAcemiOran", "skillAcemiCarpan", "skillCarpan", "dogrulukMaks"]),
    ("Baski / ozguven", ["ozguven", "baskiEtki", "baskiLambsCarpan", "baskiYakinM", "baskiGozlemciM"]),
    ("Reaksiyon / tempo", ["hizliFarkS", "hizliFarkAci", "hizliFarkSeviye", "animHiz", "cqbAnimEk", "donusHizi", "botAdimCarpan"]),
    ("Cover", ["siperYaricap", "siperYakinM", "siperYakinKosuM", "siperGercekCezaM", "siperYanAgirlik", "rotaRiskAgirlik", "ongoruAgirlik", "siperOnTaramaM", "uzakHucumM", "siperUzaklik", "siperYakinlik", "coverHugMesafe", "siperDostAralik", "siperCokluAgirlik", "siperMermiOncelik", "siperGorunurCeza", "siperKarsilikBonus", "siperSafCeza", "siperAyniAnda", "siperDurusCesit", "siperArazOncelik", "siperKentselArazi"]),
    ("Durus", ["durusDisiplinSn", "durusYatMesafe"]),
    ("UGL", ["uglCooldown", "uglMinM", "uglMaxM"]),
    ("Cekilme", ["erkenKayipOran", "erkenKayipHiz"]),
    ("RPG", ["rpgMaxM", "rpgYedek"]),
]
RPG_BOOL = [("rpgAktif", "karar katmani", "ACIK: bu tarafin roketatarli AI hedef secimi yapar (genel 'RPG sistemi: hedef secimi' de acik olmali). KAPALI: bu tarafin roketatarlilari ELITE karar katmanindan roket emri almaz (atis kapisi / guvenlik kurallari yine calisir)."),
            ("rpgMuhimmat", "piyadeye uygun (AP) roket tasi", "ACIK: bu tarafin roketatarlilari piyadeye uygun roket tasir (genel 'RPG muhimmat' de acik olmali; yer yoksa 'RPG muhimmat: sirt cantasi' ayari). KAPALI: bu tarafin envanterine dokunulmaz.")]
TARAFLAR = [("West", "BLUFOR", "_katBlufor", "ELITE BLUFOR"), ("East", "OPFOR", "_katOpfor", "ELITE OPFOR"), ("Ind", "INDEPENDENT", "_katInd", "ELITE INDEPENDENT")]
def q(t): return t.replace('"', '""')
s = open(PREP, encoding="utf-8").read()
G = {}
for m in re.finditer(r'\[\s*"(lambs_(?:danger|main)_[A-Za-z0-9_]+)"\s*,\s*"(CHECKBOX|SLIDER|LIST|EDITBOX|COLOR|TIME)"', s):
    try: arr, _ = kg.dizi(s, m.start())
    except Exception: continue
    ad = m.group(1)[len("lambs_danger_"):]
    e2 = arr[2] if len(arr) > 2 else None
    isim = kg.duz(e2[1][0]) if e2 and e2[0] == "arr" and e2[1] else (e2[1] if e2 and e2[0] == "str" else ad)
    G[ad] = (m.group(2), arr[4] if len(arr) > 4 else None, isim)
satirlar = []; preset = []; atlanan = []
for ek, taraf, katv, katad in TARAFLAR:
    satirlar.append("")
    for tema, adlar in TEMALAR:
        for ad in adlar:
            if ad not in G or G[ad][0] != "SLIDER": atlanan.append((ad, "yok / SLIDER degil")); continue
            tip, veri, isim = G[ad]
            a = [kg.duz(x) for x in veri[1]]
            try: mx = float(a[1]); mn = float(a[0]); dec = int(float(a[3])) if len(a) > 3 else 0
            except Exception: atlanan.append((ad, "aralik okunamadi")); continue
            if mn < 0: atlanan.append((ad, "genel min < 0")); continue
            mxs = a[1]
            satirlar.append('    ["lambs_danger_%s%s", "SLIDER", ["%s | %s: %s", "v8.803 taraf bazli (%s). -1 = genel ayar (%s) gecerli; baska deger = yalniz %s icin (genel ayarla ayni aralik / sinir). Varsayilan -1 (genel ayar)."], %s, [-1, %s, -1, %d], 1] call CBA_fnc_addSetting;' % (ad, ek, taraf, tema, q(isim), taraf, q(isim), taraf, katv, mxs, dec))
            preset.append("force lambs_danger_%s%s = -1;" % (ad, ek))
    for ad, baslik, ac in RPG_BOOL:
        satirlar.append('    ["lambs_danger_%s%s", "CHECKBOX", ["%s | RPG: %s", "v8.803 taraf bazli (%s). %s Varsayilan ACIK."], %s, true, 1] call CBA_fnc_addSetting;' % (ad, ek, taraf, baslik, taraf, ac, katv))
        preset.append("force lambs_danger_%s%s = true;" % (ad, ek))
blok = ['// ==== TARAF-AYAR-BASLA (tools/taraf_uret.py uretir; ELLE DEGISTIRME) ====',
        '// v8.803 (kullanici: \'blufor opfor ve independent icin herseyiyle ayri ayarlayabilelim, farkli kategorilerde olsun\'): her taraf icin AYRI CBA kategorisi; -1 = genel ayar. Okuma: fnc_ayarTaraf.',
        'if (!isNil "CBA_fnc_addSetting" && {!isNil "CBA_settings_default"}) then {']
for ek, taraf, katv, katad in TARAFLAR:
    blok.append('    private %s = ["LAMBS Danger", "%s"];' % (katv, katad))
blok += satirlar
blok += ['};', '// ==== TARAF-AYAR-BITIS ====']
yeni = "\n".join(blok) + "\n"
crlf = "\r\n" in s
t = s.replace("\r\n", "\n")
# eski elle yazilmis taraf RPG satirlari (v8.802) kaldirilir (uretilenle ayni adlar)
t = "\n".join(l for l in t.split("\n") if not re.search(r'"lambs_danger_rpg(Aktif|Muhimmat|MaxM|Yedek)(West|East|Ind)"', l))
if "// ==== TARAF-AYAR-BASLA" in t:
    t = re.sub(r"// ==== TARAF-AYAR-BASLA.*?// ==== TARAF-AYAR-BITIS ====\n", lambda m: yeni, t, flags=re.S)
else:
    i = t.index('diag_log "[ELITE-BOOT]')
    t = t[:i] + yeni + "\n" + t[i:]
if crlf: t = t.replace("\n", "\r\n")
open(PREP, "w", encoding="utf-8", newline="").write(t)
presetler = sorted(glob.glob(os.path.join(KOK, "CBA_LAMBS_Danger_v8.*.txt")), key=lambda p: [int(x) for x in re.findall(r"\d+", os.path.basename(p))])
if presetler:
    p = presetler[-1]; raw = open(p, "rb").read().decode("utf-8"); pc = "\r\n" in raw
    L = [l for l in raw.replace("\r\n", "\n").split("\n")]
    while L and L[-1] == "": L.pop()
    L = [l for l in L if not re.match(r"^(?:force\s+)?lambs_danger_(rpgAktif|rpgMuhimmat|rpgMaxM|rpgYedek)(West|East|Ind)\s*=", l)]
    var = set(re.match(r"^(?:force\s+)?(lambs_\w+)", l).group(1) for l in L if re.match(r"^(?:force\s+)?(lambs_\w+)", l))
    L += [l for l in preset if re.match(r"force (lambs_\w+)", l).group(1) not in var]
    out = "\n".join(L) + "\n"
    if pc: out = out.replace("\n", "\r\n")
    open(p, "wb").write(out.encode("utf-8"))
    print("preset:", os.path.basename(p), "taraf satiri", len(preset))
print("uretilen ayar satiri:", len([l for l in satirlar if l.strip()]), "| atlanan:", atlanan)
