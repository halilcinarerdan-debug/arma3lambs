#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BILGI ESIGI — TEK TABLO (v8.366; denetim raporu 3.1: 'knowsAbout esikleri 0.2-1.2 arasinda sistemden sisteme degisiyor, tek tablo'). 'Dusmani biliyor' ifadesinin SAYISAL tanimi ARTIK TEK YERDE.
 * Arma 'knowsAbout' olcegi 0-4 (0 = bilmiyor, ~1.5 = gorulmus / hedef alinabilir, 4 = tam bilgi). Esik, KARARIN SONUCUNUN MALIYETINE gore secilir (neden -> esik):
 *
 *   ISARET  0.15  Iz: yeni atesle vurulmus / havada silahli arac asili. Tepki UCUZ + GERI ALINABILIR ama tehdit AGIR -> en ufak ize tepki (silahli heli, ates alan).
 *   SEZILDI 0.30  Bir sey SEZILDI (ses, kisa gorus, paylasilan ipucu). UCUZ ve GERI ALINABILIR tepkiler: bakma / donme, uyari, hedef yonune ates egilimi (atis ustunlugu), silahci hedefe donsun,
 *                 tank-dron uyarisi, plan icin kaba dusman merkezi.
 *   SUPHE   0.50  MUHTEMEL dusman, yer kabaca biliniyor. YEREL taktik secimler (hata maliyeti dusuk): bastirma hedefi, sis, bina penceresi, bounding odagi, roket tepkisi, saglik / siper yer degistirme.
 *   TESPIT  0.80  Dusman TESPIT edildi ve konumlandi. GRUP / PLAN duzeyi kararlar ve maliyetli ama geri alinabilir eylemler: dusman sayimi / plan gozlemi, yakin temas kose temkini, zirhli hedefe patlayici,
 *                 esir / teslim karari, keskin nisanci ates emri, dusmana karsi pusu bilgisi.
 *   KESIN   1.20  Dusman TESHIS edildi ve izleniyor. GERI ALINAMAZ / DOSTA ZARAR riski olan ya da pahali varliklari baglayan kararlar: dolayli ates gozlemi (FO) ve karsi-batarya, pusu tetigi,
 *                 AT / zirh kararlari, komutan tehdit gecerliligi, HQ istihbarat paylasimi.
 *   TAM     2.00  Dusman bizi de TAM biliyor / tam teshis (keskin nisanci karsi-tedbir).
 * Esikler SIRALI (monoton) tutulur: bir asamanin degeri bir onceki asamadan kucuk olamaz (CBA'dan ters girilirse otomatik yukseltilir).
 * Ayar: CBA 'ELITE bilgi esikleri' (lambs_danger_esik_<AD>); degisiklik <= 2 sn icinde gecerli. Kodda DOGRUDAN sayi yazmak yasak: tools/tutarlilik_denetimi.py [BILGI-ESIK] yakalar.
 * Kitap karsiligi: tasarim [T] (kaynak setinde 'knowsAbout' yok — Arma'ya ozgu olcek); mantik 'karar maliyetine gore kanit esigi' (TC 3-21.76 / MCWP 3-11.1: geri alinamaz karar daha guvenilir istihbarat ister — kavram [K~]).
 * Belge: BILGI_ESIK_TABLOSU.md (her kullanimin eski -> yeni degeri).
 *
 * Arguments:
 * 0: Asama adi <STRING> "ISARET" | "SEZILDI" | "SUPHE" | "TESPIT" | "KESIN" | "TAM"
 *
 * Return Value: Esik <NUMBER>
 * Public: No
*/

params [["_t", "SUPHE", [""]]];

// TABLO (tek kaynak): sirali [ad, varsayilan]
private _onb = missionNamespace getVariable ["lambs_danger_esikOnbellek", []];
if (_onb isEqualTo [] || {(diag_tickTime - (_onb select 0)) > 2}) then {
    private _tablo = [["ISARET", 0.15], ["SEZILDI", 0.30], ["SUPHE", 0.50], ["TESPIT", 0.80], ["KESIN", 1.20], ["TAM", 2.00]];
    private _h = createHashMap;
    private _onceki = 0;
    {
        _x params ["_ad", "_vars"];
        private _v = (missionNamespace getVariable [format ["lambs_danger_esik_%1", _ad], _vars]) max _onceki;   // monoton
        _h set [_ad, _v];
        _onceki = _v;
    } forEach _tablo;
    _onb = [diag_tickTime, _h];
    missionNamespace setVariable ["lambs_danger_esikOnbellek", _onb];
};
private _r = (_onb select 1) get _t;
if (isNil "_r") exitWith {
    if (isNil "lambs_danger_esikHataLog") then {
        lambs_danger_esikHataLog = true;
        diag_log format ["[BILGI-ESIK] bilinmeyen asama '%1' (ISARET / SEZILDI / SUPHE / TESPIT / KESIN / TAM) -> SUPHE kullanildi", _t];
    };
    (_onb select 1) get "SUPHE"
};
_r
