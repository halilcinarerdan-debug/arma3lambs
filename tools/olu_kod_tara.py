#!/usr/bin/env python3
# OLU KOD TARAYICISI (v8.828; kullanici: 'bunun gibi calismayan olu kodlar var mi arastir'; v8.827: PEEL bayragi (isPeeling) 5 yerde OKUNUYOR, bounding yolunda hic YAZILMIYORDU).
# Statik tarama (calistirmadan): 1) QGVAR(x) bayraklari: OKUNAN ama hic YAZILMAYAN (olu okuma) / YAZILAN ama hic OKUNMAYAN; 2) PREP fonksiyonu: hic cagrilmayan; 3) CBA ayari: kayitli ama hic okunmayan ya da okunan ama kayitsiz;
#   4) rpt_ozet.py karnesinin bekledigi log etiketi ([XXX]) kodda hic uretilmiyor; 5) 'case "X"' dallari: switch'te hic uretilmeyen karar (YALNIZ bilgi). Cikti: tools/olu_kod_raporu.txt
import re, glob, os, collections
KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FN = glob.glob(os.path.join(KOK, "addons", "**", "*.sqf"), recursive=True)
HPP = glob.glob(os.path.join(KOK, "addons", "**", "*.hpp"), recursive=True)
metin = {f: open(f, encoding="utf-8", errors="ignore").read() for f in FN + HPP}
tum = "\n".join(metin.values())
sonuc = []

# 1) QGVAR bayraklari (toplam referans == okuma ise HIC yazilmiyor; "lambs_danger_ad" dize kullanimi da yazma sayilir)
oku = collections.Counter(); tum_ref = collections.Counter(); yaz = collections.Counter()
for f, t in metin.items():
    for m in re.finditer(r"getVariable\s*(?:\[\s*)?QGVAR\((\w+)\)", t): oku[m.group(1)] += 1
    for m in re.finditer(r"QGVAR\((\w+)\)", t): tum_ref[m.group(1)] += 1
    for m in re.finditer(r"setVariable\s*\[\s*QGVAR\((\w+)\)", t): yaz[m.group(1)] += 1
def dize(k): return len(re.findall(r'"lambs_danger_%s"' % re.escape(k), tum)) + len(re.findall(r"'lambs_danger_%s'" % re.escape(k), tum))
olu_oku = sorted(k for k in oku if tum_ref[k] == oku[k] and dize(k) == 0)
olu_yaz = sorted(k for k in yaz if tum_ref[k] == yaz[k] and dize(k) == 0 and oku[k] == 0)
sonuc.append("== 1a) OKUNAN ama HIC YAZILMAYAN bayrak (okuma hep varsayilani doner = OLU OKUMA; %d) ==" % len(olu_oku))
for k in olu_oku: sonuc.append("  %s  (okuma %d)" % (k, oku[k]))
sonuc.append("== 1b) YAZILAN ama HIC OKUNMAYAN bayrak (%d) ==" % len(olu_yaz))
for k in olu_yaz: sonuc.append("  %s  (yazma %d)" % (k, yaz[k]))

# 2) PREP fonksiyonlari
prep = re.findall(r"^PREP\((\w+)\);", metin.get(os.path.join(KOK, "addons", "danger", "XEH_PREP.hpp"), ""), re.M)
olu_fn = []
for fn in prep:
    ref = len(re.findall(r"FUNC\(%s\)" % fn, tum)) + len(re.findall(r"lambs_danger_fnc_%s\b" % fn, tum)) + len(re.findall(r"QFUNC\(%s\)" % fn, tum))
    kendi = len(re.findall(r"FUNC\(%s\)" % fn, metin.get(os.path.join(KOK, "addons", "danger", "functions", "fnc_%s.sqf" % fn), "")))
    dz = len(re.findall(r'"%s"' % re.escape(fn), tum)) + len(re.findall(r"'%s'" % re.escape(fn), tum))   # baslatici listeleri / format ["lambs_danger_fnc_%1"] yoluyla
    if ref - kendi <= 0 and dz <= 0: olu_fn.append(fn)
sonuc.append("== 2) PREP'li ama HIC CAGRILMAYAN fonksiyon (%d) ==" % len(olu_fn))
for fn in sorted(olu_fn): sonuc.append("  " + fn)

# 3) CBA ayarlari
kayit = set(re.findall(r'\["(lambs_danger_\w+)",\s*"(?:CHECKBOX|SLIDER|LIST|EDITBOX|COLOR)"', tum))
okunan = collections.Counter()
for m in re.finditer(r'getVariable\s*\[\s*"(lambs_danger_\w+)"', tum): okunan[m.group(1)] += 1
for m in re.finditer(r'missionNamespace getVariable "(lambs_danger_\w+)"', tum): okunan[m.group(1)] += 1
# tarafBazli ayar (rpgTarafDeger / ayarTaraf): ad + West/East/Ind soneki
taban = lambda n: re.sub(r"(West|East|Ind)$", "", n)
tum_str = tum
olu_ayar = []
for a in sorted(kayit):
    ad = a[len("lambs_danger_"):]
    b = taban(ad)
    var = okunan[a] > 0 or okunan["lambs_danger_" + b] > 0 or len(re.findall(r'"%s"' % re.escape(b), tum)) > 0 or len(re.findall(r'"%s"' % re.escape(ad), tum)) > 0 or len(re.findall(r"\b%s\b" % re.escape(a), tum)) > 1 or len(re.findall(r"\b%s\b" % re.escape("lambs_danger_" + b), tum)) > 1
    if not var: olu_ayar.append(a)
sonuc.append("== 3a) KAYITLI ama KODDA HIC OKUNMAYAN CBA ayari (%d) ==" % len(olu_ayar))
for a in olu_ayar: sonuc.append("  " + a)
kayitsiz = sorted(a for a in okunan if a not in kayit and not a.startswith('lambs_danger_fnc_') and ('QGVAR(%s)' % a[len('lambs_danger_'):]) not in tum and not re.search(r"(Started|Off|Say|Tab|Fn|LogN|T|Tani|Sayac|Cache)$", a) and len(re.findall(r'setVariable\s*\[\s*"%s"' % a, tum)) == 0 and len(re.findall(r"\b%s\s*=" % a, tum)) == 0)
sonuc.append("== 3b) OKUNAN ama KAYITSIZ (CBA'da yok, baska yerde de atanmiyor) 'lambs_danger_*' (%d; yazim hatasi / olu ayar adayi) ==" % len(kayitsiz))
for a in kayitsiz: sonuc.append("  %s (okuma %d)" % (a, okunan[a]))

# 4) karnede beklenen log etiketleri
oz = open(os.path.join(KOK, "tools", "rpt_ozet.py"), encoding="utf-8", errors="ignore").read()
etiket = sorted(set(re.findall(r"\[([A-Z][A-Z0-9-]{3,})\]", oz)))
olu_et = []
for e in etiket:
    if e in ("ELITE-BOOT", "BILGI", "GECTI", "KALDI", "KONTROL", "VERI", "YOK"): continue
    if ("[" + e) not in tum and e not in tum: olu_et.append(e)
sonuc.append("== 4) KARNEDE ARANAN ama KODDA HIC URETILMEYEN log etiketi (%d) ==" % len(olu_et))
for e in olu_et: sonuc.append("  [" + e + "]")

# 5) bilgi: commanderAssess kararlari vs dagitim
kararlar = set(re.findall(r'\["(WITHDRAW|PEEL|DELAY|PUSH|HOLD|ASSAULT|SUPPRESS_ASSAULT|FLANK|BOUNDING|EVADE_ARMOR|AT_ENGAGE)"', metin.get(os.path.join(KOK, "addons", "danger", "functions", "fnc_commanderAssess.sqf"), "")))
sonuc.append("== 5) commanderAssess kararlari: %s ==" % sorted(kararlar))
for dosya in ("fnc_tactics.sqf", "fnc_tacticsBounding.sqf"):
    t = metin.get(os.path.join(KOK, "addons", "danger", "functions", dosya), "")
    cs = set(re.findall(r'case "(\w+)"', t))
    sonuc.append("  %s case dallari: %s | karar olup case'i OLMAYAN (default'a duser): %s" % (dosya, sorted(cs & kararlar), sorted(kararlar - cs)))
cikti = "\n".join(sonuc)
open(os.path.join(KOK, "tools", "olu_kod_raporu.txt"), "w", encoding="utf-8").write(cikti + "\n")
print(cikti)
