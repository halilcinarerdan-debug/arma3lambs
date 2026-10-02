#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RPT OZETLEYICI (lambs_danger ELITE fork)
Kullanim:  python tools/rpt_ozet.py Arma3_x64_....rpt [baska.rpt ...]
           --anomali            sadece [ANOMALI] listesi (kod ozeti + ilk satirlar)
           --grup "Alpha 1-1"   o grubun ZAMAN CIZELGESI (olay / bounding / retreat / pusu / karar / anomali, tekrarlar birlestirilir)
           --aralik 12:50:00-12:55:00   cizelgeyi / anomaliyi zaman araligiyla sinirla

Her RPT icin tek ekranlik ozet: build, etiket sayilari, spam tespiti, komutan kararlari, bounding, retreat, doktrin puani,
el bombasi tepki suresi, UGL kullanimi, hatalar (mod gurultusu ayiklanir).
"""
import re, sys, collections, statistics

TAGS = ["DURUM", "DURUM-GRUP", "DOKTRIN", "KOMUT", "CAGRI", "JEST", "CMD", "BND-BASLA", "BND", "BND-BITTI", "BND-CIKIS", "OVERWATCH",
        "GERI-CEKILME-BASLA", "GERI-CEKILME-EK", "ROTA", "PUSU", "KAMUFLAJ", "KAMUFLAJ-YER", "ARAZI", "ARAZI-KOMUTAN", "ANOMALI", "SAGLIK", "ORTAM-SKILL", "GERI-CEKILME", "GERI-CEKILME-TAMAM", "TEMAS-KES-BASLA", "TEMAS-KES", "ATES-DESTEK", "ATIS-GUVENLIK",
        "ATES-HATTI", "SIKISMA", "DUVAR-KORUMA", "ARKA-GUVENLIK", "GRENADE-ATIS", "EL-BOMBASI", "EL-BOMBASI-TARAMA", "ATIS-TANI",
        "KOMUTAN-BEKLE", "KOMUTAN-FORM", "ROL-GOREV", "SIS", "TCCC", "SAHA", "BUDDY", "SIPER-ANALIZ", "DOKTRIN-PROFIL", "OLAY"]
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

    print("\n-- SIPER ANALIZI (v2) --")
    sa = [l for l in satirlar if "[SIPER-ANALIZ]" in l]
    if sa:
        deg = len([1 for l in sa if "DEGISTI" in l])
        print("  cagri:", len(sa), "| faz2 ilk secimi degistirdi: %d (%.0f%%)" % (deg, 100.0 * deg / len(sa)))
    else:
        print("  yok (lambs_main_coverV2 kapali ya da siper cagrisi olmadi)")
    print("\n-- ROTA PLANLAMA (v1) --")
    rt = [l for l in satirlar if "[ROTA]" in l]
    if rt:
        sap = [int(m.group(1)) for l in rt for m in [re.search(r"sapma:(-?\d+)", l)] if m]
        dr = [int(m.group(1)) for l in rt for m in [re.search(r"direkt:(\d+)", l)] if m]
        pl = [int(m.group(1)) for l in rt for m in [re.search(r"plan:(\d+)", l)] if m]
        ms = [int(m.group(1)) for l in rt for m in [re.search(r"sure:(\d+) ms", l)] if m]
        print("  plan:", len(rt), "| sapma != 0:", len([1 for x in sap if x != 0]), "| maruziyet direkt ort %.0f%% -> plan %.0f%% | sure ort %.0f ms (en yuksek %d)" % (
            statistics.mean(dr) if dr else 0, statistics.mean(pl) if pl else 0, statistics.mean(ms) if ms else 0, max(ms) if ms else 0))
    else:
        print("  yok (rota: tehdit 90-600 m + bounding gerekir)")
    kmf = [l for l in satirlar if "[KAMUFLAJ] " in l and "coef:" in l]
    print("\n-- KAMUFLAJ / ARAZI BILINCI --")
    if kmf:
        cs = [float(m.group(1)) for l in kmf for m in [re.search(r"coef:([0-9.]+)", l)] if m]
        print("  kamuflaj katsayisi: %d degisim | ort %.2f | en dusuk %.2f | ufukta: %d" % (len(kmf), statistics.mean(cs), min(cs), len([1 for l in kmf if "ufukta:true" in l])))
    else:
        print("  kamuflaj: yok")
    print("  stealth yer degistirme (ufuk cizgisinden cekilme):", len([1 for l in satirlar if "[KAMUFLAJ-YER]" in l]))
    az = [l for l in satirlar if "[ARAZI] " in l]
    print("  arazi analizi:", len(az), "| hakim nokta bulunan:", len([1 for l in az if "hakim:+" in l]), "| komutan gozetleme hakim nokta:", len([1 for l in satirlar if "[ARAZI-KOMUTAN]" in l]))
    an = [l for l in satirlar if "[ANOMALI]" in l]
    print("\n-- ANOMALI (saglik izleyicisi) --")
    if an:
        kod = collections.Counter(re.search(r"\[ANOMALI\] ([A-Z-]+)", l).group(1) for l in an if re.search(r"\[ANOMALI\] ([A-Z-]+)", l))
        print("  ", dict(kod))
        for l in an[:8]: print("   ", re.sub(r"^\s*", "", l)[:170])
    else:
        print("  yok (saglik izleyicisi: v8.14+; sorun bulunmadi)")
    ps = [l for l in satirlar if "[PUSU]" in l]
    print("\n-- PUSU / ATES EMRI --")
    if ps:
        bas = len([1 for l in ps if "BASLADI" in l]); ates = len([1 for l in ps if "| ATES |" in l]); ipt = len([1 for l in ps if "IPTAL" in l])
        print("  basladi:", bas, "| ates:", ates, "| iptal:", ipt)
        nd = {}
        for l in ps:
            m = re.search(r"neden:(ATES:[^|]+)", l)
            if m: nd[m.group(1).strip()] = nd.get(m.group(1).strip(), 0) + 1
        print("  ates nedenleri:", nd)
        for l in ps[:6]: print("  ", l.split('"')[1][:150] if '"' in l else l[:150])
    else:
        print("  yok (pusu: 90-260 m yaklasan piyade dusman + temas yok gerekir)")
    ek = [l for l in satirlar if "[GERI-CEKILME-EK]" in l]
    print("\n-- RETREAT EK SICRAMA --")
    print("  ek sicrama satiri:", len(ek))
    dp = [re.sub(r"^.*\[DOKTRIN-PROFIL\] ", "", l)[:90] for l in satirlar if "[DOKTRIN-PROFIL]" in l]
    if dp:
        print("\n-- DOKTRIN PROFILLERI --")
        for d in dp[:6]:
            print("  ", d)

    ol = collections.Counter()
    for l in satirlar:
        m = re.search(r"\[OLAY\] [^|]+\| ([A-Za-z]+) \|", l)
        if m:
            ol[m.group(1)] += 1
    print("\n-- GRUP OLAYLARI --")
    print("  ", dict(ol) if ol else "yok")
    gn = len([1 for l in satirlar if "AllClear guvenlik agi" in l])
    if gn:
        print("   !! guvenlik agi %d kez bayrak temizledi (taktik kilidi / disableAI kalintisi: bir taktik anormal bitiyor olabilir)" % gn)

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

def zaman_cizelgesi(path, grup, aralik):
    """Bir grubun olaylarini zaman sirasinda, tekrarlari birlestirerek yazdirir."""
    ETIK = ("OLAY", "BND-BASLA", "BND-BITTI", "BND-CIKIS", "GERI-CEKILME", "GERI-CEKILME-BASLA", "GERI-CEKILME-EK", "GERI-CEKILME-SIPER",
            "GERI-CEKILME-TAMAM", "TEMAS-KES-BASLA", "TEMAS-KES", "PUSU", "CMD", "DURUM-GRUP", "ANOMALI", "ROTA", "KAMUFLAJ-YER", "SIS", "KOMUTAN-BEKLE")
    t0, t1 = 0, 99999999
    if aralik:
        a, b = aralik.split("-")
        t0, t1 = sn(a), sn(b)
    onceki, tekrar = None, 0
    for l in open(path, encoding="utf-8", errors="replace").read().splitlines():
        m = re.match(r'\s*(\d+:\d\d:\d\d)\s+"?\[([A-Z0-9-]+)\]', l)
        if not m or m.group(2) not in ETIK or grup not in l:
            continue
        t = sn(m.group(1))
        if t < t0 or t > t1:
            continue
        govde = re.sub(r"^\s*\d+:\d\d:\d\d\s*", "", l).strip('" ')
        anahtar = re.sub(r"[0-9.]+", "#", govde)[:90]
        if anahtar == onceki:
            tekrar += 1
            continue
        if tekrar:
            print("      (x%d benzer satir)" % tekrar)
        onceki, tekrar = anahtar, 0
        print("%s  %s" % (m.group(1), govde[:200]))
    if tekrar:
        print("      (x%d benzer satir)" % tekrar)

def anomali_listesi(path, aralik):
    t0, t1 = 0, 99999999
    if aralik:
        a, b = aralik.split("-")
        t0, t1 = sn(a), sn(b)
    for l in open(path, encoding="utf-8", errors="replace").read().splitlines():
        m = re.match(r'\s*(\d+:\d\d:\d\d)\s+"?\[(ANOMALI|SAGLIK)\]', l)
        if m and t0 <= sn(m.group(1)) <= t1:
            print(re.sub(r"^\s*", "", l)[:220])

if __name__ == "__main__":
    args = sys.argv[1:]
    grup = aralik = None
    sadece_anomali = False
    yollar = []
    i = 0
    while i < len(args):
        if args[i] == "--grup" and i + 1 < len(args):
            grup = args[i + 1]; i += 2
        elif args[i] == "--aralik" and i + 1 < len(args):
            aralik = args[i + 1]; i += 2
        elif args[i] == "--anomali":
            sadece_anomali = True; i += 1
        else:
            yollar.append(args[i]); i += 1
    if not yollar:
        print(__doc__)
        sys.exit(1)
    for p in yollar:
        if grup:
            print("=" * 78); print(p, "| grup:", grup, "| aralik:", aralik or "tum")
            zaman_cizelgesi(p, grup, aralik)
        elif sadece_anomali:
            print("=" * 78); print(p)
            anomali_listesi(p, aralik)
        else:
            ozet(p)
