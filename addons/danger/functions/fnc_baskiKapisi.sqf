#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BASTIRMA KAPISI (v8.743; kullanici: 'botlar supress atarken cok sacma sapan yerlere supress atiyor, onunde bos duvar var orayi tariyor, dusman yakinda degilse yapmasin' + 'ileri gozlemci olabilir'):
 * NEDEN: bastirma atisi (doSuppressiveFire) cagri yerlerinin cogu HAT kontrolu yapiyordu (fnc_atesHatiAcik: duvar / bina hatti kapatir) ama dusmanin UZAK ve kimsenin GORMEDIGI durumda yine de atiyordu:
 *   siper tahmini (hedefSiper: dusmanin alacagi siper NOKTASINA, hat kontrolu bile yoktu -> cogu zaman bir duvarin / nesnenin kendisi), penetrasyon / pencere atesi, taban atesi, atis ustunlugu, hucum hazirligi, MG / kapsama destegi, siper zorla.
 * KURAL (hile yok: bilgi + gorus): dusman nesnesi verilmisse bastirma YALNIZ SU DURUMLARDA serbest:
 *   1) dusman baskiYakinM (80 m) icinde (yakin dovus: kim nereye atsa anlamli), YA DA
 *   2) 'ILERI GOZLEMCI': ayni gruptan (gerekirse 150 m icindeki dost) canli bir asker dusmani SU AN gorus hattiyla (VIEW LOD, gorunurluk >= 0.3) goruyor ve (knowsAbout >= SEZILDI) bilinen dusman baskiGozlemciM (250 m) icinde.
 *   Atici kendisi de gozlemci sayilir (kendisi dusmani goruyorsa). Hic kimse gormuyor + dusman uzak = bos tarama: atis yapilmaz (mermi + dikkat tasarrufu, duvara bosaltma yok).
 * Hat kuralini (duvar / arazi) cagri yeri YINE fnc_atesHatiAcik ile uygular; bu fonksiyon yalniz 'dusman yakin mi / goren var mi' sorusunu cevaplar. Dusman nesnesi yoksa (null) karar vermez: true.
 * OLCUM: [BASKI-KAPI] RED (ilk 30: kaynak, atici, dusman mesafesi, gozlemci sayisi) + 60 sn [BASKI-KAPI-OZET] (kaynak basina izin / red). Karne: BASTIRMA KAPISI.
 * CBA: lambs_danger_baskiKapisi (varsayilan ACIK), baskiYakinM, baskiGozlemciM.
 * SINIR: oyunda DENENMEDI; 'goren' hesabi anlik gorus; gozlemci arkada saklanan tek dost olabilir (gercek ileri gozlemci). Penetrasyon / pencere atesi (gorunmeyen hedef) uzakta yalniz gozlemci hedefi goruyorsa degil, YAKINDA serbesttir.
 *
 * Arguments:
 * 0: Atici <OBJECT>
 * 1: Dusman <OBJECT> (null = karar verme)
 * 2: Kaynak etiketi (log) <STRING> (varsayilan "")
 *
 * Return Value: Bastirma serbest mi <BOOL>
 *
 * Public: No
*/

params ["_u", ["_e", objNull], ["_kaynak", ""]];
// v8.798 PIYADE BOMBACI (kullanici: 'baski atesini daha akilli yapsinlar, bombada azalt', 'arac haric', 'siperde de check et'): bombaci ATICI ise (RPT 44282768: kosan bombaci 23 m'de duvara [PENETRE-ATES] atti, kosusu durdu) ya da HEDEF ise (kosan hedefe konum bastirmasi bos mermi, bombaciyi dondurur; AI nisanli atesle zaten vurur) bastirma yok. ARAC bombasi etkilenmez (fnc_bombaciMi).
private _bomba = "";
if ([_u] call FUNC(bombaciMi)) then { _bomba = "atici"; } else { if (!isNull _e && {[_e] call FUNC(bombaciMi)}) then { _bomba = "hedef"; }; };
if (_bomba isNotEqualTo "") exitWith {
    private _sb = missionNamespace getVariable ["lambs_danger_baskiKapiSay", createHashMap];
    missionNamespace setVariable ["lambs_danger_baskiKapiSay", _sb];
    private _kb = format ["%1_bombaci_%2", _kaynak, _bomba];
    _sb set [_kb, (_sb getOrDefault [_kb, 0]) + 1];
    private _nb = missionNamespace getVariable ["lambs_danger_baskiBombaLogN", 0];
    if (_nb < 20) then {
        missionNamespace setVariable ["lambs_danger_baskiBombaLogN", _nb + 1];
        diag_log format ["[BASKI-KAPI] BOMBACI RED | %1 | %2 | bombaci %3 | atici %4 | dusman %5 | %6 m", _kaynak, groupId group _u, _bomba, name _u, ["yok", name _e] select !isNull _e, ["?", str round (_u distance2D _e)] select !isNull _e];
    };
    false
};
if !(missionNamespace getVariable ["lambs_danger_baskiKapisi", true]) exitWith {true};
if (isNull _e || {!alive _e}) exitWith {true};
if (isPlayer _u) exitWith {false};   // v8.749: oyuncu birimine bastirma emri anlamsiz

private _say = missionNamespace getVariable ["lambs_danger_baskiKapiSay", createHashMap];
missionNamespace setVariable ["lambs_danger_baskiKapiSay", _say];
private _yakinM = ((missionNamespace getVariable ["lambs_danger_baskiYakinM", 80]) max 10) min 300;
private _d = _u distance2D _e;
private _izin = true;
private _gorenN = 0;
private _kisi = 0;
if (_d > _yakinM) then {
    private _gM = ((missionNamespace getVariable ["lambs_danger_baskiGozlemciM", 250]) max _yakinM) min 600;
    private _esik = ["SEZILDI"] call FUNC(bilgiEsik);
    private _eEye = eyePos _e;
    private _taraf = side group _u;
    private _aday = (units group _u) select {alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
    if (_d <= _gM) then {
        _aday append (((getPosATL _u) nearEntities ["CAManBase", 150]) select {alive _x && {!(_x in _aday)} && {(_taraf getFriend (side group _x)) >= 0.6} && {(lifeState _x) in ["HEALTHY", "INJURED"]}});
    };
    _kisi = count _aday;
    _gorenN = {
        (_x distance2D _e) <= _gM && {(_x knowsAbout _e) >= _esik} && {([_x, "VIEW", _e] checkVisibility [eyePos _x, _eEye]) >= 0.3}
    } count _aday;
    _izin = _d <= _gM && {_gorenN > 0};
};

private _k = format ["%1_%2", _kaynak, ["red", "izin"] select _izin];
_say set [_k, (_say getOrDefault [_k, 0]) + 1];
if (!_izin) then {
    private _n = missionNamespace getVariable ["lambs_danger_baskiKapiLogN", 0];
    if (_n < 30) then {
        missionNamespace setVariable ["lambs_danger_baskiKapiLogN", _n + 1];
        diag_log format ["[BASKI-KAPI] RED | %1 | %2 (%3) | dusman %4 m > %5 m ve gorus hatti olan gozlemci yok (kisi %6, goren %7, gozlemci menzili %8 m) -> bastirma atilmadi", _kaynak, name _u, groupId group _u, round _d, round _yakinM, _kisi, _gorenN, round ((missionNamespace getVariable ["lambs_danger_baskiGozlemciM", 250]) max _yakinM)];
    };
};
private _ot = missionNamespace getVariable ["lambs_danger_baskiKapiOzetT", time + 60];
if (time > _ot) then {
    missionNamespace setVariable ["lambs_danger_baskiKapiOzetT", time + 60];
    private _ks = keys _say;
    private _nz = _ks select {(_say get _x) > 0};
    if (_nz isNotEqualTo []) then {
        diag_log format ["[BASKI-KAPI-OZET] 60 sn (kaynak_sonuc): %1", (([_nz, [], {_x}, "ASCEND"] call BIS_fnc_sortBy) apply { format ["%1=%2", _x, _say get _x] }) joinString " "];
    };
    { _say set [_x, 0]; } forEach _ks;
} else {
    if (isNil {missionNamespace getVariable "lambs_danger_baskiKapiOzetT"}) then { missionNamespace setVariable ["lambs_danger_baskiKapiOzetT", time + 60]; };
};
_izin
