#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOMUTAN ZIHNI v1 (v8.156) — kullanici: "karsida bir komutan var desin; AI oyuncunun hareketlerini ogrensin, alıskanlik edinsin, orta-hizli ogrensin, hile olmasin, SQL / kalici tablo yok".
 *
 * ADIL BILGI: AI yalnizca KENDI askerlerinin DUYDUGU / GORDUGU seyi kaydeder:
 *   - ATIS: dusman (karsi taraf) bir birim ates etti ve AI tarafinin bir askeri 450 m icinde (ses; duman atisi 300 m) -> yon / mesafe tahmini gurultulu (mesafenin %6'si), arazi tipi
 *   - DUMAN: karsi tarafin duman atmasi (ayni duyma kurali)
 *   - TEMAS: AI grubu temasa girdi (fnc_olay InContact); dusman = grubun BILDIGI en yakin dusman (findNearestEnemy)
 *   Haritada / sunucuda gercek konum SORGULANMAZ (isim: hile yok). Oyuncunun gercek konumu yalniz atis aninda, AI askeri duyabilirse kullanilir (+ gurultu).
 * HAFIZA (yalniz oturum icinde, dosya / SQL YOK): taraf basina en fazla 160 gozlem; agirlik yari omru 25 dk; en az 4 gozlem (lambs_danger_zihinHiz ile olceklenir: 1 = orta-hizli).
 * HIPOTEZLER (30 sn'de bir): YON (45 derecelik 8 sektor, pay >= %50), MENZIL bandi, DUMAN kullanimi, ARAZI tercihi (sehir / orman / acik); guven = min(1, n / (2.5 x esik)) x tutarlilik.
 * ETKI (kucuk, insanca): guven >= 0.45 iken AI tarafinin DURAN, temassiz, planda olmayan gruplari liderin bakisini beklenen yone cevirir (gözetleme) — daha fazlasi sonraki dilimlerde.
 * Her 5 dk [KOMUTAN-ZIHIN] OZET (hipotezler + gozlem sayisi) RPT'ye. Kapatma: lambs_danger_zihinOff = true. Hiz: lambs_danger_zihinHiz (1.0 varsayilan; 2 = 2 kat hizli).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_zihinStarted") exitWith {false};
lambs_danger_zihinStarted = true;

// ---- her makine: yerel birimlerin atis bildirimi (sunucuya), 6 sn / birim (duman her zaman) ----
["CAManBase", "Fired", {
    params ["_u", "_wep", "_muz", "_mode", "_ammo"];
    if (!local _u || {missionNamespace getVariable ["lambs_danger_zihinOff", false]}) exitWith {};
    private _s = side group _u;
    if (_s isEqualTo civilian) exitWith {};
    private _tip = "ATIS";
    if (((toLower (getText (configFile >> "CfgAmmo" >> _ammo >> "simulation"))) find "smoke") >= 0) then { _tip = "DUMAN"; } else {
        if (_ammo isKindOf "ShellBase") then { _tip = "TOPCU"; };
    };
    if (_tip isEqualTo "ATIS" && {(time - (_u getVariable [QGVAR(zihinT), -999])) < 6}) exitWith {};
    _u setVariable [QGVAR(zihinT), time];
    ["lambs_danger_zihinAtis", [_s, getPosATL _u, _tip, _wep]] call CBA_fnc_serverEvent;
}, true, [], true] call CBA_fnc_addClassEventHandler;

if (!isServer) exitWith {true};

diag_log "[KOMUTAN-ZIHIN] komutan zihni baslatildi (v8.156): algiya dayali gozlem + alıskanlik hipotezi, oturum hafizasi, hile yok";

lambs_danger_zihinKisilik = createHashMap; // str taraf -> TEMKINLI / DENGELI / SALDIRGAN (oturum boyunca sabit; okunabilir)
lambs_danger_zihinTavir = createHashMap;   // str taraf -> [ad, puan, zaman]
{ lambs_danger_zihinKisilik set [str _x, selectRandom ["TEMKINLI", "DENGELI", "SALDIRGAN"]]; } forEach [west, east, independent];
diag_log format ["[KOMUTAN-TAVIR] kisilikler: %1", lambs_danger_zihinKisilik toArray false];
lambs_danger_zihinKayit = createHashMap;   // str taraf -> [[t, tip, yon, mesafe, arazi, detay], ...]
lambs_danger_zihinHip = createHashMap;     // str taraf -> HashMap hipotez

private _arazi = {
    params ["_p"];
    private _bn = count (nearestTerrainObjects [_p, ["HOUSE", "BUILDING"], 40]);
    private _ag = count (nearestTerrainObjects [_p, ["TREE", "BUSH"], 40]);
    if (_bn >= 3) exitWith {"SEHIR"};
    if (_ag >= 14) exitWith {"ORMAN"};
    "ACIK"
};

private _kaydet = {
    params ["_taraf", "_rec"];
    private _k = str _taraf;
    private _l = lambs_danger_zihinKayit getOrDefault [_k, []];
    _l pushBack _rec;
    if (count _l > 160) then { _l deleteAt 0; };
    lambs_danger_zihinKayit set [_k, _l];
};
missionNamespace setVariable ["lambs_danger_zihinKaydet", _kaydet];

// ATIS / DUMAN / TOPCU: AI tarafinin duyabilecegi askerler (ses); KARSILIK: AI tarafi son 12 sn icinde bu yone ates etmisse
lambs_danger_zihinSonAtis = createHashMap;
["lambs_danger_zihinAtis", {
    params ["_s", "_pos", "_tip", "_wep"];
    if (missionNamespace getVariable ["lambs_danger_zihinOff", false]) exitWith {};
    lambs_danger_zihinSonAtis set [str _s, [time, _pos]];
    private _menzil = switch (_tip) do { case "DUMAN": {300}; case "TOPCU": {1500}; default {450} };
    private _arazi = missionNamespace getVariable ["lambs_danger_zihinArazi", {"ACIK"}];
    {
        private _T = _x;
        if (_T isEqualTo _s || {(_T getFriend _s) >= 0.6}) then { continue };
        private _dinleyen = ([_pos select 0, _pos select 1] nearEntities [["CAManBase"], _menzil]) select {alive _x && {!isPlayer _x} && {(side group _x) isEqualTo _T}};
        if (_dinleyen isEqualTo []) then { continue };
        private _d0 = _dinleyen select 0;
        private _gercek = (getPosATL _d0) distance2D _pos;
        private _dm = _gercek * (1 + (random 0.12) - 0.06);                       // gurultulu mesafe tahmini
        private _yon = ((getPosATL _d0) getDir _pos) + ((random 16) - 8);
        _yon = (_yon + 360) mod 360;
        private _kayit = missionNamespace getVariable "lambs_danger_zihinKaydet";
        [_T, [time, _tip, _yon, _dm, [_pos] call _arazi, _wep]] call _kayit;
        if (_tip isEqualTo "ATIS") then {
            // KARSILIK: bizim taraf (T) son 12 sn icinde ates ettiyse, bu atis bir karsilik mi? (taciz atisina nasil tepki verdigi)
            private _son = lambs_danger_zihinSonAtis getOrDefault [str _T, [-999, [0, 0, 0]]];
            if ((time - (_son select 0)) < 12 && {(_dinleyen select 0) distance2D (_son select 1) < 600}) then {
                [_T, [time, "KARSILIK", _yon, _dm, [_pos] call _arazi, round (time - (_son select 0))]] call _kayit;
            };
        };
    } forEach [west, east, independent];
}] call CBA_fnc_addEventHandler;

// TEMAS: AI grubunun temasa girisi (bildigi en yakin dusman)
["lambs_danger_grupOlayi", {
    params ["_g", "_ad"];
    if (_ad isNotEqualTo "InContact" || {isNull _g} || {missionNamespace getVariable ["lambs_danger_zihinOff", false]}) exitWith {};
    private _l = leader _g;
    if (isNull _l || {isPlayer _l} || {(side _g) isEqualTo civilian}) exitWith {};
    private _e = _l findNearestEnemy (getPosATL _l);
    if (isNull _e) exitWith {};
    private _arazi = missionNamespace getVariable ["lambs_danger_zihinArazi", {"ACIK"}];
    [side _g, [time, "TEMAS", (getPosATL _l) getDir (getPosATL _e), (getPosATL _l) distance2D (getPosATL _e), [getPosATL _e] call _arazi, ""]] call (missionNamespace getVariable "lambs_danger_zihinKaydet");
}] call CBA_fnc_addEventHandler;
missionNamespace setVariable ["lambs_danger_zihinArazi", _arazi];

// KAYIP: AI tarafindan bir asker oldu -> grubun O AN BILDIGI en yakin dusmana yon (katil gercek konumu degil)
["CAManBase", "Killed", {
    params ["_u"];
    if (!local _u || {isPlayer _u} || {missionNamespace getVariable ["lambs_danger_zihinOff", false]}) exitWith {};
    private _g = group _u;
    private _T = side _g;
    if (isNull _g || {_T isEqualTo civilian}) exitWith {};
    private _k = (units _g) select {alive _x};
    if (_k isEqualTo []) exitWith {};
    private _e = (_k select 0) findNearestEnemy (getPosATL _u);
    if (isNull _e) exitWith {};
    private _arazi2 = missionNamespace getVariable ["lambs_danger_zihinArazi", {"ACIK"}];
    [_T, [time, "KAYIP", (getPosATL _u) getDir (getPosATL _e), (getPosATL _u) distance2D (getPosATL _e), [getPosATL _e] call _arazi2, ""]] call (missionNamespace getVariable "lambs_danger_zihinKaydet");
}, true, [], true] call CBA_fnc_addClassEventHandler;

// ---- analiz + etki + rapor ----
private _calis = {
    private _hizSayi = missionNamespace getVariable ["lambs_danger_zihinHiz", 1];
    private _logN = 0;
    private _ozetT = time + 300;
    private _etkiT = time + 45;
    while {true} do {
        sleep 30;
        if (missionNamespace getVariable ["lambs_danger_zihinOff", false]) then { continue };
        // GORUS: AI gruplarinin BILDIGI hedefler (nearTargets: algilanan konum / tur / yas); en fazla 8 grup / tur, grup basina 25 sn'de bir
        private _ornek = 0;
        {
            private _g = _x;
            if (_ornek >= 8) exitWith {};
            private _T = side _g;
            private _l = leader _g;
            if (!local _g || {isNull _l} || {isPlayer _l} || {!alive _l} || {(time - (_g getVariable [QGVAR(zihinGorusT), -999])) < 25}) then { continue };
            // nearTargets: [konum, tur, taraf, maliyet, nesne, konum dogrulugu]; yalniz GERCEKTEN bilinen (knowsAbout > 0.5) ve konum hatasi < 80 m hedefler
            private _hedef = (_l nearTargets 800) select {((_T getFriend (_x select 2)) < 0.6) && {(_x select 5) < 80} && {(_l knowsAbout (_x select 4)) > 0.5}};
            if (_hedef isEqualTo []) then { continue };
            _g setVariable [QGVAR(zihinGorusT), time];
            _ornek = _ornek + 1;
            private _inf = 0; private _arac = 0; private _hava = 0; private _sx = 0; private _sy = 0;
            {
                private _tt = _x select 1;
                if (_tt isKindOf "CAManBase") then { _inf = _inf + 1; } else { if (_tt isKindOf "Air") then { _hava = _hava + 1; } else { _arac = _arac + 1; }; };
                _sx = _sx + ((_x select 0) select 0); _sy = _sy + ((_x select 0) select 1);
            } forEach _hedef;
            private _merk = [_sx / (count _hedef), _sy / (count _hedef), 0];
            [_T, [time, "GORUS", (getPosATL _l) getDir _merk, (getPosATL _l) distance2D _merk, [_merk] call (missionNamespace getVariable ["lambs_danger_zihinArazi", {"ACIK"}]), [_inf, _arac + _hava]]] call (missionNamespace getVariable "lambs_danger_zihinKaydet");
        } forEach (allGroups select {(side _x) in [west, east, independent]});
        private _hiz = (missionNamespace getVariable ["lambs_danger_zihinHiz", 1]) max 0.3;
        private _nMin = (round (4 / _hiz)) max 2;
        private _omur = 1500 / (_hiz max 1);
        {
            private _T = _x;
            private _l = lambs_danger_zihinKayit getOrDefault [str _T, []];
            private _gz = _l select {(time - (_x select 0)) < 2400};
            private _n = count _gz;
            if (_n < _nMin) then { continue };
            private _toplam = 0;
            private _sek = [0, 0, 0, 0, 0, 0, 0, 0];
            private _bandlar = [0, 0, 0, 0];
            private _araziS = createHashMapFromArray [["ACIK", 0], ["ORMAN", 0], ["SEHIR", 0]];
            private _duman = 0; private _topcu = 0; private _karsilik = 0; private _karGec = 0;
            private _gorusN = 0; private _gorusInf = 0; private _gorusZirh = 0;
            private _vx = 0; private _vy = 0;
            {
                _x params ["_t", "_tip", "_yon", "_m", "_ar", "_det"];
                private _w = 0.5 ^ ((time - _t) / _omur);
                switch (_tip) do {
                    case "DUMAN": { _duman = _duman + 1; };
                    case "TOPCU": { _topcu = _topcu + 1; };
                    case "KARSILIK": { _karsilik = _karsilik + 1; _karGec = _karGec + (_det max 0); };
                    case "GORUS": { _gorusN = _gorusN + 1; _gorusInf = _gorusInf + ((_det select 0)); if ((_det select 1) > 0) then { _gorusZirh = _gorusZirh + 1; }; };
                };
                if (_tip in ["DUMAN", "TOPCU", "KARSILIK"]) then { continue };
                if (_tip isEqualTo "KAYIP") then { _w = _w * 1.5; };
                _toplam = _toplam + _w;
                private _i = (round (_yon / 45)) mod 8;
                _sek set [_i, (_sek select _i) + _w];
                private _b = 3;
                if (_m < 500) then { _b = 2; };
                if (_m < 250) then { _b = 1; };
                if (_m < 100) then { _b = 0; };
                _bandlar set [_b, (_bandlar select _b) + _w];
                _araziS set [_ar, (_araziS getOrDefault [_ar, 0]) + _w];
            } forEach _gz;
            if (_toplam <= 0) then { continue };
            private _en = 0; private _enW = 0;
            { if (_x > _enW) then { _enW = _x; _en = _forEachIndex; }; } forEach _sek;
            private _pay = _enW / _toplam;
            // ortalama yon: en iyi sektor +- 1 komsu
            {
                _x params ["_t", "_tip", "_yon"];
                if (_tip in ["DUMAN", "TOPCU", "KARSILIK"]) then { continue };
                private _i = (round (_yon / 45)) mod 8;
                private _dif = abs (_i - _en);
                _dif = _dif min (8 - _dif);
                if (_dif <= 1) then { _vx = _vx + sin _yon; _vy = _vy + cos _yon; };
            } forEach _gz;
            private _yonOrt = (_vx atan2 _vy + 360) mod 360;
            private _guven = ((_n / (2.5 * _nMin)) min 1) * _pay;
            private _bandAd = ["<100 m", "100-250 m", "250-500 m", ">500 m"];
            private _bi = 0; private _bw = 0;
            { if (_x > _bw) then { _bw = _x; _bi = _forEachIndex; }; } forEach _bandlar;
            private _ar = "ACIK"; private _arw = -1;
            { if ((_araziS get _x) > _arw) then { _arw = _araziS get _x; _ar = _x; }; } forEach ["ACIK", "ORMAN", "SEHIR"];
            private _hip = createHashMapFromArray [
                ["yon", [-1, _yonOrt] select (_pay >= 0.5)], ["yonGuven", _guven], ["menzil", _bandAd select _bi], ["menzilPay", _bw / _toplam],
                ["duman", _duman >= ((_nMin / 2) max 2) && {(_duman / (_n max 1)) >= 0.1}], ["arazi", _ar], ["araziPay", _arw / _toplam], ["n", _n],
                ["sektor", _sek apply {round (_x / _toplam * 100)}], ["son", (_gz select [(_n - 5) max 0, 5]) apply {round (_x select 2)}],
                ["topcu", _topcu >= 2], ["karsilik", _karsilik >= ((_nMin / 2) max 2)], ["karsilikGec", if (_karsilik > 0) then {_karGec / _karsilik} else {0}],
                ["kuvvet", if (_gorusN > 0) then {_gorusInf / _gorusN} else {0}], ["zirh", _gorusN >= 3 && {(_gorusZirh / _gorusN) >= 0.25}]
            ];
            private _eski = lambs_danger_zihinHip getOrDefault [str _T, createHashMap];
            lambs_danger_zihinHip set [str _T, _hip];
            // ---- TAVIR MOTORU (v8.158, yalniz log + gozetleme yonu): puan = hipotez uygunlugu + kisilik + doktrin; histerezis 0.12 / 180 sn ----
            private _kis = lambs_danger_zihinKisilik getOrDefault [str _T, "DENGELI"];
            private _dk = "";
            { private _dv = _x getVariable "lambs_danger_doktrin"; if (!isNil "_dv") exitWith { _dk = _dv getOrDefault ["ad", ""]; }; } forEach (allGroups select {(side _x) isEqualTo _T});
            private _pn = [];
            private _yG = [0, _guven] select ((_hip get "yon") >= 0);
            _pn pushBack ["YON-HAZIRLIK", 0.25 + 0.6 * _yG + ([0, 0.08] select (_kis isEqualTo "TEMKINLI")), format ["beklenen yon %1 derece, guven %2", round (_hip get "yon"), _yG toFixed 2]];
            if (_hip get "karsilik" && {(_hip get "karsilikGec") < 4}) then {
                _pn pushBack ["KESIF-ATISI", 0.55 + ([0, 0.12] select (_dk isEqualTo "RUS")) + ([0, 0.08] select (_kis isEqualTo "SALDIRGAN")), format ["karsilik veriyor (gecikme %1 sn): yer acigi cikarilabilir", (_hip get "karsilikGec") toFixed 1]];
            };
            if (!(_hip get "karsilik") && {_n >= (2 * _nMin)}) then {
                _pn pushBack ["TACIZ-SABITLE", 0.5 + ([0, 0.06] select (_dk isEqualTo "ABD")) + ([0, 0.06] select (_kis isEqualTo "SALDIRGAN")), "karsilik vermiyor (disiplinli): taciz atisiyla sabitle, ana guc kanada"];
            };
            if (_hip get "zirh") then { _pn pushBack ["ZIRH-AT-HAZIR", 0.7 + ([0, 0.05] select (_kis isEqualTo "TEMKINLI")), "zirh var: AT elemanlari / engel"]; };
            if (_hip get "topcu") then { _pn pushBack ["DAGIL-SIPER", 0.65 + ([0, 0.05] select (_kis isEqualTo "TEMKINLI")), "dolayli ates var: dagil ve siperlen"]; };
            if (_hip get "duman") then { _pn pushBack ["DUMAN-IZLE", 0.45, "duman kullaniyor: perde arkasi yonu izle"]; };
            _pn pushBack ["TEDBIRLI-GOZETLE", 0.3, "belirgin alisanlik yok"];
            _pn = [_pn, [], {_x select 1}, "DESCEND"] call BIS_fnc_sortBy;
            private _enT = _pn select 0;
            private _mevcut = lambs_danger_zihinTavir getOrDefault [str _T, []];
            private _yeniTavir = true;
            if (_mevcut isNotEqualTo [] && {(time - (_mevcut select 2)) < 180}) then {
                private _mp = _pn findIf {(_x select 0) isEqualTo (_mevcut select 0)};
                if (_mp >= 0 && {(_enT select 1) < (((_pn select _mp) select 1) + 0.12)}) then { _yeniTavir = false; };
            };
            if (_yeniTavir && {(_mevcut isEqualTo []) || {(_mevcut select 0) isNotEqualTo (_enT select 0)}}) then {
                lambs_danger_zihinTavir set [str _T, [_enT select 0, _enT select 1, time]];
                diag_log format ["[KOMUTAN-TAVIR] %1 | tavir %2 (puan %3) | onceki %4 | kisilik %5 | doktrin %6 | neden: %7 | tum puanlar: %8",
                    _T, _enT select 0, (_enT select 1) toFixed 2, ["yok", _mevcut select 0] select (_mevcut isNotEqualTo []), _kis, _dk, _enT select 2, _pn apply {[_x select 0, (_x select 1) toFixed 2]}];
            };
            private _degisti = ((count _eski) isEqualTo 0)
                || {(abs ((_eski getOrDefault ["yon", -1]) - (_hip get "yon"))) > 25}
                || {(_eski getOrDefault ["menzil", ""]) isNotEqualTo (_hip get "menzil")}
                || {(_eski getOrDefault ["duman", false]) isNotEqualTo (_hip get "duman")}
                || {(_eski getOrDefault ["karsilik", false]) isNotEqualTo (_hip get "karsilik")}
                || {(_eski getOrDefault ["zirh", false]) isNotEqualTo (_hip get "zirh")}
                || {(_eski getOrDefault ["topcu", false]) isNotEqualTo (_hip get "topcu")};
            // kanit (kullanici testi: 3 kisi ayni konumdan geldi -> yon sektoru ve son gozlemler gorunsun)
            if (_degisti && {_logN < 120}) then {
                _logN = _logN + 1;
                diag_log format ["[KOMUTAN-ZIHIN] %1 (AI) KANIT | sektor yuzdeleri (K, KD, D, GD, G, GB, B, KB): %2 | son 5 gozlem yonu: %3 | yon ortalamasi %4", _T, _hip get "sektor", _hip get "son", round _yonOrt];
            };
            if (_degisti && {_logN < 80}) then {
                _logN = _logN + 1;
                diag_log format ["[KOMUTAN-ZIHIN] %1 (AI) hipotez | gozlem %2 | yon %3 (guven %4) | menzil %5 (%6%7) | duman %8 | arazi %9 (%10%11) | karsilik ates %12 | zirh %13 | topcu %14 | ort. kuvvet %15",
                    _T, _n, ["belirsiz", format ["%1 derece", round (_hip get "yon")]] select ((_hip get "yon") >= 0), _guven toFixed 2, _hip get "menzil", round ((_hip get "menzilPay") * 100), "%",
                    _hip get "duman", _hip get "arazi", round ((_hip get "araziPay") * 100), "%", _hip get "karsilik", _hip get "zirh", _hip get "topcu", (_hip get "kuvvet") toFixed 1];
            };
        } forEach [west, east, independent];

        // ETKI: duran, temassiz AI gruplari beklenen yone bakar
        if (time > _etkiT) then {
            _etkiT = time + 45;
            private _sayi = 0;
            {
                private _g = _x;
                if (_sayi >= 6) exitWith {};
                private _T = side _g;
                private _hip = lambs_danger_zihinHip getOrDefault [str _T, createHashMap];
                if ((_hip getOrDefault ["yonGuven", 0]) < 0.45 || {(_hip getOrDefault ["yon", -1]) < 0}) then { continue };
                private _l = leader _g;
                if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {!isNull objectParent _l} || {(speed _l) > 1.5}) then { continue };
                if ((time - (_g getVariable [QGVAR(contact), -999])) < 60) then { continue };
                if ((_g getVariable [QGVAR(planAktif), false]) || {(_g getVariable [QGVAR(garnizonAlt), ""]) isNotEqualTo ""} || {_g getVariable [QGVAR(tarafKapali), false]} || {_g getVariable [QGVAR(oyuncuKomutaAktif), false]}) then { continue };
                if ((time - (_g getVariable [QGVAR(zihinBakisT), -999])) < 120) then { continue };
                _g setVariable [QGVAR(zihinBakisT), time];
                _l doWatch ((getPosATL _l) getPos [250, _hip get "yon"]);
                _sayi = _sayi + 1;
                if (_logN < 80) then {
                    _logN = _logN + 1;
                    diag_log format ["[KOMUTAN-ZIHIN] %1 | %2 | gozetleme yonu %3 derece (beklenen yon hipotezi, guven %4)", groupId _g, _T, round (_hip get "yon"), (_hip get "yonGuven") toFixed 2];
                };
            } forEach (allGroups select {(side _x) in [west, east, independent]});
        };

        if (time > _ozetT) then {
            _ozetT = time + 300;
            {
                private _T = _x;
                private _n = count (lambs_danger_zihinKayit getOrDefault [str _T, []]);
                if (_n > 0) then {
                    private _hip = lambs_danger_zihinHip getOrDefault [str _T, createHashMap];
                    diag_log format ["[KOMUTAN-ZIHIN] OZET %1 (AI) | gozlem %2 | hipotez: %3", _T, _n, if ((count _hip) isEqualTo 0) then {"henuz yok (esik altinda)"} else {_hip toArray false}];
                };
            } forEach [west, east, independent];
        };
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] komutanZihin betigi sonlandi (hata?)";
        sleep 5;
    };
};

true
