#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EMIR EZME DENETIMI (v8.681; kullanici: '1 2 6 yap'): 'gecikmeli geri cagri ya da serbest birakma baska sistemin YENI emrini eziyor' hata sinifini tekrar sokulmaz hale getirir.

Gecmis hatalar (hepsi ayni kalip): fnc_kacis, fnc_yakinHareket, fnc_haltKur, fnc_tacticsFlank / Assault / Suppress zamanlayicilari, fnc_rpgReaction - CBA gecikmeli geri cagrisi ya da serbest birakma
koruma OLMADAN doStop / doFollow / taktikKilit sifirlama / forceMove silme yapip geri cekilmenin (ya da baska taktigin) emrini eziyordu.

KURALLAR:
  A) HAM doFollow: beyaz liste (taktigin KENDI temizligi, arac / hekim / IED isi) disindaki dosyalarda 'X doFollow Y' dogrudan kullanilmamali; [asker, lider] call FUNC(doFollowGuvenli) kullanilmali.
  B) GECIKMELI GERI CAGRI (CBA_fnc_waitAndExecute / waitUntilAndExecute dizisi) icinde doStop / doFollow / 'taktikKilit ... 0|nil' / 'forceMove ... nil' varsa, ayni dizide bir KORUMA belirteci
     (isRetreating, isBreakingContact, isEvading, isBounding, isExecutingTactic, forceMove, kacisTok, siperTutBit, doFollowGuvenli, retKosuModu) bulunmali.
Cikti: UYARI satirlari (hata degil; beyaz liste / belirtec listesi asagida). Kullanim: python3 tools/emir_ezme_denetimi.py [--siki] (--siki: uyari varsa cikis 1).
"""
import glob
import os
import re
import sys

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONK = os.path.join(KOK, "addons", "danger", "functions")

# Kural A beyaz listesi: bu dosyalarda ham doFollow serbesttir (taktigin kendi cikisi / baska varlik turu)
BEYAZ = {
    "fnc_doFollowGuvenli.sqf",
    "fnc_tacticsBounding.sqf", "fnc_tacticsBreakContact.sqf", "fnc_tacticsEvadeArmor.sqf", "fnc_tacticsATEngage.sqf", "fnc_tacticsFlank.sqf",
    "fnc_tacticsAssault.sqf", "fnc_tacticsSuppress.sqf", "fnc_tacticsHide.sqf", "fnc_tacticsGarrison.sqf", "fnc_tacticsRetreat.sqf",
    "fnc_siperTut.sqf", "fnc_kacis.sqf", "fnc_rpgReaction.sqf", "fnc_aracMedevac.sqf", "fnc_tankMurettebat.sqf", "fnc_hqDestek.sqf",
    "fnc_iedFarkindalik.sqf", "fnc_buildingClearRun.sqf", "fnc_orphanWatchdog.sqf", "fnc_teslimBaskiKes.sqf", "fnc_tccc.sqf", "fnc_toparlan.sqf",
    "fnc_sinsiGeri.sqf", "fnc_yakinHareket.sqf",
}
KORUMA = ["isRetreating", "isBreakingContact", "isEvading", "isBounding", "isExecutingTactic", "forceMove", "kacisTok", "siperTutBit", "doFollowGuvenli", "retKosuModu"]
EZEN = re.compile(r"\bdoStop\b|\bdoFollow\b|taktikKilit\)\s*,\s*(?:0|nil)\s*\]|forceMove\)\s*,\s*nil\s*\]")


# v8.687 KURAL C (BILGI, basarisizlik DEGIL): gecikmeli geri cagri setUnitPos / setUnitPosWeak / doMove yapiyor ve dizide KORUMA belirteci yok.
#   Neden: RPT 6a939f32 - fnc_acikSiper'in gecikmeli geri cagrilari (durus yaz, siper noktasina kaydir / doMove) geri cekilen askerin durusunu / yonunu eziyordu (acikSiper duzeltildi). Kalan adaylar listelenir; hepsi retreat'le ilgili degil
#   (hava / dron / IED vb.) - tek tek incelenip korunur, sonra kural B'ye tasinir.
EZEN_C = re.compile(r"\bsetUnitPos(?:Weak)?\b|\bdoMove\b")


def yorumsuz(s):
    s = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), s, flags=re.S)   # blok yorumlari (satir sayisi korunur)
    return yorumsuz2(s)


def yorumsuz2(s):
    # '//' yorumlarini bosluga cevir (string icindeki // olasiligi icin satir sonuna kadar degil, tirnak disinda)
    out, i, n = [], 0, len(s)
    ks = None
    while i < n:
        c = s[i]
        if ks:
            out.append(c)
            if c == ks:
                if i + 1 < n and s[i + 1] == ks:
                    out.append(s[i + 1]); i += 1
                else:
                    ks = None
        elif c in "\"'":
            ks = c; out.append(c)
        elif c == "/" and i + 1 < n and s[i + 1] == "/":
            while i < n and s[i] != "\n":
                i += 1
            continue
        else:
            out.append(c)
        i += 1
    return "".join(out)


def dizi_baslangic(s, son):
    # 'son' = 'CBA_fnc_wait...' konumu; oncesindeki '] call' 'in ESLESEN '[' konumunu bul (parantez eslestirme)
    i = s.rfind("]", 0, son)
    if i < 0:
        return -1
    d = 0
    while i >= 0:
        if s[i] == "]":
            d += 1
        elif s[i] == "[":
            d -= 1
            if d == 0:
                return i
        i -= 1
    return -1


def main():
    siki = "--siki" in sys.argv
    uyari = []
    bilgi = []
    for yol in sorted(glob.glob(os.path.join(FONK, "fnc_*.sqf"))):
        ad = os.path.basename(yol)
        ham = open(yol, encoding="utf-8", errors="replace").read()
        s = yorumsuz(ham)
        # Kural A
        if ad not in BEYAZ:
            for m in re.finditer(r"(?<![A-Za-z_])([A-Za-z_][A-Za-z_0-9]*|\))\s+doFollow\b", s):
                satir = s[: m.start()].count("\n") + 1
                uyari.append((ad, satir, "A", "ham doFollow (korumasiz serbest birakma): [asker, lider] call FUNC(doFollowGuvenli) kullan"))
        # Kural B
        for m in re.finditer(r"CBA_fnc_wait(?:Until)?AndExecute", s):
            bas = dizi_baslangic(s, m.start())
            if bas < 0:
                continue
            govde = s[bas: m.start()]
            kilit_kars = re.search(r"taktikKilit\)\s*,\s*0\]\)[^;{}]{0,20}?(?:isEqualTo|<=|<|-\s*time)", govde)   # kilit silinmeden ONCE degeri karsilastiriliyorsa (kendi kilidimiz mi) korumali sayilir
            if EZEN.search(govde) and not any(k in govde for k in KORUMA) and not kilit_kars:
                satir = s[:bas].count("\n") + 1
                uyari.append((ad, satir, "B", "gecikmeli geri cagri doStop / doFollow / kilit-bayrak sifirlama yapiyor ama dizide KORUMA belirteci yok"))
            elif EZEN_C.search(govde) and not any(k in govde for k in KORUMA):
                satir = s[:bas].count("\n") + 1
                bilgi.append((ad, satir))
    # tekrarlari ele
    gor = set()
    sonuc = []
    for u in uyari:
        if u not in gor:
            gor.add(u); sonuc.append(u)
    print("== EMIR EZME DENETIMI ==")
    for ad, satir, kural, ileti in sonuc:
        print("  UYARI : [%s] %s:%d | %s" % (kural, ad, satir, ileti))
    print("-- %d UYARI (A: ham doFollow, B: korumasiz gecikmeli geri cagri) --" % len(sonuc))
    bd = sorted(set(bilgi))
    print("-- BILGI [C]: gecikmeli geri cagri setUnitPos / doMove, KORUMA belirteci yok: %d aday (basarisizlik DEGIL) %s" % (len(bd), ", ".join("%s:%d" % (a_.replace("fnc_", "").replace(".sqf", ""), l_) for a_, l_ in bd[:30])))
    return 1 if (siki and sonuc) else 0


if __name__ == "__main__":
    sys.exit(main())
