#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RPT OZETLEYICI (lambs_danger ELITE fork)
Kullanim:  python tools/rpt_ozet.py Arma3_x64_....rpt [baska.rpt ...]
           --karne              TOPLU TEST KARNESI: her ozellik icin OK / KONTROL / YOK + kanit (en hizli okuma)
           --form               FORMASYON DEGISIM TESHISI: grup basina [FORM-DEGISIM] sayisi, <20 sn aralikli salinim (felc) tespiti
           --kayip              KAYIP TABLOSU (v8.90): taraf basina OLU + BAYILAN (ACE etkisiz) + oran; gercek hayat hedefiyle karsilastirma icin
           --zeka               TAKTIK ZEKA katmani (v8.60): olum bolgesi hafizasi, karsi pusu, rota gozcusu, HQ otomatik; otomatik cikarim
           --hava-ied           HAVA + IED TESHISI: zaman cizelgesi + otomatik 'neden tepki yok' cikarimi (v8.52 loglari)
           --anomali            sadece [ANOMALI] listesi (kod ozeti + ilk satirlar)
           --grup "Alpha 1-1"   o grubun ZAMAN CIZELGESI (olay / bounding / retreat / pusu / karar / anomali, tekrarlar birlestirilir)
           --aralik 12:50:00-12:55:00   cizelgeyi / anomaliyi zaman araligiyla sinirla

Her RPT icin tek ekranlik ozet: build, etiket sayilari, spam tespiti, komutan kararlari, bounding, retreat, doktrin puani,
el bombasi tepki suresi, UGL kullanimi, hatalar (mod gurultusu ayiklanir).
"""
import re, sys, collections, statistics

TAGS = ["DURUM", "DURUM-GRUP", "DOKTRIN", "KOMUT", "CAGRI", "JEST", "CMD", "BND-BASLA", "BND", "BND-BITTI", "BND-CIKIS", "OVERWATCH",
        "GERI-CEKILME-BASLA", "GERI-CEKILME-EK", "ROTA", "PUSU", "KAMUFLAJ", "KAMUFLAJ-YER", "ARAZI", "ARAZI-KOMUTAN", "ANOMALI", "SAGLIK", "ORTAM-SKILL", "SKILL-VARSAYILAN", "SKILL-OZET", "MEDIC-TASMA", "MEDIC-TASMA-OZET", "MORAL", "MORAL-OZET", "ROE-IHLAL", "ROE-OZET", "SON-DIRENIS", "GERI-CEKILME-TOPLAN", "HQ", "HQ-TAHTA", "HQ-RAPOR", "HQ-TAKVIYE", "HQ-EMIR", "HQ-MEDEVAC", "HQ-KANAT", "HQ-ISTIHBARAT", "HQ-MODUL", "TOPLAN", "TOPLAN-RAPOR", "PUSU-GUVENLIK", "PUSU-KZ", "ROTA-ZINCIR", "ODA", "HQ-FEINT", "GERI-CEKILME-YON", "GERI-CEKILME-BITIS", "TESLIM", "YORGUNLUK", "SIPER-YAPIS-OZET", "SIPER-YAPIS-TANI", "GERI-CEKILME-TAKILI", "CQB-POZ", "TELSIZ-GRUP", "TEMAS-KES-YON", "YAPRAK", "YAPRAK-OZET", "YAPRAK-TANI", "YAPRAK-PERF", "YAPRAK-TEST", "GERI-CEKILME", "GERI-CEKILME-TAMAM", "TEMAS-KES-BASLA", "TEMAS-KES", "ATES-DESTEK", "ATIS-GUVENLIK",
        "ATES-HATTI", "SIKISMA", "DUVAR-KORUMA", "ARKA-GUVENLIK", "GRENADE-ATIS", "EL-BOMBASI", "EL-BOMBASI-TARAMA", "ATIS-TANI",
        "KOMUTAN-BEKLE", "KOMUTAN-FORM", "ROL-GOREV", "SIS", "TCCC", "SAHA", "BUDDY", "SIPER-ANALIZ", "DOKTRIN-PROFIL", "OLAY"]
BEKLENEN_SURUM = "v8.152"   # her surumde guncelle (karne SURUM satiri eski paket yuklu mu diye kontrol eder)
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
    yp = [l for l in satirlar if "[YAPRAK] " in l]
    ypo = [l for l in satirlar if "[YAPRAK-OZET]" in l]
    print("\n-- YAPRAK ARKASI GORUS KIRICI --")
    for l in satirlar:
        if "[YAPRAK-TANI]" in l: print("  ", re.sub(r"^\s*\d+:\d\d:\d\d\s*", "", l)[:200])
    if ypo:
        top = {"kontrol": 0, "gizli": 0, "unuttu": 0}
        for l in ypo:
            for k in top:
                m = re.search(k + r":(\d+)", l)
                if m: top[k] += int(m.group(1))
        ms = [float(m.group(1)) for l in ypo for m in [re.search(r"tick ort:([0-9.]+)", l)] if m]
        print("  60 sn ozetleri: %d | toplam kontrol:%d gizli:%d unuttu:%d | gizli orani %.0f%% | tick ort %.1f ms (en yuksek %.1f)" % (len(ypo), top["kontrol"], top["gizli"], top["unuttu"], 100.0 * top["gizli"] / max(top["kontrol"], 1), statistics.mean(ms) if ms else 0, max(ms) if ms else 0))
    elif yp:
        print("  unutma kararlari:", len(yp), "(60 sn ozeti yok: oturum kisa)")
    else:
        print("  yok (kirici: v8.16+; ya da yakin dusman / cali yok)")
    print("  PERF uyarilari:", len([1 for l in satirlar if "[YAPRAK-PERF]" in l]))
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

def karne(path):
    """TOPLU TEST KARNESI: her ozellik icin OK / KONTROL / YOK + kanit."""
    L = open(path, encoding="utf-8", errors="replace").read().splitlines()
    t = "\n".join(L)
    def say(etiket): return len([1 for l in L if ("[%s]" % etiket) in l])
    def sayi(rx, grup=1): return [float(m.group(grup)) for l in L for m in [re.search(rx, l)] if m]
    sat = []
    def ekle(ad, durum, kanit): sat.append((ad, durum, kanit))
    b = re.search(r"build (v[0-9.]+[A-Z-]*)", t)
    ekle("SURUM", "OK" if b and b.group(1).startswith(BEKLENEN_SURUM) else "KONTROL", ("%s (beklenen %s)" % (b.group(1), BEKLENEN_SURUM)) if b else "boot satiri yok")
    hata_say = 0
    for i, l in enumerate(L):
        if "Error in expression" in l or "Error position" in l or "Error Undefined" in l or "Error Type" in l or "Error Zero" in l:
            if not any(n in " ".join(L[i:i + 3]) for n in NOISE):
                hata_say += 1
    ekle("SCRIPT HATASI", "OK" if hata_say == 0 else "KONTROL", "%d satir" % hata_say)
    # retreat
    vr = [(int(m.group(1)), int(m.group(2))) for l in L for m in [re.search(r"sonuc \| vardi:(\d+)/(\d+)", l)] if m]
    if vr:
        a_, b_ = sum(x for x, _ in vr), sum(y for _, y in vr)
        ekle("RETREAT varis", "OK" if a_ >= 0.5 * b_ else "KONTROL", "%d/%d (%.0f%%), ek sicrama:%d, baski-kirma:%d" % (a_, b_, 100.0 * a_ / max(b_, 1), say("GERI-CEKILME-EK"), len([1 for l in L if "GERI-CEKILME-SIPER" in l])))
    else:
        ekle("RETREAT varis", "YOK", "retreat olmadi (senaryo: retreat_kayipli)")
    # rota
    dr, pl = sayi(r"direkt:(\d+)"), sayi(r"plan:(\d+)%")
    if dr: ekle("ROTA", "OK" if (sum(pl) / len(pl)) < 0.8 * (sum(dr) / len(dr)) else "KONTROL", "%d plan, maruziyet %.0f%% -> %.0f%%" % (len(dr), sum(dr) / len(dr), sum(pl) / len(pl)))
    else: ekle("ROTA", "YOK", "bounding 90-600 m yok")
    rz = [l for l in L if "[ROTA-ZINCIR]" in l]
    ekle("ROTA ZINCIRI", "OK" if rz else "YOK", ("%d zincir, ort %.1f bacak" % (len(rz), sum(int(re.search(r"\| (\d+) bacak", l).group(1)) for l in rz if re.search(r"\| (\d+) bacak", l)) / max(1, len(rz)))) if rz else "sapmali rota (ortulu hat) gerektiren yaklasma olmadi")
    od = [l for l in L if "[ODA]" in l]
    odc = [l for l in od if "CLEAR" in l]
    odk = [l for l in od if "Door_N_trigger" in l]
    ekle("KAPI / ODA TEMIZLEME", "OK" if odc else ("KONTROL" if od else "YOK"), ("yigilma:%d (kapi noktasi bulunan:%d) oda CLEAR:%d" % (len([1 for l in od if "yigilma" in l]), len(odk), len(odc))) if od else "bina temizleme calismadi (catisma sonrasi bina yok / abort)")
    # pusu
    pb, pa = len([1 for l in L if "[PUSU]" in l and "BASLADI" in l]), len([1 for l in L if "[PUSU]" in l and "| ATES |" in l])
    pg = len([1 for l in L if "[PUSU-GUVENLIK]" in l])
    pcog = len([1 for l in L if "[PUSU]" in l and "cogunluk" in l])
    pbuy = len([1 for l in L if "[PUSU]" in l and "cok buyuk" in l])
    if pb: ekle("PUSU", "OK" if pa > 0 else "KONTROL", "basladi:%d ates:%d (cogunluk kill zone'da:%d) iptal:%d (cok buyuk dusman:%d) | security atamasi:%d" % (pb, pa, pcog, len([1 for l in L if "[PUSU]" in l and "IPTAL" in l]), pbuy, pg))
    else: ekle("PUSU", "YOK", "yaklasan piyade dusman + temas yok kosulu olusmadi")
    # kamuflaj / arazi
    kc = sayi(r"\[KAMUFLAJ\] .*coef:([0-9.]+)")
    ekle("KAMUFLAJ", "OK" if kc else "YOK", ("%d degisim, ort %.2f, ufuktan cekilme:%d" % (len(kc), sum(kc) / len(kc), say("KAMUFLAJ-YER"))) if kc else "katsayi degisimi yok")
    az = say("ARAZI")
    ekle("ARAZI BILINCI", "OK" if az else "YOK", "analiz:%d, komutan hakim nokta:%d" % (az, say("ARAZI-KOMUTAN")))
    # ortam
    oc = say("ORTAM-SKILL")
    cf = "CF_BAI algilandi:True" in t
    ekle("ORTAM SKILL", "OK" if oc else ("KONTROL" if cf else "YOK"), ("%d degisim" % oc) if oc else ("CF_BAI yuklu -> kapali" if cf else "degisim yok (hava / isik / cihaz sabit olabilir)"))
    mt = say("MEDIC-TASMA")
    ekle("MEDIC TASMA", "OK" if mt else "YOK", ("%d geri cagirma" % mt) if mt else "saglikci onde kalmadi ya da temas yok")
    ty = say("TEMAS-KES-YON")
    if ty:
        sp = sayi(r"sapma (\d+)")
        gz = len([1 for l in L if "TEMAS-KES-YON" in l and "gizli:true" in l])
        ekle("TEMAS KES YON", "OK" if sp and sum(sp) / len(sp) <= 60 and gz >= 0.5 * ty else "KONTROL", "%d hedef | gizli:%d | ort sapma %.0f derece" % (ty, gz, sum(sp) / max(len(sp), 1)))
    else:
        ekle("TEMAS KES YON", "YOK", "temas kesme olmadi (<4 kisi, kayip / baski)")

    sy = [l for l in L if "[SIPER-YAPIS-OZET]" in l]
    if sy:
        aj = sum(int(m.group(1)) for l in sy for m in [re.search(r"ayarlandi:(\d+)", l)] if m)
        ac = sum(int(m.group(1)) for l in sy for m in [re.search(r"acikta:(\d+)", l)] if m)
        ekle("SIPER YAPISMA", "OK" if aj > 0 else "KONTROL", "ayarlandi:%d acikta:%d | %s" % (aj, ac, re.sub(r"^.*\[SIPER-YAPIS-OZET\] ", "", sy[-1])[:90]))
    else:
        ekle("SIPER YAPISMA", "YOK", "60 sn ozeti yok (temas / oturum kisa)")
    bh = len([1 for l in L if "[ANOMALI] BOSTA-HAREKET" in l])
    ekle("BOSTA HAREKET", "OK" if bh == 0 else "KONTROL", "%d anomali (formasyonda surekli hareket suphesi)" % bh)
    tg = [l for l in L if "[TELSIZ-GRUP]" in l]
    ekle("TELSIZ / REINFORCE", "OK" if tg else "YOK", ("%d grup tanisi; reinforce acik: %d" % (len(tg), len([1 for l in tg if "enableGroupReinforce:true" in l]))) if tg else "tani yok (v8.19+)")

    mo = say("MORAL"); te = say("TESLIM"); yo = say("YORGUNLUK")
    ekle("MORAL / TESLIM", "OK" if (mo or te or say("MORAL-OZET")) else "YOK", "moral degisimi:%d teslim:%d" % (mo, te))
    ekle("YORGUNLUK", "OK" if yo else "YOK", ("%d kisaltma logu" % yo) if yo else "yorgunluk > 0.3 olmadi (ACE fatigue / uzun yaklasma)")

    cq = [l for l in L if "[CQB-POZ]" in l]
    if cq:
        dar = len([1 for l in cq if re.search(r"aci genisligi:[12]/5", l)]); acik = len([1 for l in cq if "aci genisligi:5/5" in l])
        ekle("CQB ATIS POZISYONU", "OK", "%d degerlendirme | dar aci:%d | tam acik:%d | geriye kaydirilan:%d | PEEK:%d" % (len(cq), dar, acik, len([1 for l in cq if "geriye kaydirildi:true" in l]), len([1 for l in cq if "PEEK:true" in l])))
    else:
        ekle("CQB ATIS POZISYONU", "YOK", "iceride atis pozisyonu secimi olmadi (bina catismasi gerekir)")

    ri = [l for l in L if "[ROE-IHLAL]" in l]
    ekle("ROE (SIVIL / DOST KORUMASI)", "OK" if (not ri) else "KONTROL", ("ihlal yok" if not ri else "%d ihlal (sivil: %d) - ornek: %s" % (len(ri), len([1 for l in ri if "(CIVILIAN)" in l]), re.sub(r"^.*\[ROE-IHLAL\] ", "", ri[0])[:120])))
    sd = [l for l in L if "[SON-DIRENIS]" in l and "BASLADI" in l]
    ekle("SON DIRENIS (KALE)", "OK" if sd else "YOK", ("%d kale savunmasi, bitis: %s" % (len(sd), [re.search(r"neden:([^|]+)", l).group(1).strip() for l in L if "[SON-DIRENIS]" in l and "BITTI" in l][:3])) if sd else "<= 3 asker son care olmadi")
    hqt = [l for l in L if "[HQ-TAKVIYE]" in l]
    hqm = [l for l in L if "[HQ-MEDEVAC]" in l]
    hqb = [l for l in L if "[HQ-TAHTA]" in l]
    hqf = [l for l in L if "[HQ-FEINT]" in l]
    hqk = [l for l in L if "[HQ-KANAT]" in l and "EMIR" in l]
    hqs = [l for l in L if "[HQ-KANAT]" in l and "SALDIRI" in l]
    hqi = [l for l in L if "[HQ-ISTIHBARAT]" in l]
    hqmod = [l for l in L if "[HQ-MODUL]" in l]
    ekle("KUMANDA (HQ)", "OK" if hqmod else ("KONTROL" if any("[HQ] kumanda" in l for l in L) else "KONTROL"),
         ("modul: %s | tahta:%d takviye:%d kanat emri:%d (saldiri:%d) istihbarat bildirimi:%d medevac:%d" % (hqmod[-1].split("[HQ-MODUL]")[1].strip()[:60], len(hqb), len(hqt), len(hqk), len(hqs), len(hqi), len(hqm))) if hqmod else "Zeus 'ELITE Kumanda (HQ)' modulu yerlestirilmemis (kumanda KAPALI — beklenen)" )
    ekle("RETREAT TOPARLANMA", "OK" if any("[GERI-CEKILME-TOPLAN]" in l for l in L) else "YOK", "%d toparlanma" % len([1 for l in L if "[GERI-CEKILME-TOPLAN]" in l and "toparlanma:" not in l and "geri acildi" not in l]))
    tb = [l for l in L if "[TOPLAN]" in l and "BASLA" in l]
    tr = [l for l in L if "[TOPLAN-RAPOR]" in l]
    tt = [l for l in L if "[TOPLAN]" in l and "BITTI" in l]
    yb = [l for l in L if "[GERI-CEKILME-BITIS]" in l]
    yy = [l for l in L if "[GERI-CEKILME-YON]" in l]
    neden = {}
    for l in tt:
        m = re.search(r"neden:([^|]+)", l)
        if m: neden[m.group(1).strip()[:28]] = neden.get(m.group(1).strip()[:28], 0) + 1
    bn = {}
    for l in yb:
        m = re.search(r"neden:([^|]+)", l)
        if m: bn[m.group(1).strip()] = bn.get(m.group(1).strip(), 0) + 1
    ekle("TOPLANMA (DOKTRIN: consolidate+reorganize)", "OK" if tb else "YOK", ("basla:%d rapor:%d bitis:%s" % (len(tb), len(tr), neden)) if tb else "retreat sonrasi toparlanma baslamadi (retreat olmadi mi / toparlan kapali?)")
    ekle("RETREAT BITIS KRITERI (gorus)", "OK" if yb else "YOK", ("bitis nedenleri: %s | yon degistirme sicramasi:%d" % (bn, len(yy))) if yb else "ek sicrama bitisi kaydi yok")
    # varsayilan beceri
    sv = [l for l in L if "[SKILL-VARSAYILAN] " in l and "onceki:" in l]
    so = [l for l in L if "[SKILL-OZET]" in l]
    if sv or so:
        son = so[-1] if so else ""
        m = re.search(r"uygulandi=(\d+)", son)
        ekle("SKILL VARSAYILAN", "OK" if (sv or (m and int(m.group(1)) > 0)) else "KONTROL", "%d birim logu%s" % (len(sv), (" | " + re.sub(r"^.*\[SKILL-OZET\] ", "", son)[:110]) if son else ""))
    else:
        ekle("SKILL VARSAYILAN", "YOK", "sistem logu yok (v8.17+)")

    # yaprak
    ypo = [l for l in L if "[YAPRAK-OZET]" in l]
    if ypo:
        k = sum(int(m.group(1)) for l in ypo for m in [re.search(r"kontrol:(\d+)", l)] if m)
        g = sum(int(m.group(1)) for l in ypo for m in [re.search(r"gizli:(\d+)", l)] if m)
        ms = [float(m.group(1)) for l in ypo for m in [re.search(r"tick ort:([0-9.]+)", l)] if m]
        oran = 100.0 * g / max(k, 1)
        dur = "OK" if (k > 0 and oran <= 70 and (not ms or max(ms) < 12)) else "KONTROL"
        ekle("YAPRAK KIRICI", dur, "kontrol:%d gizli:%d (%.0f%%), tick ort max %.1f ms" % (k, g, oran, max(ms) if ms else 0))
    else:
        ekle("YAPRAK KIRICI", "YOK", "60 sn ozeti yok (oturum kisa ya da kapali)")
    # saglik
    an = [l for l in L if "[ANOMALI]" in l]
    if say("SAGLIK"):
        kod = collections.Counter(re.search(r"\[ANOMALI\] ([A-Z-]+)", l).group(1) for l in an if re.search(r"\[ANOMALI\] ([A-Z-]+)", l))
        ekle("SAGLIK / ANOMALI", "OK" if not an else "KONTROL", "anomali:%d %s" % (len(an), dict(kod) if an else ""))
    else:
        ekle("SAGLIK / ANOMALI", "YOK", "izleyici satiri yok")
    # olay + doktrin + spam
    oc2 = say("OLAY")
    ekle("OLAY MESAJLARI", "OK" if oc2 else "YOK", "%d satir (InContact:%d Casualty:%d)" % (oc2, len([1 for l in L if "InContact" in l and "[OLAY]" in l]), len([1 for l in L if "Casualty" in l and "[OLAY]" in l])))
    dp = sayi(r"PUAN:(\d+)/100")
    ekle("DOKTRIN PUANI", "OK" if dp and sum(dp) / len(dp) >= 70 else ("KONTROL" if dp else "YOK"), ("ort %.0f" % (sum(dp) / len(dp))) if dp else "-")
    ekle("UGL", "OK" if say("ATES-DESTEK") + say("ROL-GOREV") else "YOK", "ates-destek:%d rol-gorev:%d" % (say("ATES-DESTEK"), say("ROL-GOREV")))
    # v8.62: UGL-OZET (neden atmadi sayaclari) son satir + UGL-KARAR (atis) sayisi
    uo = [l for l in L if "[UGL-OZET]" in l]
    if uo:
        ekle("UGL NEDEN", "KONTROL", re.sub(r'^\s*\d+:\d\d:\d\d\s+"?\[UGL-OZET\]\s*', "", uo[-1])[:160] + " | UGL-KARAR(atis): %d" % say("UGL-KARAR"))
    print("=" * 78); print("TOPLU TEST KARNESI |", path)
    for ad, d, k in sat:
        print("  [%-7s] %-18s %s" % (d, ad, k))
    print("  OK:%d  KONTROL:%d  YOK:%d" % tuple(len([1 for _, d, _ in sat if d == x]) for x in ("OK", "KONTROL", "YOK")))


def hava_ied(path):
    """HAVA / IED teshisi: ilgili etiketleri zaman sirasinda dok, ardindan otomatik NEDEN cikarimi yap."""
    L = open(path, encoding="utf-8", errors="replace").read().splitlines()
    rx = re.compile(r'^\s*(\d+:\d\d:\d\d)\s+"?\[(HAVA-FARK[A-Z-]*|IED-FARK[A-Z-]*|WATCHDOG-YENIDEN)\]')
    ev = []
    for i, l in enumerate(L):
        m = rx.match(l)
        if m:
            ev.append((i, m.group(1), m.group(2), l.strip()))
    hata = [(i, l.strip()) for i, l in enumerate(L) if "Error in expression" in l or "Error position" in l or re.search(r"Error [a-z0-9_]+:", l) or "lambs/addons" in l]
    hata = [(i, l) for i, l in hata if not any(n in l for n in NOISE)]
    print("=" * 78)
    print(path, "| HAVA / IED TESHISI")
    sayac = collections.Counter(e[2] for e in ev)
    print("etiket sayilari:", dict(sayac))
    print("-" * 78)
    for i, t, tag, l in ev:
        if tag in ("HAVA-FARK-NABIZ", "IED-FARK-NABIZ") and sayac[tag] > 6:
            continue   # nabizi seyrelt (ilk 6'yi gosterir)
        print(l[:300])
    print("-" * 78)
    print("OTOMATIK CIKARIM")
    ok = lambda m: print("  [OK]    " + m)
    uy = lambda m: print("  [SORUN] " + m)
    kt = lambda m: print("  [KONTROL] " + m)
    # watchdog
    wd = [e for e in ev if e[2] == "WATCHDOG-YENIDEN"]
    if wd:
        uy("watchdog %d kez yeniden basladi (betik hata ile oldu). Son adim + ustteki Error satirina bak:" % len(wd))
        for i, t, tag, l in wd[:5]:
            print("      ", l[:260])
            for j in range(max(0, i - 6), i):
                if "Error" in L[j]:
                    print("        >", L[j].strip()[:200])
    else:
        ok("watchdog yeniden baslamadi")
    if hata:
        lam = [h for h in hata if "lambs" in h[1] or "fnc_" in h[1]]
        if lam:
            uy("RPT'de lambs / fnc_ iceren %d hata satiri (ilk 5):" % len(lam))
            for i, l in lam[:5]:
                print("      ", l[:200])
    # HAVA
    nab = [e for e in ev if e[2] == "HAVA-FARK-NABIZ"]
    if not any(e[2] == "HAVA-FARK" and "baslatildi" in e[3] for e in ev):
        kt("HAVA-FARK baslangic satiri yok (eski surum ya da modul yuklenmedi)")
    elif not nab:
        kt("HAVA-FARK-NABIZ yok: oturum 60 sn'den kisa ya da dongu hic calismadi")
    else:
        ok("hava dongusu yasiyor (NABIZ %d adet; son: %s)" % (len(nab), nab[-1][3][:160]))
    ates = [e for e in ev if e[2] == "HAVA-FARK-ATES"]
    if not ates:
        kt("HAVA-FARK-ATES yok: hic hava araci gorulmedi ya da Fired EH eklenmedi")
    else:
        yerel = [e for e in ates if "YEREL" in e[3]]
        uzak = [e for e in ates if "uzaktan" in e[3]]
        etti = [e for e in ates if "ates etti" in e[3]]
        print("      Fired EH: yerel %d | uzaktan istenen %d | 'ates etti' %d" % (len(yerel), len(uzak), len(etti)))
        if uzak and not etti:
            uy("EH uzaktan istendi ama hic 'ates etti' gelmedi -> remoteExec engelli olabilir; saldiri tespiti yalniz baskiya (getSuppression) dayanir")
    tani = [e for e in ev if e[2] == "HAVA-FARK-TANI"]
    kar = [e for e in ev if e[2] == "HAVA-FARK-KARAR"]
    ele = [e for e in ev if e[2] == "HAVA-FARK-ELE"]
    tepki = [e for e in ev if e[2] == "HAVA-FARK" and "tepki:" in e[3]]
    if tani and not kar and not tepki:
        uy("heli goruldu (TANI %d) ama hic KARAR / tepki yok -> hedef secilmedi. ELE nedenleri:" % len(tani))
        for e in ele[:6]:
            print("      ", e[3][:260])
        if not ele:
            print("       (ELE satiri yok: grup atlandi ya da lider yerel degil; HAVA-FARK-ATLA satirlarina bak)")
    if kar:
        sal = [e for e in kar if "saldiri:true" in e[3]]
        sal_zarfsiz = [e for e in sal if "zarf:false" in e[3]]
        sal_zarfli = [e for e in sal if "zarf:true" in e[3]]
        topl = [e for e in tepki if "TOPLU-ATES" in e[3]]
        print("      KARAR %d | saldiri:true %d | zarf disi %d | zarf ici %d | TOPLU-ATES %d" % (len(kar), len(sal), len(sal_zarfsiz), len(sal_zarfli), len(topl)))
        if sal_zarfli and not topl:
            uy("saldiri + zarf ici ama TOPLU-ATES yok -> koşullardan biri (silahli / duran asker / 80 sn pencere) tutmuyor; KARAR satirlarina bak")
        if sal and not sal_zarfli:
            kt("saldiri var ama hep zarf disinda (mesafe >600 m ya da yukseklik >300 m): bu ATP 3-01.8'e uygun (etkisiz) ama esikleri gozden gecir")
        if not sal:
            kt("heli yakindi (KARAR var) ama saldiri:true hic olmadi: heli ates etmedi ya da Fired EH / baski sinyali gelmedi")
    # GARRISON
    gar = [e for e in ev if e[2] == "HAVA-FARK-GARRISON"]
    if gar:
        for e in gar:
            m = re.search(r"CAGRI ONCESI \| yakin bina:(\d+) \(en yakin (\d+) m\) \| kullanilabilir bina pozisyonu:(\d+) \| hazir asker:(\d+)/(\d+)", e[3])
            if m:
                bina, _, poz, hazir, top = (int(x) for x in m.groups())
                msg = "GARRISON cagrisi: bina %d, pozisyon %d, hazir asker %d/%d" % (bina, poz, hazir, top)
                if poz < hazir:
                    uy(msg + " -> pozisyon sayisi hazir askerden az: herkes iceri giremez (bina kucuk)")
                elif hazir < top:
                    kt(msg + " -> bazi askerler 'hazir' sayilmadi (LAMBS findReadyUnits): temas / baska gorev")
                else:
                    ok(msg)
            if "CAGRI SONUCU: false" in e[3] or "BASARISIZ" in e[3]:
                uy("GARRISON basarisiz, HIDE'a dusuldu: " + e[3][:200])
            m = re.search(r"(\d+ sn[^|]*) \| ICERIDE:(\d+) .*?\| ACIKTA:(\d+)", e[3])
            if m and "30 sn" in m.group(1):
                ic, ac = int(m.group(2)), int(m.group(3))
                (ok if ac == 0 else uy)("GARRISON son durum (30 sn): iceride %d, acikta %d" % (ic, ac))
    # IED
    inab = [e for e in ev if e[2] == "IED-FARK-NABIZ"]
    if inab:
        ok("IED dongusu yasiyor (NABIZ %d; son: %s)" % (len(inab), inab[-1][3][:160]))
    gz = [e for e in ev if e[2] == "IED-FARK-GOZLEM"]
    if gz:
        c = collections.Counter(re.search(r"tespit YOK: (.*)$", e[3]).group(1)[:30] if re.search(r"tespit YOK: (.*)$", e[3]) else "?" for e in gz)
        kt("IED tespit EDILEMEDI nedenleri: %s" % dict(c))
    ik = [e for e in ev if e[2] == "IED-FARK-KARAR"]
    if ik:
        imha_evet = [e for e in ik if "imha karari:true" in e[3]]
        print("      IED KARAR %d | imha karari EVET %d | HAYIR %d" % (len(ik), len(imha_evet), len(ik) - len(imha_evet)))
        for e in ik:
            if "imha karari:false" in e[3]:
                nedenler = []
                if "EOD sayisi:0" in e[3]: nedenler.append("EOD yok")
                elif "kitli:0" in e[3]: nedenler.append("EOD'da imha kiti yok")
                if "temas:true" in e[3]: nedenler.append("temas var")
                if "ikincil(yakinlik tetikli komsu):true" in e[3]: nedenler.append("yakinlik tetikli komsu IED")
                if "bu IED yakinlik tetikli:true" in e[3]: nedenler.append("bu IED yakinlik tetikli")
                if "devam eden is:true" in e[3]: nedenler.append("baska imha suruyor")
                m = re.search(r"EOD-IED mesafe:(\d+)", e[3])
                if m and int(m.group(1)) >= 110: nedenler.append("EOD >=110 m uzakta")
                print("       %s imha YOK: %s" % (e[1], ", ".join(nedenler) or "?"))
    im = [e for e in ev if e[2] == "IED-FARK-IMHA" or (e[2] == "IED-FARK" and "imha " in e[3])]
    basladi = [e for e in im if "BASLADI" in e[3]]
    tamam = [e for e in ev if e[2] == "IED-FARK" and "imha TAMAM" in e[3]]
    yarim = [e for e in ev if e[2] == "IED-FARK" and "YARIM KALDI" in e[3]]
    if basladi:
        print("      imha: BASLADI %d | TAMAM %d | YARIM %d" % (len(basladi), len(tamam), len(yarim)))
        for e in yarim[:5]:
            print("       ", e[3][:240])
        takil = [e for e in im if "ilerleme yok:" in e[3] and re.search(r"ilerleme yok:(\d+)", e[3]) and int(re.search(r"ilerleme yok:(\d+)", e[3]).group(1)) >= 20]
        if takil:
            uy("EOD yaklasirken %d kez 20 sn+ ilerleyemedi (yol / engel / baska sistem komutu):" % len(takil))
            for e in takil[:3]:
                print("       ", e[3][:240])
        if not tamam and not yarim:
            kt("imha basladi ama ne TAMAM ne YARIM logu var: betik oldu ya da oturum bitti")
    zr = [e for e in ev if e[2] == "IED-FARK-ZAR"]
    if zr:
        b = len([e for e in zr if "-> BASARI" in e[3]])
        ip = len([e for e in zr if "IPTAL" in e[3]])
        pt = len([e for e in zr if "PATLAMA" in e[3]])
        print("      zar: BASARI %d | IPTAL %d | PATLAMA %d" % (b, ip, pt))
        if pt:
            kt("zar sonucu EOD'nin hata ile cihazi patlatmasi %d kez (beklenen: dusuk olasilik)" % pt)
    cv = [e for e in ev if e[2] == "IED-FARK-CEVRE"]
    if cv:
        print("      cevre emniyeti: %d satir (BASLADI/BITTI)" % len(cv))
    print()


def zeka(path):
    """TAKTIK ZEKA (v8.60) teshisi: ZEKA-* etiketleri + ROTA 'olum bolgesi gozcusu' + HQ-MODUL."""
    L = open(path, encoding="utf-8", errors="replace").read().splitlines()
    rx = re.compile(r'^\s*(\d+:\d\d:\d\d)\s+"?\[(ZEKA-[A-Z]+|HQ-MODUL|HQ|HQ-ISTIHBARAT|HQ-KANAT|HQ-TAKVIYE|HQ-FEINT|WATCHDOG-YENIDEN)\]')
    ev = [(i, m.group(1), m.group(2), l.strip()) for i, l in enumerate(L) for m in [rx.match(l)] if m]
    rota = [l.strip() for l in L if "[ROTA]" in l and "olum bolgesi gozcusu" in l]
    print("=" * 78)
    print(path, "| TAKTIK ZEKA TESHISI")
    sayac = collections.Counter(e[2] for e in ev)
    print("etiket sayilari:", dict(sayac))
    print("-" * 78)
    for i, t, tag, l in ev:
        if tag == "ZEKA-NABIZ" and sayac[tag] > 5:
            continue
        print(l[:300])
    print("-" * 78)
    print("OTOMATIK CIKARIM")
    ok = lambda m: print("  [OK]    " + m)
    uy = lambda m: print("  [SORUN] " + m)
    kt = lambda m: print("  [KONTROL] " + m)
    if not any(e[2] == "ZEKA-OLUM" and "baslatildi" in e[3] for e in ev):
        uy("ZEKA-OLUM baslangic satiri YOK: fnc_olumBolgesi yuklenmedi / PREP eksik (v8.60 paketi tam mi?)")
    else:
        ok("zeka katmani baslatildi")
    ol = [e for e in ev if e[2] == "ZEKA-OLUM" and "| kayip |" in e[3]]
    bil = [e for e in ev if e[2] == "ZEKA-OLUM" and "BILINMIYOR" in e[3]]
    if ol:
        ok("olum bolgesi kaydi: %d (katil konumu bilinmeyen: %d)" % (len(ol), len(bil)))
    elif bil:
        uy("kayip oldu ama katil konumu %d kez BILINMIYOR -> bolge yazilamadi (isim eslesmesi / cmdSit eski)" % len(bil))
    else:
        kt("olum bolgesi hic yazilmadi (kayip olmadi mi?)")
    if rota:
        ok("rota planlamasinda olum bolgesi gozcusu kullanildi: %d satir; ornek: %s" % (len(rota), rota[0][:200]))
    elif ol:
        kt("olum bolgesi var ama rota planlamasi onu kullanmadi (hedef 90-600 m araliginda yaklasma olmadi mi?)")
    pu = [e for e in ev if e[2] == "ZEKA-PUSU"]
    if pu:
        tepki = [e for e in pu if "TEPKI:ASSAULT" in e[3] or "TEPKI:DELAY" in e[3]]
        print("      ZEKA-PUSU: %d gozlem | %d tepki (ASSAULT/DELAY)" % (len(pu), len(tepki)))
        if pu and not tepki:
            kt("pusu imzasi goruldu ama kural hic tepki vermedi (yakin+zayif ya da uzak+saglikli kombinasyonu)")
    tb = [e for e in ev if e[2] == "ZEKA-TEMAS"]
    if tb:
        ani = [e for e in tb if re.search(r"sakin sure:(\d+)", e[3]) and int(re.search(r"sakin sure:(\d+)", e[3]).group(1)) >= 25]
        print("      ZEKA-TEMAS: %d yeni temas | ani (>=25 sn sakin) %d" % (len(tb), len(ani)))
    for tag, ad, baslangic in [("ZEKA-HAZIRLIK", "hucum hazirlik penceresi", None), ("ZEKA-BASKI", "baski tufekcisi atamasi", "baslatildi"), ("ZEKA-YAN", "yan koruma / arka emniyet", "baslatildi"), ("ZEKA-NOKTA", "nokta elemani (traveling overwatch)", "baslatildi"), ("ZEKA-YETIM", "tek kalan katilimi", "baslatildi"), ("PANIK", "panik / felc", "baslatildi"), ("GIZLI", "gizli algi (ayak sesi + isik)", "baslatildi"), ("MEKANIZE", "mekanize dur-kalk izleyici", "baslatildi"), ("ARAC-MEDEVAC", "aracli medevac", "baslatildi"), ("HALT", "halt (slot kovalama kesici)", "baslatildi"), ("GOZCU", "ileri gozcu + RTO", "baslatildi"), ("CEPHANE", "cephane + bomba paylasimi", "baslatildi"), ("TEHLIKE-ALANI", "yol gecisi", "baslatildi"), ("BAYGIN-ROE", "bayilana patlayici iptali", None), ("TCCC-DURGUN", "hekim durgun mudahale", None), ("SINSI-GERI", "sinsi geri cekilme", "baslatildi"), ("ACE-TEDAVI", "ACE tedavi olaylari", None), ("HQ-DESTEK", "destek atesi", None), ("LIDER-DEVRI", "lider devri", None), ("LIDER-DEVRI-HALEF", "lider halef degisimi", None), ("CEPHANE-NEDEN", "cephane verici yok nedeni", None), ("CEPHANE-TANI", "cephane dusuk cephane tanisi", None), ("BUDDY-ES", "MG / AT asistan cifti", None), ("SIS-EKONOMI", "sis ekonomisi", None), ("ARAC-SENKRON", "arac piyade senkronu", None), ("PLAN", "komutan plani", None), ("PLAN-OZET", "plan sonuc / AAR", None), ("PLAN-KAPI", "plan sunucu kapisi", None), ("PLAN-ISTEK", "plan istegi (istemci)", None), ("PLAN-DEVIR", "grup sahipligi sunucuya devri", None), ("SUNUCU-DEVIR", "AI grubu sunucuya devir", "baslatildi"), ("TELEMETRI", "telemetri", "baslatildi"), ("TELEMETRI-SUNUCU", "sunucu fps / ozet", None), ("TELEMETRI-GRUP", "grup telemetrisi", None), ("HIZ-ANOMALI", "yaya hiz anomalisi", None), ("DONUS-OZET", "donus animasyonu", None), ("GOREV-ATAMA", "Zeus gorev atamasi", None), ("KARAKOL", "karakol / HQ kaydi + alarm", None), ("TASIMA", "arac nakli", None), ("ARAC-SURUCU", "gorevli arac surucu durumu", None), ("PLAN-RECON", "recon (kesif unsuru)", None), ("PLAN-ISTIHBARAT", "istihbarat raporu / iddia farki", None), ("PLAN-ZARAR", "atis sonrasi sivil / dost kaybi", None), ("KARAKOL-GARNIZON", "karakol garnizonu", "baslatildi"), ("KARAKOL-GARNIZON-OZET", "garnizon ozeti", None), ("KARAKOL-YANIT", "garnizon yaniti", None), ("TAKSI", "arac taksisi", "baslatildi"), ("EZME", "ezme korumasi (fren)", "baslatildi"), ("EZME-BAYGIN", "dost yaya bayildi + yakin arac", None), ("EZME-NABIZ", "ezme korumasi nabzi", None), ("OYUNCU-KOMUTA", "oyuncu komutasi gruplari", None), ("GIYIM-TANI", "giyim / techizat tanisi", "baslatildi"), ("MURETTEBAT-KORU", "arac murettebat koruma", "baslatildi"), ("KARAKOL-ISTEK", "karakol istegi (istemci)", None), ("PLAN-ATAMA", "plan: atamali gruplar / rol ezme", None), ("PLAN-YANIT", "plan sunucu yaniti", None), ("PLAN-UYARI", "manuel nokta uyarisi", None), ("PLAN-MANUEL", "manuel plan noktasi", None), ("PLAN-TOPCU", "topcu destegi", None), ("PLAN-ROE", "plan ROE", None), ("MERMI", "mermi disiplini", "baslatildi")]:
        satir = [e for e in ev if e[2] == tag]
        if baslangic:
            if not any(baslangic in e[3] for e in satir):
                kt("%s: baslangic satiri YOK (v8.63+ paketi tam mi / PREP eksik mi?)" % ad)
                continue
        etk = [e for e in satir if baslangic is None or baslangic not in e[3]]
        if etk:
            ok("%s: %d olay (ornek: %s)" % (ad, len(etk), etk[0][3][:170]))
        else:
            kt("%s: calisti ama olay yok (kosul olusmadi: grup boyutu / hareket / temas muhtemel / MG var?)" % ad)
    hq = [e for e in ev if e[2] == "HQ-MODUL"]
    if any("OTOMATIK" in e[3] for e in hq):
        ok("HQ otomatik acildi")
    elif hq and any("AKTIF" in e[3] for e in hq):
        ok("HQ Zeus modulu ile aktif")
    else:
        kt("HQ KAPALI: Zeus 'ELITE Kumanda (HQ)' modulu yok ve lambs_danger_hqOtomatik acik degil (istihbarat paylasimi / kanat / takviye devre disi)")
    print()


def form_teshis(path):
    L = open(path, encoding="utf-8", errors="replace").read().splitlines()
    rx = re.compile(r'^\s*(\d+:\d\d:\d\d)\s+"?\[FORM-DEGISIM\]\s+(.+?)\s+\|\s+(.+?)\s+->\s+(.+?)\s+\|\s+karar:(\S+)')
    gr = collections.defaultdict(list)
    for l in L:
        m = rx.match(l)
        if m:
            gr[m.group(2)].append((sn(m.group(1)), m.group(3), m.group(4), m.group(5)))
    print("=" * 78)
    print(path, "| FORMASYON DEGISIM TESHISI")
    if not gr:
        print("  [OK]    [FORM-DEGISIM] satiri yok (formasyon degismedi ya da log kapali)")
        return
    for g, ev in gr.items():
        hizli = [(ev[i], ev[i + 1]) for i in range(len(ev) - 1) if ev[i + 1][0] - ev[i][0] < 20]
        cift = collections.Counter((e[1], e[2]) for e in ev)
        durum = "[SORUN]" if len(hizli) >= 4 else "[OK]   "
        print("  %s %s: %d degisim | <20 sn aralikli ardisik: %d | karar: %s" % (durum, g, len(ev), len(hizli), collections.Counter(e[3] for e in ev).most_common(2)))
        if len(hizli) >= 4:
            print("          en sik gecis:", cift.most_common(2), "-> salinim (formasyon felci); kok neden: taktik yeniden cagrilinca eski zamanlayici formasyon geri yaziyor (v8.61 ile giderildi)")
    # v8.80 formSet hakemi: hangi kaynak kac kez yazdi / kac kez atlandi
    uyg, atl = collections.Counter(), collections.Counter()
    for l in open(path, encoding="utf-8", errors="replace").read().splitlines():
        m = re.search(r"\[FORM-SET\] .*?\| (ATLANDI )?.*?kaynak:([a-z0-9-]+)", l)
        if m:
            (atl if m.group(1) else uyg)[m.group(2)] += 1
    if uyg or atl:
        print("  [FORM-SET] uygulanan kaynaklar:", dict(uyg.most_common()), "| hakemin ATLADIGI kaynaklar:", dict(atl.most_common()))
    print()

def kayip_tablosu(path):
    """Taraf basina olu + bayilan (ACE: gorev 'Incapacitated') sayisi. Taraf: [ZEKA-OLUM] (WEST / EAST / GUER) ve [DOKTRIN-PROFIL] fraksiyon adindan cikarilir."""
    L = open(path, encoding="utf-8", errors="replace").read().splitlines()
    taraf = {}
    for l in L:
        m = re.search(r"\[ZEKA-OLUM\] (Alpha [0-9-]+) \((WEST|EAST|GUER|INDEPENDENT)\)", l)
        if m:
            taraf[m.group(1)] = m.group(2)
    for l in L:
        m = re.search(r"\[DOKTRIN-PROFIL\] (Alpha [0-9-]+) \| faction:([A-Za-z0-9_]+)", l)
        if m and m.group(1) not in taraf:
            f = m.group(2).lower()
            taraf[m.group(1)] = "EAST" if any(k in f for k in ("opf", "ists", "rus", "chn", "taliban", "irgc")) else ("GUER" if any(k in f for k in ("ind", "guer", "fia", "aaf", "nato_")) else "WEST")
    bayilan = {}
    for l in L:
        m = re.search(r"\[DURUM\] (Alpha [0-9-]+) \| ([A-Za-z' -]+?) \|.*gorev:Incapacitated", l)
        if m:
            bayilan.setdefault(m.group(1), set()).add(m.group(2).strip())
    olu = {}
    for l in L:
        m = re.search(r"\[OLAY\] (Alpha [0-9-]+) \| Casualty \| \[\"?\"?([^\"]+)", l)
        if m:
            olu.setdefault(m.group(1), set()).add(m.group(2))
    print("=" * 78)
    print(path, "| KAYIP TABLOSU (olu = Casualty olayi, bayilan = [DURUM] gorev:Incapacitated; ikisi ust uste olabilir)")
    ozet = {}
    for g in sorted(set(bayilan) | set(olu) | set(taraf)):
        t = taraf.get(g, "?")
        o, b = len(olu.get(g, ())), len(bayilan.get(g, ()))
        print("  %-10s %-6s olu:%-3d bayilan:%-3d" % (g, t, o, b))
        ozet.setdefault(t, [0, 0])
        ozet[t][0] += o
        ozet[t][1] += b
    for t, (o, b) in ozet.items():
        print("  TOPLAM %-6s olu:%d bayilan:%d etkisiz(toplam):%d" % (t, o, b, o + b))
    print("  NOT: 'etkisiz' ust uste sayilmis olabilir (bayilip olenler iki satirda). Hedef tablo: kaynaklar_doktrin/arastirma_gerceklik/README_GERCEKLIK_KALIBRASYON.md")
    print()


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
    karne_modu = False
    hava_ied_modu = False
    zeka_modu = False
    form_modu = False
    kayip_modu = False
    yollar = []
    i = 0
    while i < len(args):
        if args[i] == "--grup" and i + 1 < len(args):
            grup = args[i + 1]; i += 2
        elif args[i] == "--aralik" and i + 1 < len(args):
            aralik = args[i + 1]; i += 2
        elif args[i] == "--karne":
            karne_modu = True; i += 1
        elif args[i] == "--anomali":
            sadece_anomali = True; i += 1
        elif args[i] == "--hava-ied":
            hava_ied_modu = True; i += 1
        elif args[i] == "--zeka":
            zeka_modu = True; i += 1
        elif args[i] == "--form":
            form_modu = True; i += 1
        elif args[i] == "--kayip":
            kayip_modu = True; i += 1
        else:
            yollar.append(args[i]); i += 1
    if not yollar:
        print(__doc__)
        sys.exit(1)
    for p in yollar:
        if kayip_modu:
            kayip_tablosu(p)
        elif form_modu:
            form_teshis(p)
        elif zeka_modu:
            zeka(p)
        elif hava_ied_modu:
            hava_ied(p)
        elif karne_modu:
            karne(p)
        elif grup:
            print("=" * 78); print(p, "| grup:", grup, "| aralik:", aralik or "tum")
            zaman_cizelgesi(p, grup, aralik)
        elif sadece_anomali:
            print("=" * 78); print(p)
            anomali_listesi(p, aralik)
        else:
            ozet(p)
