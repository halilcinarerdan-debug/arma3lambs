#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TUTARLILIK DENETIMI (lambs_danger ELITE fork) - v8.364
Kullanim:  python tools/tutarlilik_denetimi.py            (depo kokunden; hata varsa cikis kodu 1)

Oyunsuz, statik ve TEKRARLANABILIR kontroller (hepsi 244+ dosyanin TAMAMINI tarar; 'kitaba uygunluk' ya da 'oyunda calisir' iddiasi DEGILDIR):
  1. PREP / dosya / FUNC referanslari (olmayan fonksiyon cagrisi, PREP'siz dosya)   [upstream LAMBS fonksiyonlari beklenen eksik sayilir]
  2. CBA olaylari: emit edilip dinlenmeyen olay; emit argumani handler'in params'indan FAZLA/EKSIK
  3. CBA ayarlari: kayit varsayilani <-> kodda getVariable yedek degeri; ipucu metnindeki 'varsayilan' <-> gercek varsayilan; slider varsayilani aralik icinde mi
  4. Tanimsiz yerel degisken (dosya genelinde bildirilmemis _ad)
  5. spawn / CBA waitAndExecute / addEventHandler kapanisi, DISARIDAKI yerel degiskeni kullaniyor mu (spawn'lanan kod dis yerel degiskenleri GORMEZ)
  6. Deger DONDURMEYEN komutlarin deger olarak kullanimi (reverse / sort / append)
  7. Surum tutarliligi: boot satiri <-> rpt_ozet BEKLENEN_SURUM <-> DEVIR_LOGU son girisi
  8. Belgelerde gecen lambs_danger_* adlari kodda var mi
  9. exitWith, if-then / else BLOGU icinde ve donus degeri (false/true/[]/sayi) veriyorsa: exitWith yalniz o blogu terk eder, fonksiyonu DEGIL (fonksiyon cikisi sanilan mantik hatasi)
"""
import re, os, sys, glob, collections

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = os.path.join(KOK, "addons", "danger")
HATA = []; UYARI = []; BILGI = []

# ------------------------------------------------------------------ SQF ayristirici (dize / yorum duyarli)
def skip_str(t, i):
    q = t[i]; i += 1
    while i < len(t):
        if t[i] == q:
            if i + 1 < len(t) and t[i + 1] == q: i += 2; continue
            return i + 1
        i += 1
    return i

def match(t, i):
    pairs = {"[": "]", "(": ")", "{": "}"}
    st = [pairs[t[i]]]; i += 1
    while i < len(t) and st:
        c = t[i]
        if c in "\"'": i = skip_str(t, i); continue
        if t[i:i + 2] == "//": j = t.find("\n", i); i = len(t) if j < 0 else j; continue
        if t[i:i + 2] == "/*": j = t.find("*/", i); i = len(t) if j < 0 else j + 2; continue
        if c in pairs: st.append(pairs[c])
        elif c == st[-1]: st.pop()
        i += 1
    return i

def split_top(t, i):
    e = match(t, i); inner = t[i + 1:e - 1]
    out = []; cur = 0; j = 0; d = 0
    while j < len(inner):
        c = inner[j]
        if c in "\"'": j = skip_str(inner, j); continue
        if inner[j:j + 2] == "//": k = inner.find("\n", j); j = len(inner) if k < 0 else k; continue
        if c in "[({": d += 1
        elif c in "])}": d -= 1
        elif c == "," and d == 0: out.append(inner[cur:j].strip()); cur = j + 1
        j += 1
    son = inner[cur:].strip()
    if son or out: out.append(son)
    return out, e

def temizle(t):
    """yorum ve dize ICERIKLERINI bosluga cevirir (uzunluk korunur)"""
    o = []; i = 0; n = len(t)
    while i < n:
        c = t[i]
        if c in "\"'":
            j = skip_str(t, i); o.append(c + " " * max(j - i - 2, 0) + (c if j - i >= 2 else "")); i = j; continue
        if t[i:i + 2] == "//": j = t.find("\n", i); j = n if j < 0 else j; o.append(" " * (j - i)); i = j; continue
        if t[i:i + 2] == "/*":
            j = t.find("*/", i); j = n if j < 0 else j + 2
            o.append("".join(ch if ch == "\n" else " " for ch in t[i:j])); i = j; continue
        o.append(c); i += 1
    return "".join(o)

def oku(p): return open(p, encoding="utf-8", errors="replace").read()
SQF = {p: oku(p) for p in glob.glob(R + "/**/*.sqf", recursive=True)}
HPP = {p: oku(p) for p in glob.glob(R + "/**/*.hpp", recursive=True) + glob.glob(R + "/*.cpp")}
def goreli(p): return os.path.relpath(p, R)

# ------------------------------------------------------------------ 1. PREP / dosya / referans
prep = HPP[R + "/XEH_PREP.hpp"]
prepd = set(re.findall(r"^\s*PREP\((\w+)\);", prep, re.M)) | set(m[1] for m in re.findall(r"^\s*SUBPREP\((\w+),(\w+)\);", prep, re.M))
dosya = {os.path.basename(p)[4:-4]: p for p in SQF if os.path.basename(p).startswith("fnc_")}
UPSTREAM = {"brain", "brainAdjust", "brainAssess", "brainEngage", "brainForced", "brainHide", "brainReact", "brainVehicle", "fsmAllowAnimation", "isForced", "isForcedExit", "isLeader",
            "moduleConfigureGroupAI", "moduleDisableAI", "moduleSetRadio", "setDisableAI", "setDisableGroupAI", "setHasRadio", "setReinforcement", "showHasRadio", "showReinforcement",
            "showSetDisableAI", "showSetDisableGroupAI", "tacticsAssess", "tacticsCQB", "tacticsProfiles", "tacticsReinforce"}
for n in sorted(set(dosya) - prepd): HATA.append("[PREP] dosya var, PREP yok: %s" % n)
for n in sorted(prepd - set(dosya) - UPSTREAM): HATA.append("[PREP] PREP var, dosya yok (upstream listesinde de degil): %s" % n)
ref = collections.defaultdict(set)
for p, t in list(SQF.items()) + list(HPP.items()):
    c = temizle(t)
    for m in re.finditer(r"\b(?:FUNC|QFUNC)\((\w+)\)", c): ref[m.group(1)].add(goreli(p))
    for m in re.finditer(r"lambs_danger_fnc_(\w+)", t): ref[m.group(1)].add(goreli(p))
for n in sorted(ref):
    if n not in dosya and n not in UPSTREAM: HATA.append("[FUNC] cagrilan fonksiyon yok: %s (%s)" % (n, sorted(ref[n])[0]))
# lambs_main (addons/main) de danger fonksiyonlarini DEGISKEN ADIYLA cagirir (ornek findCover -> lambs_danger_fnc_eliteCover)
for _mp in glob.glob(os.path.join(KOK, "addons", "main", "**", "*.sqf"), recursive=True):
    for m in re.finditer(r"lambs_danger_fnc_(\w+)", oku(_mp)): ref[m.group(1)].add("main/" + os.path.basename(_mp))
dyn = set(re.findall(r'"(\w+)"', prep))
for n in sorted(dosya):
    if n not in ref and n not in dyn:
        UYARI.append("[FUNC] hic cagrilmayan fonksiyon (olu kod?): %s" % n)
BILGI.append("PREP %d, dosya %d (v8.365: olu kod kalmadi; hepsi canlandirildi)" % (len(prepd), len(dosya)))

# ------------------------------------------------------------------ 2. CBA olaylari
emit = collections.defaultdict(list); hand = {}
for p, t in SQF.items():
    b = goreli(p)
    for m in re.finditer(r'\[\s*"(lambs_danger_\w+)"\s*,\s*(\[)', t):
        e = match(t, m.start())
        if re.match(r"\s*call\s+CBA_fnc_(server|global|local|target|owner)Event", t[e:e + 48]):
            a, _ = split_top(t, m.start(2)); emit[m.group(1)].append((b, len(a), t[:m.start()].count("\n") + 1))
    for m in re.finditer(r'\[\s*"(lambs_danger_\w+)"\s*,\s*\{', t):
        e = match(t, m.start())
        if re.match(r"\s*call\s+CBA_fnc_addEventHandler", t[e:e + 40]):
            body = t[m.end() - 1:match(t, m.end() - 1)]; pm = re.search(r"params\s*\[", body)
            if pm:
                pa, _ = split_top(body, pm.end() - 1)
                hand.setdefault(m.group(1), []).append((b, len(pa), sum(1 for x in pa if not x.startswith("["))))
            else: hand.setdefault(m.group(1), []).append((b, None, None))
for ev, st in sorted(emit.items()):
    if ev not in hand: HATA.append("[OLAY] emit edilen olayin dinleyicisi yok: %s (%s:%s)" % (ev, st[0][0], st[0][2])); continue
    for (b, n, l) in st:
        if all(h[1] is not None and n > h[1] for h in hand[ev]): UYARI.append("[OLAY] %s emit argumani (%d) tum dinleyicilerin params'indan fazla (%s:%d)" % (ev, n, b, l))
        if all(h[2] is not None and n < h[2] for h in hand[ev]): HATA.append("[OLAY] %s emit argumani (%d) zorunlu params'tan az (%s:%d)" % (ev, n, b, l))
BILGI.append("CBA olayi: %d emit, %d dinleyici" % (len(emit), len(hand)))

# ------------------------------------------------------------------ 3. CBA ayarlari
sets = {}
for m in re.finditer(r'\[\s*"(lambs_danger_\w+)"\s*,\s*"(CHECKBOX|SLIDER|LIST)"\s*,', prep):
    a, _ = split_top(prep, m.start())
    if len(a) >= 5:
        tip = a[2] if a[2].startswith("[") else (a[3] if len(a) > 3 else "")
        sets[m.group(1)] = (m.group(2), a[4], tip, prep[:m.start()].count("\n") + 1)
def norm(x):
    x = x.strip()
    try: f = float(x); return str(int(f)) if f == int(f) else str(f)
    except Exception: return x
def varsayilan(tur, spec):
    spec = spec.strip()
    if tur == "SLIDER":
        m = re.match(r"\[\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)", spec); return m.group(3) if m else spec
    return spec
okuma = collections.defaultdict(list)
for p, t in SQF.items():
    for m in re.finditer(r'missionNamespace\s+getVariable\s*\[\s*"(lambs_danger_\w+)"\s*,\s*', t):
        j = m.end(); d = 0; k = j
        while k < len(t):
            c = t[k]
            if c in "\"'": k = skip_str(t, k); continue
            if c in "[({": d += 1
            elif c in "])}":
                if d == 0: break
                d -= 1
            k += 1
        okuma[m.group(1)].append((norm(t[j:k]), goreli(p), t[:m.start()].count("\n") + 1))
# fnc_varsayilanSkill tablo degerleri (_min/_max) bilincli: tablo ayarla ezilir
for ad, (tur, spec, tip, satir) in sets.items():
    if tur == "SLIDER":
        m = re.match(r"\[\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)", spec.strip())
        if m and not (float(m.group(1)) <= float(m.group(3)) <= float(m.group(2))): HATA.append("[AYAR] %s varsayilan aralik disi (XEH_PREP.hpp:%d)" % (ad, satir))
        for q in re.finditer(r"(?:[Vv]arsayilan|default)[: ]+([-\d.]+)", tip):
            try: v = float(q.group(1).rstrip("."))
            except ValueError: continue
            if m and abs(v - float(m.group(3))) > 1e-9: HATA.append("[AYAR] %s ipucu 'varsayilan %s' ama gercek %s (XEH_PREP.hpp:%d)" % (ad, q.group(1), m.group(3), satir))
    if tur == "CHECKBOX":
        d = spec.strip()
        if re.search(r"[Vv]arsayilan\s+KAPALI", tip) and d == "true": HATA.append("[AYAR] %s ipucu KAPALI ama varsayilan true" % ad)
        if re.search(r"[Vv]arsayilan\s+ACIK", tip) and d == "false": HATA.append("[AYAR] %s ipucu ACIK ama varsayilan false" % ad)
    d0 = norm(varsayilan(tur, spec))
    for (fb, b, l) in okuma.get(ad, []):
        if tur != "LIST" and not fb.startswith("_") and norm(fb) != d0: UYARI.append("[AYAR] %s: kodda yedek deger %s <> ayar varsayilani %s (%s:%d)" % (ad, fb, d0, b, l))
for ad in sets:
    if sum(len(re.findall(r"\b" + ad + r"\b", t)) for t in list(SQF.values()) + list(HPP.values())) <= 1: UYARI.append("[AYAR] kayitli ama kullanilmayan ayar: %s" % ad)
BILGI.append("CBA ayari (tablo/addSetting): %d" % len(sets))

# ------------------------------------------------------------------ 4/5. yerel degiskenler + kapanis kapsami
BUILT = {"_x", "_y", "_z", "_this", "_forEachIndex", "_thisScript", "_thisEventHandler", "_fnc_scriptName", "_fnc_scriptNameParent", "_thisArgs", "_args", "_ehArgs"}
def bildirimler(raw):
    d = set(BUILT)
    for m in re.finditer(r"\bprivate\s+(_\w+)", raw): d.add(m.group(1))
    for m in re.finditer(r"\bprivate\s*\[([^\]]*)\]", raw): d.update(re.findall(r'"(_\w+)"', m.group(1)))
    for m in re.finditer(r"\bparams\s*\[", raw):
        j = m.end(); dep = 1
        while j < len(raw) and dep:
            dep += (raw[j] == "[") - (raw[j] == "]"); j += 1
        d.update(re.findall(r'"(_\w+)"', raw[m.end():j]))
    for m in re.finditer(r'\bfor\s+"(_\w+)"', raw): d.add(m.group(1))
    return d
def atamalar(c): return set(m.group(1) for m in re.finditer(r"(?<![\w=!<>])(_\w+)\s*=(?!=)", c))
for p, raw in SQF.items():
    c = temizle(raw)
    kullanim = set(re.findall(r"(?<![\w])(_[A-Za-z]\w*)", c))
    tanimsiz = [u for u in kullanim if u not in bildirimler(raw) | atamalar(c)]
    if tanimsiz: HATA.append("[DEGISKEN] %s: dosyada hic bildirilmeyen yerel degisken %s" % (goreli(p), sorted(tanimsiz)[:6]))
    kap = []
    for m in re.finditer(r"\bspawn\s*\{", c): kap.append((m.end() - 1, match(c, m.end() - 1), "spawn"))
    for m in re.finditer(r"\bspawn\s+(_\w+)\b", c):
        for a in re.finditer(r"private\s+" + m.group(1) + r"\s*=\s*\{", c): kap.append((a.end() - 1, match(c, a.end() - 1), "spawn " + m.group(1)))
    for m in re.finditer(r"call\s+CBA_fnc_(waitAndExecute|waitUntilAndExecute|addPerFrameHandler|execNextFrame|addEventHandler)\b", c):
        k = m.start() - 1
        while k >= 0 and c[k] in " \t\r\n": k -= 1
        if k >= 0 and c[k] == "]":
            dep = 0; j = k
            while j >= 0:
                if c[j] == "]": dep += 1
                elif c[j] == "[":
                    dep -= 1
                    if dep == 0: break
                j -= 1
            e = match(c, j); q = j + 1; dd = 0
            while q < e - 1:
                ch = c[q]
                if ch == "{" and dd == 0: end = match(c, q); kap.append((q, end, "CBA " + m.group(1))); q = end; continue
                if ch in "[(": dd += 1
                elif ch in "])": dd -= 1
                elif ch == "{": q = match(c, q); continue
                q += 1
    for m in re.finditer(r'\baddEventHandler\s*\[\s*"[^"]*"\s*,\s*\{', c): kap.append((m.end() - 1, match(c, m.end() - 1), "addEH"))
    for (s, e, tur) in set(kap):
        govde = c[s:e]; ic = bildirimler(raw[s:e]) | atamalar(govde)
        serbest = [u for u in set(re.findall(r"(?<![\w])(_[A-Za-z]\w*)", govde)) if u not in ic]
        dis = bildirimler(raw[:s] + raw[e:]) | atamalar(c[:s])
        kotu = [u for u in serbest if u in dis]
        if kotu: HATA.append("[KAPSAM] %s:%d %s kapanisi disaridaki yerel degiskeni goremez: %s" % (goreli(p), c[:s].count("\n") + 1, tur, sorted(kotu)[:6]))

# ------------------------------------------------------------------ 6. deger dondurmeyen komutlar
for p, t in SQF.items():
    c = temizle(t)
    for m in re.finditer(r"(?:forEach|select|apply|count|=)\s*\(?\s*reverse\s*\(?", c):
        HATA.append("[DEGER] %s:%d 'reverse' deger DONDURMEZ (yerinde ters cevirir)" % (goreli(p), c[:m.start()].count("\n") + 1))
    for m in re.finditer(r"(?:=|\()\s*_\w+\s+(append|sort)\b", c):
        HATA.append("[DEGER] %s:%d '%s' deger DONDURMEZ" % (goreli(p), c[:m.start()].count("\n") + 1, m.group(1)))

# ------------------------------------------------------------------ 7. surum
boot = re.search(r"lambs_danger ELITE build (v[\d.]+)", prep); bek = re.search(r'BEKLENEN_SURUM\s*=\s*"(v[\d.]+)"', oku(os.path.join(KOK, "tools", "rpt_ozet.py")))
log = re.findall(r"^(v\d+\.\d+)[ b(]", oku(os.path.join(KOK, "DEVIR_LOGU_v7.0.txt")), re.M)
if boot and bek and not boot.group(1).startswith(bek.group(1)): HATA.append("[SURUM] boot %s <> rpt_ozet BEKLENEN_SURUM %s" % (boot.group(1), bek.group(1)))
if boot and log and not boot.group(1).startswith(log[-1]): UYARI.append("[SURUM] boot %s <> DEVIR_LOGU son girisi %s" % (boot.group(1), log[-1]))
BILGI.append("surum: boot %s, rpt_ozet %s, devir logu %s" % (boot.group(1) if boot else "?", bek.group(1) if bek else "?", log[-1] if log else "?"))

# ------------------------------------------------------------------ 8. belge adlari
kod = "".join(SQF.values()) + "".join(HPP.values())
kodad = set(re.findall(r"lambs_danger_\w+", kod)) | set("lambs_danger_" + m for m in re.findall(r"Q?GVAR\((\w+)\)", kod)) | set("lambs_danger_fnc_" + m for m in re.findall(r"S?U?B?PREP\((?:\w+,)?(\w+)\)", kod))
dinamik = [d for d in re.findall(r'"(lambs_danger_\w*?)_?%\d', kod) if len(d) > 14]
for belge in ["README.md", "OZELLIKLER_LISTESI.md", "OZELLIKLER_DETAYLI.md", "TEST_SENARYOLARI.md", "DOGRULANMAYANLAR.md", "MOD_UYUMLULUK.md"]:
    bp = os.path.join(KOK, belge)
    if os.path.exists(bp):
        for ad in sorted(set(re.findall(r"lambs_danger_[A-Za-z0-9_]+", oku(bp)))):
            if ad not in kodad and not ad.endswith("_") and not any(ad.startswith(x) for x in dinamik): UYARI.append("[BELGE] %s: '%s' kodda yok" % (belge, ad))

# ------------------------------------------------------------------ 9. then / else icinde donus degerli exitWith
for p, raw in SQF.items():
    c = temizle(raw)
    bloklar = []; st = []
    for i, ch in enumerate(c):
        if ch == "{": st.append(i)
        elif ch == "}" and st: bloklar.append((st.pop(), i))
    bloklar.sort()
    for m in re.finditer(r"\bexitWith\s*\{", c):
        en_yakin = None
        for (bs, be) in bloklar:
            if bs < m.start() < be and (en_yakin is None or bs > en_yakin[0]): en_yakin = (bs, be)
        if not en_yakin: continue
        once = c[max(0, en_yakin[0] - 14):en_yakin[0]].rstrip()
        if not (once.endswith("then") or once.endswith("else")): continue
        e = match(c, m.end() - 1); govde = c[m.end():e - 1].strip(" \t\r\n;")
        son = govde.split(";")[-1].strip()
        if re.fullmatch(r"(false|true|\[\]|nil|objNull|-?\d+(\.\d+)?)", son) and c[e:en_yakin[1]].strip(" ;\r\n\t"):
            HATA.append("[EXITWITH] %s:%d if-then/else blogu icinde donus degerli exitWith (fonksiyondan degil, yalniz o bloktan cikar; bayrak + fonksiyon seviyesinde exitWith kullanin)" % (goreli(p), c[:m.start()].count("\n") + 1))

# ------------------------------------------------------------------ cikti
print("== TUTARLILIK DENETIMI ==")
for b in BILGI: print("  bilgi :", b)
for u in UYARI: print("  UYARI :", u)
for h in HATA: print("  HATA  :", h)
print("-- %d HATA, %d UYARI --" % (len(HATA), len(UYARI)))
sys.exit(1 if HATA else 0)
