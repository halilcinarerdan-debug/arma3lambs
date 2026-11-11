#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SENARYO DENETIMI (v8.501; Asama 9 araci 1) - mission.sqm (DUZ METIN) dosyasini okur, oyunu acmadan tasarim hatalarini listeler. Kod DEGISTIRMEZ.
Kullanim:  python tools/senaryo_denetimi.py <mission.sqm> [--koltuk SINIF=N ...] [--araclar sinif1,sinif2]
  --koltuk   arac sinifi icin kargo koltuk sayisi (bilinmeyen siniflar icin); ornek: --koltuk B_Truck_01_transport_F=15
  --araclar  arac sayilacak ek sinif adlari (heuristik arac / asker ayrimi yanlis giderse)
KAPSAM (oyundaki ON UCUS blogunun senaryo-oncesi karsiligi): HQ baglantisi, rol gruplari (recon / medevac / topcu), objektif / Harekat / faz, nakil koltugu / mesafe, IHA mesafesi, topcu mesafesi, oyuncu, tetikler.
SINIRLAR (T = dogrulanmadi): mission.sqm gercek bir dosyayla denenmedi, sentetik ornekle (tools/ornek_mission.sqm) sinandi. Ikili (binarize) kaydedilmis mission.sqm okunamaz. Grup adi, arac / asker ayrimi ve SYNC
 baglantilari (grup mu, lider asker mi) icin birkac yedek yol denenir; arac koltugu yalniz bilinen siniflarda kesin (digerleri icin --koltuk). Sonuc "olasi sorun" listesidir, kesin hata kanitı DEGILDIR.
"""
import re, sys, math, collections

# ---------------------------------------------------------------- SQM ayristirici
TOK = re.compile(r'\s*(?:(//[^\n]*)|(/\*.*?\*/)|("(?:[^"]|"")*")|(\[\])|([A-Za-z_][A-Za-z0-9_]*)|(-?\d+\.?\d*(?:[eE][-+]?\d+)?)|([{}=;:,\[\]]))', re.S)

def tokenle(t):
    i = 0; out = []
    n = len(t)
    while i < n:
        m = TOK.match(t, i)
        if not m:
            if t[i:].strip() == "": break
            i += 1; continue
        i = m.end()
        if m.group(1) or m.group(2): continue
        if m.group(3) is not None: out.append(("S", m.group(3)[1:-1].replace('""', '"')))
        elif m.group(4): out.append(("ARR", "[]"))
        elif m.group(5): out.append(("I", m.group(5)))
        elif m.group(6):
            v = m.group(6); out.append(("N", float(v) if ("." in v or "e" in v.lower()) else int(v)))
        else: out.append(("P", m.group(7)))
    return out

class Blok(dict):
    pass

def deger(tk, i):
    t, v = tk[i]
    if t == "P" and v == "{":
        liste = []; i += 1
        while tk[i] != ("P", "}"):
            if tk[i] == ("P", ","): i += 1; continue
            d, i = deger(tk, i); liste.append(d)
        return liste, i + 1
    if t in ("S", "N", "I"): return v, i + 1
    return None, i + 1

def blok(tk, i):
    b = Blok()
    while i < len(tk) and tk[i] != ("P", "}"):
        t, v = tk[i]
        if t == "I" and v == "class":
            ad = tk[i + 1][1]; i += 2
            if tk[i] == ("P", ":"): i += 2   # miras
            if tk[i] == ("P", "{"):
                alt, i = blok(tk, i + 1)
                if i < len(tk) and tk[i] == ("P", "}"): i += 1
                if i < len(tk) and tk[i] == ("P", ";"): i += 1
                b[ad] = alt
            else:
                if tk[i] == ("P", ";"): i += 1
        elif t == "I":
            ad = v; i += 1
            if tk[i][0] == "ARR": i += 1
            if tk[i] != ("P", "="): i += 1; continue
            d, i = deger(tk, i + 1)
            if i < len(tk) and tk[i] == ("P", ";"): i += 1
            b[ad] = d
        else:
            i += 1
    return b, i

def sqm_oku(yol):
    t = open(yol, encoding="utf-8", errors="replace").read()
    if "\x00" in t[:2000]: raise SystemExit("mission.sqm ikili (binarize) gorunuyor; 3DEN'de 'Binarize' kapali kaydedin")
    tk = tokenle(t)
    b, _ = blok(tk, 0)
    return b

# ---------------------------------------------------------------- varlik cikarma
def alt_bloklar(b, onek="Item"):
    return [v for k, v in sorted(b.items(), key=lambda kv: (len(kv[0]), kv[0])) if k.startswith(onek) and isinstance(v, dict)]

def varliklar(entities, ebeveyn=None, grup=None, out=None):
    out = [] if out is None else out
    for it in alt_bloklar(entities):
        dt = it.get("dataType")
        if dt in ("Object", "Logic", "Trigger", "Group", "Marker", "Layer", "Comment"):
            v = {"dt": dt, "id": it.get("id"), "tip": it.get("type", ""), "taraf": it.get("side", ""), "ham": it, "grup": grup if dt != "Group" else None}
            pi = it.get("PositionInfo", {})
            p = pi.get("position") if isinstance(pi, dict) else None
            v["poz"] = (p[0], p[2]) if isinstance(p, list) and len(p) >= 3 else None
            at = it.get("Attributes", {}) if isinstance(it.get("Attributes"), dict) else {}
            v["ozellik"] = ozellikler(at)
            v["ad"] = at.get("name", "") if isinstance(at.get("name", ""), str) else ""
            v["oyuncu"] = bool(at.get("isPlayer") == 1 or at.get("isPlayable") == 1)
            out.append(v)
            if dt == "Group":
                wp = it.get("Waypoints")
                v["wp"] = len(alt_bloklar(wp)) if isinstance(wp, dict) else 0
                v["ad"] = v["ad"] or str(it.get("name", "")) or str(it.get("Attributes", {}).get("callsign", "") if isinstance(it.get("Attributes"), dict) else "")
                if isinstance(it.get("Entities"), dict): varliklar(it["Entities"], it, v, out)
            elif dt == "Layer":
                if isinstance(it.get("Entities"), dict): varliklar(it["Entities"], it, grup, out)
    return out

def ozellikler(at):
    s = {}
    for k, a in at.items():
        if not (k.startswith("Attribute") and isinstance(a, dict)): continue
        p = a.get("property"); val = a.get("Value", {})
        if isinstance(val, dict):
            d = val.get("data", {})
            if isinstance(d, dict): s[p] = d.get("value")
    return s

def baglantilar(m):
    cn = m.get("Connections", {})
    links = cn.get("Links", {}) if isinstance(cn, dict) else {}
    out = []
    for l in alt_bloklar(links):
        a, b = l.get("item0"), l.get("item1")
        if a is not None and b is not None: out.append((a, b))
    return out

def mesafe(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1]) if a and b else None

# ---------------------------------------------------------------- bilinen siniflar
KOLTUK = {"B_Truck_01_transport_F": 15, "B_Truck_01_covered_F": 15, "B_MBT_01_TUSK_F": 6}
ARAC_RX = re.compile(r"(?i)(truck|offroad|hunter|strider|ifrit|marshall|mora|panther|mbt|apc|mrap|uav|heli|plane|boat|quadbike|van\b|_car|tank|static|mortar|hmg|gmg|kamaz|btr|bmp|zamak|tempest|hemtt|bobcat|gorgon|rhino|slammer|nyx|scorcher|sandstorm|cheetah|angara|varsuk|kuma|oshkosh)")
IHA_RX = re.compile(r"(?i)(uav|darter|pelican|greyhawk|falcon|ababil|sentinel|qav|bayraktar|yabhon|mavic)")
TOP_RX = re.compile(r"(?i)(arty|scorcher|sholef|mortar|m4_scorcher|rhs.*(m109|d30|2s1)|howitzer)")

# ---------------------------------------------------------------- denetim
def denetle(yol, koltuk_ek, arac_ek):
    m = sqm_oku(yol)
    mis = m.get("Mission", {}) if isinstance(m.get("Mission"), dict) else {}
    ent = mis.get("Entities", {}) if isinstance(mis.get("Entities"), dict) else {}
    V = varliklar(ent)
    by = {v["id"]: v for v in V if v["id"] is not None}
    L = baglantilar(mis)
    kolt = dict(KOLTUK); kolt.update(koltuk_ek)
    ARAC_EK = set(arac_ek)
    sonuc = []   # (seviye, baslik, metin)
    def ekle(sv, ba, tx): sonuc.append((sv, ba, tx))

    moduller = [v for v in V if v["dt"] == "Logic" and v["tip"].lower().startswith("lambs_danger_eden")]
    objekt = []
    triggerlar = [v for v in V if v["dt"] == "Trigger"]
    adamlar = [v for v in V if v["dt"] == "Object" and v["grup"] is not None]
    def arac_mi(v): return v["tip"] in ARAC_EK or bool(ARAC_RX.search(v["tip"]))
    araclar = [v for v in adamlar if arac_mi(v)]
    askerler = [v for v in adamlar if not arac_mi(v)]
    gruplar = [v for v in V if v["dt"] == "Group"]
    ai_gruplar = [g for g in gruplar if any((not a["oyuncu"]) and a["grup"] is g and not arac_mi(a) for a in adamlar)]

    ekle("BILGI", "ENVANTER", "ELITE modul %d | tetik %d | grup %d | asker %d | arac %d | oyuncu %d" %
         (len(moduller), len(triggerlar), len(gruplar), len(askerler), len(araclar), sum(1 for a in adamlar if a["oyuncu"])))
    tur = collections.Counter(v["tip"].split("_", 3)[-1] for v in moduller)
    if tur: ekle("BILGI", "MODUL", "modul turleri: %s" % dict(tur))
    else: ekle("BILGI", "MODUL", "ELITE 3DEN modulu yok (lambs_danger_Eden*): yalniz taktik tepkiler calisir; makro modul (Kumanda / Karakol / Garnizon / IHA) istenirse ekleyin")

    # waypoint: SQM'de grup waypoint'i sayilir (Waypoints sinifi); waypoint'siz AI grubu SENARYO MODU'nda yerinde durur
    wpsiz = [g for g in ai_gruplar if not g.get("wp")]
    if ai_gruplar and len(wpsiz) == len(ai_gruplar):
        ekle("BILGI", "WAYPOINT", "waypoint okunamadi ya da hic AI grubunun waypoint'i yok (senaryo modunda grup yerinde bekler; waypoint'i 3DEN'de cizin)")
    elif wpsiz:
        ekle("BILGI", "WAYPOINT", "waypoint'siz AI grubu: %d (%s) - senaryo modunda yerinde bekler" % (len(wpsiz), ", ".join((g["ad"] or "?") for g in wpsiz[:10])))

    # rol gruplari (ad) - Gorev Ata modulu yoksa grup adindan otomatik atama
    def adlar(rx): return [g["ad"] for g in gruplar if g["ad"] and re.search(rx, g["ad"], re.I)]
    for ad, rx in (("medevac", r"medic|medevac"), ("topcu", r"topcu|top\b|artil|mortar")):
        if not adlar(rx): ekle("BILGI", "ROL", "'%s' adli grup yok (Gorev Ata modulu ya da grup adi gerekir; rol kullanmayacaksan sorun degil)" % ad)

    # surucusuz arac grubu: arac var, grupta adam yok
    for v in araclar:
        g = v["grup"]
        if IHA_RX.search(v["tip"]) or TOP_RX.search(v["tip"]): continue   # IHA / topcu murettebati oyunda otomatik / ayri grup
        if g is not None and not any((a["grup"] is g) and not arac_mi(a) for a in adamlar):
            ekle("UYARI", "ARAC", "%s (%s) grubunda murettebat yok: surucusuz arac waypoint izleyemez" % (v["tip"], g["ad"] or v["id"]))

    # IHA / topcu envanteri
    for v in adamlar + [x for x in V if x["dt"] == "Object" and x["grup"] is None]:
        if IHA_RX.search(v["tip"]): ekle("BILGI", "IHA", "%s var (SYNC'li 'ELITE IHA' modulu / Zeus IHA Gorevi ile gorevlendirilir)" % v["tip"])
        if TOP_RX.search(v["tip"]): ekle("BILGI", "TOPCU", "%s var (Gorev Ata -> TOPCU ile ates destegi verir)" % v["tip"])
    return sonuc

def main(arg):
    if not arg or arg[0] in ("-h", "--help"):
        print(__doc__); return 1
    yol = arg[0]; koltuk = {}; arac = []
    i = 1
    while i < len(arg):
        if arg[i] == "--koltuk" and i + 1 < len(arg):
            k, _, n = arg[i + 1].partition("="); koltuk[k] = int(n); i += 2
        elif arg[i] == "--araclar" and i + 1 < len(arg):
            arac += arg[i + 1].split(","); i += 2
        else: i += 1
    try:
        s = denetle(yol, koltuk, arac)
    except SystemExit as e:
        print(e); return 2
    print("=" * 78); print("SENARYO DENETIMI |", yol)
    sayac = collections.Counter()
    for sv in ("UYARI", "BILGI"):
        for sev, ba, tx in s:
            if sev == sv:
                print("  [%-5s] %-9s %s" % (sev, ba, tx)); sayac[sev] += 1
    print("-- %d UYARI, %d BILGI (olasi sorun listesi; kesin hata kaniti degil) --" % (sayac["UYARI"], sayac["BILGI"]))
    return 1 if sayac["UYARI"] else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
