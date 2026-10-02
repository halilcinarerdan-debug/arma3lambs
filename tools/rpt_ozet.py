#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RPT OZETLEYICI (lambs_danger ELITE fork)
Kullanim:  python tools/rpt_ozet.py Arma3_x64_....rpt [baska.rpt ...]

Her RPT icin tek ekranlik ozet: build, etiket sayilari, spam tespiti, komutan kararlari, bounding, retreat, doktrin puani,
el bombasi tepki suresi, UGL kullanimi, hatalar (mod gurultusu ayiklanir).
"""
import re, sys, collections, statistics

TAGS = ["DURUM", "DURUM-GRUP", "DOKTRIN", "KOMUT", "CAGRI", "JEST", "CMD", "BND-BASLA", "BND", "BND-BITTI", "BND-CIKIS", "OVERWATCH",
        "GERI-CEKILME-BASLA", "GERI-CEKILME", "GERI-CEKILME-TAMAM", "TEMAS-KES-BASLA", "TEMAS-KES", "ATES-DESTEK", "ATIS-GUVENLIK",
        "ATES-HATTI", "SIKISMA", "DUVAR-KORUMA", "ARKA-GUVENLIK", "GRENADE-ATIS", "EL-BOMBASI", "EL-BOMBASI-TARAMA", "ATIS-TANI",
        "KOMUTAN-BEKLE", "KOMUTAN-FORM", "ROL-GOREV", "SIS", "TCCC", "SAHA", "BUDDY"]
NOISE = ("Bone ", "setHitPointDamage", "CAN_COLLIDE", "addWeaponWithAttachmentsCargoGlobal", "Destroy waypoint", "fnc_throwWeapon")

def sn(t):
    h, m, s = t.split(":")
    return int(h) * 3600 + int(m) * 60 + int(s)

def ozet(path):
    satirlar = open(path, encoding="utf-8", errors="replace").read().splitlines()
    print("=" * 78)
    print(path, "|", len(satirlar), "satir")
    sur = re.search(r"build (v[0-9.]+)", "\n".join(satirlar[:6000]))
    print("build:", sur.group(1) if sur else "?")

    sayac = collections.Counter()
    zaman = collections.defaultdict(list)
    for l in satirlar:
        m = re.match(r'\s*(\d+:\d\d:\d\d)\s+"?\[([A-Z0-9-]+)\]', l)
        if m:
            sayac[m.group(2)] += 1
            zaman[m.group(2)].append(sn(m.group(1)))
    print("\n-- ETIKET SAYILARI --")
    print(", ".join("%s:%d" % (t, sayac[t]) for t in TAGS if sayac[t]))

    # spam: ayni etiket 10 sn icinde >= 15 satir (DURUM/KOMUT/CAGRI/JEST haric: zaten sinirli)
    print("\n-- SPAM TESPITI (10 sn'de >= 15 satir) --")
    bulundu = False
    for t, zl in zaman.items():
        if t in ("DURUM", "KOMUT", "JEST", "CAGRI") or t not in TAGS:
            continue
        zl.sort()
        j = 0
        for i in range(len(zl)):
            while zl[i] - zl[j] > 10:
                j += 1
            if i - j + 1 >= 15:
                print("  %s: %d satir / 10 sn (~%s)" % (t, i - j + 1, "%d:%02d:%02d" % (zl[i] // 3600, zl[i] % 3600 // 60, zl[i] % 60)))
                bulundu = True
                break
    if not bulundu:
        print("  yok")

    print("\n-- KOMUTAN KARARLARI --")
    kar = collections.Counter()
    for l in satirlar:
        m = re.search(r"\[CMD\].*\| ([A-Z_]+) \(", l)
        if m:
            kar[m.group(1)] += 1
    print("  ", dict(kar) if kar else "yok")

    print("\n-- BOUNDING --")
    print("  baslangic:", sayac["BND-BASLA"], "| cycle satiri:", sayac["BND"], "| bitis:", sayac["BND-BITTI"], "| komutan cikisi:", sayac["BND-CIKIS"])
    har = []
    for l in satirlar:
        m = re.search(r"\[BND\].*hareket:(\d+) kapsama:(\d+)", l)
        if m:
            har.append((int(m.group(1)), int(m.group(2))))
    if har:
        oran = [a / (a + b) for a, b in har if a + b]
        print("   hareket orani (ortalama): %.0f%% | en yuksek: %.0f%%" % (100 * statistics.mean(oran), 100 * max(oran)))

    print("\n-- RETREAT --")
    sonuc = [(int(a), int(b)) for a, b in re.findall(r"sicrama \d+ sonuc \| vardi:(\d+)/(\d+)", "\n".join(satirlar))]
    print("  baslangic:", sayac["GERI-CEKILME-BASLA"], "| sicrama sonucu:", len(sonuc),
          "| varanlar toplam: %d/%d" % (sum(a for a, _ in sonuc), sum(b for _, b in sonuc)) if sonuc else "")

    print("\n-- DOKTRIN PUANI --")
    pu = [int(x) for x in re.findall(r"PUAN:(\d+)/100", "\n".join(satirlar))]
    if pu:
        onde = len(re.findall(r"komutan_onde:true", "\n".join(satirlar)))
        print("  ortalama: %.0f | en dusuk: %d | en yuksek: %d | komutan onde: %d/%d" % (statistics.mean(pu), min(pu), max(pu), onde, len(pu)))
    else:
        print("  yok")

    print("\n-- EL BOMBASI --")
    atis = [(sn(re.match(r"\s*(\d+:\d\d:\d\d)", l).group(1)), l) for l in satirlar if "[GRENADE-ATIS]" in l]
    tepki = [sn(re.match(r"\s*(\d+:\d\d:\d\d)", l).group(1)) for l in satirlar if "[EL-BOMBASI]" in l and "bomba" in l]
    print("  atis:", len(atis), "| tepki satiri:", len(tepki))
    for t0, l in atis[:6]:
        sonra = [t for t in tepki if t0 <= t <= t0 + 8]
        print("   %s -> ilk tepki %s" % (l.split('"')[1][:60] if '"' in l else l[:60], ("%d sn sonra" % (min(sonra) - t0)) if sonra else "YOK"))
    fk = re.findall(r"fitil kalan ([0-9.]+) sn", "\n".join(satirlar))
    if fk:
        print("   fitil kalan (tepki aninda): ort %.1f sn (>= 2.5 iyi)" % statistics.mean(float(x) for x in fk))

    print("\n-- UGL / RPG --")
    print("  UGL salvo:", len([1 for l in satirlar if "UGL salvo" in l]), "| ROL-GOREV UGL:", len([1 for l in satirlar if "ROL-GOREV" in l and "UGL" in l]),
          "| atis guvenligi iptali:", sayac["ATIS-GUVENLIK"])

    print("\n-- HATALAR (mod gurultusu ayiklanmis) --")
    hata = collections.Counter()
    for i, l in enumerate(satirlar):
        if "Error in expression" in l or "Error position" in l or "Error Undefined" in l or "Error Type" in l or "Error Zero" in l:
            ctx = " ".join(satirlar[i:i + 3])
            if any(n in ctx for n in NOISE):
                continue
            hata[re.sub(r"^\s*\d+:\d\d:\d\d\s*", "", l)[:110]] += 1
    if hata:
        for h, n in hata.most_common(8):
            print("  %dx %s" % (n, h))
    else:
        print("  yok")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for p in sys.argv[1:]:
        ozet(p)
