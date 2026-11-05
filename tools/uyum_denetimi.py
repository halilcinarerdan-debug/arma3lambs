#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UYUM DENETIMI (v8.500) - "ses yonlendirmesi" haritasi. Kod DEGISTIRMEZ, yalniz okur.
Her UZUV (hiz, hareket, davranis, binis, formasyon) icin hangi dosyalar yaziyor, hangi alan (arac / plan / taktik / piyade mikro) ve
birakma disiplini var mi (forceSpeed <x> koyan dosya forceSpeed -1 de yapiyor mu) cikarir. Cok alanli uzuvlar CAKISMA ADAYIDIR.
Kullanim:  python tools/uyum_denetimi.py            -> ekrana ozet
           python tools/uyum_denetimi.py --yaz      -> UYUM_DENETIMI.md dosyasina ayrintili rapor
SINIR: statik metin taramasi (yorum satirlari ayiklanir, dize icindekiler ayiklanmaz); 'cakisma adayi' gercek cakisma KANITI degildir, RPT ile dogrulanir.
"""
import re, sys, os, collections

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FN = os.path.join(KOK, "addons", "danger", "functions")

UZUVLAR = collections.OrderedDict([
    ("HIZ", [r"\bforceSpeed\b", r"\blimitSpeed\b", r"\bsetSpeedMode\b"]),
    ("HAREKET", [r"\bdoMove\b", r"\bdoStop\b", r"\bcommandMove\b", r"\bcommandStop\b", r"\baddWaypoint\b", r"\bsetCurrentWaypoint\b", r"\bdisableAI\s+\"PATH\"", r"\benableAI\s+\"PATH\""]),
    ("DAVRANIS", [r"\bsetBehaviour\b", r"\bsetCombatMode\b", r"\bsetUnitPos\b"]),
    ("BINIS", [r"\bassignAsCargo\b", r"\borderGetIn\b", r"\bdoGetOut\b", r"\bmoveOut\b", r"\bmoveInCargo\b", r"\bmoveInDriver\b", r"\bunassignVehicle\b", r"\bleaveVehicle\b"]),
    ("FORMASYON/TAKIP", [r"\bdoFollow\b", r"\bsetFormation\b", r"\bsetFormDir\b"]),
])

ALANLAR = [
    ("ARAC", r"^fnc_(arac|surus|mekanize|ezme|tank|zirh|nakil|taksi|reconArac|orphan|murettebat|tehlikeAlani)"),
    ("PLAN", r"^fnc_(komutanPlan|planZirh|harekat|hq|kumanda|objektif|karakol|garnizon)"),
    ("TAKTIK", r"^fnc_(tactics|bounding|retreat|assault|flank|leaderSync|sonDirenis|panik|pusu|rota)"),
    ("PIYADE-MIKRO", r"^fnc_(cqb|kose|siper|acikSiper|reload|grenade|yigilma|binaPencere|atesHareket|giyim|topSiper|istiksaf|tccc|gozetle|topcu|iha|dron)"),
]

def alan(ad):
    for a, rx in ALANLAR:
        if re.search(rx, ad):
            return a
    return "DIGER"

def yorumsuz(satir):
    s = satir.strip()
    if s.startswith("//") or s.startswith("*") or s.startswith("/*"):
        return ""
    # satir sonu yorumu: dize disinda ' //' (kaba)
    q = None
    for i, c in enumerate(satir):
        if q:
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c == "/" and satir[i:i + 2] == "//":
            return satir[:i]
    return satir

def tara():
    sonuc = {u: collections.defaultdict(list) for u in UZUVLAR}   # uzuv -> dosya -> [(satir_no, metin)]
    disiplin = {}   # dosya -> (forceSpeed_set, forceSpeed_birak)
    for kok, _, dosyalar in os.walk(FN):
        for f in sorted(dosyalar):
            if not f.endswith(".sqf"):
                continue
            yol = os.path.join(kok, f)
            ad = os.path.splitext(f)[0]
            fs_set = fs_birak = 0
            for no, ham in enumerate(open(yol, encoding="utf-8", errors="replace"), 1):
                s = yorumsuz(ham)
                if not s:
                    continue
                for u, rxl in UZUVLAR.items():
                    if any(re.search(rx, s) for rx in rxl):
                        sonuc[u][ad].append((no, s.strip()[:110]))
                if re.search(r"forceSpeed\s+-1", s):
                    fs_birak += 1
                elif re.search(r"\bforceSpeed\b", s):
                    fs_set += 1
            if fs_set or fs_birak:
                disiplin[ad] = (fs_set, fs_birak)
    return sonuc, disiplin

def rapor(sonuc, disiplin, yaz):
    out = []
    P = out.append
    P("# UYUM DENETIMI (statik; kod degistirmez)\n")
    P("Cakisma adayi = ayni uzva birden fazla ALAN yaziyor. Gercek cakisma RPT ile dogrulanir (`[UYUM]` etiketi hakem eklenince).\n")
    ozet = []
    for u, d in sonuc.items():
        alanlar = collections.defaultdict(set)
        toplam = 0
        for ad, satirlar in d.items():
            alanlar[alan(ad)].add(ad)
            toplam += len(satirlar)
        ozet.append((u, len(d), toplam, {a: len(v) for a, v in alanlar.items()}))
    P("## 1. Uzuv ozeti\n")
    P("| Uzuv | Dosya | Cagri | Alan dagilimi (dosya) |\n|---|---|---|---|")
    for u, nd, nt, al in ozet:
        P("| %s | %d | %d | %s |" % (u, nd, nt, ", ".join("%s:%d" % (a, n) for a, n in sorted(al.items(), key=lambda x: -x[1]))))
    P("\n## 2. ARAC SURUCUSU cakisma kumesi (HIZ + HAREKET + BINIS; ARAC ve PLAN alanlari)\n")
    P("Bu bolum oturumdaki RPT sorunlarinin (konvoy gecme, kalkmayan arac, ping-pong) bulundugu yer.\n")
    for u in ("HIZ", "HAREKET", "BINIS"):
        dosyalar = sorted(ad for ad in sonuc[u] if alan(ad) in ("ARAC", "PLAN"))
        P("**%s** (%d dosya): %s\n" % (u, len(dosyalar), ", ".join("%s(%d)" % (a, len(sonuc[u][a])) for a in dosyalar)))
    P("\n## 3. Birakma disiplini (forceSpeed): deger koyan ama -1 ile BIRAKMAYAN dosyalar\n")
    P("| Dosya | Alan | forceSpeed koy | forceSpeed -1 |\n|---|---|---|---|")
    kotu = [(ad, s, b) for ad, (s, b) in disiplin.items() if s > 0 and b == 0]
    for ad, s, b in sorted(kotu, key=lambda x: -x[1]):
        P("| %s | %s | %d | %d |" % (ad, alan(ad), s, b))
    if not kotu:
        P("| (yok) | | | |")
    P("\n## 4. Cakisma adaylari: ayni uzva en cok farkli alan yazan uzuvlar\n")
    for u, nd, nt, al in sorted(ozet, key=lambda x: -len(x[3])):
        P("- %s: %d alan %s" % (u, len(al), sorted(al)))
    P("\n## 5. Ayrinti: HIZ yazan ARAC / PLAN dosyalari ve satirlar (ilk 3)\n")
    for ad in sorted(a for a in sonuc["HIZ"] if alan(a) in ("ARAC", "PLAN")):
        P("### %s (%s)" % (ad, alan(ad)))
        for no, m in sonuc["HIZ"][ad][:3]:
            P("- `%d`: `%s`" % (no, m.replace("`", "'")))
    metin = "\n".join(out)
    if yaz:
        with open(os.path.join(KOK, "UYUM_DENETIMI.md"), "w", encoding="utf-8") as f:
            f.write(metin + "\n")
        print("yazildi: UYUM_DENETIMI.md")
    return metin, ozet, kotu

if __name__ == "__main__":
    yaz = "--yaz" in sys.argv
    sonuc, disiplin = tara()
    metin, ozet, kotu = rapor(sonuc, disiplin, yaz)
    print("== UYUM DENETIMI ==")
    for u, nd, nt, al in ozet:
        print("  %-16s %3d dosya %4d cagri | %s" % (u, nd, nt, ", ".join("%s:%d" % (a, n) for a, n in sorted(al.items(), key=lambda x: -x[1]))))
    print("  birakma disiplini bozuk (forceSpeed koyar, -1 yapmaz): %d dosya %s" % (len(kotu), [k[0] for k in kotu][:8]))
