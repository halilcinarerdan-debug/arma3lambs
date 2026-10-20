#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOMUTAN PLANI SUNUCU KAPISI (v8.116) — Zeus modulleri CURATOR'UN makinesinde calisir; gruplar ise SUNUCUDA yereldir. Planlayici yerel gruplari kullandigi icin
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

["lambs_danger_planIstegi", {
    params ["_taraf", "_obj", "_ayarCiftler"];
    if (!isServer) exitWith {};
    diag_log format ["[PLAN-KAPI] plan istegi alindi (sunucu): %1 | %2", _taraf, mapGridPosition _obj];
    // v8.121: sonuc tum makinelere bildirilir (Zeus ekraninda systemChat); istemci RPT'sinde de gorunur
    [_taraf, _obj, _ayarCiftler] spawn {
        params ["_taraf", "_obj", "_ayarCiftler"];
        private _ayar = createHashMapFromArray _ayarCiftler;
        private _r = [_taraf, _obj, _ayar] call (missionNamespace getVariable ["lambs_danger_fnc_komutanPlan", {false}]);
        // v8.205: reddedilirse GERCEK neden istemciye gider ("canli AI yok" mesaji yaniltici idi: asil neden cogunlukla 'zaten planda')
        private _neden = if (_r isEqualTo true) then {""} else { missionNamespace getVariable ["lambs_danger_planRedNeden", ""] };
        missionNamespace setVariable ["lambs_danger_planRedNeden", ""];
        ["lambs_danger_planYanit", [_taraf, _ayar getOrDefault ["tip", 0], _r isEqualTo true, _neden]] call CBA_fnc_globalEvent;
    };
}] call CBA_fnc_addEventHandler;

// v8.121: sunucudan donen yanit (her makinede; yalniz arayuzu olan gosterir)
["lambs_danger_planYanit", {
    params ["_taraf", "_tip", "_ok", ["_neden", ""]];
    if (!hasInterface) exitWith {};
    private _m = switch (_tip) do {
        case 2: { ["IPTAL: aktif plan yok", "IPTAL: plan durduruldu"] select _ok };
        case 3: { ["ONAY: bekleyen plan yok", "ONAY: plan baslatildi"] select _ok };
        default { [if (_neden isNotEqualTo "") then {format ["PLAN KURULAMADI: %1", _neden]} else {"PLAN KURULAMADI: uygun grup yok (en az 3 canli AI asker, o taraf icin ELITE acik, objektife <= 4000 m, baska planda degil)"}, "PLAN KURULDU (haritada ELITE_PLAN isaretleri + grup waypoint'leri)"] select _ok };
    };
    diag_log format ["[PLAN-YANIT] %1 | %2", _taraf, _m];
    if (!isNull (getAssignedCuratorLogic player)) then { systemChat format ["[ELITE] %1", _m]; };
}] call CBA_fnc_addEventHandler;

["lambs_danger_planNoktaIstegi", {
    params ["_taraf", "_ad", "_poz"];
    if (!isServer) exitWith {};
    if (isNil "lambs_danger_planManuel") then { lambs_danger_planManuel = createHashMap; };
    private _anahtar = format ["%1|%2", _taraf, _ad];
    private _mn = format ["ELITE_MANUEL_%1_%2", _taraf, _ad];
    if (_poz isEqualTo []) then {
        lambs_danger_planManuel deleteAt _anahtar;
        deleteMarker _mn;
    } else {
        lambs_danger_planManuel set [_anahtar, _poz];
        deleteMarker _mn;
        createMarker [_mn, _poz];
        _mn setMarkerType "mil_destroy";
        _mn setMarkerColor (switch (_taraf) do { case west: {"ColorBLUFOR"}; case east: {"ColorOPFOR"}; default {"ColorIndependent"} });
        _mn setMarkerText format ["MANUEL %1", _ad];
    };
    diag_log format ["[PLAN-MANUEL] %1 | %2 | %3", _taraf, _ad, ["SILINDI", format ["konuldu: %1 (sonraki Objektif planinda kullanilir)", mapGridPosition _poz]] select (_poz isNotEqualTo [])];
}] call CBA_fnc_addEventHandler;

// v8.239 COKLU MEVZI: SAVUN plani icin elle konan savunma mevzileri (taraf basina birden cok); plan kurulurken objektife <= 700 m olanlar plana girer ve gruplar mevzilere dagitilir
["lambs_danger_savunmaMevziIstegi", {
    params ["_taraf", "_islem", "_poz", "_yon"];
    if (!isServer) exitWith {};
    if (isNil "lambs_danger_savunmaMevzi") then { lambs_danger_savunmaMevzi = createHashMap; };
    if (isNil "lambs_danger_savunmaMevziSay") then { lambs_danger_savunmaMevziSay = 0; };
    private _k = str _taraf;
    private _liste = lambs_danger_savunmaMevzi getOrDefault [_k, []];
    switch (_islem) do {
        case "EKLE": {
            lambs_danger_savunmaMevziSay = lambs_danger_savunmaMevziSay + 1;
            private _mn = format ["ELITE_MEVZI_%1_%2", _k, lambs_danger_savunmaMevziSay];
            createMarker [_mn, _poz];
            _mn setMarkerType "mil_triangle";
            _mn setMarkerColor (switch (_taraf) do { case west: {"ColorBLUFOR"}; case east: {"ColorOPFOR"}; default {"ColorIndependent"} });
            _mn setMarkerText format ["MEVZI %1", count _liste + 1];
            if (_yon >= 0) then { _mn setMarkerDir _yon; };
            _liste pushBack [+_poz, _yon, _mn];
        };
        case "SIL-YAKIN": {
            private _i = -1;
            private _en = 150;
            { private _d = (_x select 0) distance2D _poz; if (_d < _en) then { _en = _d; _i = _forEachIndex; }; } forEach _liste;
            if (_i >= 0) then { deleteMarker ((_liste select _i) select 2); _liste deleteAt _i; };
        };
        case "SIL-HEPSI": {
            { deleteMarker (_x select 2); } forEach _liste;
            _liste = [];
        };
        default {};
    };
    lambs_danger_savunmaMevzi set [_k, _liste];
    diag_log format ["[PLAN-MEVZI] %1 | %2 | %3 | yon %4 | bu taraf icin kayitli mevzi: %5", _taraf, _islem, mapGridPosition _poz, _yon, count _liste];
}] call CBA_fnc_addEventHandler;

// v8.127: Zeus 'ELITE Gorev Ata' -> sunucu degiskeni yazar (grup + varsa arac)
["lambs_danger_gorevAta", {
    params ["_hedef", "_kod"];
    if (!isServer || {isNull _hedef}) exitWith {};
    private _g = if (_hedef isEqualType grpNull) then {_hedef} else {group (effectiveCommander _hedef)};
    private _nesneler = [];
    if (!(_hedef isEqualType grpNull) && {!(_hedef isKindOf "CAManBase")}) then { _nesneler pushBack _hedef; };
    if (_hedef isKindOf "CAManBase" && {!isNull objectParent _hedef}) then { _nesneler pushBack (vehicle _hedef); };
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
    params ["_nid", "_mod", "_tur", "_tarafI", "_poz", "_yar", "_men", ["_yaratSn", ""], ["_tetik", 0], ["_opNid", ""], ["_opMod", 0], ["_cantaNid", ""]];
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
    if (isNull _iha && {_yaratSn isNotEqualTo ""} && {isClass (configFile >> "CfgVehicles" >> _yaratSn)}) exitWith {
        [_yaratSn, _tf, _poz, _tur, _yar, _men, _tetik, _op, _opMod, _canta] call (missionNamespace getVariable ["lambs_danger_fnc_ihaBekle", {false}]);
    };
    [_iha, _mod, _tur, _tf, _poz, _yar, _men, _op, _opMod] call (missionNamespace getVariable ["lambs_danger_fnc_ihaSorti", {false}]);
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
    _mn setMarkerText format ["%1 (%2 m)", _ad, _yar];
    private _kayit = [_taraf, _poz, _yar, _ad, _sav, _mn, false];
    lambs_danger_karakollar pushBack _kayit;
    diag_log format ["[KARAKOL] %1 | %2 | %3 | yaricap %4 m | savunma %5", _taraf, _ad, mapGridPosition _poz, _yar, ["YOK", "HEMEN", "ALARM"] select (_sav min 2)];
    if (_sav isEqualTo 1 && {_elle}) then {
        _kayit set [6, true];
        diag_log format ["[KARAKOL] %1 | savunma grubu ELLE secilecek (Zeus squad listesi); otomatik plan kurulmadi", mapGridPosition _poz];
    };
    if (_sav isEqualTo 1 && {!_elle}) then {
        _kayit set [6, true];
        [_taraf, _poz, createHashMapFromArray [["tip", 1], ["grupN", 8], ["grupMesafe", _yar * 1.5], ["bina", true], ["piyade", true], ["rallyM", 250], ["orpM", 150], ["basla", 0]]] spawn (missionNamespace getVariable ["lambs_danger_fnc_komutanPlan", {false}]);
    };
}] call CBA_fnc_addEventHandler;

// v8.178: HQ / US kayitlari (kategori: HQ1 / HQ2 / HQ3 / US) + squad atamasi. Objektif planlari bir HQ'dan baslar; katilacak squadlar HQ'ya atananlardir; iptal / basarisizlikta HQ'ya donulur.
// Kayit: [id, taraf, poz, kategori, yaricap, marker]; istemci arayuzu icin lambs_danger_hqListe (publicVariable): [id, taraf (str), kategori, poz, yaricap, atanan_grup_sayisi]
if (isNil "lambs_danger_hqlar") then { lambs_danger_hqlar = []; };
if (isNil "lambs_danger_hqListe") then { lambs_danger_hqListe = []; };
lambs_danger_hqYayinla = {
    if (!isServer) exitWith {};
    lambs_danger_hqListe = lambs_danger_hqlar apply {
        private _id = _x select 0;
        [_id, str (_x select 1), _x select 3, _x select 2, _x select 4, {(_x getVariable ["lambs_danger_hqId", ""]) isEqualTo _id} count allGroups]
    };
    publicVariable "lambs_danger_hqListe";
};
["lambs_danger_hqIstegi", {
    params ["_taraf", "_poz", "_katI", "_yar"];
    if (!isServer) exitWith {};
    private _kat = ["HQ1", "HQ2", "HQ3", "US"] select (_katI max 0 min 3);
    private _id = format ["%1_%2", _kat, _taraf];
    private _eski = lambs_danger_hqlar findIf {(_x select 0) isEqualTo _id};
    if (_eski >= 0) then { deleteMarker ((lambs_danger_hqlar select _eski) select 5); lambs_danger_hqlar deleteAt _eski; };
    private _mn = format ["ELITE_HQ_%1", _id];
    deleteMarker _mn;
    createMarker [_mn, _poz];
    _mn setMarkerType (["b_hq", "b_hq", "b_hq", "mil_flag"] select (_katI max 0 min 3));
    _mn setMarkerColor (switch (_taraf) do { case west: {"ColorBLUFOR"}; case east: {"ColorOPFOR"}; default {"ColorIndependent"} });
    _mn setMarkerText format ["%1 (%2 m)", _kat, _yar];
    lambs_danger_hqlar pushBack [_id, _taraf, +_poz, _kat, round _yar, _mn];
    call lambs_danger_hqYayinla;
    diag_log format ["[HQ-NOKTA] %1 KURULDU / GUNCELLENDI | %2 | %3 | yaricap %4 m | atanmis squad %5", _id, _taraf, mapGridPosition _poz, round _yar, {(_x getVariable ["lambs_danger_hqId", ""]) isEqualTo _id} count allGroups];
    ["lambs_danger_garnizonYanit", [format ["%1 (%2) kuruldu: %3", _kat, _taraf, mapGridPosition _poz]]] call CBA_fnc_globalEvent;
}] call CBA_fnc_addEventHandler;
["lambs_danger_hqAtama", {
    params ["_id", "_netIdler"];
    if (!isServer) exitWith {};
    if ((lambs_danger_hqlar findIf {(_x select 0) isEqualTo _id}) < 0) exitWith { diag_log format ["[HQ-NOKTA] atama reddedildi: %1 kayitli degil", _id]; };
    private _yeni = _netIdler apply {groupFromNetId _x} select {!isNull _x};
    // bu HQ'daki eski atamalar (secilmeyenler) temizlenir; secilenler baska HQ'dan alinir
    { if ((_x getVariable ["lambs_danger_hqId", ""]) isEqualTo _id && {!(_x in _yeni)}) then { _x setVariable ["lambs_danger_hqId", nil, true]; }; } forEach allGroups;
    { _x setVariable ["lambs_danger_hqId", _id, true]; } forEach _yeni;
    call lambs_danger_hqYayinla;
    diag_log format ["[HQ-NOKTA] %1 | squad atandi: %2 grup: %3", _id, count _yeni, _yeni apply {groupId _x}];
    ["lambs_danger_garnizonYanit", [format ["%1: %2 squad atandi", _id, count _yeni]]] call CBA_fnc_globalEvent;
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
        if (!local _v) then { _rapor pushBack format ["%1: sunucuda YEREL DEGIL (sahip %2)", _ad, owner _v]; continue };
        if (!canFire _v) then { _rapor pushBack format ["%1: canFire FALSE (hasar / mermi)", _ad]; continue };
        if (_mg isEqualTo "") then { _rapor pushBack format ["%1: mermi YOK (getArtilleryAmmo bos)", _ad]; continue };
        if !(_poz inRangeOfArtillery [[_v], _mg]) then {
            private _kon = [_v, _poz, "TEST"] call (missionNamespace getVariable ["lambs_danger_fnc_topcuKonumla", {false}]);
            _rapor pushBack format ["%1: hedef %2 m'de MENZIL DISI -> %3", _ad, round (_v distance2D _poz), ["yer degistirme emri verilemedi (300 sn kilit / surucu yok)", "yer degistiriyor, 1-2 dk sonra tekrar deneyin"] select _kon];
            continue
        };
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
    {
        _x params ["_hid", "_ht", "_hp", "_hk", "_hy"];
        _liste pushBack [format ["H:%1", _hid], format ["%1 | %2 | %3 | yaricap %4 m | %5 squad atanmis", _hk, _ht, mapGridPosition _hp, _hy, {(_x getVariable ["lambs_danger_hqId", ""]) isEqualTo _hid} count allGroups], _hp];
    } forEach lambs_danger_hqlar;
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
    private _ipt = 0;
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
                // yanindaki aktif SAVUN plani (ayni taraf, yaricap x1.5 + 100 m)
                if (!isNil "lambs_danger_planlar") then {
                    {
                        private _pl = _y;
                        if ((_pl get "taraf") isEqualTo (_k select 0) && {(_pl getOrDefault ["tip", 0]) isEqualTo 1} && {((_pl get "obj") distance2D _kp) < (((_k select 2) * 1.5) + 100)} && {!((_pl getOrDefault ["faz", ""]) in ["BITTI", "IPTAL"])}) then {
                            _pl set ["faz", "IPTAL"];
                            _ipt = _ipt + 1;
                            diag_log format ["[KALDIR] karakola bagli savunma plani IPTAL: %1", _x];
                        };
                    } forEach lambs_danger_planlar;
                };
            };
        } else {
            if ((_a select [0, 2]) isEqualTo "H:") then {
                private _hid = _a select [2];
                private _hi = lambs_danger_hqlar findIf {(_x select 0) isEqualTo _hid};
                if (_hi >= 0) then {
                    deleteMarker ((lambs_danger_hqlar select _hi) select 5);
                    lambs_danger_hqlar deleteAt _hi;
                    { if ((_x getVariable ["lambs_danger_hqId", ""]) isEqualTo _hid) then { _x setVariable ["lambs_danger_hqId", nil, true]; }; } forEach allGroups;
                    call lambs_danger_hqYayinla;
                    _kal = _kal + 1;
                    diag_log format ["[KALDIR] HQ / US KALDIRILDI: %1 (atamalar temizlendi)", _hid];
                };
            };
            if ((_a select [0, 2]) isEqualTo "P:" && {!isNil "lambs_danger_planlar"}) then {
                private _id = _a select [2];
                private _pl = lambs_danger_planlar getOrDefault [_id, createHashMap];
                if (count _pl > 0 && {!((_pl getOrDefault ["faz", ""]) in ["BITTI", "IPTAL"])}) then {
                    _pl set ["faz", "IPTAL"];
                    _ipt = _ipt + 1;
                    diag_log format ["[KALDIR] plan IPTAL: %1", _id];
                };
            };
        };
    } forEach _anahtarlar;
    ["lambs_danger_garnizonYanit", [format ["Kaldirildi: %1 karakol/mevzi, %2 plan iptal", _kal, _ipt]]] call CBA_fnc_globalEvent;
}] call CBA_fnc_addEventHandler;

// v8.130: Zeus 'ELITE Karakol Garnizon' — ayar kaydi (nobet / devriye / ust kat / arac); uygulama fnc_karakolGarnizon bekcisinde
if (isNil "lambs_danger_karakolAyar") then { lambs_danger_karakolAyar = createHashMap; };
["lambs_danger_garnizonIstegi", {
    params ["_poz", "_islem", "_nobet", "_dev", "_devBoy", "_ust", "_arac"];
    if (!isServer) exitWith {};
    private _ad = lambs_danger_karakollar select {((_x select 1) distance2D _poz) <= ((_x select 2) + 150)};
    if (_ad isEqualTo []) exitWith {
        diag_log format ["[KARAKOL-GARNIZON] istek reddedildi: %1 yakininda karakol yok (once ELITE Karakol / HQ modulunu koyun)", mapGridPosition _poz];
        ["lambs_danger_garnizonYanit", ["Garnizon: yakinda karakol yok - once 'ELITE Karakol / HQ' modulu koyun (yaricap + 150 m icine)"]] call CBA_fnc_globalEvent;
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
        lambs_danger_karakolAyar set [_mn, createHashMapFromArray [["nobet", _nobet], ["devriye", _dev], ["devBoy", _devBoy], ["ustKat", _ust], ["arac", _arac], ["surum", (_eski getOrDefault ["surum", 0]) + 1]]];
        diag_log format ["[KARAKOL-GARNIZON] %1 | %2 ayar: nobet %3 | devriye %4 x %5 | ust kat %6 | arac %7 (surum %8)", _k select 0, _k select 3, _nobet, _dev, _devBoy, _ust, _arac, (_eski getOrDefault ["surum", 0]) + 1];
        ["lambs_danger_garnizonYanit", [format ["Garnizon ayari alindi: %1 | nobet %2, devriye %3 x %4, ust kat %5, arac %6 (15 sn icinde uygulanir)", _k select 3, _nobet, _dev, _devBoy, _ust, _arac]]] call CBA_fnc_globalEvent;
    };
}] call CBA_fnc_addEventHandler;
["lambs_danger_garnizonYanit", {
    params ["_m"];
    if (!hasInterface) exitWith {};
    diag_log format ["[KARAKOL-YANIT] %1", _m];
    if (!isNull (getAssignedCuratorLogic player)) then { systemChat format ["[ELITE] %1", _m]; };
}] call CBA_fnc_addEventHandler;

// ALARM bekcisi: duşman karakolun 800 m icinde savunanlarca bilinirse savunma plani kurulur
if (isServer) then {
    private _alarmFn = {
        while {true} do {
            sleep 5;
            if (missionNamespace getVariable ["lambs_danger_karakolOff", false]) then { continue };
            {
                private _k = _x;
                _k params ["_taraf", "_poz", "_yar", "_ad", "_sav", "_mn", "_tetik"];
                if (_sav isNotEqualTo 2 || {_tetik}) then { continue };
                private _sav_gr = allGroups select {(side _x) isEqualTo _taraf && {!isNull leader _x} && {((leader _x) distance2D _poz) < (_yar * 1.5)} && {!isPlayer (leader _x)}};
                if (_sav_gr isEqualTo []) then { continue };
                private _dus = (_poz nearEntities ["CAManBase", 800]) select {alive _x && {(_taraf getFriend (side _x)) < 0.6} && {(side _x) isNotEqualTo civilian}};
                private _bilinen = _dus select {private _d = _x; (_sav_gr findIf {(_x knowsAbout _d) >= 0.5}) >= 0};
                if (_bilinen isNotEqualTo []) then {
                    _k set [6, true];
                    diag_log format ["[KARAKOL] ALARM: %1 %2 | duşman %3 m icinde bilindi (%4 kisi) -> savunma plani", _taraf, _ad, round (_poz distance2D (_bilinen select 0)), count _bilinen];
                    [_taraf, _poz, createHashMapFromArray [["tip", 1], ["grupN", 8], ["grupMesafe", _yar * 1.5], ["bina", true], ["piyade", true], ["rallyM", 250], ["orpM", 150], ["basla", 0], ["tehditY", 0]]] spawn (missionNamespace getVariable ["lambs_danger_fnc_komutanPlan", {false}]);
                };
            } forEach lambs_danger_karakollar;
        };
    };
    [_alarmFn] spawn {
        params ["_fn"];
        while {true} do {
            private _h = [] spawn _fn;
            waitUntil { sleep 5; scriptDone _h };
            diag_log "[WATCHDOG-YENIDEN] karakol alarm betigi sonlandi (hata?)";
            sleep 5;
        };
    };
};

diag_log "[PLAN-KAPI] komutan plani sunucu kapisi baslatildi (v8.116)";
true
