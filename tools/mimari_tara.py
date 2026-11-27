#!/usr/bin/env python3
# MIMARI TARAYICI (v8.838; kullanici: 'bunun gibi seyleri tara, proje butunsel olarak iliskili olsun, botlar smooth karar versin'): statik tarama.
# 1) Paylasilan durumu (hareket / durus / davranis / hiz / AI bayragi) kac dosya yaziyor; 2) taktik kilidi / forceMove'a bakmadan hareket emri veren dosyalar; 3) ayni sinyalin kac farkli esikle okundugu (baski, temas yasi);
# 4) kodda var ama son N RPT'de HIC gorunmeyen log etiketleri (uykuda ozellik adaylari; kapsam disi senaryolar yanlis pozitif verir). Kullanim: python3 tools/mimari_tara.py [rpt_klasoru] -> MIMARI_DENETIM_RAPORU.txt
import re, glob, os, sys, collections
KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FN = glob.glob(os.path.join(KOK, "addons", "danger", "functions", "*.sqf"))
txt = {os.path.basename(f)[4:-4]: open(f, encoding="utf-8", errors="ignore").read() for f in FN}
out = []
def cnt(p):
    c = collections.Counter()
    for f, t in txt.items():
        n = len(re.findall(p, t))
        if n: c[f] = n
    return c
out.append("== 1) PAYLASILAN DURUM YAZARLARI (dosya sayisi / cagri sayisi) ==")
for k, p in {"hareket emri (doMove)": r"\bdoMove\b", "durdurma (doStop)": r"\bdoStop\b", "ham doFollow": r"\bdoFollow\b", "durus (setUnitPos*)": r"setUnitPos(Weak)?\b", "davranis (setBehaviour*)": r"setBehaviour(Strong)?\b",
             "muharebe modu": r"setCombatMode|setUnitCombatMode", "hiz (setSpeedMode / forceSpeed)": r"setSpeedMode|forceSpeed", "disableAI": r"disableAI", "enableAI": r"enableAI", "bakis (doWatch)": r"\bdoWatch\b", "ates emri (doTarget / doFire)": r"\bdoTarget\b|\bdoFire\b", "bastirma (doSuppressiveFire)": r"doSuppressiveFire"}.items():
    c = cnt(p); out.append("  %-34s %3d dosya / %4d cagri | en cok: %s" % (k, len(c), sum(c.values()), ", ".join("%s:%d" % x for x in c.most_common(3))))
dom = cnt(r"\bdoMove\b"); kil = cnt(r"taktikKilit|forceMove")
out.append("== 2) doMove veren ama taktikKilit / forceMove'a HIC bakmayan dosyalar (%d) ==" % len([f for f in dom if f not in kil]))
out.append("  " + ", ".join(sorted(f for f in dom if f not in kil)))
bt = collections.Counter(); ct = collections.Counter()
for f, t in txt.items():
    for m in re.finditer(r"getSuppression[^;{}]{0,40}?(>=|<=|>|<)\s*(\d?\.\d+)", t): bt[m.group(2)] += 1
    for m in re.finditer(r"QGVAR\(contact\)[^;]{0,60}?(?:time|\(time) *[-+] *(\d+)", t): ct[m.group(1)] += 1
out.append("== 3) AYNI SINYAL, FARKLI ESIK ==")
out.append("  getSuppression: %d farkli esik (deger:adet) %s" % (len(bt), dict(sorted(bt.items(), key=lambda x: -x[1]))))
out.append("  temas yasi (contact): %d farkli sn esigi %s" % (len(ct), dict(sorted(ct.items(), key=lambda x: -x[1]))))
ham_b = sum(len(re.findall(r"getSuppression", t)) for t in txt.values()); sev_b = sum(len(re.findall(r"FUNC\(baskiSeviye\)", t)) for t in txt.values())
ham_t = sum(len(re.findall(r"QGVAR\(contact\)[^;]{0,40}?time *[-+] *\d+", t)) for t in txt.values()); sev_t = sum(len(re.findall(r"FUNC\(temasSeviye\)", t)) for t in txt.values())
out.append("  TASIMA ILERLEMESI: baski ham %d (getSuppression) / seviye %d (baskiSeviye); temas yasi ham %d / seviye %d (temasSeviye); hakem (emirKilitli) %d yer" % (ham_b, sev_b, ham_t, sev_t, sum(len(re.findall(r"FUNC\(emirKilitli\)", t)) for t in txt.values())))
out.append("  'dusman biliniyor' tanimi: findNearestEnemy %d dosya / nearTargets %d dosya / knowsAbout %d dosya" % (len(cnt(r"findNearestEnemy")), len(cnt(r"nearTargets")), len(cnt(r"knowsAbout"))))
out.append("  zamanlanmis dongu: while{true} %d dosya, spawn %d dosya, sleep %d dosya" % (len(cnt(r"while \{true\}")), len(cnt(r"\bspawn\b")), len(cnt(r"\bsleep\b"))))
rk = sys.argv[1] if len(sys.argv) > 1 else None
if rk and os.path.isdir(rk):
    rpts = sorted(glob.glob(os.path.join(rk, "*.rpt")), key=os.path.getmtime, reverse=True)[:14]
    seen = set(); rx = re.compile(r'"\[([A-Z][A-Z0-9-]{2,})\]')
    for f in rpts:
        for l in open(f, errors="ignore"):
            m = rx.search(l)
            if m: seen.add(m.group(1))
    code = collections.defaultdict(set)
    for f, t in txt.items():
        for m in re.finditer(r'diag_log[^;]{0,80}?"\[([A-Z][A-Z0-9-]{2,})\]', t): code[m.group(1)].add(f)
    gm = sorted(set(code) - seen)
    out.append("== 4) SON %d RPT'DE HIC GORUNMEYEN LOG ETIKETI (%d / %d; kapsam disi senaryo yanlis pozitif) ==" % (len(rpts), len(gm), len(code)))
    out.append("  " + ", ".join("%s(%s)" % (t, "/".join(sorted(code[t]))) for t in gm))
rapor = "\n".join(out)
open(os.path.join(KOK, "MIMARI_DENETIM_RAPORU.txt"), "w", encoding="utf-8").write(rapor + "\n")
print(rapor)
