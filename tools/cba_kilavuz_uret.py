#!/usr/bin/env python3
# CBA AYAR KILAVUZU URETICISI (v8.793): addons/danger/XEH_PREP.hpp icindeki CBA_fnc_addSetting girdilerini okur,
# tools/cba_kilavuz_sablon.md (elle yazilan bolumler; {SURUM} / {PRESET} / {SAYI} yer tutuculari) + otomatik tam listeyi birlestirip CBA_AYAR_KILAVUZU.md yazar.
# Kullanim: python3 tools/cba_kilavuz_uret.py
import re, glob, os, sys
KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREP = os.path.join(KOK, "addons", "danger", "XEH_PREP.hpp")
SABLON = os.path.join(KOK, "tools", "cba_kilavuz_sablon.md")
CIKTI = os.path.join(KOK, "CBA_AYAR_KILAVUZU.md")

def bosluk(s, i):
    n = len(s)
    while i < n:
        if s[i] in " \t\r\n,": i += 1
        elif s.startswith("//", i): i = s.index("\n", i) if "\n" in s[i:] else n
        elif s.startswith("/*", i): i = s.index("*/", i) + 2
        else: break
    return i

def dizge(s, i):
    j = i + 1; out = []
    while True:
        if s[j] == '"':
            if j + 1 < len(s) and s[j + 1] == '"': out.append('"'); j += 2; continue
            return "".join(out), j + 1
        out.append(s[j]); j += 1

def deger(s, i):
    i = bosluk(s, i)
    if s[i] == '"': t, j = dizge(s, i); return ("str", t), j
    if s[i] == "[": a, j = dizi(s, i); return ("arr", a), j
    j = i; d = 0
    while j < len(s):
        c = s[j]
        if c == '"': _, j = dizge(s, j); continue
        if c in "([": d += 1
        elif c in ")]":
            if d == 0: break
            d -= 1
        elif c == "," and d == 0: break
        j += 1
    return ("tok", s[i:j].strip()), j

def dizi(s, i):
    items = []; i += 1
    while True:
        i = bosluk(s, i)
        if s[i] == "]": return items, i + 1
        v, i = deger(s, i); items.append(v)

def duz(v):
    if v is None: return ""
    k, x = v
    if k in ("str", "tok"): return x
    return "[" + ", ".join(duz(y) for y in x) + "]"

def main():
    s = open(PREP, encoding="utf-8").read()
    katlar = [(m.start(), m.group(1), m.group(2)) for m in re.finditer(r'private (_kat\w*) = \["LAMBS Danger", "([^"]+)"\]', s)]
    def kategori(poz, ad=None):
        adaylar = [k for k in katlar if k[0] < poz and (ad is None or k[1] == ad)]
        return adaylar[-1][2] if adaylar else "Diger"
    girdiler = {}
    for m in re.finditer(r'\[\s*"(lambs_(?:danger|main)_[A-Za-z0-9_]+)"\s*,\s*"(CHECKBOX|SLIDER|LIST|EDITBOX|COLOR|TIME)"', s):
        try:
            arr, _ = dizi(s, m.start())
        except Exception:
            continue
        ad = m.group(1)[len("lambs_danger_"):] if m.group(1).startswith("lambs_danger_") else m.group(1)
        tip = m.group(2)
        e2 = arr[2] if len(arr) > 2 else None
        if e2 and e2[0] == "str":
            isim = e2[1]; ipucu = duz(arr[3]) if len(arr) > 3 else ""; veri = arr[4] if len(arr) > 4 else None; kat = kategori(m.start())
        elif e2 and e2[0] == "arr":
            isim = duz(e2[1][0]) if e2[1] else ""; ipucu = duz(e2[1][1]) if len(e2[1]) > 1 else ""
            kid = duz(arr[3]) if len(arr) > 3 else ""
            veri = arr[4] if len(arr) > 4 else None
            kat = kategori(m.start(), kid if re.fullmatch(r"_kat\w*", kid) else None)
            if arr[3][0] == "arr" and len(arr[3][1]) > 1: kat = duz(arr[3][1][1])
        else:
            continue
        girdiler[ad] = (kat, isim, tip, veri, ipucu)
    # aralik / varsayilan
    def bicim(tip, veri):
        if veri is None: return ("?", "?")
        if tip == "CHECKBOX":
            d = duz(veri).strip().lower()
            return ("açık/kapalı", "açık" if d == "true" else "kapalı")
        if tip == "SLIDER" and veri[0] == "arr" and len(veri[1]) >= 3:
            a = [duz(x) for x in veri[1]]
            return ("%s–%s" % (a[0], a[1]), a[2])
        if tip == "LIST" and veri[0] == "arr" and len(veri[1]) >= 3:
            vals, labs, di = veri[1][0], veri[1][1], duz(veri[1][2])
            if vals[0] == "arr" and labs[0] == "arr" and di.isdigit() and int(di) < len(labs[1]):
                return ("liste (%s)" % ", ".join(duz(x) for x in labs[1]), duz(labs[1][int(di)]))
            return ("liste", di)
        if tip == "EDITBOX": return ("metin", duz(veri))
        return (tip.lower(), duz(veri))
    # preset (en yeni)
    presetler = sorted(glob.glob(os.path.join(KOK, "CBA_LAMBS_Danger_v8.*.txt")), key=lambda p: [int(x) for x in re.findall(r"\d+", os.path.basename(p))])
    preset = os.path.basename(presetler[-1]) if presetler else "?"
    pset = {}
    if presetler:
        for l in open(presetler[-1], encoding="utf-8", errors="replace").read().replace("\r\n", "\n").split("\n"):
            m = re.match(r"^(?:force\s+)?lambs_danger_(\w+)\s*=\s*(.*);\s*$", l)
            if m: pset[m.group(1)] = m.group(2)
    surum = re.search(r'ELITE build (v8\.\d+)-SADE', s)
    surum = surum.group(1) if surum else "?"
    kategoriler = []; icerik = {}
    for ad, (kat, isim, tip, veri, ipucu) in girdiler.items():
        if kat not in icerik: kategoriler.append(kat); icerik[kat] = []
        ar, vs = bicim(tip, veri)
        ipucu = ipucu.replace("|", "\\|").replace("\n", " ")
        if len(ipucu) > 700: ipucu = ipucu[:700] + "…"
        icerik[kat].append((ad, isim.replace("|", "\\|"), ar.replace("|", "\\|"), vs.replace("|", "\\|"), ipucu))
    sablon = open(SABLON, encoding="utf-8").read()
    out = [sablon.replace("{SURUM}", surum).replace("{PRESET}", "`%s`" % preset).replace("{SAYI}", str(len(girdiler)))]
    out.append("\n## 4. Tüm CBA ayarları (otomatik liste)\n\nAralık: kaydırıcının alt–üst sınırı · Varsayılan: kod varsayılanı (preset farklı olabilir). Bu bölüm `tools/cba_kilavuz_uret.py` ile XEH_PREP.hpp'den üretilir; elle düzenlemeyin.\n")
    for kat in kategoriler:
        satirlar = sorted(icerik[kat])
        out.append("### %s (%d ayar)\n\n| Ayar | Ad | Aralık | Varsayılan | Açıklama |\n|---|---|---|---|---|" % (kat, len(satirlar)))
        for ad, isim, ar, vs, ip in satirlar:
            out.append("| `%s` | %s | %s | %s | %s |" % (ad, isim, ar, vs, ip))
        out.append("")
    eksik = sorted(k for k in pset if k not in girdiler)
    if eksik:
        out.append("### Preset'te olup bu tabloda olmayanlar (%d)\n\nDoktrin / profil seçimleri gibi döngüyle kaydedilen ya da başka bir yerden gelen ayarlar. Değer: presetteki.\n\n| Ayar | Preset değeri |\n|---|---|" % len(eksik))
        for k in eksik: out.append("| `%s` | %s |" % (k, pset[k].replace("|", "\\|")))
        out.append("")
    open(CIKTI, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("kilavuz yazildi: %d ayar, %d kategori, surum %s, preset %s, preset'te olup tabloda olmayan %d" % (len(girdiler), len(kategoriler), surum, preset, len(eksik)))
    return girdiler

if __name__ == "__main__":
    main()
