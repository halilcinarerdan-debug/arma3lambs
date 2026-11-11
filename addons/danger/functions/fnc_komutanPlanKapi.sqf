#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * v8.503 SADE: plan / objektif olay isleyicileri (planIstegi / planYanit / planNoktaIstegi / savunmaMevziIstegi) KALDIRILDI; dosya yalniz Zeus / 3DEN modul olay kapisi (gorevAta, ihaGorev, gozetleAta, karakol, hq, topcuTest, kaldir, garnizon) olarak kaldi.
 * (eski aciklama) KOMUTAN PLANI SUNUCU KAPISI (v8.116) — Zeus modulleri CURATOR'UN makinesinde calisir; gruplar ise SUNUCUDA yereldir. Planlayici yerel gruplari kullandigi icin
 * dedicated / listen (Zeus istemcide) sunucuda plan 'uygun grup yok' diyerek kurulamazdi. Moduller artik CBA sunucu olayi gonderir; bu kapi sunucuda dinler ve plani sunucuda kurar.
 *   lambs_danger_planIstegi      [taraf, objektif, ayar (HashMap -> [[anahtar, deger]])]
 *   lambs_danger_planNoktaIstegi [taraf, nokta adi, pozisyon ya da []]  (manuel plan noktasi ekle / sil)
 * Log: [PLAN-KAPI]
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_planKapiStarted") exitWith {false};
lambs_danger_planKapiStarted = true;

// v8.396 ISARET YAZISI CAKISMASI (kullanici: 'karakol yazisi ust uste biniyor'): otomatik garnizon bolgeleri (KARAKOL / MEVZI / GOZLETME) ve HQ isaretleri birbirine 100-300 m yakin; her birinin
//   'KARAKOL (120 m)' gibi uzun yazisi haritada binisiyordu. Artik yazi KISA (yaricap yazilmaz: KALDIR paneli / Zeus listesi gosterir) ve 150 m icinde yazili baska bir ELITE karakol / mevzi / HQ isareti varsa
//   yeni isaret YAZISIZ (yalniz ikon: bayrak = karakol, ucgen = mevzi, nokta = gozletme, HQ simgesi) olur. Zeus listeleri yazisiz isaretin adini ikon turunden turetir (lambs_danger_isaretAdi).
lambs_danger_isaretMetin = {
    params ["_mn", "_metin"];
    private _p = markerPos _mn;
    private _yakinVar = (allMapMarkers findIf {
        _x isNotEqualTo _mn && {((_x find "ELITE_KARAKOL_") isEqualTo 0) || {(_x find "ELITE_HQ_") isEqualTo 0} || {(_x find "ELITE_MEVZI_") isEqualTo 0}}
        && {(markerText _x) isNotEqualTo ""} && {((markerPos _x) distance2D _p) < 150}
    }) >= 0;
    if (_yakinVar) then {""} else {_metin}
};
lambs_danger_isaretAdi = {
    params ["_m"];
    private _t = markerText _m;
    if (_t isNotEqualTo "") then {_t} else {
        switch (markerType _m) do {
            case "mil_flag": {"KARAKOL"};
            case "mil_triangle": {"MEVZI"};
            case "mil_dot": {"GOZETLEME"};
            case "b_hq": {"HQ"};
            default {_m};
        }
    }
};

// v8.127: Zeus 'ELITE Gorev Ata' -> sunucu degiskeni yazar (grup + varsa arac)
["lambs_danger_gorevAta", {
    params ["_hedef", "_kod"];
    if (!isServer || {isNull _hedef}) exitWith {};
    private _g = if (_hedef isEqualType grpNull) then {_hedef} else {group (effectiveCommander _hedef)};
    private _nesneler = [];
    if (!(_hedef isEqualType grpNull) && {!(_hedef isKindOf "CAManBase")}) then { _nesneler pushBack _hedef; };
    if (!(_hedef isEqualType grpNull) && {_hedef isKindOf "CAManBase"} && {!isNull objectParent _hedef}) then { _nesneler pushBack (vehicle _hedef); };   // v8.407: grup nesnesinde isKindOf hata veriyordu (RPT b95a6bae: Type Group, expected String,Object)
    if (!isNull _g) then { _nesneler pushBack _g; };
    // v8.151: oyuncu komutasi bayragi (gorev degiskenine yazilmaz): OYUNCU = true, ELITE_TAM = false, Otomatik = silinir (oyunculu grup otomatik)
    if (_kod in ["OYUNCU", "ELITE_TAM"]) exitWith {
        if (!isNull _g) then { _g setVariable ["lambs_danger_oyuncuKomuta", _kod isEqualTo "OYUNCU", true]; };
        diag_log format ["[OYUNCU-KOMUTA] %1 -> %2", [groupId _g, "-"] select (isNull _g), ["ELITE TAM ACIK (zorla)", "OYUNCU KOMUTASI (ELITE taktik kapali)"] select (_kod isEqualTo "OYUNCU")];
    };
    if (_kod isEqualTo "" && {!isNull _g}) then { _g setVariable ["lambs_danger_oyuncuKomuta", nil, true]; };
    { _x setVariable ["lambs_danger_gorev", _kod, true]; } forEach _nesneler;
    // v8.141: arac atamasinda ekip grubu kaydi (surucu araci terk ederse yeniden binmesi icin)
    if (!(_hedef isEqualType grpNull) && {!(_hedef isKindOf "CAManBase")} && {!isNull _g}) then { _hedef setVariable ["lambs_danger_ekipGrup", _g, true]; };
    diag_log format ["[GOREV-ATAMA] %1 -> %2 (nesne: %3)", [groupId _g, "-"] select (isNull _g), ["TEMIZLENDI", _kod] select (_kod isNotEqualTo ""), count _nesneler];
}] call CBA_fnc_addEventHandler;

// v8.233: Zeus 'ELITE IHA Gorevi' -> fnc_ihaSorti (sunucu)
["lambs_danger_ihaGorev", {
    params ["_nid", "_mod", "_tur", "_tarafI", "_poz", "_yar", "_men", ["_yaratSn", ""], ["_tetik", 0], ["_opNid", ""], ["_opMod", 0], ["_cantaNid", ""], ["_sure", 0]];
    private _op = objectFromNetId _opNid;
    private _canta = objectFromNetId _cantaNid;
    if (!isServer) exitWith {};
    private _iha = objectFromNetId _nid;
    private _tf = [west, east, independent] select (_tarafI max 0 min 2);
    // v8.267: KALDIR + dron yok -> firlatma noktasinin 60 m icindeki bekleyen firlatma emirleri iptal edilir
    if (isNull _iha && {_mod isEqualTo "KALDIR"}) exitWith {
        private _n = 0;
        { if (((_x select 0) distance2D _poz) <= 60 && {!(_x select 1)}) then { _x set [1, true]; _n = _n + 1; }; } forEach (missionNamespace getVariable ["lambs_danger_ihaBekleEmirleri", []]);
        diag_log format ["[IHA-BEKLEME] Zeus KALDIR: %1 bekleyen firlatma emri iptal edildi (%2)", _n, mapGridPosition _poz];
        private _cu = (allCurators apply {getAssignedCuratorUnit _x}) select {!isNull _x};
        if (_cu isNotEqualTo []) then { [format ["[ELITE] IHA firlatma emri iptal: %1", _n]] remoteExec ["systemChat", _cu]; };
    };
    // v8.267 BILINCLI FIRLATMA: 'Dron yarat' dronu hemen degil, firlatma noktasinin tetik mesafesinde BILINEN dusman gorulunce yaratir (fnc_ihaBekle); tetik 0 = hemen (eski)
    // v8.363: Gozlem devriyesi + 'Dron yarat' -> tur GOZLEM'e zorlanir (eskiden 'Otomatik' tur Crocus'ta FPV sortisi olurdu) ve firlatma BEKLEMEZ (gozlem dronu dusman bilinmeden, bilgi toplamak icin kalkar; tetik mesafesi dusman gerektirirdi)
    if (_mod isEqualTo "GOZLEM") then { _tur = "GOZLEM"; _tetik = 0; };
    if (isNull _iha && {_yaratSn isNotEqualTo ""} && {isClass (configFile >> "CfgVehicles" >> _yaratSn)}) exitWith {
        [_yaratSn, _tf, _poz, _tur, _yar, _men, _tetik, _op, _opMod, _canta, _sure] call (missionNamespace getVariable ["lambs_danger_fnc_ihaBekle", {false}]);
    };
    [_iha, _mod, _tur, _tf, _poz, _yar, _men, _op, _opMod, _sure] call (missionNamespace getVariable ["lambs_danger_fnc_ihaSorti", {false}]);
}] call CBA_fnc_addEventHandler;

// v8.214: Zeus 'ELITE Gozetleme Ata' -> grup secilen karakol / mevzi isaretinde nobet tutar (fnc_gozetleAta)
["lambs_danger_gozetleAta", {
    params ["_gNet", "_mn"];
    if (!isServer) exitWith {};
    [groupFromNetId _gNet, _mn] call (missionNamespace getVariable ["lambs_danger_fnc_gozetleAta", {}]);
}] call CBA_fnc_addEventHandler;

// v8.128: Zeus 'ELITE Karakol / HQ' — karakol kaydi + harita isareti + savunma plani (hemen / alarm)
if (isNil "lambs_danger_karakollar") then { lambs_danger_karakollar = []; };
["lambs_danger_karakolIstegi", {
    params ["_taraf", "_poz", "_adI", "_yar", "_sav", ["_elle", false]];
    if (!isServer) exitWith {};
    private _adlar = ["KARAKOL", "MEVZI", "GOZETLEME"];
    private _ad = _adlar select (_adI max 0 min 2);
    // ayni noktada (60 m) mevcut kayit: once sil
    private _eski = lambs_danger_karakollar select {((_x select 1) distance2D _poz) < 60 && {(_x select 0) isEqualTo _taraf}};
    { deleteMarker (_x select 5); if (!isNil "lambs_danger_karakolAyar") then { lambs_danger_karakolAyar set [_x select 5, createHashMap]; }; lambs_danger_karakollar deleteAt (lambs_danger_karakollar find _x); } forEach _eski;
    if (_sav isEqualTo 3) exitWith {
        diag_log format ["[KARAKOL] %1 | %2 KALDIRILDI (%3 kayit)", _taraf, mapGridPosition _poz, count _eski];
    };
    private _mn = format ["ELITE_KARAKOL_%1_%2", _taraf, round (_poz select 0)];
    deleteMarker _mn;
    createMarker [_mn, _poz];
    _mn setMarkerType (["mil_flag", "mil_triangle", "mil_dot"] select (_adI max 0 min 2));
    _mn setMarkerColor (switch (_taraf) do { case west: {"ColorBLUFOR"}; case east: {"ColorOPFOR"}; default {"ColorIndependent"} });
    _mn setMarkerText ([_mn, _ad] call lambs_danger_isaretMetin);
    private _kayit = [_taraf, _poz, _yar, _ad, _sav, _mn, false];
    lambs_danger_karakollar pushBack _kayit;
    diag_log format ["[KARAKOL] %1 | %2 | %3 | yaricap %4 m | savunma %5", _taraf, _ad, mapGridPosition _poz, _yar, ["YOK", "HEMEN", "ALARM"] select (_sav min 2)];
}] call CBA_fnc_addEventHandler;

// v8.196: Zeus 'ELITE Topcu TEST' - plan mantigindan bagimsiz atis denemesi (sunucu)
["lambs_danger_topcuTestIstegi", {
    params ["_poz", "_sahip"];
    if (!isServer) exitWith {};
    private _rapor = [];
    private _araclar = vehicles select {alive _x && {(getNumber (configOf _x >> "artilleryScanner")) > 0}};
    if (_araclar isEqualTo []) then { _rapor pushBack "sahada artilleryScanner'li arac YOK"; };
    {
        private _v = _x;
        private _ad = format ["%1 (%2)", getText (configOf _v >> "displayName"), side (group _v)];
        private _g = gunner _v;
        private _mg = (getArtilleryAmmo [_v]) param [0, ""];
        if (isNull _g) then { _rapor pushBack format ["%1: topcu (gunner) YOK", _ad]; continue };
        if (isPlayer _g) then { _rapor pushBack format ["%1: gunner OYUNCU - AI atis emri verilmez", _ad]; continue };
        if (!local _v) then {
            // v8.287: yerel degilse murettebat gruplari hemen sunucuya devredilir (oyuncu / uzaktan kontrol yoksa); 15-20 sn sonra testi tekrarlayin
            private _grlar = [];
            { private _gx = group _x; if (!isNull _gx && {!(_gx in _grlar)}) then { _grlar pushBack _gx; }; } forEach (crew _v);
            private _engel = (_grlar findIf { ((units _x) findIf {isPlayer _x}) >= 0 || {((units _x) findIf {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner", objNull])}) >= 0} }) >= 0;
            if (_engel) then {
                _rapor pushBack format ["%1: sunucuda YEREL DEGIL (sahip %2); murettebatta OYUNCU / ZEUS UZAKTAN KONTROL var -> devredilemez (kontrolu birak)", _ad, owner _v];
            } else {
                { _x setGroupOwner 2; } forEach _grlar;
                _rapor pushBack format ["%1: sunucuda yerel degildi (sahip %2) -> murettebat sunucuya DEVREDILDI; 15-20 sn sonra testi tekrarlayin", _ad, owner _v];
            };
            continue
        };
        if (!canFire _v) then { _rapor pushBack format ["%1: canFire FALSE (hasar / mermi)", _ad]; continue };
        if (_mg isEqualTo "") then { _rapor pushBack format ["%1: mermi YOK (getArtilleryAmmo bos)", _ad]; continue };
        if !(_poz inRangeOfArtillery [[_v], _mg]) then {
            private _kon = [_v, _poz, "TEST"] call (missionNamespace getVariable ["lambs_danger_fnc_topcuKonumla", {false}]);
            _rapor pushBack format ["%1: hedef %2 m'de MENZIL DISI -> %3", _ad, round (_v distance2D _poz), ["yer degistirme emri verilemedi (300 sn kilit / surucu yok)", "yer degistiriyor, 1-2 dk sonra tekrar deneyin"] select _kon];
            continue
        };
        [_v, _poz, _mg] call (missionNamespace getVariable ["lambs_danger_fnc_topcuAtisHazirla", {false}]);   // v8.287: hareket emri iptal, davranis / combatMode, atis tanisi
        _v doArtilleryFire [_poz getPos [random 25, random 360], _mg, 3];
        _rapor pushBack format ["%1: ATES EMRI VERILDI (%2 m, %3, 3 mermi, ETA %4 sn)", _ad, round (_v distance2D _poz), _mg, round (_v getArtilleryETA [_poz, _mg])];
    } forEach _araclar;
    { diag_log format ["[TOPCU-TEST] %1 | %2", mapGridPosition _poz, _x]; } forEach _rapor;
    ["lambs_danger_topcuTestYanit", [_rapor], _sahip] call CBA_fnc_ownerEvent;
}] call CBA_fnc_addEventHandler;
["lambs_danger_topcuTestYanit", {
    params ["_rapor"];
    if (!hasInterface) exitWith {};
    { systemChat format ["[ELITE Topcu TEST] %1", _x]; } forEach _rapor;
}] call CBA_fnc_addEventHandler;

// v8.176: Zeus 'ELITE Karakol / Plan KALDIR' - liste istegi (sunucu) -> liste (istemci panel) -> kaldirma istegi (sunucu)
["lambs_danger_kaldirListeIstegi", {
    params ["_sahip"];
    if (!isServer) exitWith {};
    private _liste = [];
    {
        _x params ["_t", "_p", "_y", "_ad", "_sav", "_mn"];
        _liste pushBack [format ["K:%1", _mn], format ["KARAKOL | %1 | %2 | %3 | yaricap %4 m | %5", _t, _ad, mapGridPosition _p, _y, ["savunma YOK", "savunma HEMEN", "ALARM"] select (_sav min 2)], _p];
    } forEach lambs_danger_karakollar;
    // v8.179: aktif planlar listeden CIKARILDI (ayni islev: plan iptali "ELITE Objektif -> Gorev tipi: IPTAL" ile yapilir ve gruplar HQ / US'ye doner)
    diag_log format ["[KALDIR] liste istendi: %1 kayit (sahip %2)", count _liste, _sahip];
    ["lambs_danger_kaldirListe", [_liste], _sahip] call CBA_fnc_ownerEvent;
}] call CBA_fnc_addEventHandler;
["lambs_danger_kaldirListe", {
    params ["_liste"];
    if (!hasInterface) exitWith {};
    [{
        params ["_liste"];
        [_liste, 0, []] call (missionNamespace getVariable ["lambs_danger_fnc_kaldirPanel", {}]);
    }, [_liste]] call CBA_fnc_execNextFrame;
}] call CBA_fnc_addEventHandler;
["lambs_danger_kaldirIstegi", {
    params ["_anahtarlar"];
    if (!isServer) exitWith {};
    private _kal = 0;
    {
        private _a = _x;
        if ((_a select [0, 2]) isEqualTo "K:") then {
            private _mn = _a select [2];
            private _i = lambs_danger_karakollar findIf {(_x select 5) isEqualTo _mn};
            if (_i >= 0) then {
                private _k = lambs_danger_karakollar select _i;
                private _kp = _k select 1;
                deleteMarker _mn;
                if (!isNil "lambs_danger_karakolAyar") then { lambs_danger_karakolAyar set [_mn, createHashMap]; };
                lambs_danger_karakollar deleteAt _i;
                _kal = _kal + 1;
                diag_log format ["[KALDIR] karakol KALDIRILDI: %1 | %2 | %3", _k select 3, _k select 0, mapGridPosition _kp];
            };
        } else {
            // (H: HQ ve P: plan anahtarlari sade surumde yok)
        };
    } forEach _anahtarlar;
    ["lambs_danger_garnizonYanit", [format ["Kaldirildi: %1 karakol/mevzi", _kal]]] call CBA_fnc_globalEvent;
}] call CBA_fnc_addEventHandler;

// v8.130: Zeus 'ELITE Karakol Garnizon' — ayar kaydi (nobet / devriye / ust kat / arac); uygulama fnc_karakolGarnizon bekcisinde
if (isNil "lambs_danger_karakolAyar") then { lambs_danger_karakolAyar = createHashMap; };
["lambs_danger_garnizonIstegi", {
    params ["_poz", "_islem", "_nobet", "_dev", "_devBoy", "_ust", "_arac", ["_uyeler", []], ["_devMes", 0], ["_gruplar", []], ["_iha", []], ["_aa", 0]];   // v8.398: _iha = [mod 0 yok / 1 surekli / 2 alarmda, yaricap (0 = karakol yaricapi), sure dk (0 = CBA), baglanan IHA netId dizisi]   // v8.394: elle secilen asker netId'leri (bos = yaricap havuzu) + devriye mesafesi (0 = yaricap %60)
    if (!isServer) exitWith {};
    // v8.393: garnizon modulu karakolun yaricapi + CBA garnizonEk (varsayilan 500 m; eskiden sabit 150) icine birakilabilir; en yakin karakol secilir
    private _ad = lambs_danger_karakollar select {((_x select 1) distance2D _poz) <= ((_x select 2) + (missionNamespace getVariable ["lambs_danger_garnizonEk", 500]))};
    // v8.400 SADELESTIRME (kullanici: 'ayni isi yapan modulleri sadelestir'; RPT: iki garnizon modulu 'yakinda karakol yok' diye reddedilmisti): yakinda karakol YOKSA modul konumunda OTOMATIK karakol kurulur.
    //   Taraf: SYNC / secili askerin, secili takimin, SYNC'li IHA'nin ya da module en yakin AI askerin tarafi; hicbiri yoksa reddedilir. Yaricap 150 m (genis alan icin karakol modulunu kullan). Kaldirma islemi karakol kaydina dokunmaz.
    if (_ad isEqualTo [] && {_islem isEqualTo 0}) then {
        private _tOto = sideUnknown;
        private _ilkA = (_uyeler apply {objectFromNetId _x}) select {!isNull _x};
        if (_ilkA isNotEqualTo []) then { _tOto = side (group (_ilkA select 0)); };
        if (_tOto isEqualTo sideUnknown) then {
            private _ilkG = (_gruplar apply {groupFromNetId _x}) select {!isNull _x};
            if (_ilkG isNotEqualTo []) then { _tOto = side (_ilkG select 0); };
        };
        if (_tOto isEqualTo sideUnknown) then {
            private _ilkI = ((_iha param [3, []]) apply {objectFromNetId _x}) select {!isNull _x};
            if (_ilkI isNotEqualTo []) then {
                private _iv = _ilkI select 0;
                _tOto = if ((crew _iv) isNotEqualTo []) then {side (group ((crew _iv) select 0))} else {[east, west, independent, civilian] select (((getNumber (configOf _iv >> "side")) max 0) min 3)};
            };
        };
        if (_tOto isEqualTo sideUnknown) then {
            private _yk = (nearestObjects [_poz, ["CAManBase"], 400]) select {alive _x && {!isPlayer _x} && {(side (group _x)) in [west, east, independent]}};
            if (_yk isNotEqualTo []) then { _tOto = side (group (_yk select 0)); };
        };
        if (_tOto in [west, east, independent]) then {
            ["lambs_danger_karakolIstegi", [_tOto, _poz, 0, 150, 0, false]] call CBA_fnc_serverEvent;
            _ad = lambs_danger_karakollar select {((_x select 1) distance2D _poz) <= ((_x select 2) + (missionNamespace getVariable ["lambs_danger_garnizonEk", 500]))};
            diag_log format ["[KARAKOL-GARNIZON] %1 yakininda karakol yoktu: OTOMATIK karakol kuruldu (%2, yaricap 150 m)", mapGridPosition _poz, _tOto];
        };
    };
    if (_ad isEqualTo []) exitWith {
        diag_log format ["[KARAKOL-GARNIZON] istek reddedildi: %1 yakininda karakol yok ve taraf belirlenemedi (yakinda AI asker / baglanan asker-takim-IHA yok)", mapGridPosition _poz];
        ["lambs_danger_garnizonYanit", ["Garnizon: yakinda karakol yok ve taraf belirlenemedi - modulun yakinina AI asker koyun / SYNC edin ya da once 'ELITE Karakol / Mevzi' modulu koyun (yaricap + CBA 'Garnizon modulu ek mesafe' icine; varsayilan 500 m)"]] call CBA_fnc_globalEvent;
    };
    _ad = [_ad, [], {(_x select 1) distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy;
    private _k = _ad select 0;
    private _mn = _k select 5;
    if (_islem isEqualTo 1) then {
        lambs_danger_karakolAyar set [_mn, createHashMap];
        diag_log format ["[KARAKOL-GARNIZON] %1 | %2 garnizon KALDIRILDI", _k select 0, _k select 3];
        ["lambs_danger_garnizonYanit", [format ["Garnizon kaldirildi: %1", _k select 3]]] call CBA_fnc_globalEvent;
    } else {
        private _eski = lambs_danger_karakolAyar getOrDefault [_mn, createHashMap];
        lambs_danger_karakolAyar set [_mn, createHashMapFromArray [["nobet", _nobet], ["devriye", _dev], ["devBoy", _devBoy], ["ustKat", _ust], ["arac", _arac], ["uyeler", _uyeler], ["devMes", _devMes], ["gruplar", _gruplar], ["aa", _aa], ["ihaMod", _iha param [0, 0]], ["ihaYar", _iha param [1, 0]], ["ihaSure", _iha param [2, 0]], ["ihalar", _iha param [3, []]], ["surum", (_eski getOrDefault ["surum", 0]) + 1]]];
        diag_log format ["[KARAKOL-GARNIZON] %1 | %2 ayar: nobet %3 | devriye %4 x %5 | ust kat %6 | arac %7 | secili asker %8 | secili takim %11 | iha mod %12 | AA %13 | devriye mesafesi %9 (surum %10)", _k select 0, _k select 3, _nobet, _dev, _devBoy, _ust, _arac, count _uyeler, _devMes, (_eski getOrDefault ["surum", 0]) + 1, count _gruplar, _iha param [0, 0], _aa];
        ["lambs_danger_garnizonYanit", [format ["Garnizon ayari alindi: %1 | nobet %2, devriye %3 x %4, ust kat %5, arac %6 (15 sn icinde uygulanir)", _k select 3, _nobet, _dev, _devBoy, _ust, _arac]]] call CBA_fnc_globalEvent;
    };
}] call CBA_fnc_addEventHandler;
["lambs_danger_garnizonYanit", {
    params ["_m"];
    if (!hasInterface) exitWith {};
    diag_log format ["[KARAKOL-YANIT] %1", _m];
    if (!isNull (getAssignedCuratorLogic player)) then { systemChat format ["[ELITE] %1", _m]; };
}] call CBA_fnc_addEventHandler;

diag_log "[PLAN-KAPI] komutan plani sunucu kapisi baslatildi (v8.116)";
true
