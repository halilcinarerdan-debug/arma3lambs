#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RPT OZETLEYICI (lambs_danger ELITE fork)
Kullanim:  python tools/rpt_ozet.py Arma3_x64_....rpt [baska.rpt ...]
           --onucus             ON UCUS karnesi (v8.500l): oyun basinda yapilandirma durumu: oturumlar, 3DEN nitelik (EDEN-IFADE dahil), grup / arac / topcu / IHA envanteri, kapasite, UYARI listesi
           --karne              TOPLU TEST KARNESI: her ozellik icin OK / KONTROL / YOK + kanit (en hizli okuma)
           --kabul              KABUL TESTI (v8.684): v8.656+ degisikliklerinin oyunda dogrulanmasi; her madde GECTI / KALDI / KONTROL / VERI YOK + kanit (TEST_PROTOKOLU.md ile)
           --form               FORMASYON DEGISIM TESHISI: grup basina [FORM-DEGISIM] sayisi, <20 sn aralikli salinim (felc) tespiti
           --tani               NET TANI (v8.255): [OLUM-TANI] [HENDEK-DURUM] [ARAC-TERK] [ARAC-HAREKET] [TANI-TOPCU] [KAYIP-DEGERLENDIRME] [ARAC-DUMAN] ozeti + otomatik cikarim
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
        "KOMUTAN-BEKLE", "KOMUTAN-FORM", "ROL-GOREV", "SIS", "TCCC", "SAHA", "BUDDY", "SIPER-ANALIZ", "DOKTRIN-PROFIL", "OLAY", "YIGILMA-NEDEN", "YIGILMA-COZ", "YIGILMA-BAYGIN", "YIGILMA-OZET", "TCCC-DURUS", "CQB-CEVIK", "CQB-CEVIK-OZET", "OZGUVEN", "OZGUVEN-OZET", "ISINLANMA", "STEALTH-SES", "EDEN-POZISYON", "POZISYON-SEC", "MEVZI-POZ", "CM-DEGIS", "HAVA-AA", "LAMBS-RPG", "ATES-HATTI-OZET", "BND-BASKI-YON", "BND-FORM-SALINIM", "BND-MG-YER", "TEHLIKE-ACIK"]
BEKLENEN_SURUM = "v8.829"   # her surumde guncelle (karne SURUM satiri eski paket yuklu mu diye kontrol eder)
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
    dd = [l for l in satirlar if "[DURUS-DISIPLIN-OZET]" in l]
    print("\n-- DURUS DISIPLINI (v8.668: temasta hareketsiz ayakta asker) --")
    if dd:
        for l in dd[-4:]: print("  ", l.split('"')[1][:260] if '"' in l else l[:260])
        top = [0, 0, 0, 0]
        for l in dd:
            for i, k in enumerate(["durgun + ayakta \\(temasta\\) (\\d+)", "yat (\\d+)", "comel (\\d+)", "direnen\\) (\\d+)"]):
                m = re.search(k, l)
                if m: top[i] += int(m.group(1))
        print("  toplam: durgun+ayakta %d | yat %d | comel %d | AI ayaga kaldirdi %d" % tuple(top))
    else:
        print("  yok (temasta hareketsiz AYAKTA asker bulunmadi ya da durusDisiplin kapali; v8.668+ gerekir)")
    print("\n-- v8.669 PLANLI MANEVRA KATMANLARI (hakim nokta / kanat baskisi / sektor plani / geri cekilme bacagi / FOV) --")
    for etiket, aciklama in [
        ("[MG-HAKIM]", "MG / nisanci / AT hakim noktaya gecti"),
        ("[KANAT-BASKI]", "kanat: baski ekibi kapisi (KURULDU / BITTI / KAYIP)"),
        ("[SEKTOR-PLAN]", "sektor atamasi (yanal sirali)"),
        ("[GERI-CEKILME-BACAK]", "geri cekilme bacagi yenilendi"),
        ("[TEMAS-SONRASI]", "temas sonrasi sessizlikte COMBAT -> AWARE"),
        ("[AVANTAJLI-YER]", "avantajli yer (GERI / SAVUNMA / BND: arazi + koy / ev)"),
        ("[SAVUNMA-YER]", "HOLD: manga avantajli yere yerlesti"),
        ("[GERI-CEKILME-EZME-TANI]", "geri cekilme: koşu emri bozuldu (ezen sistem adaylari)"),
        ("[GERI-CEKILME-KORUMA]", "geri cekilme: formasyona donen koşu emri yeniden verildi"),
        ("[DOFOLLOW-ATLA]", "korumali doFollow: retreat / temas kes / kacis sirasinda serbest birakma atlandi"),
        ("[SNIPER-GOZLEMCI]", "sniper gozlemcisi nisanciya yaklastirildi"),
        ("[GERI-CEKILME-KOSU-MODU]", "geri cekilme: takilan asker kosu moduna alindi (AWARE + hedef alma kapali)"),
    ]:
        ls = [l for l in satirlar if etiket in l]
        print("  %s %s: %d satir" % (etiket, aciklama, len(ls)))
        for l in ls[:3]: print("     ", l.split('"')[1][:230] if '"' in l else l[:230])
    pd = [l for l in satirlar if "[PERF-DUSUN]" in l]
    print("  [PERF-DUSUN] izleyici dongu hizi (gerceklesen / istenen; ~1-1.5 saglikli, >= 2 yavas): %d ozet" % len(pd))
    for l in pd[-2:]: print("     ", l.split('"')[1][:420] if '"' in l else l[:420])
    fv = [l for l in satirlar if "[FOV-OLCUM]" in l and "derece" in l]
    if fv:
        print("  [FOV-OLCUM] bakis acisi kovalarina gore bilinen dusman orani (son %d ozet):" % min(3, len(fv)))
        for l in fv[-3:]: print("     ", l.split('"')[1][:330] if '"' in l else l[:330])
    else:
        print("  [FOV-OLCUM] yok (v8.669+; temasli AI, hatti acik 15-250 m dusman, >= 20 cift gerekir)")
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

def kabul(path):
    """KABUL TESTI (v8.684): her madde GECTI / KALDI / KONTROL / VERI YOK + kanit. VERI YOK = senaryo o ozelligi tetiklemedi (TEST_PROTOKOLU.md'deki ilgili senaryoyu calistir)."""
    L = open(path, encoding="utf-8", errors="replace").read().splitlines()
    t = "\n".join(L)
    sat = []
    def ekle(ad, d, k): sat.append((ad, d, k))
    def say(etiket): return len([1 for l in L if ("[%s]" % etiket) in l])
    def zaman(l):
        m = re.match(r"\s*(\d+:\d\d:\d\d)", l)
        return sn(m.group(1)) if m else None
    b = re.search(r"build (v[0-9.]+[A-Z-]*)", t)
    ekle("SURUM", "GECTI" if b and b.group(1).startswith(BEKLENEN_SURUM) else "KALDI", ("%s (beklenen %s)" % (b.group(1), BEKLENEN_SURUM)) if b else "boot satiri yok")
    hata = 0
    yabanci = 0
    for i, l in enumerate(L):
        if ("Error in expression" in l or "Error position" in l or "Error Undefined" in l or "Error Type" in l or "Error Zero" in l) and not any(n in " ".join(L[i:i + 3]) for n in NOISE):
            # v8.708: bagiminda lambs / ELITE / fnc_ gecen hata bizim; digerleri yabanci mod (RPT 1e81987e: 166 satirin hepsi 4 sn'de partikul efekti ifadeleri: directionX / humidity interpolate / distToSurface)
            blok = " ".join(L[max(i - 2, 0):i + 8]).lower()
            if "lambs" in blok or "elite" in blok or "fnc_" in blok:
                hata += 1
            else:
                yabanci += 1
    ekle("SCRIPT HATASI", "GECTI" if hata == 0 else "KALDI", "%d satir (LAMBS / ELITE baglamli)%s" % (hata, (" | yabanci mod (partikul / efekt ifadeleri vb.): %d satir, bizim kod degil" % yabanci) if yabanci else ""))

    # --- 1) DUSUNME HIZI (izleyici dongu hizi; n >= 20 olanlar; ~1-1.5 saglikli, >= 2 yavas)
    oranlar = []
    for l in L:
        if "[PERF-DUSUN]" not in l: continue
        for m in re.finditer(r"(\w+) x([0-9.]+) \(n (\d+),", l):
            if int(m.group(3)) >= 20: oranlar.append((float(m.group(2)), m.group(1), int(m.group(3))))
    if oranlar:
        mx = max(oranlar)
        ekle("DUSUNME HIZI", "GECTI" if mx[0] < 2.0 else "KALDI", "en yavas izleyici %s x%.2f (n %d); %d izleyici-penceresi olculdu, >= 2.0 olan: %d" % (mx[1], mx[0], mx[2], len(oranlar), len([1 for o in oranlar if o[0] >= 2.0])))
    else:
        ekle("DUSUNME HIZI", "VERI YOK", "[PERF-DUSUN] yok (60 sn dolmadi ya da perfOlcum kapali)")

    # --- 2) KOMUTAN KARARLILIGI (TELEMETRI-GRUP: karar:X (N sn once) -> karar baslangic zamani = satir zamani - N)
    ser = collections.defaultdict(list)
    for l in L:
        m = re.search(r"\[TELEMETRI-GRUP\] (Alpha [\d-]+|[^|]+?) \| (\w+) \|.*?\| karar:([A-Z_]+) \((\d+) sn once\)", l)
        z = zaman(l)
        if m and z is not None:
            dm_ = re.search(r"en yakin dusman:(\d+) m", l)
            ser[(m.group(1).strip(), m.group(2))].append((z - int(m.group(4)), m.group(3), z, int(dm_.group(1)) if dm_ else 9999))
    ATAK = {"BOUNDING", "FLANK", "ASSAULT", "SUPPRESS_ASSAULT"}
    SAV = {"DELAY", "HOLD"}
    kisa, gecis, aba = [], 0, 0
    for k, v in ser.items():
        v.sort()
        kar = []
        for bs, kr, z, dm in v:
            if kar and kar[-1][1] == kr and abs(kar[-1][0] - bs) <= 4: continue
            kar.append([bs, kr, dm])
        for i in range(len(kar) - 1):
            gecis += 1
            if kar[i][1] in SAV and kar[i + 1][1] in ATAK:
                # v8.821: savunma karari dusman <= 30 m iken verilmisse (yakin temas: PUSH / hucum mesru) kisa gecis sayilmaz
                if kar[i + 1][0] - kar[i][0] < 25 and kar[i][2] > 30: kisa.append((k, kar[i][1], kar[i + 1][1], kar[i + 1][0] - kar[i][0]))
        for i in range(len(kar) - 2):
            if kar[i][1] in ATAK and kar[i + 1][1] in SAV and kar[i + 2][1] in ATAK and kar[i + 2][0] - kar[i][0] < 90: aba += 1
    if ser:
        ekle("KOMUTAN KARARLILIGI", "GECTI" if not kisa else "KALDI", "%d grup, %d karar gecisi | savunma -> hucum 25 sn'den kisa: %d %s | hucum-savunma-hucum (90 sn icinde): %d" % (len(ser), gecis, len(kisa), kisa[:2] if kisa else "", aba))
    else:
        ekle("KOMUTAN KARARLILIGI", "VERI YOK", "[TELEMETRI-GRUP] karar satiri yok")

    # --- 3) BIRIM EMIR GIDIP-GELME (MOVE -> STOP -> MOVE <= 4 sn)
    eg = [l for l in L if "[EMIR-GIDIP-GELME]" in l]
    if eg:
        st = sum(int(m.group(1)) for l in eg for m in [re.search(r"MOVE -> STOP (\d+)", l)] if m)
        tr = sum(int(m.group(1)) for l in eg for m in [re.search(r"ters donus \(.*?\) (\d+)", l)] if m)
        # v8.707: 'siperOtur' = acikSiper'in KENDI siper-noktasina-otur doMove'u (kasitli); orana katilmaz, ham sayi yine yazilir (eski RPT'lerde alan yok = 0)
        kas = sum(int(m.group(1)) for l in eg for m in [re.search(r"siperOtur (\d+) \(kasitli\)", l)] if m) + sum(int(m.group(1)) for l in eg for m in [re.search(r"retreatEmir (\d+) \(kasitli\)", l)] if m)
        lg_ = sum(int(m.group(1)) for l in eg for m in [re.search(r"lambsGorev (\d+) \(LAMBS taban kodu", l)] if m)
        oran_ham = 100.0 * tr / max(st, 1)
        oran = 100.0 * max(tr - kas, 0) / max(st, 1)
        son = re.sub(r"^.*\[EMIR-GIDIP-GELME\] ", "", max(eg, key=lambda x: len(x)))[:230]
        ekle("EMIR GIDIP-GELME", "GECTI" if oran <= 10 else ("KONTROL" if oran <= 20 else "KALDI"), "STOP %d, ters donus %d (ham %.0f%%) - kasitli (siper-oturma + retreat emri) %d = %d (%.0f%%) | bunlardan LAMBS gorev etiketli (taban kod, dolayli) %d | %s" % (st, tr, oran_ham, kas, max(tr - kas, 0), oran, lg_, son))
        td = [l for l in L if "[EMIR-TERS-DONUS]" in l]
        gv = collections.Counter(re.search(r"g:([^,\]]+)", l).group(1) for l in td if re.search(r"g:([^,\]]+)", l))
        if td:
            # kaynak siniflamasi (imza belirtecleri): acikSiper = siper arama mikro-hareketi, RET = geri cekilme sirasinda, digeri
            sinif = collections.Counter(("RET" if "RET" in im.split(",") else ("siperOtur" if "kaynak:siperOtur" in im else ("retEmir" if "kaynak:retEmir" in im else ("acikSiper" if "acikSiper" in im else "diger")))) for im in [re.search(r"imza \(STOP aninda\): ([^|]+)", l).group(1) for l in td if re.search(r"imza \(STOP aninda\): ([^|]+)", l)])
            ekle("  ters donus kaynaklari", "BILGI", "%d satir | RET (geri cekilme sirasinda): %d | siperOtur (kasitli, v8.707+): %d | acikSiper (diger siper arama): %d | diger: %d | gorev dagilimi %s | ornek: %s" % (len(td), sinif["RET"], sinif["siperOtur"], sinif["acikSiper"], sinif["diger"], dict(gv.most_common(4)), re.sub(r"^.*\[EMIR-TERS-DONUS\] ", "", td[0])[:150]))
    else:
        ekle("EMIR GIDIP-GELME", "VERI YOK", "[EMIR-GIDIP-GELME] yok (v8.684+ ve temasli grup gerekir)")

    # --- 4) RETREAT (varis, koruma, ezme tanisi)
    vr = [(int(m.group(1)), int(m.group(2))) for l in L for m in [re.search(r"sonuc \| vardi:(\d+)/(\d+)", l)] if m]
    if vr:
        a_, b_ = sum(x for x, _ in vr), sum(y for _, y in vr)
        ekle("RETREAT VARIS", "GECTI" if a_ >= 0.5 * b_ else "KALDI", "%d/%d (%.0f%%) | koruma yeniden-emir:%d  doFollow atlandi:%d  ezme tanisi:%d  durgun sicrama:%d" % (a_, b_, 100.0 * a_ / max(b_, 1), say("GERI-CEKILME-KORUMA"), say("DOFOLLOW-ATLA"), say("GERI-CEKILME-EZME-TANI"), say("GERI-CEKILME-DURGUN")))
    else:
        ekle("RETREAT VARIS", "VERI YOK", "retreat olmadi (senaryo B: zayif grup)")

    # --- 5) TCCC BEKLEME (baygin dusman artik tehdit degil)
    # v8.714: bekleme ATES ALTINDA ise (son ates <= 10 sn) tasarim geregi (tcccKatiGuvenlik: catismada ilk yardim yok; RPT 4c87bab5: 4 uzun bekleme 96-183 sn, hepsinde 'son ates 1-2 sn once' = sureklli carpisma, ACE Medical YOK -> vanilla HealSoldier yolu); puan yalniz SESSIZKEN (son ates > 10 sn) bekleyenlere gore verilir
    bk_t = [(int(m.group(2)), int(m.group(1))) for l in L for m in [re.search(r"\[TCCC-BEKLE\].*son ates (\d+) sn once.*bekliyor (\d+) sn", l)] if m]
    bk = [int(m.group(1)) for l in L for m in [re.search(r"\[TCCC-BEKLE\].*bekliyor (\d+) sn", l)] if m]
    tc = len([1 for l in L if "[TCCC]" in l and "hekim" in l and "IPTAL" not in l])
    if bk or tc:
        mb = max(bk) if bk else 0
        sess = [b for b, a in bk_t if a > 10]
        ms = max(sess) if sess else 0
        ekle("TCCC BEKLEME", "GECTI" if ms <= 90 else ("KONTROL" if ms <= 180 else "KALDI"), "en uzun bekleme %d sn (%d satir) | SESSIZKEN (son ates > 10 sn) en uzun %d sn | ates altinda bekleme tasarim geregi (tcccKatiGuvenlik) | tedaviye giden hekim: %d" % (mb, len(bk), ms, tc))
    else:
        ekle("TCCC BEKLEME", "VERI YOK", "yarali / hekim olayi yok")

    # --- 6) DURUS DISIPLINI + TEMAS SONRASI + COMBAT
    dd = [l for l in L if "[DURUS-DISIPLIN-OZET]" in l]
    if dd:
        ekle("DURUS DISIPLINI", "GECTI", "%d ozet | son: %s" % (len(dd), re.sub(r"^.*\[DURUS-DISIPLIN-OZET\] ", "", dd[-1])[:150]))
    else:
        ekle("DURUS DISIPLINI", "VERI YOK", "hareketsiz ayakta asker olusmadi (temas + durma gerekir)")
    tyc = len([1 for l in L if "[ANOMALI] TEMAS-YOK-COMBAT" in l])
    hic = len([1 for l in L if "[ANOMALI] COMBAT-HIC-TEMAS" in l])
    ekle("COMBAT'TA KALMA", "GECTI" if tyc == 0 else "KALDI", "TEMAS-YOK-COMBAT anomali:%d | temas-sonrasi gevseme:%d | COMBAT-HIC-TEMAS (bayrak hic kurulmadi, v8.707+): %d" % (tyc, len([1 for l in L if "[TEMAS-SONRASI]" in l and "sessizlik" in l and "baslatildi" not in l]), hic))
    ya = [l for l in L if "[ANOMALI] YURUMUYOR" in l]
    yy = len(ya)
    # v8.708: sahip / lider alanlari (yoksa eski RPT)
    yh = [l for l in ya if "| sahip:" in l]
    if yh:
        yl = len([1 for l in yh if re.search(r"sahip:(LAMBS|TUTAN)", l)])
        yld = len([1 for l in yh if "lider:true" in l])
        yel = len([1 for l in yh if not re.search(r"sahip:(LAMBS|TUTAN)", l)])
        ekle("YURUMUYOR ANOMALISI", "GECTI" if yel <= 3 else "KONTROL", "%d satir | LAMBS / TUTAN sahipli (ELITE yonetmiyor): %d | ELITE yonetimindeki: %d | lider olan: %d (kisa acik-siper / bomba kacisi anlari normal)" % (yy, yl, yel, yld))
    else:
        ekle("YURUMUYOR ANOMALISI", "GECTI" if yy <= 3 else "KONTROL", "%d satir (kisa acik-siper / bomba kacisi anlari normal; kalici takilma degil; sahip alani yok = v8.708 oncesi RPT)" % yy)

    # --- 7) FOV / ALGI KAYNAGI (mesafe x aci)
    fv = [l for l in L if "[FOV-OLCUM] 60 sn" in l]
    if fv:
        blok = collections.defaultdict(lambda: {"cift": 0, "bilen": 0.0, "arkaC": 0, "arkaB": 0.0, "kaynak": [0, 0, 0, 0]})
        for l in fv:
            for bl in l.split(" || "):
                m = re.search(r"MESAFE (.+?) \(toplam (\d+)\)", bl)
                if not m: continue
                ad = m.group(1)
                if "KAPALI" in ad: ad = "yakin (azaltici KAPALI)"
                for mm in re.finditer(r"(\d+)-(\d+): (\d+) cift (\d+) %", bl):
                    lo, c, p = int(mm.group(1)), int(mm.group(3)), int(mm.group(4))
                    blok[ad]["cift"] += c; blok[ad]["bilen"] += c * p / 100.0
                    if lo >= 90: blok[ad]["arkaC"] += c; blok[ad]["arkaB"] += c * p / 100.0
                mk = re.search(r"ses (\d+) / grup (\d+) / yakin (\d+) / aciklanamayan (\d+)", bl)
                if mk:
                    for i in range(4): blok[ad]["kaynak"][i] += int(mk.group(i + 1))
        parcalar = []
        yorum = ""
        yak = uz = None
        for ad, v in blok.items():
            pc = 100.0 * v["arkaB"] / v["arkaC"] if v["arkaC"] else None
            tp = 100.0 * v["bilen"] / v["cift"] if v["cift"] else None
            k = v["kaynak"]
            parcalar.append("%s: cift %d, bilen %s, ARKA(>=90) cift %d bilen %s | kaynak ses/grup/yakin/aciklanamayan %d/%d/%d/%d" % (ad, v["cift"], ("%.0f%%" % tp) if tp is not None else "-", v["arkaC"], ("%.0f%%" % pc) if pc is not None else "-", k[0], k[1], k[2], k[3]))
            if ad.startswith("yakin") and v["arkaC"] >= 5: yak = pc
            if ad.startswith("60-250") and v["arkaC"] >= 5: uz = pc
        if yak is not None and uz is not None:
            if yak >= 80 and uz <= 50: yorum = "YORUM: arka yari algisi yakinda ~yuksek, uzakta dusuk -> azaltici katmanlarin yakinda kapanmasi (yakinAlgiM) kullanici hipotezini DESTEKLIYOR"
            elif uz >= 80: yorum = "YORUM: arka yari algisi UZAK mesafede de yuksek -> neden yakinAlgi DEGIL; kaynak sutunlarina bak (aciklanamayan agirlikliysa motor / 360 derece algi)"
            else: yorum = "YORUM: karma sonuc; daha fazla ornek gerekir"
        ekle("ALGI KAYNAGI (FOV)", "BILGI", " || ".join(parcalar) + (" || " + yorum if yorum else ""))
    else:
        ekle("ALGI KAYNAGI (FOV)", "VERI YOK", "[FOV-OLCUM] yok (hatti acik 12-250 m dusman, >= 20 cift ve >= 60 sn temas gerekir)")
    kz = [l for l in L if "[FOV-OLCUM-KAMUFLAJ]" in l]
    ya = [l for l in L if "[YAKIN-ALGI-OZET]" in l]
    sfr = sum(int(m.group(1)) for l in kz for m in [re.search(r"<= 0.05 olan ornek (\d+)", l)] if m) + sum(int(m.group(1)) for l in ya for m in [re.search(r"<= 0.05 olup 1.0 sayilan (\d+)", l)] if m)
    sfr += len([1 for l in L if re.search(r"\[YAKIN-ALGI\] .*camouflageCoef 0\.0[0-5] ->", l)])   # eski surum (v8.683-) 0.00'i dogrudan loglar; yeni surum 1.0 sayip ozette bildirir
    ekle("camouflageCoef <= 0.05", "GECTI" if (kz or ya) and sfr == 0 else ("KONTROL" if sfr else "VERI YOK"), "sifira yakin katsayi gorulen ornek / giris: %d (0.00 = 'gorunmez'; yakinAlgi artik 1.0 sayar, kaynagi arastirilmali)" % sfr if (kz or ya) else "olcum satiri yok")
    yg = [l for l in L if "[YAKIN-ALGI]" in l and "dusman <=" in l]
    if yg or ya:
        ekle("YAKIN ALGI KATMANI", "BILGI", "azaltici katmanlar kapanan giris: %d (ilk 15 log) | %s" % (len(yg), re.sub(r"^.*\[YAKIN-ALGI-OZET\] ", "", ya[-1])[:140].rstrip('"') if ya else ""))

    # --- 8) UGL SIKLIGI (atici basina dakika)
    ugl = collections.defaultdict(list)
    for l in L:
        m = re.search(r"\[UGL-KARAR\] (Alpha [\d-]+) \| ([^|]+?) \| hedef (\d+) m", l)
        z = zaman(l)
        if m and z is not None: ugl[(m.group(1), m.group(2))].append(z)
    if ugl:
        dk = max((len(v) / max((max(v) - min(v)) / 60.0, 1.0)) for v in ugl.values())
        mn = min(int(m.group(1)) for l in L for m in [re.search(r"\[UGL-KARAR\].*hedef (\d+) m", l)] if m)
        ekle("UGL SIKLIGI", "GECTI" if dk <= 6 else "KONTROL", "%d karar, %d atici, en sik atici %.1f karar/dk, en yakin hedef %d m (uglGrupAralik / uglCooldown CBA ile ayarlanir)" % (sum(len(v) for v in ugl.values()), len(ugl), dk, mn))
    else:
        ekle("UGL SIKLIGI", "VERI YOK", "UGL karari yok")

    # --- 8b) MANGALAR ARASI KOORDINASYON (v8.710; yalniz olcum: kac modul gercekten calisti)
    ist = len([1 for l in L if "[HQ-ISTIHBARAT] " in l and "muhbir " in l])
    kan = len([1 for l in L if "[HQ-KANAT]" in l and "EMIR:" in l])
    des = len([1 for l in L if "[HQ-DESTEK]" in l and "EMIR" in l])
    des_t = len([1 for l in L if "[HQ-DESTEK]" in l and "EMIR" in l and "destek temasta:true" in l])
    fei = len([1 for l in L if "[HQ-FEINT]" in l and "EMIR" in l])
    tak = len([1 for l in L if "[HQ-TAKVIYE]" in l and "EMIR" in l])
    kom = len([1 for l in L if "[GAFIL]" in l and "BEKLEME BITTI" in l and "neden: komsu" in l])
    nd = [m.group(1) for l in L for m in [re.search(r"\[HQ-DESTEK-OZET\].*?(musait destek grubu yok:\d+)", l)] if m]
    ekle("MANGALAR ARASI KOORD.", "BILGI", "istihbarat raporu %d | kanat emri %d | destek atesi emri %d (temasli B: %d) | feint %d | takviye %d | gafil KOMSU sinyali %d | destek 'musait' yok sayaci (son): %s" % (ist, kan, des, des_t, fei, tak, kom, nd[-1] if nd else "-"))

    # --- 8d) CQB SESSIZLIK (v8.720): bot konusmasi, en yakin GERCEK dusman cqbSessizM icindeyken olmamali
    mM = [int(m.group(1)) for l in L for m in [re.search(r"CQB sessiz \(el isareti\) true / (\d+) m", l)] if m]
    if mM:
        eM = max(mM)
        bk = [l for l in L if "[KONUSMA-OLAY]" in l and "(bot)" in l]
        ic = 0
        for l in bk:
            m = re.search(r"en yakin dusman (\S+) m", l)
            if m and m.group(1) != ">400" and int(m.group(1)) <= eM: ic += 1
        ekle("CQB SESSIZLIK", "GECTI" if ic == 0 else "KALDI", "bot konusma olayi (log): %d | en yakin dusman <= %d m iken konusan: %d (0 olmali; v8.720 oncesi RPT'de bilinen-dusman kosulu yuzunden konusuyorlardi)" % (len(bk), eM, ic))

    # --- 8c) ACRE2 / OYUNCU KONUSMASI (v8.712; yalniz olcum)
    acre = any("[KONUSMA] ACRE2 algilandi" in l for l in L)
    k_olay = len([1 for l in L if "(OYUNCU) konustu" in l])
    k_duy = [l for l in L if "[KONUSMA]" in l and "konusma duyuldu" in l and "konusan OYUNCU" in l]
    k_mes = [int(m.group(1)) for l in k_duy for m in [re.search(r"\| (\d+) m \(etkin", l)] if m]
    k_ozet = sum(int(m.group(1)) for l in L for m in [re.search(r"OYUNCU konusmasi: (\d+)", l)] if m)
    ekle("OYUNCU KONUSMASI (ACRE2)", "BILGI", "ACRE2 algilandi: %s | oyuncu konusma olayi (log): %d | duyuldu (log satiri): %d%s | 60 sn ozetlerinde oyuncu konusmasi duyulma: %d" % ("evet" if acre else "hayir", k_olay, len(k_duy), (" (mesafe %d-%d m)" % (min(k_mes), max(k_mes))) if k_mes else "", k_ozet))

    # --- v8.722: sahte geri cekilme HUNISI (hangi kapida eleniyor) + el bombasi izi (bina girisi)
    hn = [0] * 7
    hn_n = 0
    for l in L:
        m = re.search(r"\[SAHTE-CEKILME-OZET\].*?HUNI.*?bayragi (\d+), LAMBS-TUTAN sahipli (\d+), binada (\d+), asker az \(< \d+\) (\d+), baski >= 0.4 (\d+), oyuncu hedef yok \(<= \d+ m\) (\d+), oyuncu < \d+ m (\d+)", l)
        if m:
            hn_n += 1
            for i in range(7): hn[i] += int(m.group(i + 1))
    if hn_n:
        ekle("SAHTE CEKILME HUNISI", "BILGI", "%d ozet | temasli grup-tur elenme: taktik/bayrak %d, LAMBS-TUTAN %d, binada %d, asker az %d, baski %d, oyuncu hedef yok %d, oyuncu cok yakin %d (en buyuk kalem = ana engel)" % ((hn_n,) + tuple(hn)))
    else:
        ekle("SAHTE CEKILME HUNISI", "BILGI", "ozet yok (v8.722 oncesi RPT ya da sahteCekilme kapali / temasli grup olmadi)")
    hf_t = 0; hf_ts = 0.0; hf_m = 0; hf_ms = 0.0; hfn = 0
    for l in L:
        m = re.search(r"\[HIZLI-FARK-OZET\] 60 sn: tetiklenen (\d+) \(ort\. gorunur->fark ([\d.]+) sn\) \| motorun kendi fark ettigi (\d+) \(ort\. gorunur->fark ([\d.]+) sn", l)
        if m:
            hfn += 1
            a, asn, b, bsn = int(m.group(1)), float(m.group(2)), int(m.group(3)), float(m.group(4))
            hf_t += a; hf_ts += a * asn; hf_m += b; hf_ms += b * bsn
    if hfn:
        ekle("HIZLI FARK (reaksiyon)", "BILGI", "%d ozet | bizim tetik %d (ort. gorunur->fark %.2f sn) | motor kendi fark etti %d (ort. %.2f sn, referans) | tetik / (tetik + motor) = %.0f%%" % (hfn, hf_t, hf_ts / max(hf_t, 1), hf_m, hf_ms / max(hf_m, 1), 100.0 * hf_t / max(hf_t + hf_m, 1)))
    else:
        ekle("HIZLI FARK (reaksiyon)", "BILGI", "ozet yok (v8.727 oncesi RPT ya da gorunen insan oyuncu olmadi)")
    cba_yok = sorted(set(re.findall(r"Setting (lambs_danger_\w+) does not exist", "\n".join(L))))
    ekle("CBA AYAR KAYDI", "GECTI" if not cba_yok else "KALDI", "kayitsiz ayar: %d %s (0 olmali; 'does not exist' = XEH_PREP'te kategori degiskeni kullanimdan once tanimli degil; v8.731 lint'i yakalar)" % (len(cba_yok), cba_yok[:6]))
    ck = len([1 for l in L if "[CIKMAZ-KIR]" in l])
    ekle("CIKMAZ KIRICI", "BILGI", "%d olay (sessiz HOLD > cikmazKirS sn -> BOUNDING; savunma tercihi HOLD'u 60 sn atlanir)" % ck)
    ot = [0, 0, 0]; otn = 0
    for l in L:
        m = re.search(r"\[SIPER-ON-TARAMA-OZET\] 60 sn: taranan (\d+) \| uzak engel \(siper degil\) (\d+) \| yakin siper bulunup gonderilen (\d+)", l)
        if m:
            otn += 1
            for i in range(3): ot[i] += int(m.group(i + 1))
    ekle("SIPER ON TARAMA", "BILGI", ("%d ozet | taranan %d | uzak engel %d | yakin siper bulunup gonderilen %d (gonderilen / uzak = %.0f%%)" % ((otn,) + tuple(ot) + (100.0 * ot[2] / max(ot[1], 1),))) if otn else "ozet yok (v8.732 oncesi RPT ya da temasli bosta asker olmadi)")
    cn = 0; cs = 0.0; cu = 0.0; ca = 0.0
    for l in L:
        m = re.search(r"\[COVER-OLCUM\] 60 sn: ornek (\d+) \| SIPER \(<= 4 m nesne\) (\d+) % / UZAK ENGEL \(arazi / uzak nesne\) (\d+) % / ACIKTA (\d+) %", l)
        if m:
            k = int(m.group(1)); cn += k; cs += k * int(m.group(2)); cu += k * int(m.group(3)); ca += k * int(m.group(4))
    _kor = (cs + cu) / max(cn, 1)
    _acik = ca / max(cn, 1)
    ekle("KORUNAKLILIK (arazi + nesne; sert siper beklenmez)", ("VERI YOK" if not cn else ("GECTI" if _acik <= 15 else ("KONTROL" if _acik <= 25 else "KALDI"))), ("ornek %d | KORUNAKLI %%%.0f (nesne <= 4 m %%%.0f + arazi / uzak engel %%%.0f) | ACIKTA %%%.0f (kullanici: bu oyunda sert siper yok; 'gercek siper %%' olcusu emekli, ACIKTA <= %%15 beklenir)" % (cn, _kor, cs / max(cn, 1), cu / max(cn, 1), _acik)) if cn else "COVER-OLCUM ornegi yok")
    dn = dg = dy = dc = dh = 0
    for l in L:
        m = re.search(r"\[COVER-OLCUM-DURUS\] 60 sn: hareketsiz ornek (\d+) \| KENDI DURUSUNDA GIZLI %(\d+) \| GORUNUR %(\d+) \| gorunurlerin icinde: YATSA gizli (\d+) / COMELSE gizli (\d+) / hicbir durusta gizli degil (\d+)", l)
        if m:
            k = int(m.group(1)); dn += k; dg += round(k * int(m.group(3)) / 100.0); dy += int(m.group(4)); dc += int(m.group(5)); dh += int(m.group(6))
    ekle("DURUS / ARAZI GIZLENME (hareketsiz)", "BILGI", ("hareketsiz ornek %d | KENDI DURUSUNDA GORUNUR %%%.0f | gorunenlerden: yatsa gizli %d, comelse gizli %d, hicbir durusta gizli degil %d (yatsa / comelse gizli yuksekse durus disiplini eksik; hicbiri yuksekse yer degistirme gerekir)" % (dn, 100.0 * dg / max(dn, 1), dy, dc, dh)) if dn else "[COVER-OLCUM-DURUS] yok (v8.788 oncesi RPT)")
    mgd = len([1 for l in L if "[MG-DESTEK]" in l]); mgo = len([1 for l in L if "[MG-ONDE]" in l and "baslatildi" not in l])
    ekle("MG DESTEK / ONDE", "BILGI", "MG destek (bastirma) logu %d (ilk 15) | MG one alinan %d (ilk 20)" % (mgd, mgo))
    uh = len([1 for l in L if "[UZAK-HUCUM]" in l])
    ekle("UZAK HUCUM YOK", "BILGI", "%d olay (SUPPRESS_ASSAULT / ASSAULT -> BOUNDING, dusman > uzakHucumM); karne: acikta orani (ACIKTA-SINIF-OZET) ve 'hucum ailesi' gruplarin acik arazide formasyonla yurumesi azalmali" % uh)
    ost = [l for l in L if "[ONGORU-STABILITE]" in l]
    ekle("ONGORU STABILITE", "BILGI", (re.sub(r"^.*?\"\[ONGORU-STABILITE\] ", "", ost[-1]).strip().rstrip('"')[:330]) if ost else "stabilite satiri yok (v8.733 oncesi RPT ya da olcum kaydi yok)")
    yk_k = 0; yk_u = 0
    for l in L:
        m = re.search(r"\[ACIK-SIPER-OZET\].*", l)
        if m:
            a = re.search(r"yedek_kuruldu=(\d+)", l); b = re.search(r"yedek_kullanildi=(\d+)", l)
            if a: yk_k += int(a.group(1))
            if b: yk_u += int(b.group(1))
    ekle("YEDEK SIPER (iki sicramali on plan)", "BILGI", "kurulan %d | kullanilan %d (kullanilan / kurulan = %.0f%%; yeniden secim / hesap gidip-gelmesi azalmali)" % (yk_k, yk_u, 100.0 * yk_u / max(yk_k, 1)))
    rr_e = 0.0; rr_y = 0.0; rr_n = 0
    for l in L:
        m = re.search(r"\[BND-PLAN\].*rota riski \(siper bacaklari, m-esdeger\): ilk aday ([\d.]+) -> secilen ([\d.]+)", l)
        if m:
            rr_n += 1; rr_e += float(m.group(1)); rr_y += float(m.group(2))
    ekle("ROTA RISKI (bounding bacaklari)", "BILGI", ("%d plan | toplam risk: ilk aday %.1f -> secilen %.1f (azalma %.0f%%)" % (rr_n, rr_e, rr_y, 100.0 * (rr_e - rr_y) / max(rr_e, 0.1))) if rr_n else "plan satiri yok (v8.735 oncesi RPT ya da bounding olmadi)")
    kume = [l for l in L if "[ONGORU-KUME]" in l]
    ekle("ONGORU KUME (olasi siper)", "BILGI", (re.sub(r"^.*?\"\[ONGORU-KUME\] ", "", kume[-1]).strip().rstrip('"')[:300]) if kume else "kume olcumu yok (ongoru kapali ya da v8.735 oncesi)")
    ka = 0; mg = 0; er = 0
    for l in L:
        if "[ACIK-SIPER-OZET]" in l:
            for key, tgt in (("kapsama_ates", 0), ("mg_destek", 1), ("ertelendi", 2)):
                m = re.search(key + r"=(\d+)", l)
                if m:
                    if tgt == 0: ka += int(m.group(1))
                    elif tgt == 1: mg += int(m.group(1))
                    else: er += int(m.group(1))
    ekle("KAPSAMA ATESI / AYNI ANDA HAREKET", "BILGI", "tufek kapsama atesi %d | MG bastirma %d | ayni anda hareket siniri nedeniyle ertelenen %d (siperAyniAnda)" % (ka, mg, er))
    cp = [l for l in L if "[ROE-IHLAL]" in l and "captive:true" in l and "oyuncu true" in l]
    cp_neden = {}
    for l in cp:
        m = re.search(r"ACE baygin (\w+), ACE elkelepce (\w+), ACE teslim (\w+), yasam (\w+)", l)
        if m:
            k = "baygin" if m.group(1) == "true" else ("elkelepce" if m.group(2) == "true" else ("teslim" if m.group(3) == "true" else "ACE disi / bilinmiyor (ornek yasam: %s)" % m.group(4)))
            cp_neden[k] = cp_neden.get(k, 0) + 1
    ekle("OYUNCU CAPTIVE (botlar seni dusman SAYMAZ)", "KONTROL" if cp else "GECTI", ("%d ROE-IHLAL satiri (ilk 60 loglanir): nedenler %s -> bu anlarda test gecersiz: botlar oyuncuyu hedef almaz / ROE hedefi unutturur" % (len(cp), cp_neden)) if cp else "oyuncu captive degil")
    gc = {"sahte_siper_elendi": 0, "siper_karsilik": 0, "siper_saf_saklanma": 0}
    for l in L:
        if "[ACIK-SIPER-OZET]" in l:
            for k in gc:
                m = re.search(k + r"=(\d+)", l)
                if m: gc[k] += int(m.group(1))
    sahteHug = 0
    for l in L:
        m = re.search(r"sahte_siper=(\d+)", l)
        if m and "SIPER-YAPIS-OZET" in l: sahteHug += int(m.group(1))
    ekle("GERCEK SIPER KURALI", "BILGI", "sahte (gorunur + mermi geciren) aday elenen %d | karsilik verebilen aday %d | saf saklanma cezasi %d (ates edemeyen siper) | coverHug sahte siper (SIPER-YAPIS-OZET) %d" % (gc["sahte_siper_elendi"], gc["siper_karsilik"], gc["siper_saf_saklanma"], sahteHug))
    vt = [0, 0]
    for l in L:
        m = re.search(r"\[VURULDU-TEPKI-OZET\] 60 sn: hareketsizken vurulan (\d+) \| yeni siper bulunup gonderilen (\d+)", l)
        if m: vt[0] += int(m.group(1)); vt[1] += int(m.group(2))
    ekle("VURULUNCA YENIDEN DEGERLENDIRME", "BILGI", "hareketsizken vurulan %d | yeni siper bulunup gonderilen %d (korunakliyken vurulma = siper 'sus' / yan yon acik; azalmali)" % tuple(vt))
    hs = [l for l in L if "[COVER-OLCUM-HAREKETSIZ]" in l]
    hn = hsip = huz = hac = hgo = 0.0
    for l in hs:
        m = re.search(r"hareketsiz ornek (\d+) \| GERCEK SIPER \(<= 4 m nesne\) %(\d+) \| uzak engel %(\d+) \| acik %(\d+) \| dusmani su an goruyor \(ates edebilir\) %(\d+)", l)
        if m:
            k = int(m.group(1)); hn += k; hsip += k * int(m.group(2)); huz += k * int(m.group(3)); hac += k * int(m.group(4)); hgo += k * int(m.group(5))
    ekle("HAREKETSIZ ASKER KORUNAKLILIK", "BILGI", ("hareketsiz ornek %d | GERCEK SIPER %%%.0f | uzak engel %%%.0f | acik %%%.0f | dusmani goruyor (ates edebilir) %%%.0f (hedef: gercek siper artar, acik azalir)" % (hn, hsip / hn, huz / hn, hac / hn, hgo / hn)) if hn else "hareketsiz ornek yok (v8.737 oncesi RPT)")
    cs = {}
    for l in L:
        m = re.search(r"\[CEVRE-PROFIL-OZET\] 60 sn \(asker taramasi\): (.*)$", l)
        if m:
            for k, v in re.findall(r"(ORMAN|KENTSEL|ACIK|KARISIK)=(\d+)", m.group(1)):
                cs[k] = cs.get(k, 0) + int(v)
    cg = len([1 for l in L if "[CEVRE-PROFIL] " in l and " -> " in l])
    tp = sum(cs.values())
    ekle("CEVRE PROFILI (dinamik cover)", "BILGI", ("tarama %d | %s | profil gecisi (ilk 30 loglanir) %d" % (tp, " ".join("%s %%%.0f" % (k, 100.0 * v / tp) for k, v in sorted(cs.items(), key=lambda x: -x[1])), cg)) if tp else "profil taramasi yok (v8.738 oncesi RPT ya da cevreProfil kapali / siper secimi olmadi)")
    ui = [l for l in L if "[UGL-IZI-OZET]" in l]
    ekle("UGL ISABET (40 mm dusus izi)", "BILGI", (re.sub(r"^.*?\"\[UGL-IZI-OZET\] ", "", ui[-1]).strip().rstrip('"')[:260]) if ui else ("[UGL-IZI] ornek %d (OZET henuz yok)" % len([1 for l in L if "[UGL-IZI]" in l and "OZET" not in l]) if any("[UGL-IZI]" in l for l in L) else "UGL izi yok (v8.741 oncesi RPT ya da UGL atisi olmadi)"))
    ra = len([1 for l in L if "[RPG-ATIS]" in l]); ri = len([1 for l in L if "[RPG-IPTAL]" in l]); rk = len([1 for l in L if "[RPG-KARAR]" in l])
    rt = [l for l in L if "[RPG-TANI]" in l]
    rmt = [l for l in L if "[RPG-MERMI-TANI]" in l]
    ekle("RPG MERMI IZNI (LAMBS RPG yamasi)", "BILGI", ((re.sub(r"^.*?\"\[RPG-TANI\] ", "", rt[-1]).strip().rstrip('"')[:170]) + " | roketatar mermisi %d (piyadeye emir HAYIR: %d)" % (len(rmt), len([1 for l in rmt if "HAYIR" in l]))) if rt else "[RPG-TANI] yok (v8.747 oncesi RPT)")
    rm = [l for l in L if "[RPG-MUHIMMAT]" in l]; rd_ = [l for l in L if "[RPG-MERMI-DEGIS]" in l]
    ekle("RPG MUHIMMAT (AP roket tasima / yuklu mermi degisimi)", "BILGI", ("[RPG-MUHIMMAT] birim %d (ilk 40 loglanir; yer degisimi AT->AP %d, yer yok %d) | [RPG-MERMI-DEGIS] %d (basarili %d)" % (len(rm), len([1 for l in rm if "yer degisimi 0" not in l]), len([1 for l in rm if "yer yok 0" not in l]), len(rd_), len([1 for l in rd_ if "basarili: true" in l]))) if (rm or rd_) else "muhimmat kaydi yok (v8.748 oncesi RPT ya da roketatarli AI / AP uyumlu sarjor yok)")
    rs = [l for l in L if "[RPG-KARAR-SONUC]" in l]; rsa = len([1 for l in rs if "atildi: true" in l])
    ro = [l for l in L if "[RPG-OZET]" in l]
    # v8.802 (kullanici: 'roket neden kullanilmadi'): karar ozeti toplami + muhimmat sonucu = roketin neden kullanilmadigi
    rko_ = {}
    for l in L:
        if "[RPG-KARAR-OZET]" in l:
            for k_, v_ in re.findall(r"(\w+)=(\d+)", l.split("[RPG-KARAR-OZET]", 1)[1]): rko_[k_] = rko_.get(k_, 0) + int(v_)
    rmu_ = [l for l in L if "[RPG-MUHIMMAT] " in l and "AP sarjor" in l]
    rme_ = sum(int(x) for l in rmu_ for x in re.findall(r"eklenen (\d+)", l)); rmy_ = sum(int(x) for l in rmu_ for x in re.findall(r"yer yok (\d+)", l)); rmc_ = sum(int(x) for l in rmu_ for x in re.findall(r"canta eklendi (\d+)", l))
    if rko_ or rmu_:
        ekle("RPG: NEDEN KULLANILMADI (karar ozeti)", "KONTROL" if (rko_.get("izin_yok", 0) > 0 and rko_.get("emir", 0) == 0) else "BILGI",
             "aday %d | filtre %d | hedef bilinmiyor %d | IZIN YOK (yuklu roket piyadeye uygun degil + AP yok) %d | emir %d || AP muhimmat: birim %d, eklenen %d, yer yok %d, canta eklendi %d (v8.802+; izin yok yuksek + eklenen 0 ise: envanter / canta sorunu, 'RPG muhimmat: sirt cantasi' CBA acik olmali)" % (rko_.get("aday", 0), rko_.get("filtre", 0), rko_.get("hedef_bilinmiyor", 0), rko_.get("izin_yok", 0), rko_.get("emir", 0), len(rmu_), rme_, rmy_, rmc_))
    ekle("RPG SISTEMI (karar + atis kapisi)", "BILGI", ("karar %d | sonuc: atildi %d / %d | atis (kapidan gecen) %d | iptal %d | %s" % (rk, rsa, len(rs), ra, ri, (re.sub(r"^.*?\"\[RPG-OZET\] ", "", ro[-1]).strip().rstrip('"')[:240]) if ro else "OZET yok")) if (ra or ri or rk) else "RPG kaydi yok (v8.746 oncesi RPT ya da roketatarli AI atis / karar yok; karar atilmiyorsa [RPG-KARAR-SONUC] 'atilmadi' = motor roketatari secmedi)")
    sp = len([1 for l in L if "[SIS-PERDE] " in l]); so = [l for l in L if "[SIS-PERDE-OLCUM]" in l]
    sok = len([1 for l in so if "bulutu: 0 " not in l])
    ekle("DUMAN PERDESI (okkali perde)", "BILGI", ("perde olayi %d (ilk 40 loglanir) | 7 sn sonra lider -> tehdit hattini KESEN perde %d / %d olcum (hedef: cogu kesmeli)" % (sp, sok, len(so))) if sp else "perde kaydi yok (v8.755 oncesi RPT ya da duman olayi yok; [SIS-BUTCE] ret nedenleri butce / aralik mi bak)")
    snp = [l for l in L if "[SIPER-SNAP]" in l]
    ekle("VARIS NOKTASI SIPERE OTUR", "BILGI", ("[SIPER-SNAP] kaydirilan nokta %d (ilk 40 loglanir; bacak %d / geri cekilme %d) | hedef: gercek siper %% ve 'hareketsiz gercek siper %%' artmali" % (len(snp), len([1 for l in snp if "] bacak" in l]), len([1 for l in snp if "geri cekilme" in l]))) if snp else "[SIPER-SNAP] yok (v8.756 oncesi RPT ya da yakinda sert nesne bulunmadi)")
    cb = [l for l in L if "[COVER-OLCUM-BINA]" in l]
    cbi = cbd = cba = cbt = cby = 0
    for l in cb:
        m = re.search(r"bina ICI (\d+) .*? bina DISI (\d+): bina / ev ARKASI \(<= 8 m\) (\d+) \| herhangi nesne <= 6 m (\d+)", l)
        if m: cbi += int(m.group(1)); cbd += int(m.group(2)); cba += int(m.group(3)); cby += int(m.group(4))
    cbt = cbi + cbd
    ekle("COVER: BINA / EV DAHIL (Afgan koyu)", "BILGI", ("ornek %d | bina ICI %%%.0f | bina / ev ARKASI (<= 8 m) %%%.0f | nesne <= 6 m %%%.0f | SIPER BENZERI (bina ici + bina arkasi) %%%.0f" % (cbt, 100.0*cbi/max(cbt,1), 100.0*cba/max(cbt,1), 100.0*cby/max(cbt,1), 100.0*(cbi+cba)/max(cbt,1))) if cbt else "[COVER-OLCUM-BINA] yok (v8.757 oncesi RPT)")
    rdz = [l for l in L if "[RPG-DUZELTME]" in l]
    ekle("RPG ISABET DUZELTMESI", "BILGI", ("duzeltilen roket %d (ilk 30 loglanir); isabeti [RPG-ATIS] sonrasi hasar / olum ile karsilastir" % len(rdz)) if rdz else "[RPG-DUZELTME] yok (v8.761 oncesi RPT ya da gudumsuz roket atisi / hedef yok)")
    tc = len([1 for l in L if "[TEMAS-COMBAT]" in l])
    ekle("TEMASTA AWARE -> COMBAT", "BILGI", ("[TEMAS-COMBAT] %d olay (ilk 20 loglanir)" % tc) if tc else "[TEMAS-COMBAT] yok (v8.767 oncesi RPT ya da temasta AWARE kalan grup olmadi)")
    bso = [l for l in L if "[BINA-SALDIRI-OZET]" in l]
    ekle("BINA SALDIRISI (kapi ozeti)", "BILGI", re.sub(r"^.*?\"\[BINA-SALDIRI-OZET\] ", "", bso[-1]).strip().rstrip('"')[:300] if bso else "[BINA-SALDIRI-OZET] yok (v8.771 oncesi RPT ya da AI grup yok)")
    tb = len([1 for l in L if "[TESLIM-BOMBA] ISARETLI" in l]); tbk = len([1 for l in L if "[TESLIM-BOMBA] SON AN KOSU" in l]); tbp = len([1 for l in L if "[TESLIM-BOMBA] SONUC" in l and "PATLADI" in l])
    ekle("TESLIM + EYP (son anda kosu)", "BILGI", ("isaretli %d | son an kosusu %d | patladi %d" % (tb, tbk, tbp)) if tb else "[TESLIM-BOMBA] yok (v8.776 oncesi RPT ya da teslimBomba kapali (varsayilan) / teslim olan + patlayicili asker yok)")
    mb = [l for l in L if "[MEKANIZE-INIS] BASLA" in l]; mi_ = len([1 for l in L if "[MEKANIZE-INIS] INDI" in l]); ms_ = len([1 for l in L if "[MEKANIZE-INIS] SERBEST" in l])
    ekle("MEKANIZE INIS (BMP / BTR / KAMYON)", "BILGI", ("inis basladi %d | indi %d | serbest %d | siniflar: IFV %d APC %d KAMYON %d | nedenler: temas+dusman %d, hasar %d, baski %d, hareketsiz %d" % (len(mb), mi_, ms_, len([1 for l in mb if "(IFV)" in l]), len([1 for l in mb if "(APC)" in l]), len([1 for l in mb if "(KAMYON)" in l]), len([1 for l in mb if "temas + dusman" in l]), len([1 for l in mb if "hasar aldi" in l]), len([1 for l in mb if "surucu baskida" in l]), len([1 for l in mb if "arac hareketsiz" in l]))) if mb else "[MEKANIZE-INIS] BASLA yok (v8.789 oncesi RPT ya da yolcu tasiyan IFV / APC / kamyon temasa girmedi)")
    ya_ = [l for l in L if "[YERE-ATES] " in l and "hedef" in l and "baslatildi" not in l and "TEHDIT ENGELI" not in l]
    yo_ = {}
    for l in L:
        if "[YERE-ATES-OZET]" in l:
            for k_, v_ in re.findall(r'""?(\w+):(\d+)""?', l): yo_[k_] = yo_.get(k_, 0) + int(v_)
    yo_s = " | teshis sayaclari: " + ", ".join("%s %d" % kv for kv in sorted(yo_.items())) if yo_ else ""
    ekle("HOSTILE ACT YERE ATES (olu / baygin)", "BILGI", ("yere ates secimi %d (OLU %d, BAYGIN %d) | doktrinler: %s" % (len(ya_), len([1 for l in ya_ if "hedef OLU" in l]), len([1 for l in ya_ if "hedef BAYGIN" in l]), ", ".join(sorted(set(re.findall(r"doktrin (\S+)", " ".join(ya_))))) or "-") + yo_s) if ya_ else ("[YERE-ATES] yok (v8.789 oncesi RPT ya da yereAtes kapali / doktrin olasiligi 0 / taze olu-baygin dusman gorulmedi)" + yo_s))
    kk = len([1 for l in L if "[EYP-KOMUT] KURULDU" in l]); kp = len([1 for l in L if "[EYP-KOMUT] SONUC" in l and "PATLADI" in l]); op = len([1 for l in L if "[EYP-KOS] OLUM PATLAMASI" in l]); ar = len([1 for l in L if "[CANLI-BOMBA] SECILDI" in l and "ARAC (" in l]); zi = len([1 for l in L if "[EYP-ISARET] " in l and "tespit" in l]); zk = len([1 for l in L if "[EDEN] EYP kur" in l]); ad = len([1 for l in L if "[EYP-ISARET] SONUC" in l and "arac durdu" in l]); td = len([1 for l in L if "[EYP-KOS] TEREDDUT" in l]); du_ = len([1 for l in L if "[EYP-KOS] DURAKLAMA" in l]); at_ = len([1 for l in L if "[EYP-ISARET] ATES ALTINDA" in l])
    co_ = [l for l in L if "[EYP-KOS] CATISARAK OZET" in l]; co_a = sum(int(x) for l in co_ for x in re.findall(r"ates denemesi (\d+)", l)); co_m = sum(int(x) for l in co_ for x in re.findall(r"harcanan mermi (-?\d+)", l))
    ekle("EYP KOMUTLA + ARAC BOMBASI (v8.777)", "BILGI", ("komutla EYP kuruldu %d (patladi %d) | arac bombasi secildi %d | olunce patlama %d | editor / Zeus bomba isareti %d | 3DEN EYP %d | arac durdu %d (0 olmali; [EYP-KOS] ARAC DURDU TESHIS satirina bak) | tereddut %d | piyade duraklama %d ([EYP-KOS] DURAKLAMA satirlarina bak) | ates altinda %d | catisarak kosu %d (forceWeaponFire denemesi %d, harcanan mermi %d; denemeler > 0 ama mermi 0 = ates calismiyor)" % (kk, kp, ar, op, zi, zk, ad, td, du_, at_, len(co_), co_a, co_m)) if (kk or ar or op or zi or zk or ad or td or du_ or at_) else "[EYP-KOMUT] / ARAC / [EYP-KOS] yok (v8.777 oncesi RPT ya da eypKomutlu / canliBomba kapali)")
    ek = len([1 for l in L if "[EYP-KUR]" in l]); cb = [l for l in L if "[CANLI-BOMBA] SONUC" in l]; cbp = len([1 for l in cb if "PATLADI" in l])
    ekle("EYP TUZAK / CANLI BOMBA (oyun davranisi)", "BILGI", ("tuzak %d | canli bomba sonuc %d (patladi %d) | eypKur / canliBomba CBA kapaliysa 0" % (ek, len(cb), cbp)) if (ek or cb) else "[EYP-KUR] / [CANLI-BOMBA] yok (v8.775 oncesi RPT ya da eypKur / canliBomba kapali (varsayilan))")
    ri = [l for l in L if "[RPG-IZI]" in l]; rih = len([1 for l in ri if "ISABET (<= 10 m)" in l])
    ekle("RPG ISABET IZI", "BILGI", ("izlenen roket %d | ISABET (<= 10 m) %d | kacan %d | isabet orani %%%.0f" % (len(ri), rih, len(ri) - rih, 100.0 * rih / max(len(ri), 1))) if ri else "[RPG-IZI] yok (v8.766 oncesi RPT ya da hedefi bilinen roket atisi yok)")
    rz = [l for l in L if "[RPG-ZAMAN]" in l]
    rza = [l for l in rz if "ATILMADI" not in l]
    ekle("RPG ZAMANLAMA (emir -> atis)", "BILGI", ("emir %d | atilan %d | atilmayan %d (silah elde / atis suresi icin [RPG-ZAMAN] satirlarina bak)" % (len(rz), len(rza), len(rz) - len(rza))) if rz else "[RPG-ZAMAN] yok (v8.763 oncesi RPT ya da karar yok)")
    se = [l for l in L if "[SKILL-ESIT]" in l]
    ekle("OYUNCU GRUBU ESITLIGI (beceri + hiz)", "BILGI", re.sub(r"^.*?\"\[SKILL-ESIT\] ", "", se[-1]).strip().rstrip('"')[:420] if se else "[SKILL-ESIT] yok (v8.745 oncesi RPT ya da oyuncu grubunda bot / dusman bot yok)")
    ca_n = ca_g = 0
    for l in L:
        if "[ACIK-SIPER-OZET]" in l:
            mn = re.search(r"cokaci_n=(\d+)", l); mg = re.search(r"cokaci_gor=(\d+)", l)
            if mn and mg: ca_n += int(mn.group(1)); ca_g += int(mg.group(1))
    vy = len([1 for l in L if "[VURULDU-TEPKI] YENI SIPER YOK" in l])
    ekle("SIPER COK ACILI GUVENCE", "BILGI", ("sinanan kazanan aday %d | ortalama gorunen atici konumu %.2f / 4 (dusuk iyi: 0 = her yandan kapali) | vurulunca yeni siper yok (teshis logu) %d" % (ca_n, ca_g / float(ca_n), vy)) if ca_n else "cok acili guvence kaydi yok (v8.750 oncesi RPT ya da siper secimi olmadi)")
    bk = [l for l in L if "[BASKI-KAPI-OZET]" in l]
    bkr = len([1 for l in L if "[BASKI-KAPI] RED" in l])
    bkb = [l for l in L if "[BASKI-KAPI] BOMBACI RED" in l]
    ekle("BASTIRMA KAPISI (bos yere bastirma yok)", "BILGI", (("RED ornek %d (ilk 30 loglanir) | bombaci RED %d (atici %d, hedef %d; v8.798, arac haric) | " % (bkr, len(bkb), len([1 for l in bkb if "bombaci atici" in l]), len([1 for l in bkb if "bombaci hedef" in l]))) + (re.sub(r"^.*?\"\[BASKI-KAPI-OZET\] ", "", bk[-1]).strip().rstrip('"')[:260] if bk else "OZET yok")) if (bk or bkr or bkb) else "bastirma kapisi kaydi yok (v8.743 oncesi RPT ya da baskiKapisi kapali / uzak + gozlemcisiz bastirma denemesi olmadi)")
    bm = [l for l in L if "[EL-BOMBASI-MESAFE]" in l]
    bmy = len([1 for l in bm if "yuz yuze:true" in l])
    ekle("EL BOMBASI YUZ YUZE (motor atisi)", "BILGI", "motor atisi iptal %d (yuz yuze %d, uzak / baygin %d); iptal yoksa motor yuz yuze bomba atmadi ya da v8.743 oncesi" % (len(bm), bmy, len(bm) - bmy))
    og = [l for l in L if "[ONGORU-OLCUM] TAHMIN:" in l]
    if og:
        son = og[-1]
        hk = re.search(r"HUKUM: (.*)$", son)
        ekle("ONGORU OLCUMU", "GECTI" if (hk and hk.group(1).startswith("ISE YARIYOR")) else ("KALDI" if (hk and hk.group(1).startswith("YARAMIYOR")) else "BILGI"), "HUKUM: %s | %s" % (hk.group(1).rstrip('"')[:70] if hk else "?", re.sub(r"^.*?\"\[ONGORU-OLCUM\] ", "", son).strip().rstrip('"')[:330]))
    else:
        ekle("ONGORU OLCUMU", "BILGI", "olcum satiri yok (v8.730 oncesi RPT ya da nesne arkasi siper secimi olmadi)")
    yd = [0, 0]
    for l in L:
        m = re.search(r"\[ACIK-SIPER\] .*?\| dusman (\d+) m acikta -> (?:NESNE ARKASI|bina) \S+ \((\d+) m", l)
        if m:
            yd[0] += 1
            if int(m.group(1)) < 25 and int(m.group(2)) > 6: yd[1] += 1
    ekle("YAKIN DOVUS KOSUSU", "GECTI" if yd[1] == 0 else "KALDI", "siper kosusu %d | dusman < 25 m iken > 6 m kosu: %d (0 olmali; v8.729 siperYakinM)" % (yd[0], yd[1]))
    hd = [0] * 5; hdn = 0
    for l in L:
        m = re.search(r"\[HAREKET-DESTEK-OZET\] 60 sn: tespit (\d+) \| adim1 \(yeniden emir\) (\d+) \| adim2 \(yan adim\) (\d+) \| adim3 \(gruba don\) (\d+) \| kurtarilan (\d+)", l)
        if m:
            hdn += 1
            for i in range(5): hd[i] += int(m.group(i + 1))
    if hdn:
        ekle("MOVE TIKANMA (kurtarici)", "BILGI", "%d ozet | tespit %d | yeniden emir %d | yan adim %d | gruba don %d | KURTARILAN %d (kurtarilan / yeniden emir = %.0f%%)" % ((hdn,) + tuple(hd) + (100.0 * hd[4] / max(hd[1], 1),)))
    else:
        ekle("MOVE TIKANMA (kurtarici)", "BILGI", "ozet yok (v8.726 oncesi RPT ya da tikanan asker olmadi)")
    dk = 0.0; dg = 0; dl = 0; dn = 0
    for l in L:
        m = re.search(r"\[DURUS-AKICI-OZET\] 60 sn: izlenen birim-dk ([\d.]+) \| durus degisimi (\d+) \| birim basina dakikada ([\d.]+) \| kilit (\d+) \| muaf (\d+)", l)
        if m:
            dn += 1; dk += float(m.group(1)); dg += int(m.group(2)); dl += int(m.group(4))
    if dn:
        ekle("YAT-KALK (durus degisimi)", "BILGI", "%d ozet | birim basina dakikada %.1f durus degisimi (%d degisim / %.1f birim-dk) | kilit %d (dusuk iyi; v8.725 oncesi referans yok, 20 sn ornekleme tek botta ~39 degisim/dk gosterdi)" % (dn, dg / max(dk, 0.05), dg, dk, dl))
    else:
        ekle("YAT-KALK (durus degisimi)", "BILGI", "ozet yok (v8.725 oncesi RPT ya da temasli AI olmadi)")
    yk = []
    for l in L:
        m = re.search(r"\[TEMAS-KES-BASLA\].*?tehdit:(\d+)m \| kacis:true", l)
        if m: yk.append(int(m.group(1)))
        m = re.search(r"\[KACIS\] (?:EAST|WEST|GUER|CIV)\b.*?\| dusman (\d+) m \|", l)
        if m: yk.append(int(m.group(1)))
    ykn = len([1 for x in yk if x < 60])
    iptal = len([1 for l in L if "[KACIS-IPTAL]" in l])
    ekle("YAKIN KACIS (arkasini donup kacma)", "GECTI" if ykn == 0 else "KALDI", "kacis baslangici %d | dusman < 60 m iken baslayan: %d (0 olmali; v8.723 kacisYakinM) | donma iptali: %d" % (len(yk), ykn, iptal))
    biz = [l for l in L if "[BOMBA-IZI]" in l]
    if biz:
        def _hd(l):
            m = re.search(r"hedefe (\d+) m", l)
            return int(m.group(1)) if m else 999
        ic = len([1 for l in biz if "bina altinda true" in l])
        yk = len([1 for l in biz if _hd(l) <= 6])
        dv = len([1 for l in biz if re.search(r"nesne Land_\w*(House|Shed|Cargo|Hotel|Barracks|Church|Office|Bunker|Hut)\w*, yukseklik \+?[1-4]\.", l)])
        ekle("EL BOMBASI IZI (bina girisi)", "BILGI", "%d bomba | hedefe <= 6 m: %d | bina altinda (iceri girdi): %d | duvara +1..+4 m'de carpan (pencere denizligi): %d (v8.722 tup denetimi sonrasi azalmali)" % (len(biz), yk, ic, dv))

    # --- 9) senaryo kapsami (tetiklenmeyen ozellikler)
    for ad, tag, ipucu in [
        ("YEM + TACIZ (oyuncuya)", "YEM", "oyuncuyu bilen >= 6 kisilik AI grubu, oyuncu 150-450 m"),
        ("BAKIS FARKINDALIGI", "BAKIS-FARK", "oyuncu bota (5 derece, <= 350 m, arada engel yok) 0.8 sn bakmali"),
        ("SAHTE GERI CEKILME", "SAHTE-CEKILME", "ustun AI grubu + oyuncu 120-400 m + acik arazi (kotu arazi orani >= 0.5)"),
        ("GAFIL AVLAMA", "GAFIL", "oyuncuyu bilen AI grubu + oyuncu bakisi 5 sn boyunca gruba eslesmiyor + savas baslamamis"),
        ("SESE GORE TAVIR", "SES-TAVIR", "temasta olmayan grup + ates sesi / parlama seviyesi >= 0.7 (CBA sesTavir acik)"),
        ("BILGI ARTISI", "BILGI-ARTIS", "oyuncuyu bilen AI grubu (bilgiArtis / bilgiTaban > 0)"),
        ("SAVUNMA YERLESIM", "SAVUNMA-YER", "senaryo C: >= 3 kisilik HOLD / DELAY grubu, dusman 45-250 m"),
        ("AVANTAJLI YER", "AVANTAJLI-YER", "senaryo B / C (geri cekilme, savunma)"),
        ("MG HAKIM NOKTA", "MG-HAKIM", "MG'li grup + dusman 100-300 m"),
        ("KANAT BASKISI", "KANAT-BASKI", "FLANK karari (baski ekibi >= 2)"),
        ("SEKTOR PLANI", "SEKTOR-PLAN", "temasli grup >= 2 aday"),
        ("SNIPER GOZLEMCI", "SNIPER-GOZLEMCI", "sniper takimi (nisanci + gozlemci)"),
        ("TEMAS SONRASI GEVSEME", "TEMAS-SONRASI", "temas bittikten sonra >= 75 sn sessizlik"),
    ]:
        n = len([1 for l in L if ("[%s]" % tag) in l and "baslatildi" not in l])
        ekle(ad, "GECTI" if n else "VERI YOK", ("%d satir" % n) if n else ipucu)

    # --- 10) GERCEKCILIK KARNESI (v8.801; kullanici: 'gerceklik karnesi ekle'): kalibrasyon hedefine gore GECTI / KONTROL / VERI YOK
    # HEDEF BANTLAR = oyun icin TAHMINI baslangic hedefleri (gercek hayat rakami DEGIL; ayarlamak icin buradaki sabitleri degistir). KONTROL = hedef bant disi (kalibrasyon ayari gerek), KALDI degil.
    HB_ISABET = {"<50 m": (10, 20), "50-120 m": (5, 10), "<120 m": (5, 15), "120-250 m": (1, 4), ">250 m": (0, 1)}   # '<120 m' = v8.801 oncesi RPT'lerin tek bandi
    HB_MERMI_ISABET = (30, 100)       # genel mermi / isabet (bastirma dahil)
    HB_ACIKTA_MAX = 20                # hareketsiz askerin acikta orani % (en cok)
    HB_STAND_MAX = 30                 # hareketsiz askerde ayakta (STAND) orani % (en cok)
    HB_GORUNUR_MAX = 40               # hareketsiz askerin KENDI DURUSUNDA gorunur orani % (en cok)
    HB_FARK = (0.8, 2.5)              # gorunur -> fark etme ort. sn
    MIN_ATIS = 30                     # bant basina en az nisanli atis (altinda 'az veri')
    bant = collections.OrderedDict()
    for l in L:
        if "[BOT-ISABET]" not in l: continue
        for ad_, a_, i_ in re.findall(r"(<\d+ m|\d+-\d+ m|>\d+ m): nisanli (\d+) atis / (\d+) isabet", l):
            v_ = bant.setdefault(ad_, [0, 0]); v_[0] += int(a_); v_[1] += int(i_)
    sirali = [b_ for b_ in ["<50 m", "50-120 m", "<120 m", "120-250 m", ">250 m"] if b_ in bant]
    ol_ = []; ihlal_ = []; olc_ = 0
    for b_ in sirali:
        a_, i_ = bant[b_]
        if a_ < MIN_ATIS or i_ < 10:   # v8.824: bant basina en az 10 isabet (RPT 9eb0728d: 3 / 8 / 9 isabetle %1-7 oranlari gurultu)
            ol_.append("%s: az veri (%d atis, %d isabet)" % (b_, a_, i_)); continue
        olc_ += 1
        o_ = 100.0 * i_ / a_; lo_, hi_ = HB_ISABET[b_]
        dd_ = "ok" if lo_ <= o_ <= hi_ else ("DUSUK" if o_ < lo_ else "YUKSEK")
        if dd_ != "ok": ihlal_.append("%s %s" % (b_, dd_))
        ol_.append("%s: %d atis / %d isabet = %%%.1f (hedef %%%d-%d) %s" % (b_, a_, i_, o_, lo_, hi_, dd_))
    ekle("GERCEKCILIK: BOT ISABET (mesafe bandi)", "VERI YOK" if not olc_ else ("GECTI" if not ihlal_ else "KONTROL"),
         (" | ".join(ol_) + (" | SAPMA: " + ", ".join(ihlal_) if ihlal_ else "") + " (ayar: >= 250 m YUKSEK -> isabetUzakSapma artir; < 120 m DUSUK -> isabetYakinYardim artir [v8.822]; ayrica skillIsabetMax / Min, dogrulukMaks, isabetSeviye; her turda tek grup ayari degistir)") if sirali else "[BOT-ISABET] yok (v8.577 oncesi RPT ya da bot atisi olmadi; bant bazli olcum v8.801+)")
    otr_ = re.findall(r"OTURUM: (\d+) atis / (\d+) isabet", "\n".join([l for l in L if "[BOT-ISABET]" in l]))
    if otr_:
        ta_, ti_ = int(otr_[-1][0]), int(otr_[-1][1])
        mi_ = (float(ta_) / ti_) if ti_ else None
        ekle("GERCEKCILIK: GENEL MERMI / ISABET", "VERI YOK" if ta_ < 200 else ("GECTI" if (mi_ is not None and HB_MERMI_ISABET[0] <= mi_ <= HB_MERMI_ISABET[1]) else "KONTROL"),
             "oturum %d atis / %d isabet = %s mermi/isabet (hedef %d-%d; baski atesi dahil; cok yuksek deger = neredeyse hic isabet yok)" % (ta_, ti_, ("%.0f" % mi_) if mi_ else "-", HB_MERMI_ISABET[0], HB_MERMI_ISABET[1]) + (" | az veri (< 200 atis)" if ta_ < 200 else ""))
    else:
        ekle("GERCEKCILIK: GENEL MERMI / ISABET", "VERI YOK", "[BOT-ISABET] OTURUM satiri yok")
    gn_ = 0; gs_ = 0.0; gc_ = 0.0; gp_ = 0.0; ga_ = 0.0; gk = 0; gk_g = 0.0
    for l in L:
        m = re.search(r"\[COVER-OLCUM\] 60 sn: ornek (\d+) \| SIPER \(<= 4 m nesne\) (\d+) % / UZAK ENGEL \(arazi / uzak nesne\) (\d+) % / ACIKTA (\d+) %", l)
        if m: ga_ += int(m.group(1)) * int(m.group(4)); gk += int(m.group(1))
        m = re.search(r"HAREKETSIZ (\d+) asker: STAND (\d+) % CROUCH (\d+) % PRONE (\d+) %", l)
        if m:
            n_ = int(m.group(1)); gn_ += n_; gs_ += n_ * int(m.group(2)); gc_ += n_ * int(m.group(3)); gp_ += n_ * int(m.group(4))
        m = re.search(r"\[COVER-OLCUM-DURUS\] 60 sn: hareketsiz ornek (\d+) \| KENDI DURUSUNDA GIZLI %(\d+) \| GORUNUR %(\d+)", l)
        if m: gk_g += int(m.group(1)) * int(m.group(3))
    dkn_ = sum(int(m.group(1)) for m in [re.search(r"\[COVER-OLCUM-DURUS\] 60 sn: hareketsiz ornek (\d+)", l) for l in L] if m)
    if gk or gn_ or dkn_:
        acik_ = ga_ / max(gk, 1); stand_ = gs_ / max(gn_, 1); gor_ = gk_g / max(dkn_, 1)
        ih_ = []
        if gk and acik_ > HB_ACIKTA_MAX: ih_.append("acikta %%%.0f > %%%d" % (acik_, HB_ACIKTA_MAX))
        if gn_ and stand_ > HB_STAND_MAX: ih_.append("ayakta %%%.0f > %%%d" % (stand_, HB_STAND_MAX))
        if dkn_ and gor_ > HB_GORUNUR_MAX: ih_.append("kendi durusunda gorunur %%%.0f > %%%d" % (gor_, HB_GORUNUR_MAX))
        ekle("GERCEKCILIK: GIZLENME / DURUS (hareketsiz)", "GECTI" if not ih_ else "KONTROL",
             ("acikta %%%.0f (hedef <= %%%d, ornek %d) | hareketsiz ayakta %%%.0f / comel %%%.0f / yatan %%%.0f (ayakta hedef <= %%%d, ornek %d) | kendi durusunda GORUNUR %s" % (acik_, HB_ACIKTA_MAX, gk, stand_, gc_ / max(gn_, 1), gp_ / max(gn_, 1), HB_STAND_MAX, gn_, ("%%%.0f (hedef <= %%%d, ornek %d)" % (gor_, HB_GORUNUR_MAX, dkn_)) if dkn_ else "veri yok ([COVER-OLCUM-DURUS] yok)")) + ((" | SAPMA: " + ", ".join(ih_) + " (ayar: durusDisiplin / durusDisiplinSn / durusYatMesafe, siper*)") if ih_ else ""))
    else:
        ekle("GERCEKCILIK: GIZLENME / DURUS (hareketsiz)", "VERI YOK", "[COVER-OLCUM] yok: CBA 'coverOlcum' KAPALI olabilir (acik: coverOlcum = true; 60 sn ozetleri RPT'ye yazilir)")
    fark_n = hf_t + hf_m
    if fark_n >= 5:
        fo_ = (hf_ts + hf_ms) / fark_n
        ekle("GERCEKCILIK: REAKSIYON (gorunur -> fark)", "GECTI" if HB_FARK[0] <= fo_ <= HB_FARK[1] else "KONTROL", "ort. %.2f sn (hedef %.1f-%.1f sn; ornek %d: bizim tetik %d + motor %d; ayar: hizliFark*, reaksiyonArtis)" % (fo_, HB_FARK[0], HB_FARK[1], fark_n, hf_t, hf_m))
    else:
        ekle("GERCEKCILIK: REAKSIYON (gorunur -> fark)", "VERI YOK", "[HIZLI-FARK-OZET] ornegi yok / az (%d); gorunen insan oyuncu gerekir" % fark_n)
    # v8.804 (kullanici: 'siper varisini duzelt'): siper noktasina VARIS orani + varis gozcusu sonuclari
    sv_ok = len([1 for l in L if "[SIPER-OTUR]" in l and "oturtuldu" in l]); sv_no = len([1 for l in L if "[SIPER-OTUR]" in l and "oturtulamadi" in l and not re.search(r"kalan 0\.[01] m", l)])   # v8.821: kalan 0.0-0.1 m = zaten yerinde (eski RPT'lerde de basarisizlik sayilmaz)
    sv_ul = len([1 for l in L if "[SIPER-VARIS] ULASILAMADI" in l])
    sv_re = 0; sv_ye = 0; sv_ua = 0
    for l in L:
        if "[ACIK-SIPER-OZET]" in l:
            for k_, v_ in re.findall(r"(varis_yeniden_emir|varis_yedege_gecti|varis_ulasilamadi)=(\d+)", l):
                if k_ == "varis_yeniden_emir": sv_re += int(v_)
                elif k_ == "varis_yedege_gecti": sv_ye += int(v_)
                else: sv_ua += int(v_)
    if sv_ok + sv_no >= 4 or sv_re or sv_ul or sv_ye:
        o_ = 100.0 * sv_no / max(sv_ok + sv_no, 1)
        ekle("GERCEKCILIK: SIPER VARISI", "GECTI" if o_ <= 15 and sv_ul <= 2 else "KONTROL", "oturtuldu %d / oturtulamadi %d (%%%.0f; hedef <= %%15) | varis gozcusu: yeniden emir %d, yedek sipere gecis %d, ulasilamadi (kara liste + yeniden secim) %d (v8.804+)" % (sv_ok, sv_no, o_, sv_re, sv_ye, max(sv_ul, sv_ua)))
    else:
        ekle("GERCEKCILIK: SIPER VARISI", "VERI YOK", "[SIPER-OTUR] / varis gozcusu kaydi az (siper atilisi yok)")
    # v8.805 (kullanici: 'raycast sisteminin hakkini son damlasina kadar ver'): YOL TARAMA (fnc_yolTara) - secilen siper / geri cekilme noktasina gidis yolu raycast'i
    yt_ozet = [l for l in L if "[YOL-TARA-OZET]" in l]
    yt_say = {"cagri": 0, "duz": 0, "dolasma": 0, "kapali": 0, "su": 0, "dik_yamac": 0, "dolasma_yok": 0, "dolasma_asildi": 0}
    for l in yt_ozet:
        for k_, v_ in re.findall(r"(cagri|duz|dolasma|kapali|su|dik_yamac|dolasma_yok|dolasma_asildi)=(\d+)", l):
            yt_say[k_] += int(v_)
    yk_as = 0; yd_as = 0
    for l in L:
        if "[ACIK-SIPER-OZET]" in l:
            for k_, v_ in re.findall(r"(yol_kapali|yol_dolasma)=(\d+)", l):
                if k_ == "yol_kapali": yk_as += int(v_)
                else: yd_as += int(v_)
    yt_log = [l for l in L if "[YOL-TARA] " in l]
    if yt_say["cagri"] or yk_as or yt_log:
        ekle("GERCEKCILIK: SIPER YOLU (yol tarama)", "BILGI", "tarama %d: duz acik %d | dolasma %d | ERISILEMEZ %d (su %d, dik yamac %d, dolasma kordu yok %d, dolasma > sinir %d) | acikSiper: yol_kapali %d (nokta elendi + yeniden secim), yol_dolasma %d | ilk olumsuz: %s (v8.805+; yol_kapali yuksek + [SIPER-VARIS] ULASILAMADI dusuk = ise yariyor)" % (yt_say["cagri"], yt_say["duz"], yt_say["dolasma"], yt_say["kapali"], yt_say["su"], yt_say["dik_yamac"], yt_say["dolasma_yok"], yt_say["dolasma_asildi"], yk_as, yd_as, (re.sub(r'^.*?"\[YOL-TARA\] ', "", yt_log[0]).strip().rstrip('"')[:160]) if yt_log else "-"))
    else:
        ekle("GERCEKCILIK: SIPER YOLU (yol tarama)", "VERI YOK", "[YOL-TARA] / [YOL-TARA-OZET] yok (v8.805 oncesi RPT ya da lambs_danger_yolTara kapali)")
    # v8.806 (kullanici: 'retreattami cakisan bir sey var'): retreat kosucusu hareket orani + cakisma korumasi sayaci
    iz_ = [l for l in L if "[GERI-CEKILME-IZ]" in l]
    iz_dur = 0; iz_atk = 0; iz_n = 0; iz4_n = 0; iz4_dur = 0
    for l in iz_:
        m_ = re.search(r"t\+(\d+) \| [^|]+\| hiz (\d+) \| anim \S+ \| komut (\w+)", l)
        if not m_: continue
        iz_n += 1
        if int(m_.group(1)) >= 4:
            iz4_n += 1
            if int(m_.group(2)) < 2: iz4_dur += 1
        if int(m_.group(2)) < 2:
            iz_dur += 1
            if m_.group(3) == "ATTACK": iz_atk += 1
    rb_ = [l for l in L if "[GERI-CEKILME-BITIS]" in l]
    rb_ip = len([1 for l in rb_ if "ilerleme yok" in l])
    rc_say = {}
    for l in L:
        if "[RET-CAKISMA-OZET]" in l:
            for k_, v_ in re.findall(r"(siperZorla|yumusakKay|moveAssist)=(\d+)", l): rc_say[k_] = rc_say.get(k_, 0) + int(v_)
    rc_n = len([1 for l in L if "[RET-CAKISMA] " in l])
    kp_say = {}
    for l in L:
        if "[KOSU-PATLAMA-OZET]" in l:
            for k_, v_ in re.findall(r"(retreat|varis)=(\d+)", l): kp_say[k_] = kp_say.get(k_, 0) + int(v_)
    kp_n = len([1 for l in L if "[KOSU-PATLAMA] " in l])
    kf_u = 0; kf_b = 0
    for l in L:
        if "[KOSU-FSM-OZET]" in l:
            m_ = re.search(r"uygulandi=(\d+) erken_birakildi=(\d+)", l)
            if m_: kf_u += int(m_.group(1)); kf_b += int(m_.group(2))
    kf_n = len([1 for l in L if "[KOSU-FSM] " in l])
    bk_ = [l for l in L if "[RET-BACAK-KISALT]" in l]
    dm_k = 0; dm_y = 0
    for l in L:
        if "[RET-DOMOVE-TEST]" in l:
            if "KABUL" in l.split("[RET-DOMOVE-TEST]",1)[1][:12]: dm_k += 1
            else: dm_y += 1
    if iz_n >= 10:
        o_ = 100.0 * iz_dur / iz_n
        ekle("GERCEKCILIK: RETREAT KOSUSU (kosucu hareket orani)", "GECTI" if o_ <= 40 and rb_ip == 0 else "KONTROL", "kosucu ornegi %d: duran (< 2 km/sa) %d (%%%.0f; hedef <= %%40; sicrama basindan t+4 sn sonrasi: %d ornek, duran %%%.0f), bunlardan ATTACK komutlu %d | retreat bitisi 'ilerleme yok': %d / %d | eski siper komutu engellendi (v8.806+): %s (log %d) | kosu patlamasi (v8.807+, ATTACK ile duran kosucuda hedef alma kisa sure kapali): %s (log %d) | retreat doMove testi (v8.809+; ilk 30): kabul %d / yok sayildi %d | kosu FSM kapama (v8.811+; v8.816'dan beri lider dahil): uygulandi %d, erken birakildi %d (log %d) | bacak kisaltma (v8.816+; ara nokta) %d, ilk: %s" % (iz_n, iz_dur, o_, iz4_n, 100.0 * iz4_dur / max(iz4_n, 1), iz_atk, rb_ip, len(rb_), (", ".join("%s %d" % (k, v) for k, v in sorted(rc_say.items())) or "yok"), rc_n, (", ".join("%s %d" % (k, v) for k, v in sorted(kp_say.items())) or "yok"), kp_n, dm_k, dm_y, kf_u, kf_b, kf_n, len(bk_), (re.sub(r'^.*?"\[RET-BACAK-KISALT\] ', "", bk_[0]).strip().rstrip('"')[:110]) if bk_ else "-"))
    else:
        ekle("GERCEKCILIK: RETREAT KOSUSU (kosucu hareket orani)", "VERI YOK", "[GERI-CEKILME-IZ] ornegi az (retreat yok)")
    # v8.818 HAREKET KURTARMA (kullanici: 'MOVE kabul edilip yurunmemesinin nedeni hala yok'): ortak merdiven (siper varisi + retreat); adim basina 'YURUDU' orani = hangi mudahale ise yaradi
    hk_l = [l for l in L if "[HAREKET-KURTAR] " in l]
    hk_st = {}
    for l in hk_l:
        m_ = re.search(r"\] (\S+) \|.*?\| adim (\d) \|.*?sonuc (YURUDU|YURUMEDI)", l)
        if m_:
            k_ = (m_.group(1), int(m_.group(2)))
            a_, b_ = hk_st.get(k_, (0, 0))
            hk_st[k_] = (a_ + (m_.group(3) == "YURUDU"), b_ + 1)
    hk_oz = {}
    for l in L:
        if "[HAREKET-KURTAR-OZET]" in l:
            for m_ in re.finditer(r"([a-z-]+_adim\d(?:_ok)?)=(\d+)", l):
                hk_oz[m_.group(1)] = hk_oz.get(m_.group(1), 0) + int(m_.group(2))
    if hk_st or hk_oz:
        t_ = " | ".join("%s adim %d: yurudu %d / %d (%%%.0f)" % (k[0], k[1], v[0], v[1], 100.0 * v[0] / max(v[1], 1)) for k, v in sorted(hk_st.items()))
        ekle("GERCEKCILIK: HAREKET KURTARMA (MOVE kabul + yurumuyor)", "BILGI", "olculen (ilk 25 + 30 sn'de bir): %s | ozet sayaclari (60 sn'de bir toplam): %s | KARAR: bir adimin yurudu orani yuksekse (ilk basarili adim = gereken en kucuk mudahale) o adim varsayilan yapilir; hicbiri tutmuyorsa motor MOVE'u bastiriyor -> ayri grup / join yolu" % (t_ or "-", ", ".join("%s=%d" % kv for kv in sorted(hk_oz.items())) or "-"))
    else:
        ekle("GERCEKCILIK: HAREKET KURTARMA (MOVE kabul + yurumuyor)", "VERI YOK", "[HAREKET-KURTAR] yok (v8.818 oncesi RPT, lambs_danger_hareketKurtar kapali ya da hic yurumeyen asker olmadi)")
    # v8.822 CARELESS TEMASTA (kullanici: 'elemanlar catismada careless kaliyor?'): TELEMETRI-GRUP davranisi CARELESS olan satirlar; dusman < 150 m ya da son 20 sn'de temas varsa = HATA (hedef 0)
    cr_t = 0; cr_k = []
    for l in L:
        m_ = re.search(r"\[TELEMETRI-GRUP\] ([^|]+?) \|.*?\| CARELESS/\w+/\w+/\w+ .*?temas:(-?\d+) sn once \|.*?en yakin dusman:(\d+) m", l)
        if m_:
            cr_t += 1
            if int(m_.group(3)) < 150 or int(m_.group(2)) > -20: cr_k.append("%s %s m / temas %s sn" % (m_.group(1).strip(), m_.group(3), m_.group(2)))
    tl_ = len([1 for l in L if "[TELEMETRI-GRUP]" in l])
    if tl_ >= 5:
        ekle("GERCEKCILIK: CARELESS TEMASTA", "GECTI" if not cr_k else "KALDI", "telemetri %d satir, CARELESS %d (%%%.0f) | dusman < 150 m ya da temas varken CARELESS: %d %s (0 olmali; v8.822: hareket kurtarma CARELESS'i yalniz dusman >= 150 m, baski < 0.3, 4 sn, grup duzeyinde geri alinir)" % (tl_, cr_t, 100.0 * cr_t / tl_, len(cr_k), cr_k[:3]))
    # v8.825: DOST ATES HATTI (bastirma) + RPG tani
    dh_l = [l for l in L if "[DOST-HATTI]" in l]
    dh_oz = len(dh_l)
    ekle("GERCEKCILIK: DOST ATES HATTI (bastirma)", "BILGI", "engellenen bastirma atesi (log: ilk 20 + 30 sn'de bir) %d | ilk: %s | KONTROL: oyunda dost hattina bastirma atesi gorulmemeli; [DOST-HATTI] satiri varsa onleme calisiyor" % (dh_oz, dh_l[0].split("[DOST-HATTI]",1)[1].strip()[:170] if dh_l else "-"))
    rz_l = [l for l in L if "[RPG-ZORLA]" in l]
    if rz_l:
        rz_ok = len([1 for l in L if "[RPG-ZORLA]" in l and "atildi true" in l])
        ekle("RPG: ZORLA ATIS (v8.828)", "BILGI", "deneme satiri %d (ilk 20 + 30 sn'de bir), atildi true %d | ilk: %s | KONTROL: fireAtTarget / forceWeaponFire sonucu ve 'elde' (roketatar mi tufek mi) hangisi calisiyor" % (len(rz_l), rz_ok, rz_l[0].split("[RPG-ZORLA]",1)[1].strip()[:200]))
    rt_l = [l for l in L if "[RPG-ATILMADI-TANI]" in l]
    if rt_l:
        ekle("RPG: ATILMADI TANISI", "BILGI", "tani satiri %d | ilk: %s" % (len(rt_l), rt_l[0].split("[RPG-ATILMADI-TANI]",1)[1].strip()[:420]))
    ks_ = [l for l in L if "[KOSU-ADIM] BASLA" in l and "retreat" in l]
    if ks_:
        ekle("GERCEKCILIK: RETREAT SCRIPT KOSU", "BILGI", "retreat script kosu basladi %d, hedefe vardi %d (BITTI satirlari ilk 20 + 30 sn'de bir)" % (len(ks_), len([1 for l in L if "[KOSU-ADIM] BITTI" in l and "retreat-" in l and "hedefe vardi" in l])))
    # v8.823: MEKAN DOKTRINI (grup sinifi, titrememe) + SCRIPT KOSU (son care)
    mk_l = [l for l in L if "[MEKAN-DOKTRIN] " in l]
    mk_oz = [l for l in L if "[MEKAN-DOKTRIN-OZET]" in l]
    if mk_l or mk_oz:
        gec_ = {}
        for l in mk_l:
            m_ = re.search(r"^(\d+):(\d+):(\d+).*?\[MEKAN-DOKTRIN\] ([^|]+?) \| (\w+) -> (\w+)", l)
            if m_:
                t_ = int(m_.group(1)) * 3600 + int(m_.group(2)) * 60 + int(m_.group(3))
                gec_.setdefault(m_.group(4).strip(), []).append(t_)
        hizli_ = sum(1 for v in gec_.values() for a_, b_ in zip(v, v[1:]) if b_ - a_ < 60)
        sin_ = collections.Counter()
        for l in mk_oz:
            for m_ in re.finditer(r"(KENTSEL|ORMAN|TEPELIK|KORIDOR|ACIK|KARISIK)=(\d+)", l): sin_[m_.group(1)] += int(m_.group(2))
        ekle("GERCEKCILIK: MEKAN DOKTRINI (grup sinifi)", "GECTI" if hizli_ == 0 else "KALDI", "gecis %d (60 sn'den kisa aralikli %d; 0 olmali: histerezis) | sinif taramasi: %s | ilk: %s | KONTROL: acik arazide bound / hucum mesafesi uzadi mi, ormanda / kentte kisaldi mi (karne: acikta kalma, bound ilerlemesi)" % (sum(len(v) for v in gec_.values()), hizli_, dict(sin_) or "-", mk_l[0].split("[MEKAN-DOKTRIN]",1)[1].strip()[:150] if mk_l else "-"))
    else:
        ekle("GERCEKCILIK: MEKAN DOKTRINI (grup sinifi)", "VERI YOK", "[MEKAN-DOKTRIN] yok (v8.823 oncesi RPT, mekanDoktrin kapali ya da hucum / bound / overwatch / pusu kararina giren grup olmadi)")
    ka_b = len([1 for l in L if "[KOSU-ADIM] BASLA" in l])
    ka_s = len([1 for l in L if "[KOSU-ADIM] BITTI" in l and "hedefe vardi" in l])
    if ka_b:
        ekle("GERCEKCILIK: SCRIPT KOSU (son care)", "BILGI", "basladi %d | hedefe vardi %d (log ilk 20 + 30 sn'de bir) | KONTROL: kosu dogal gorundu mu (animasyon / yon), askerler duvara / nesneye takildi mi" % (ka_b, ka_s))
    # v8.822: IKILI SICRAMA (2-3 kisilik ekip buddy bounding) + ACIK ALAN DOLASMA (bypass)
    ik_l = [l for l in L if "[IKILI-SICRAMA]" in l]
    if ik_l:
        ik_g = len(set(re.findall(r"\[IKILI-SICRAMA\] ([^|]+?) \|", "\n".join(ik_l))))
        ekle("GERCEKCILIK: IKILI SICRAMA (2-3 kisilik ekip)", "BILGI", "sicrama satiri %d (ilk 20 + 30 sn'de bir) | grup %d | ilk: %s | KONTROL: sicramadan sonra ekip siperde mi, dusman mesafesi azaliyor mu, ekip kayip veriyor mu" % (len(ik_l), ik_g, ik_l[0].split("[IKILI-SICRAMA]",1)[1].strip()[:160]))
    else:
        ekle("GERCEKCILIK: IKILI SICRAMA (2-3 kisilik ekip)", "VERI YOK", "[IKILI-SICRAMA] yok (2-3 kisilik, temasli, dusman 60-350 m ekip gerekir; v8.822 oncesi RPT ya da ikiliSicrama kapali)")
    dl_b = len([1 for l in L if "[TEHLIKE-ACIK]" in l and "DOLASMA basladi" in l])
    dl_ok = len([1 for l in L if "[TEHLIKE-ACIK]" in l and "DOLASMA SERBEST: TAMAM" in l])
    dl_iptal = len([1 for l in L if "[TEHLIKE-ACIK]" in l and "DOLASMA SERBEST: temas" in l])
    gc_b = len([1 for l in L if "[TEHLIKE-ACIK]" in l and "ACIK ALAN GECISI basladi" in l])
    if dl_b or gc_b:
        ekle("GERCEKCILIK: ACIK ALAN DOLASMA (bypass)", "BILGI", "dolasma basladi %d (tamam %d, temas / retreat ile iptal %d) | dolasma bulunamadi -> eski gecis (gozetle + oncu) %d | KONTROL: dolasma grubu ortulu seritten gitti mi, toplam sure / yol makul mu (oran <= tehlikeAcikDolasOran)" % (dl_b, dl_ok, dl_iptal, gc_b))
    else:
        ekle("GERCEKCILIK: ACIK ALAN DOLASMA (bypass)", "VERI YOK", "[TEHLIKE-ACIK] yok (rota ortu kenarindan >= 60 m acik alana giren >= 5 kisilik, temassiz grup gerekir)")
    # v8.812 (kullanici: 'retreat coz'; RPT beabaf64: grup 80 sn'de yok oldu, WITHDRAW yok): erken cekilme tetigi / reddi
    ec_tet = len([1 for l in L if "erken cekilme:" in l])
    ec_red = [l for l in L if "[ERKEN-CEKILME-RED]" in l]
    ol_ = len([1 for l in L if "[OLAY]" in l and "| Casualty |" in l])
    ec_kar = [l for l in L if "[ERKEN-CEKILME-KARAR]" in l]
    ak_ = [l for l in L if "[AGIR-KESINTI]" in l]
    ka_ = [l for l in L if "[KACIS-ARKA]" in l]
    ekle("GERCEKCILIK: ERKEN CEKILME (kayip hizi / orani)", "BILGI", "kacis noktasi arka alan (v8.814+; [KACIS-ARKA]) %d, ilk: %s | agir kayip kesintisi (taktik kilidi kirildi, v8.813+) %d, ilk: %s | erken cekilme karari %d | esik asildi ama tetiklenmedi (RED, ilk 25 log) %d | grup kaybi (Casualty olayi) %d | esik asildi ama karar WITHDRAW degil (KARAR logu) %d, ilk: %s | ilk RED: %s (v8.812+: gorunen dusman <= 3 iken guc orani sarti kalkti; PUSH agir uzak kayipta WITHDRAW'a yol verir)" % (len(ka_), (re.sub(r'^.*?"\[KACIS-ARKA\] ', "", ka_[0]).strip().rstrip('"')[:170]) if ka_ else "-", len(ak_), (re.sub(r'^.*?"\[AGIR-KESINTI\] ', "", ak_[0]).strip().rstrip('"')[:170]) if ak_ else "-", ec_tet, len(ec_red), ol_, len(ec_kar), (re.sub(r'^.*?"\[ERKEN-CEKILME-KARAR\] ', "", ec_kar[0]).strip().rstrip('"')[:200]) if ec_kar else "-", (re.sub(r'^.*?"\[ERKEN-CEKILME-RED\] ', "", ec_red[0]).strip().rstrip('"')[:230]) if ec_red else "-"))
    ekle("GERCEKCILIK: BASKI ETKISI (kafa egme / karsilik dususu)", "VERI YOK", "sayac yok: sonraki adim (baski altindaki bot orani + baski altindaki botun atis hizi); simdilik [DURUS-DISIPLIN-OZET] ve [VURULDU-TEPKI] satirlarina bak")

    print("=" * 100); print("KABUL TESTI |", path)
    for ad, d, k in sat:
        print("  [%-8s] %-24s %s" % (d, ad, k))
    sy = collections.Counter(d for _, d, _ in sat)
    print("  GECTI:%d  KALDI:%d  KONTROL:%d  VERI YOK:%d  (BILGI:%d)" % (sy["GECTI"], sy["KALDI"], sy["KONTROL"], sy["VERI YOK"], sy["BILGI"]))
    if sy["VERI YOK"]:
        print("  VERI YOK olanlar o ozelligi tetikleyen senaryo calismadi; TEST_PROTOKOLU.md'deki senaryolarla tamamlanir.")


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


def onucus_karne(path):
    """ON UCUS karnesi (v8.500l): fnc_onUcus'un [ONUCUS] / [ONUCUS-UYARI] satirlari + [EDEN-IFADE] ozeti. Duman testi (1-2 dk) ile yapilandirma sorunlarini ayiklar."""
    L = open(path, encoding="utf-8", errors="replace").read().splitlines()
    on = [l for l in L if '"[ONUCUS]' in l]
    uy = [l for l in L if '"[ONUCUS-UYARI]' in l]
    ifade = [l for l in L if '[EDEN-IFADE]' in l]
    def kes(l, n=210): return re.sub(r"^\s*", "", l)[:n]
    print("=" * 78)
    print("ON UCUS KARNESI |", path)
    if not on:
        print("  [YOK    ] ON UCUS blogu yok (paket eski mi? 'ONUCUS' satiri yazilmamis; oyun >= 30 sn calismis olmali)")
        return
    runs = [l for l in on if "| RUN |" in l or "RUN |" in l.split("[ONUCUS]")[-1][:8]]
    print("  oturum sayisi (RUN):", len(runs))
    for l in runs: print("   ", kes(l))
    def say(tag): return len([l for l in on if ("[ONUCUS] " + tag + " |") in l])
    mod = [l for l in on if "[ONUCUS] MODUL |" in l and "toplam" not in l]
    nit_yok = [l for l in mod if re.search(r"nitelik degiskeni 0:", l)]
    print("  moduller: %d | nitelik degiskeni OLMAYAN modul: %d" % (len(mod), len(nit_yok)))
    print("  [EDEN-IFADE] satiri: %d %s" % (len(ifade), "(3DEN nitelik ifadeleri CALISIYOR)" if ifade else "(HIC YOK: ifadeler calismiyor ya da paket eski)"))
    for l in ifade[:6]: print("   ", kes(l, 150))
    print("  grup: %d | arac: %d | topcu: %d | IHA: %d | oyuncu: %d" % (say("GRUP"), say("ARAC"), say("TOPCU"), say("IHA"), say("OYUNCU")))
    for l in on:
        if "[ONUCUS] KAPASITE |" in l: print("   ", kes(l, 160))
    print("  UYARI (%d):" % len(uy))
    for l in uy: print("   !", kes(l, 230))
    if not uy: print("    (yok)")

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
    for tag, ad, baslangic in [("ZEKA-HAZIRLIK", "hucum hazirlik penceresi", None), ("ZEKA-BASKI", "baski tufekcisi atamasi", "baslatildi"), ("ZEKA-YAN", "yan koruma / arka emniyet", "baslatildi"), ("ZEKA-NOKTA", "nokta elemani (traveling overwatch)", "baslatildi"), ("ZEKA-YETIM", "tek kalan katilimi", "baslatildi"), ("PANIK", "panik / felc", "baslatildi"), ("GIZLI", "gizli algi (ayak sesi + isik)", "baslatildi"), ("MEKANIZE", "mekanize dur-kalk izleyici", "baslatildi"), ("ARAC-MEDEVAC", "aracli medevac", "baslatildi"), ("HALT", "halt (slot kovalama kesici)", "baslatildi"), ("GOZCU", "ileri gozcu + RTO", "baslatildi"), ("CEPHANE", "cephane + bomba paylasimi", "baslatildi"), ("TEHLIKE-ALANI", "yol gecisi", "baslatildi"), ("BAYGIN-ROE", "bayilana patlayici iptali", None), ("TCCC-DURGUN", "hekim durgun mudahale", None), ("SINSI-GERI", "sinsi geri cekilme", "baslatildi"), ("ACE-TEDAVI", "ACE tedavi olaylari", None), ("HQ-DESTEK", "destek atesi", None), ("LIDER-DEVRI", "lider devri", None), ("LIDER-DEVRI-HALEF", "lider halef degisimi", None), ("CEPHANE-NEDEN", "cephane verici yok nedeni", None), ("CEPHANE-TANI", "cephane dusuk cephane tanisi", None), ("BUDDY-ES", "MG / AT asistan cifti", None), ("SIS-EKONOMI", "sis ekonomisi", None), ("ARAC-SENKRON", "arac piyade senkronu", None), ("PLAN", "komutan plani", None), ("PLAN-OZET", "plan sonuc / AAR", None), ("PLAN-KAPI", "plan sunucu kapisi", None), ("PLAN-ISTEK", "plan istegi (istemci)", None), ("PLAN-DEVIR", "grup sahipligi sunucuya devri", None), ("SUNUCU-DEVIR", "AI grubu sunucuya devir", "baslatildi"), ("TELEMETRI", "telemetri", "baslatildi"), ("TELEMETRI-SUNUCU", "sunucu fps / ozet", None), ("TELEMETRI-GRUP", "grup telemetrisi", None), ("HIZ-ANOMALI", "yaya hiz anomalisi", None), ("DONUS-OZET", "donus animasyonu", None), ("GOREV-ATAMA", "Zeus gorev atamasi", None), ("KARAKOL", "karakol / HQ kaydi + alarm", None), ("TASIMA", "arac nakli", None), ("ARAC-SURUCU", "gorevli arac surucu durumu", None), ("PLAN-RECON", "recon (kesif unsuru)", None), ("RECON-ARAC", "recon araci (sessiz tasima)", None), ("TCCC-ESYA", "hekim esya tedarigi", None), ("SU-KURTAR", "suda kalan asker kurtarma", None), ("TOPCU-TEST", "Zeus topcu test atisi", None), ("ARAC-SU", "arac suya girdi / geri donus", None), ("PLAN-HQ-TUM", "HQ tamami saldirisi", None), ("PLAN-SAVUNMA", "savunma komutani (karsi saldiri / kayip)", None), ("TASIMA-KIN", "kinematik surus (AI surmeyen arac)", None), ("PLAN-FRAGO", "saldiri basarisiz dali", None), ("HQ-MODUL", "kumanda otomatik acilis", None), ("RECON-ARAC-TANI", "recon araci donma tanisi", None), ("TASIMA-ZIPLAMA", "donmus arac ziplama sinamasi", None), ("TASIMA-YOL", "rota hesabi tanisi", None), ("EZME-YOL-AC", "duran araca onunden cekilme", None), ("TASIMA-SIM", "kalkamayan arac simulasyon / baglanti tanisi", None), ("TASIMA-FIZIK", "kalkamayan arac fizik tanisi", None), ("PLAN-ISTIHBARAT", "istihbarat raporu / iddia farki", None), ("PLAN-ZARAR", "atis sonrasi sivil / dost kaybi", None), ("KARAKOL-GARNIZON", "karakol garnizonu", "baslatildi"), ("KARAKOL-GARNIZON-OZET", "garnizon ozeti", None), ("KARAKOL-DEVRIYE", "akilli / planli devriye (sektor, tur takvimi)", None), ("HAREKAT", "fazli harekat (faz / objektif / plan)", "kuruldu"), ("HAREKAT-AAR", "harekat olay ozeti (AAR)", None), ("ATES-HATI", "yakin duvar - bastirma hatti kapali (v8.403)", None), ("IHA-SILAH", "silahli IHA yere atis / tehdit tirmanisi (v8.402)", "SILAHLI IHA"), ("SIPER-TANI", "siper bulunamadi - nesne turu tanisi (v8.402)", None), ("KARAKOL-DEVRIYE-HABER", "devriye agi (temas haberi / destek)", None), ("KARAKOL-YANIT", "garnizon yaniti", None), ("TAKSI", "arac taksisi", "baslatildi"), ("EZME", "ezme korumasi (fren)", "baslatildi"), ("EZME-BAYGIN", "dost yaya bayildi + yakin arac", None), ("EZME-NABIZ", "ezme korumasi nabzi", None), ("OYUNCU-KOMUTA", "oyuncu komutasi gruplari", None), ("GIYIM-TANI", "giyim / techizat tanisi", "baslatildi"), ("KOMUTAN-ZIHIN", "komutan zihni (gozlem + hipotez)", "baslatildi"), ("KOMUTAN-TAVIR", "komutan tavri (puanlama + kisilik)", None), ("PLAN-ZIRH", "plan zirh destek (tank ates pozisyonu)", None), ("PLAN-ARAC", "elle secilen arac gruplari", None), ("ARAC-SINIF", "arac sinifi (TANK / IFV / APC / KAMYON)", None), ("SU-TANI", "askerin suya girmesi tanisi", None), ("ARAC-ATES", "tasima araci silahci atisi", None), ("ARAC-UZAK", "aractan / enkazdan uzaklasma", "baslatildi"), ("TASIMA-TAKILMA", "kalkamayan arac derin tani (koltuk / waypoint / komsu / AI ozellik)", None), ("ARAC-DURUM", "tasima araci is sonu / park nedeni + tam durum", None), ("KALDIR", "karakol / plan kaldirma", None), ("HQ-NOKTA", "HQ / US kaydi ve squad atamasi", None), ("HQ-ISTEK", "HQ atama istegi (istemci)", None), ("KALDIR-ISTEK", "kaldirma istegi (istemci)", None), ("MEVZI", "savunma mevzi / statik silah / garrison", None), ("CEPHANE-ENV", "cephane aktariminda kiyafet degisimi", None), ("MURETTEBAT-KORU", "arac murettebat koruma", "baslatildi"), ("KARAKOL-ISTEK", "karakol istegi (istemci)", None), ("PLAN-ATAMA", "plan: atamali gruplar / rol ezme", None), ("PLAN-YANIT", "plan sunucu yaniti", None), ("PLAN-UYARI", "manuel nokta uyarisi", None), ("PLAN-MANUEL", "manuel plan noktasi", None), ("PLAN-TOPCU", "topcu destegi", None), ("PLAN-ROE", "plan ROE", None), ("MERMI", "mermi disiplini", "baslatildi")]:
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
    sey = [l for l in open(path, encoding="utf-8", errors="replace").read().splitlines() if "[KOMUTAN-FORM]" in l and "| SEYIR |" in l]
    print("  [SEYIR FORMASYONU] %d degisim (v8.269; temassiz hareketli gruplar). Ornek: %s" % (len(sey), "; ".join(x.split('" ', 1)[-1][:100] for x in sey[:2]) if sey else "yok - v8.269'dan once ya da gruplar hareket etmedi"))
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


def _kv(satir):
    """'[ETIKET] k=v | k=v ...' satirini sozluge cevirir."""
    govde = satir.split("] ", 1)[1] if "] " in satir else satir
    d = {}
    for parca in govde.split(" | "):
        if "=" in parca:
            k, v = parca.split("=", 1)
            d[k.strip()] = v.strip().strip('"')
    return d

def tani(path):
    """v8.255 TANI PAKETI ozeti: olum nedenleri, hendek kullanimi, arac terk, tank hareket, kayip esigi, duman. Otomatik cikarim 'CIKARIM:' satirlari."""
    L = open(path, encoding="utf-8", errors="replace").read().splitlines()
    def al(etiket): return [l for l in L if ('"[%s] ' % etiket) in l]   # yalniz satir BASINDAKI etiket (ELITE-BOOT surum notundaki gecen etiketleri sayma)
    print("=" * 78)
    b = re.search(r"build (v[0-9.]+[A-Za-z-]*)", "\n".join(L))
    print(path, "| TANI |", b.group(1) if b else "boot satiri yok")
    # ---- olum
    ol = [_kv(l) for l in al("OLUM-TANI")]
    print("\n-- OLUM TANISI (%d olum) --" % len(ol))
    if ol:
        by = collections.defaultdict(list)
        for d in ol: by[d.get("taraf", "?")].append(d)
        for t, ds in sorted(by.items()):
            hg = [d for d in ds if d.get("hendek_grubu") == "true"]
            hi = [d for d in hg if d.get("hendek_icinde") == "true"]
            hd = [d for d in hg if d.get("hendek_icinde") != "true"]
            tp = [d for d in ds if d.get("topcu_olasi") == "true"]
            tp_hi = [d for d in tp if d.get("hendek_icinde") == "true"]
            ar = [d for d in ds if d.get("aracta", "-") != "-"]
            dr = collections.Counter(d.get("durus", "?") for d in ds)
            print("  %-6s toplam:%-3d hendek_grubundan:%-3d (icinde:%d, DISINDA:%d) topcu_olasi:%-3d (icinde:%d, disinda:%d) aracta:%d durus:%s" % (t, len(ds), len(hg), len(hi), len(hd), len(tp), len(tp_hi), len(tp) - len(tp_hi), len(ar), dict(dr)))
            if hg and len(hd) >= 0.5 * len(hg):
                print("  CIKARIM: %s hendek grubunun olenlerinin %d/%d'si hendek ALANI DISINDA oldu -> hendege girmeme olum nedenlerinden biri." % (t, len(hd), len(hg)))
            if ds and len(tp) >= 0.5 * len(ds):
                print("  CIKARIM: %s olumlerinin %d/%d'si topcu dususune denk geliyor (<=35 m, <=3 sn)." % (t, len(tp), len(ds)))
            if tp and tp_hi and len(tp_hi) >= 0.5 * len(tp):
                print("  CIKARIM: %s topcu olumlerinin yarisindan fazlasi hendek ICINDE -> hendek yetersiz (topcu dogrudan isabet); girmeme tek neden degil." % t)
        for o in al("OLUM-OZET")[-3:]: print("  ", o.split('" ', 1)[-1][:160])
    else:
        print("  kayit yok (v8.255 yuklu mu? ELITE-BOOT satirina bak)")
    # ---- hendek
    hd = [_kv(l) for l in al("HENDEK-DURUM")]
    print("\n-- HENDEK DURUMU (%d satir) --" % len(hd))
    for d in hd[:24]:
        print("  %s t=%s alan=%s boyut=%s kapasite=%s atanan=%s icinde=%s yolda=%s disinda=%s %s" % (d.get("grup"), d.get("t"), d.get("alan"), d.get("boyut"), d.get("kapasite"), d.get("atanan"), d.get("icinde"), d.get("yolda"), d.get("disinda", "").split(" ")[0], " ".join(d.get("disinda", "").split(" ")[1:])[:90]))
    t90 = [d for d in hd if d.get("t") == "90sn"]
    if t90:
        a_ = sum(int(d.get("atanan", 0)) for d in t90); i_ = sum(int(d.get("icinde", 0)) for d in t90)
        print("  90 sn toplam: atanan %d, icinde %d (%.0f%%)" % (a_, i_, 100.0 * i_ / max(a_, 1)))
        for d in t90:
            if int(d.get("atanan", 0)) > int(d.get("kapasite", 99)):
                print("  CIKARIM: %s alan %s: atanan %s > kapasite %s -> alan kucuk, askerler sigmiyor." % (d.get("grup"), d.get("alan"), d.get("atanan"), d.get("kapasite")))
        seen = set()
        for d in t90:
            if d.get("alan") not in seen:
                seen.add(d.get("alan")); print("  alan %s nesneler: %s" % (d.get("alan"), d.get("nesneler", "")[:140]))
    for v in al("HENDEK-VARIS")[:12]: print("  ", v.split('" ', 1)[-1][:150])
    # ---- arac terk
    at = [_kv(l) for l in al("ARAC-TERK")]
    print("\n-- ARAC TERK (%d) --" % len(at))
    for d in at[:20]:
        neden = "belirsiz"
        try: sy = int(d.get("son_hasar_yasi", 999))
        except ValueError: sy = 999
        parca = d.get("hasarli_parca", "[]")
        if d.get("durum") == "DEAD": neden = "birim OLU (Zeus silme / olum)"
        elif d.get("canMove") == "false" and parca not in ("[]", ""): neden = "parca hasari (%s) sonrasi hareketsiz: AI terk (allowCrewInImmobile bunu onler)" % parca[:60]
        elif d.get("canMove") == "false" and sy <= 15: neden = "hasar sonrasi hareketsiz"
        elif d.get("birim_komutu") == "GET OUT": neden = "komut GET OUT (AI / script emri); arac hasari %s" % d.get("arac_hasar")
        elif d.get("surucu") in ("-", ""): neden = "surucu yok"
        print("  %s %s inen=%s rol=%s hasar=%s canMove=%s son_hasar=%ss komut=%s -> %s" % (d.get("arac"), d.get("grup"), d.get("inen"), d.get("rol"), d.get("arac_hasar"), d.get("canMove"), d.get("son_hasar_yasi"), d.get("birim_komutu"), neden))
    print("  ARAC-BINDI (tank mürettebat geri biniş): %d" % len(al("ARAC-BINDI")))
    # ---- hareket
    hr = [_kv(l) for l in al("ARAC-HAREKET")]
    print("\n-- TANK HAREKETE GECIS (%d) --" % len(hr))
    for d in hr[:14]:
        print("  %s %s durdu=%ss hiz=%s komut=%s hedef=%s planZirh=%s hide=%s vardi=%s tankManevra=%ss atTepki=%ss zirhKac=%ss dusman=%s" % (d.get("arac"), d.get("grup"), d.get("durdu", "").replace("sn", ""), d.get("hiz"), d.get("surucu_komut"), d.get("beklenen_hedef"), d.get("planZirh"), d.get("hide"), d.get("vardi"), d.get("tankManevra_yasi"), d.get("atTepki_yasi"), d.get("zirhKac_yasi"), d.get("en_yakin_dusman")))
    # ---- tank piyade bagi / hareket edemeyen tank (v8.265)
    tz = [l for l in L if ("PIYADE BAGI" in l) or ('"[TANK-TERK]' in l) or ('"[TANK-IMMOBIL]' in l) or ("HAREKET EDEMIYOR" in l)]
    print("\n-- TANK PIYADE BAGI / HAREKET EDEMEYEN TANK (%d satir) --" % len(tz))
    for v in tz[:16]: print("  ", v.split('" ', 1)[-1][:240])
    # ---- v8.276: tank taret bakisi / ileri sicrama / teslim / butun grup nakli / guvenli sefer
    tb = al("TANK-BAKIS")
    sc = [l for l in L if "ILERI SICRAMA" in l]
    print("\n-- TANK TARET BAKISI: %d satir | ILERI SICRAMA: %d --" % (len(tb), len(sc)))
    for v in (tb[:6] + sc[:6]): print("  ", v.split('" ', 1)[-1][:240])
    ts = [l for l in L if '"[TESLIM] ' in l and "teslim oldu" in l]
    tm = [l for l in L if "kayitli CBA teslim esikleri" in l]
    print("-- TESLIM: %d grup teslim oldu | eski CBA esik tasima notu: %d --" % (len(ts), len(tm)))
    for v in (tm[:1] + ts[:6]): print("  ", v.split('" ', 1)[-1][:240])
    ta = [l for l in L if '"[TANK-ATIS]' in l and "atis " in l]
    th = [l for l in L if '"[TANK-HASAR]' in l]
    print("-- TANK ATIS / HASAR (v8.279): %d atis logu, %d hasar logu --" % (len(ta), len(th)))
    for v in (ta[:6] + th[:8]): print("  ", v.split('" ', 1)[-1][:250])
    tpa = [l for l in L if '"[TOPCU-ATIS]' in l or '"[TOPCU-TEST]' in l]
    print("-- TOPCU (v8.287): %d [TOPCU-ATIS] / [TOPCU-TEST] satiri --" % len(tpa))
    for v in tpa[:12]: print("  ", v.split('" ', 1)[-1][:300])
    dy = [l for l in L if '"[DRON-YON]' in l]
    da = [l for l in L if '"[DRON-ATES]' in l]
    td = [l for l in L if '"[TANK-DRON]' in l]
    dsk = [l for l in L if '"[DRON-SAKLAN]' in l]
    print("-- DRON TEPKISI (v8.280): [DRON-YON] %d | [DRON-ATES] %d | [TANK-DRON] %d | [DRON-SAKLAN] %d --" % (len(dy), len(da), len(td), len(dsk)))
    for v in (dy[:3] + da[:3] + td[:4] + dsk[:3]): print("  ", v.split('" ', 1)[-1][:260])
    pt = [l for l in L if '"[PUSU-TEPKI]' in l]
    pc = [l for l in L if '"[PUSU-CAGRI]' in l or '"[DRON-KARSI-ATES]' in l]
    ik = [l for l in L if '"[ISTIKSAF]' in l]
    tb = [l for l in L if '"[TESLIM-BIREY]' in l]
    print("-- PUSU / GERILLA (v8.307-308): [PUSU-TEPKI] %d | cagri atesi ([PUSU-CAGRI] / [DRON-KARSI-ATES]) %d | [ISTIKSAF] %d | [TESLIM-BIREY] %d --" % (len(pt), len(pc), len(ik), len(tb)))
    for v in (pt[:4] + pc[:4] + ik[:4] + tb[:4]): print("  ", v.split('" ', 1)[-1][:280])
    pat = [l for l in L if '"[PATLAYICI]' in l]
    pod = [l for l in L if '"[PATLAYICI-OZET]' in l]
    print("-- PATLAYICI (v8.310): %d atis | %d ozet (yontem: FAT = fireAtTarget calisti, FWF = forceWeaponFire, 'YOK' = calismadi) --" % (len(pat), len(pod)))
    for v in (pat[:8] + pod[-2:]): print("  ", v.split('" ', 1)[-1][:260])
    ah = [l for l in L if '"[ATES-HAREKET]' in l]
    aho = [l for l in L if '"[ATES-HAREKET-OZET]' in l]
    print("-- ATES VE HAREKET (v8.317): %d grup satiri | %d ozet (rush / 'b' / siperli nokta yok / takas) --" % (len(ah), len(aho)))
    for v in (ah[:5] + aho[-2:]): print("  ", v.split('" ', 1)[-1][:280])
    av = [l for l in L if '"[DRON-AVI]' in l]
    print("-- DRON OPERATORU AVI (v8.320): %d [DRON-AVI] satiri (devriye gonderildi / bitti) --" % len(av))
    for v in av[:6]: print("  ", v.split('" ', 1)[-1][:300])
    zn = [l for l in L if '"[PLAN-ZINCIR]' in l or '"[PLAN-TUT]' in l]
    print("-- HEDEF ZINCIRI / TUT (v8.214, v8.324): %d [PLAN-ZINCIR] / [PLAN-TUT] satiri --" % len(zn))
    for v in zn[:8]: print("  ", v.split('" ', 1)[-1][:300])
    pa = [l for l in L if '"[PLAN-ARAC]' in l and "[TANK]" in l]
    pg = [l for l in L if '"[PLAN-GRUP-BOS]' in l]
    print("-- TANK PLANA ALINDI / ALINMADI (v8.325): %d [PLAN-ARAC][TANK] satiri | %d [PLAN-GRUP-BOS] (liste erken bosaldi) --" % (len(pa), len(pg)))
    for v in (pa[:6] + pg[:3]): print("  ", v.split('" ', 1)[-1][:300])
    dg = [l for l in L if '"[DRON-GOZLEM]' in l]
    print("-- DRON GOZLEMCISI (v8.336): %d [DRON-GOZLEM] satiri (talep / hazir dron / gozlemci asker / gozlemci yok) --" % len(dg))
    for v in dg[:8]: print("  ", v.split('" ', 1)[-1][:300])
    dt = [l for l in L if '"[DRON-TOPCU]' in l]
    dtc = [l for l in dt if "CAGRI" in l]
    dta = [l for l in dt if "ADJUST " in l and "SPLASH" in l]
    dte = [l for l in dt if "ETKI ATESI" in l or "REPEAT" in l]
    dts = [l for l in dt if "SON (END OF MISSION)" in l]
    dto = [l for l in L if '"[DRON-TOPCU-OZET]' in l]
    tz = [l for l in L if '"[TACIZ]' in l]
    kg = [l for l in L if "ATMADI (kitap emniyeti)" in l or "(NFA)" in l]
    print("-- DRON GOZLEMLI TOPCU + TACIZ (v8.338): %d [DRON-TOPCU] | cagri %d | adjust/splash %d | etki/repeat %d | gorev sonu %d | %d [TACIZ] | %d kitap-emniyeti/NFA reddi | %d ozet --" % (len(dt), len(dtc), len(dta), len(dte), len(dts), len(tz), len(kg), len(dto)))
    for v in (dtc[:3] + dta[:6] + dte[:3] + dts[:4] + tz[:5] + kg[:4] + dto[-2:]): print("  ", v.split('" ', 1)[-1][:340])
    sb = [l for l in L if '"[SIS-BUTCE]' in l]
    se = [l for l in L if '"[SIS-EKONOMI]' in l]
    print("-- SIS BUTCESI (v8.330): %d [SIS-BUTCE] ret | %d [SIS-EKONOMI] atlanan --" % (len(sb), len(se)))
    for v in sb[:8]: print("  ", v.split('" ', 1)[-1][:260])
    ie = [l for l in L if '"[IHA-ETKI]' in l]
    print("-- FPV-AT ETKISI (v8.329): %d [IHA-ETKI] (hedef hasar / parcalar > 0.3 / canMove canFire) --" % len(ie))
    for v in ie[:8]: print("  ", v.split('" ', 1)[-1][:300])
    uk = [l for l in L if '"[ARAC-UNSTUCK]' in l and "KADEME" in l]
    uo = [l for l in L if '"[ARAC-UNSTUCK-OZET]' in l]
    print("-- ARAC UNSTUCK (v8.328): %d kademe satiri | %d ozet --" % (len(uk), len(uo)))
    for v in (uk[:8] + uo[-2:]): print("  ", v.split('" ', 1)[-1][:300])
    dm = [l for l in L if '"[IHA-DUMAN]' in l]
    og = [l for l in L if '"[OTO-GARNIZON]' in l]
    ka = [l for l in L if '"[DRON-KARSI-ATES]' in l]
    dv = [l for l in L if '"[DRON-AVI]' in l and "devriye cikmadi" in l]
    print("-- v8.327: %d [IHA-DUMAN] (kilit / kor dalis) | %d [OTO-GARNIZON] | %d [DRON-KARSI-ATES] (eminlik) | %d 'devriye cikmadi' nedeni --" % (len(dm), len(og), len(ka), len(dv)))
    for v in (dm[:4] + og[:6] + ka[:3] + dv[:2]): print("  ", v.split('" ', 1)[-1][:320])
    ds = [l for l in L if "[IHA-DALIS]" in l and "dalis basladi" in l]
    print("-- IHA-DALIS: 'dalis basladi' %d kez (v8.279 sonrasi sortide ~1 olmali; >5 = dalis yine her adimda iptal ediliyor) --" % len(ds))
    au = [l for l in L if '"[ATIS-USTUNLUK]' in l]
    auo = [l for l in L if '"[ATIS-USTUNLUK-OZET]' in l]
    print("-- ATIS USTUNLUGU (v8.355): %d [ATIS-USTUNLUK] (grup bazli ilk emir) | %d ozet --" % (len(au), len(auo)))
    for v in (au[:6] + auo[-3:]): print("  ", v.split('" ', 1)[-1][:300])
    cc = [l for l in L if '"[CQB-CEVIK]' in l]
    oz = [l for l in L if '"[OZGUVEN]' in l]
    isn = [l for l in L if '"[ISINLANMA]' in l]
    ss = [l for l in L if '"[STEALTH-SES]' in l]
    print("-- v8.368: %d [CQB-CEVIK] (yanal atilim; civilenmis tespit %d) | %d [OZGUVEN] (courage) | %d [ISINLANMA] (arac murettebati geri alindi) | %d [STEALTH-SES] --" % (len(cc), len([l for l in cc if "CIVILENMIS" in l]), len(oz), len(isn), len(ss)))
    for v in (cc[:5] + oz[:3] + isn[:4] + ss[:3]): print("  ", v.split('" ', 1)[-1][:320])
    yn = [l for l in L if '"[YIGILMA-NEDEN]' in l]
    yc = [l for l in L if '"[YIGILMA-COZ]' in l]
    yb = [l for l in L if '"[YIGILMA-BAYGIN]' in l]
    td = [l for l in L if '"[TCCC-DURUS]' in l]
    nedenler = collections.Counter()
    for l in yn:
        for m in re.finditer(r'=([A-Z][A-Z-]+)(?:\(muaf\))?(?:,|"|$)', l.split("uyeler: ", 1)[-1]): nedenler[m.group(1)] += 1
    print("-- v8.367 YIGILMA NEDENI: %d [YIGILMA-NEDEN] (kalici kume) | %d [YIGILMA-COZ] (%d tasima) | %d [YIGILMA-BAYGIN] | %d [TCCC-DURUS] --" % (len(yn), len(yc), len([l for l in yc if "bos noktaya" in l]), len(yb), len(td)))
    if nedenler: print("   uye nedenleri:", ", ".join("%s:%d" % (k, v) for k, v in nedenler.most_common()))
    print("   OKUMA: ACIK-SIPER-ORTAK / BOUND-KAPSAMA / TEMAS-DURAN / FORMASYON-SIKISIK = cozulebilir yigilma (cozucu tasir); HEKIM / BOMBA / ISTASYON / BOUND-VARIS / EMIR-FM / BINA = muaf (bilincli emir); YIGILMA-BAYGIN = askerler birlikte vuruldu")
    for v in (yn[:5] + yc[:5] + yb[:3] + td[:4]): print("  ", v.split('" ', 1)[-1][:340])
    ec = [l for l in L if '"[ELIT-COVER]' in l]
    yt = [l for l in L if '"[YETIM-TOPLA]' in l]
    pl = [l for l in L if '"[PEEL]' in l]
    sl = [l for l in L if '"[SIHA-LAZER]' in l]
    print("-- v8.365 CANLANDIRILAN OLU KOD: %d [ELIT-COVER] (findCover bos -> raycast yedegi) | %d [YETIM-TOPLA] (liderden kopuk asker doFollow) | %d [PEEL] (kademeli cekilme karari) | %d [SIHA-LAZER] (LG atisi: %d BDA imha) --" % (len(ec), len(yt), len(pl), len(sl), len([l for l in sl if "IMHA" in l and "BDA" in l])))
    for v in (ec[:5] + yt[:5] + pl[:3] + sl[:6]): print("  ", v.split('" ', 1)[-1][:300])
    iu = [l for l in L if '"[IHA-UCAK]' in l]
    iek = [l for l in L if '"[IHA-ENVANTER]' in l and "kategori" in l]
    isg = [l for l in L if '"[IHA-SORTI]' in l and ("UCAK gozlem" in l or "gozlem devriyesi bitti" in l or "kategori" in l)]
    print("-- v8.363 VANILLA / MOD IHA: %d [IHA-UCAK] (ucak havadan baslatma / hiz) | %d [IHA-ENVANTER] kategorili sinif (UCAK %d / HELI %d / KARA %d) | %d gozlem satiri --" % (len(iu), len(iek), len([l for l in iek if "kategori UCAK" in l]), len([l for l in iek if "kategori HELI" in l]), len([l for l in iek if "kategori KARA" in l]), len(isg)))
    for v in (iu[:4] + isg[:6]): print("  ", v.split('" ', 1)[-1][:300])
    ed = [l for l in L if '"[EDEN]' in l]
    print("-- v8.362 3DEN: %d [EDEN] satiri (modul calistirma / red nedeni) --" % len(ed))
    for v in ed[:12]: print("  ", v.split('" ', 1)[-1][:300])
    tma = [l for l in L if '"[TANK-MUHIMMAT-ATIS]' in l]
    print("-- v8.361 TANK GERCEK ATIS: %d [TANK-MUHIMMAT-ATIS] (silah / mermi / tur: HE'li satir %d) --" % (len(tma), len([l for l in tma if "tur HE" in l])))
    for v in tma[:8]: print("  ", v.split('" ', 1)[-1][:300])
    tm = [l for l in L if '"[TANK-MUHIMMAT]' in l]
    tmo = [l for l in L if '"[TANK-MUHIMMAT-OZET]' in l]
    print("-- v8.359 TANK MUHIMMAT: %d [TANK-MUHIMMAT] (ana top / degisim / DESTEKSIZ) | %d ozet --" % (len(tm), len(tmo)))
    for v in (tm[:8] + tmo[-3:]): print("  ", v.split('" ', 1)[-1][:320])
    ta = [l for l in L if '"[TESLIM-ANIM]' in l]
    tg = [l for l in L if '"[TCCC-GITGEL]' in l]
    print("-- v8.358: %d [TESLIM-ANIM] (zorlandi: %d) | %d [TCCC-GITGEL] (hekim geri savruldu) --" % (len(ta), len([l for l in ta if "zorlandi: true" in l]), len(tg)))
    for v in (ta[:5] + tg[:5]): print("  ", v.split('" ', 1)[-1][:300])
    idn = [l for l in L if '"[IHA-DONUS]' in l]
    print("-- IHA EVE DONUS (v8.356): %d [IHA-DONUS] (eve donuyor / yere kondu / YENIDEN HAVALANDI / bitti) | %d 'KOR DALIS' --" % (len(idn), len([l for l in dm if "KOR DALIS" in l])))
    for v in idn[:8]: print("  ", v.split('" ', 1)[-1][:300])
    co = [l for l in L if '"[CEPHANE-OYUNCU]' in l]
    bm = [l for l in L if '"[ACIK-SIPER]' in l and "bina" in l]
    bp = [l for l in L if '"[BINA-PENCERE]' in l]
    print("-- v8.354: %d [CEPHANE-OYUNCU] (oyuncuya mermi) | %d [ACIK-SIPER] bina (ATIS POZISYONU / pasif) | %d [BINA-PENCERE] --" % (len(co), len(bm), len(bp)))
    for v in (co[:6] + bm[:4] + bp[:6]): print("  ", v.split('" ', 1)[-1][:300])
    ck = [l for l in L if '"[CQB-KOSE]' in l]
    cs = [l for l in L if '"[CQB-SIPER]' in l]
    cz = [l for l in L if '"[CQB-KOSE-OZET]' in l]
    cp = [l for l in L if '"[CQB-POZ]' in l]
    print("-- CQB (v8.351): %d [CQB-KOSE] (kose dilimleme: NOKTA / ISTIF) | %d [CQB-SIPER] (yakin mesafe sipere atilma) | %d [CQB-POZ] (bina ici aci) | %d ozet --" % (len(ck), len(cs), len(cp), len(cz)))
    for v in (ck[:8] + cs[:6] + cz[-2:]): print("  ", v.split('" ', 1)[-1][:300])
    zg = [l for l in L if '"[ZIRH-GECIT]' in l]
    zs = [l for l in L if '"[ZIRH-SICRAMA]' in l]
    zu = [l for l in L if '"[ZIRH-UYARI]' in l]
    zt = [l for l in L if '"[TANK-ARALIK]' in l]
    print("-- ZIRH (v8.348-349): %d [ZIRH-GECIT] (rota analizi / piyade temizledi / zaman asimi) | %d [ZIRH-SICRAMA] (sicramali gozetleme) | %d [ZIRH-UYARI] (ATGM uyarisi) | %d [TANK-ARALIK] --" % (len(zg), len(zs), len(zu), len(zt)))
    for v in (zg[:8] + zs[:6] + zu[:4] + zt[:4]): print("  ", v.split('" ', 1)[-1][:300])
    du = [l for l in L if '"[TANK-DUELLO]' in l]
    print("-- TANK DUELLOSU: %d hamle --" % len(du))
    for v in du[:8]: print("  ", v.split('" ', 1)[-1][:260])
    mu = [l for l in L if "MEVZIYE ULASAMADI" in l or "MEVZIYE ULASILAMADI" in l or "shoot-and-scoot" in l]
    print("-- TANK MEVZI (ulasamadi / yer degistirme): %d satir --" % len(mu))
    for v in mu[:8]: print("  ", v.split('" ', 1)[-1][:240])
    tk = [l for l in L if "takim bazli bolunen" in l or "SEFER ERTELENDI" in l or "butun, birden fazla araca" in l or "SEFER:" in l]
    print("-- TASIMA (butun grup / sefer): %d satir --" % len(tk))
    for v in tk[:8]: print("  ", v.split('" ', 1)[-1][:260])
    # ---- recon araci AI surusu (v8.264)
    rh = al("RECON-ARAC-HAREKET")
    print("\n-- RECON ARACI AI SURUSU (%d kayit, ilk 60 sn) --" % len(rh))
    for v in rh[:14]: print("  ", v.split('" ', 1)[-1][:220])
    # ---- kayip esigi
    kd = [_kv(l) for l in al("KAYIP-DEGERLENDIRME")]
    print("\n-- KAYIP DEGERLENDIRME (%d satir) --" % len(kd))
    pl = collections.defaultdict(list)
    for d in kd: pl[d.get("taraf", "?") + " " + (L[0] if False else "")].append(d)
    for k, ds in pl.items():
        ky = [int(x.get("kayip_yuzde", 0)) for x in ds]
        print("  %s tip=%s: ilk %%%d, son %%%d, en yuksek %%%d, son faz %s, kalan %s" % (k.strip(), ds[-1].get("tip"), ky[0], ky[-1], max(ky), ds[-1].get("faz"), ds[-1].get("kalan")))
    for v in al("PLAN-KAYIP-DONUS"): print("  ", v.split('" ', 1)[-1][:170])
    if kd and not al("PLAN-KAYIP-DONUS"):
        mx = max(int(x.get("kayip_yuzde", 0)) for x in kd)
        print("  CIKARIM: geri cekilme tetiklenmedi; en yuksek kayip %%%d (esik 50)" % mx + (" -> esik asilmadi" if mx < 50 else " -> esik asildi ama tetiklenmedi (ilk<8 / bilinen dusman<2 / faz uygun degil?)"))
    # ---- kuvvet orani kapisi (v8.261 hibrit tahmin)
    po = al("PLAN-ORAN"); pzo = [l for l in L if "ORAN BEKLEME" in l]
    print("\n-- KUVVET ORANI KAPISI: %d [PLAN-ORAN] satiri, %d tank ORAN BEKLEME satiri --" % (len(po), len(pzo)))
    for v in po[:12]: print("  ", v.split('" ', 1)[-1][:260])
    for v in pzo[:6]: print("  ", v.split('" ', 1)[-1][:200])
    if not po: print("  CIKARIM: kapi hic olculmedi (recon raporu / KESIF'e ulasilmadi, ya da oranEsik = 0 / oranKapisiOff, ya da plan once iptal edildi)")
    # ---- topcu
    tt = [_kv(l) for l in al("TANI-TOPCU")]
    print("\n-- TOPCU DUSUSLERI (%d kayit) --" % len(tt))
    hdm = [d for d in tt if d.get("hendek_alani_mesafe", "").lstrip("-").isdigit() and int(d.get("hendek_alani_mesafe")) <= 3]
    if tt: print("  dususlerin %d'i hendek alaninin <=3 m'sinde; ornek: %s" % (len(hdm), "; ".join("%s %s" % (d.get("dusme"), d.get("40m_icinde")) for d in tt[:3])))
    # ---- mevzi kilidi / statik silah
    mk = al("MEVZI-KILIT"); ms = al("MEVZI-STATIK")
    print("\n-- MEVZI KILIDI: %d geri cagirma (ilk 60 log), STATIK silah atamasi: %d --" % (len(mk), len(ms)))
    for l in mk[:6] + ms[:6]: print("  ", l.split('" ', 1)[-1][:170])
    if mk:
        print("  CIKARIM: hendek grubundan alan disina cikan asker olmus; geri cagrilanlarin komut / mesafesi yukarida (kaynagi bulmak icin ayni saniyedeki [KOMUT] / [ARAC-UZAK] satirlarina bak).")
    # ---- duman / mürettebat
    dm = al("ARAC-DUMAN")
    ok = len([1 for l in dm if "ATILDI (" in l or "| ATILDI" in l]); no = len([1 for l in dm if "ATILMADI" in l or "CALISMADI" in l])
    print("\n-- DUMAN: ATILDI %d, ATILMADI %d --" % (ok, no))
    for l in dm[:6]: print("  ", l.split('" ', 1)[-1][:170])
    print("-- TANK-MURETTEBAT: %d satir (koltuk degistirme/ geri donus/ BEKLIYOR) --" % len(al("TANK-MURETTEBAT")))
    hata = len([1 for l in L if "Error in expression" in l or "Error Undefined" in l or "Error Type" in l])
    print("\nSCRIPT HATASI satiri: %d (modsuz gurultu haric degil; --karne ile ayrinti)" % hata)
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
    kabul_modu = False
    onucus_modu = False
    hava_ied_modu = False
    zeka_modu = False
    form_modu = False
    kayip_modu = False
    tani_modu = False
    yollar = []
    i = 0
    while i < len(args):
        if args[i] == "--grup" and i + 1 < len(args):
            grup = args[i + 1]; i += 2
        elif args[i] == "--aralik" and i + 1 < len(args):
            aralik = args[i + 1]; i += 2
        elif args[i] == "--karne":
            karne_modu = True; i += 1
        elif args[i] == "--kabul":
            kabul_modu = True; i += 1
        elif args[i] == "--onucus":
            onucus_modu = True; i += 1
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
        elif args[i] == "--tani":
            tani_modu = True; i += 1
        else:
            yollar.append(args[i]); i += 1
    if not yollar:
        print(__doc__)
        sys.exit(1)
    for p in yollar:
        if kabul_modu:
            kabul(p)
        elif tani_modu:
            tani(p)
        elif kayip_modu:
            kayip_tablosu(p)
        elif form_modu:
            form_teshis(p)
        elif zeka_modu:
            zeka(p)
        elif hava_ied_modu:
            hava_ied(p)
        elif onucus_modu:
            onucus_karne(p)
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
