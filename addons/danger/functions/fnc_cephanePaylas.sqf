#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHANE + EL BOMBASI PAYLASIMI (v8.92) — kullanici: "cephane dagitimi, el bombasi paslama, ammo bearer'in mermi paylasmasi, ozellikle buddy'ler arasinda".
 * Doktrin ilkesi (genel, kaynakli degil): catisma arasi / sonrasi 'ammunition cross-leveling' — cephanesi az olana fazla olandan dagitim; tufekci / MG dusuk cephanede oncelik; yedek taşiyici (ammo bearer) en cok cephane tasiyan.
 *
 * ALICI (4 sn'de bir, yerel gruplar, piyade, oyuncu degil, bayilmamis, forceMove / taktik kilitli degil):
 *   TUFEK / MG: ana sarjor stogu (envanter, 40mm HARIC) < 2.5 x sarjor kapasitesi   |   40MM (UGL'li): envanterde 40mm < 3
 *   EL BOMBASI: parcali bomba 0 (tufekci / hekim haric herkes)   |   DUMAN: grup lideri / MG tasiyicisinin dumani 0
 * VERICI: ayni grup, tufek / MG icin >= 5 sarjor (kendinde >= 4 kalir) ve ALICININ silahina uyumlu sarjor (compatibleMagazines); bomba icin >= 3 (en az 2 kalir).
 *   Sira: ESLE (buddy) -> en cok stoku olan (ammo bearer) -> en yakin.
 * HAREKET: <= 6 m ise hemen (1.5 sn yukleme beklemesi); sakin (temas >= 15 sn yok) ise verici alici yanina yurur (<= 40 m, 25 sn sinir), aktarimdan sonra doFollow; temasta YALNIZ <= 6 m ESLER arasi.
 * Aktarim FIZIKSEL: verici 'PutDown' animasyonuyla mermiyi / bombayi YERE birakir (GroundWeaponHolder, aliciya 1.5 m), alici GIDIP YERDEN ALIR (50 sn; alamazsa 120 sn yerde kalir). 1-2 sarjor (alicinin 0 yedegi varsa 2), en dolu sarjor; 1 bomba. ('PutDown' aksiyon adi dogrulanamadi: gecersizse animasyon oynamaz, aktarim yine yapilir.) Grupta ayni anda 1 aktarim; alici 15 sn bekleme.   Kapatma: lambs_danger_cephanePaylasOff = true.   Log: [CEPHANE] (ilk 100) + [CEPHANE-OZET] 90 sn
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_cephanePaylasStarted") exitWith {false};
lambs_danger_cephanePaylasStarted = true;

diag_log "[CEPHANE] cephane + el bombasi paylasimi watchdog'u baslatildi (v8.92)";

// ---- aktarim yurutucu: VERICI yere BIRAKIR (animasyon + yer esyasi), ALICI gidip YERDEN ALIR ----
private _aktar = {
    params ["_v", "_a", "_tur", "_sinif", "_adet", "_sebep"];
    private _t0 = time;
    private _g = group _a;
    _v setVariable [QGVAR(cephaneT), time];
    _a setVariable [QGVAR(cephaneAliciT), time];
    // v8.107: aktarim bitene kadar grup ve alici kilitli (kullanici: 7 asker yarim kalan aktarimin ustune ust uste 1-2 sarjor verdi)
    _g setVariable [QGVAR(cephaneAktif), true];
    _a setVariable [QGVAR(cephaneAliciBusy), true];
    _v setVariable [QGVAR(taktikKilit), time + 60];
    _a setVariable [QGVAR(taktikKilit), time + 60];
    // 1) verici aliciya yaklasir (en cok 6 m): sakin ise
    if ((_v distance2D _a) > 6) then {
        _v doMove (getPosATL _a);
        waitUntil { sleep 1; !alive _v || {!alive _a} || {(_v distance2D _a) <= 6} || {time > (_t0 + 25)} || {(_g getVariable [QGVAR(contact), 0]) > time && {(_v distance2D _a) > 6}} };
    };
    if (!alive _v || {!alive _a} || {(_v distance2D _a) > 8}) exitWith {
        _g setVariable [QGVAR(cephaneAktif), nil]; _a setVariable [QGVAR(cephaneAliciBusy), nil]; _a setVariable [QGVAR(cephaneAliciT), time];
        _v setVariable [QGVAR(taktikKilit), nil]; _a setVariable [QGVAR(taktikKilit), nil];
        if (alive _v) then { _v doFollow (leader _g); };
        diag_log format ["[CEPHANE] %1 | %2 -> %3 | %4 x%5 | IPTAL (ulasilamadi / temas / oldu)", groupId _g, name _v, name _a, _sinif, _adet];
    };
    // 2) verici YERE BIRAKIR (PutDown animasyonu): yer esyasi aliciya dogru 1.5 m onunde; alici GIDIP ALIR
    doStop _v;
    _v doWatch _a;
    _v playActionNow "PutDown";
    sleep 1.2;
    private _yapilan = 0;
    private _liste = [];
    if (alive _v) then {
        if (_tur isEqualTo "SARJOR") then {
            private _l = (magazinesAmmo _v) select {(toLower (_x select 0)) isEqualTo (toLower _sinif)};
            if (_l isNotEqualTo []) then {
                _l = [_l, [], {_x select 1}, "DESCEND"] call BIS_fnc_sortBy;
                for "_i" from 0 to ((_adet min (count _l)) - 1) do { _liste pushBack (_l select _i); };
                private _kalan = _l select [count _liste, count _l];
                _v removeMagazines _sinif;
                { _v addMagazine [_sinif, _x select 1]; } forEach _kalan;
            };
        } else {
            if (((magazines _v) findIf {(toLower _x) isEqualTo (toLower _sinif)}) >= 0) then {
                _v removeMagazine _sinif;
                _liste pushBack [_sinif, 1];
            };
        };
    };
    private _yerKonum = (getPosATL _v) getPos [1.5, _v getDir _a];
    private _tutucu = objNull;
    if (_liste isNotEqualTo []) then {
        _tutucu = createVehicle ["GroundWeaponHolder", _yerKonum, [], 0, "CAN_COLLIDE"];
        _tutucu setPosATL [_yerKonum select 0, _yerKonum select 1, 0];
        { _tutucu addMagazineAmmoCargo [_sinif, 1, _x select 1]; } forEach _liste;
    };
    sleep 0.8;
    if (alive _v) then { _v doFollow (leader _g); _v setVariable [QGVAR(taktikKilit), nil]; };
    // 3) alici gidip yerden alir
    if (!isNull _tutucu && {alive _a}) then {
        _a doMove (getPosATL _tutucu);
        waitUntil { sleep 0.7; !alive _a || {(_a distance2D _tutucu) <= 2} || {time > (_t0 + 50)} };
        if (alive _a && {(_a distance2D _tutucu) <= 3}) then {
            _a doWatch objNull;
            _a playActionNow "PutDown";   // yerden alma (egilme)
            sleep 1.2;
            { _a addMagazine [_sinif, _x select 1]; _yapilan = _yapilan + 1; } forEach _liste;
            deleteVehicle _tutucu;
        } else {
            // alinamadi: yerde kalir (120 sn sonra silinir; baska asker alabilir)
            [{ params ["_t"]; if (!isNull _t) then { deleteVehicle _t; }; }, [_tutucu], 120] call CBA_fnc_waitAndExecute;
        };
    };
    _a setVariable [QGVAR(taktikKilit), nil];
    _g setVariable [QGVAR(cephaneAktif), nil];
    _a setVariable [QGVAR(cephaneAliciBusy), nil];
    _a setVariable [QGVAR(cephaneAliciT), time];
    if (alive _a) then { _a doFollow (leader _g); };
    diag_log format ["[CEPHANE] %1 | %2 -> %3 | %4 x%5 (%6) | yere birakti -> aldi: %7 | %8 | %9 sn", groupId _g, name _v, name _a, _sinif, count _liste, _tur, _yapilan > 0, _sebep, round (time - _t0)];
};
missionNamespace setVariable ["lambs_danger_cephaneAktarFn", _aktar];

private _calis = {
    missionNamespace setVariable ["lambs_danger_cephaneAdim", "basladi"];
    private _aktarFn = missionNamespace getVariable "lambs_danger_cephaneAktarFn";
    private _uglFn = missionNamespace getVariable ["lambs_danger_fnc_hasUGL", {""}];
    private _mags = missionNamespace getVariable ["lambs_danger_fnc_uglMags", {[]}];
    // v8.96: RHS / mod bombalari Throw muzzle listesinde tek sinif gorunuyordu (RPT bfc418e3: parcali 1) -> sinif mermi simulasyonundan (shotGrenade / shotSmoke)
    private _frag = []; private _dumanA = [];
    {
        private _mz = _x;
        {
            private _mn = toLower _x;
            private _ammo = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
            private _sim = toLower (getText (configFile >> "CfgAmmo" >> _ammo >> "simulation"));
            private _ad = _mn + "|" + (toLower _ammo);
            private _yikim = ["charge", "satchel", "demo", "bundle", "mine", "claymore", "c4", "explosive", "tnt", "sb3kg"] findIf {(_ad find _x) >= 0} >= 0;   // v8.99: patlayici yuk / demolisyon bomba degil (RPT 9ccb4953: satchel / demo / tnt listede)
            private _isik = ["chem", "strobe", "flare", "light", "tracer", "ir_"] findIf {(_ad find _x) >= 0} >= 0;
            if (_sim isEqualTo "shotgrenade" && {!_yikim} && {(getNumber (configFile >> "CfgAmmo" >> _ammo >> "hit")) >= 5}) then { _frag pushBackUnique _mn; };
            if (_sim isEqualTo "shotsmoke" && {!_isik}) then { _dumanA pushBackUnique _mn; };
        } forEach (getArray (configFile >> "CfgWeapons" >> "Throw" >> _mz >> "magazines"));
    } forEach (("isClass _x && {isArray (_x >> 'magazines')}" configClasses (configFile >> "CfgWeapons" >> "Throw")) apply {configName _x});
    diag_log format ["[CEPHANE] bomba siniflari (mermi simulasyonundan): parcali %1 %2 | duman %3 %4", count _frag, _frag select [0, 14], count _dumanA, _dumanA select [0, 14]];
    private _say = createHashMap;
    private _ozetT = time + 90;
    private _logN = 0;
    while {true} do {
        sleep 4;
        if (missionNamespace getVariable ["lambs_danger_cephanePaylasOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            if ((time - (_g getVariable [QGVAR(cephaneGrupT), -999])) < 5) then { continue };
            if (_g getVariable [QGVAR(cephaneAktif), false]) then {
                if ((time - (_g getVariable [QGVAR(cephaneGrupT), -999])) > 90) then { _g setVariable [QGVAR(cephaneAktif), nil]; };   // yarim kalan betik kilidi 90 sn sonra acilir
                continue
            };
            missionNamespace setVariable ["lambs_danger_cephaneAdim", format ["grup %1", groupId _g]];
            private _us = (units _g) select {
                alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}
                && {!(_x getVariable ["ACE_isUnconscious", false])} && {!(_x getVariable [QGVAR(forceMove), false])} && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time}
            };
            if ((count _us) < 2) then { continue };
            // v8.105: 'temas' = GERCEK ates degisimi (son 10 sn atis ya da baski > 0.2 ya da bilinen dusman < 60 m). LAMBS contact bayragi temastan sonra uzun sure (yuzlerce sn) acik kalir;
            //   eski kosul (contact > time) yuzunden grup neredeyse hep 'temasta' sayilip yalniz <= 6 m esler paslasabiliyordu (kullanici: 2 sarjorlu M4'e arkadaslari vermedi).
            private _sit = _g getVariable [QGVAR(cmdSit), []];
            private _yakinDusman = _sit isEqualType [] && {(count _sit) >= 2} && {(time - (_sit select 0)) < 20} && {(_sit select 1) < 60};
            private _aktif = _yakinDusman || {((units _g) findIf {alive _x && {((time - (_x getVariable [QGVAR(sonAtisT), -999])) < 10) || {(getSuppression _x) > 0.2}}}) >= 0};
            if (_aktif) then { _g setVariable [QGVAR(cephaneSonTemasT), time]; };
            private _temas = _aktif;
            private _sakin = (time - (_g getVariable [QGVAR(cephaneSonTemasT), -999])) > 8;

            // stok tablosu: [birim, ana sarjor sinifi, ana sarjor sayisi, kapasite, 40mm sayisi, parcali, duman]
            private _tablo = _us apply {
                private _u = _x;
                private _w = primaryWeapon _u;
                private _gl = [_u] call _uglFn;
                private _glM = if (_gl isEqualTo "") then { [] } else { [_w, _gl] call _mags };
                private _uyum = (compatibleMagazines _w) apply {toLower _x};
                private _env = magazinesAmmo _u;
                private _ana = _env select {private _k = toLower (_x select 0); _k in _uyum && {!(_k in _glM)}};
                private _sinifA = if (_ana isEqualTo []) then { "" } else { toLower ((_ana select 0) select 0) };
                // v8.106: sarjor sayisi = TUM uyumlu (40 mm haric) sarjorler (eskiden yalniz ilk sinif: karisik izli / M855A1 yuklemelerinde verici >= 5 saglanmiyordu)
                private _sayi = count _ana;
                private _anaSn = [];
                { _anaSn pushBackUnique (toLower (_x select 0)); } forEach _ana;
                private _kap = if (_sinifA isEqualTo "") then { 30 } else { (getNumber (configFile >> "CfgMagazines" >> _sinifA >> "count")) max 1 };
                private _gl40 = if (_glM isEqualTo []) then { 99 } else { {(toLower (_x select 0)) in _glM} count _env };
                [_u, _sinifA, _sayi, _kap, _gl40, {(toLower _x) in _frag} count (magazines _u), {(toLower _x) in _dumanA} count (magazines _u), _w, _uyum, _anaSn]
            };

            // [CEPHANE-TANI]: dusuk cephaneli asker var ise (30 sn'de bir, ilk 30) durum ozeti: kac asker filtrelendi, sakin mi, verici adaylari
            private _dusukTbl = _tablo select {(_x select 2) < 3 && {(_x select 7) isNotEqualTo ""}};
            if (_dusukTbl isNotEqualTo [] && {(time - (_g getVariable [QGVAR(cephaneTaniT), -999])) > 30} && {(missionNamespace getVariable ["lambs_danger_cephaneTaniN", 0]) < 30}) then {
                _g setVariable [QGVAR(cephaneTaniT), time];
                missionNamespace setVariable ["lambs_danger_cephaneTaniN", (missionNamespace getVariable ["lambs_danger_cephaneTaniN", 0]) + 1];
                diag_log format ["[CEPHANE-TANI] %1 | dusuk cephaneli: %2 | gruptaki asker %3, tabloya girenler %4 (forceMove / taktikKilit / bayilmis elenir) | sakin:%5 aktifAtes:%6 | >= 5 sarjorlu verici adayi: %7",
                    groupId _g, _dusukTbl apply {format ["%1 (%2 sarjor, sinif %3)", name (_x select 0), _x select 2, _x select 1]},
                    count (units _g), count _us, _sakin, _aktif, {(_x select 2) >= 5} count _tablo];
            };

            private _aliciSec = [];
            {
                _x params ["_u", "_sa", "_sayi", "_kap", "_gl40", "_fr", "_dm", "_w", "_uy", "_anaSn"];
                if ((time - (_u getVariable [QGVAR(cephaneAliciT), -999])) < 15 || {_u getVariable [QGVAR(cephaneAliciBusy), false]}) then { continue };
                if (_w isNotEqualTo "" && {_sayi < 3} && {(_sayi * _kap) < (2.5 * _kap)}) then { _aliciSec pushBack [_u, "SARJOR", _sa, 1 - (_sayi / 3)]; continue };
                if (_gl40 < 3) then { _aliciSec pushBack [_u, "40MM", "", 0.8]; continue };
                if (_fr isEqualTo 0 && {!(_u getUnitTrait "medic")}) then { _aliciSec pushBack [_u, "PARCALI", "", 0.4]; continue };
                if (_dm isEqualTo 0 && {_u isEqualTo _l}) then { _aliciSec pushBack [_u, "DUMAN", "", 0.3]; continue };
            } forEach _tablo;
            if (_aliciSec isEqualTo []) then { continue };
            { _say set ["alici_" + (_x select 1), (_say getOrDefault ["alici_" + (_x select 1), 0]) + 1]; } forEach _aliciSec;
            if (_temas) then { _say set ["alici_temasta", (_say getOrDefault ["alici_temasta", 0]) + 1]; };
            _aliciSec = [_aliciSec, [], {_x select 3}, "DESCEND"] call BIS_fnc_sortBy;

            private _basladi = false;
            {
                if (_basladi) exitWith {};
                _x params ["_a", "_tur", "_sa", "_oncelik"];
                private _aTbl = _tablo select (_tablo findIf {(_x select 0) isEqualTo _a});
                private _buddy = _a getVariable [QGVAR(buddy), objNull];
                // verici adaylari
                private _aUyum = _aTbl select 8;
                private _vAd = _tablo select {
                    private _vu = _x select 0;
                    _vu isNotEqualTo _a && {(time - (_vu getVariable [QGVAR(cephaneT), -999])) > 10}
                    && {switch (_tur) do {
                        case "SARJOR": { (_x select 2) >= 5 && {((_x select 9) findIf {_x in _aUyum}) >= 0} };
                        case "40MM": { false };
                        case "PARCALI": { (_x select 5) >= 3 };
                        case "DUMAN": { (_x select 6) >= 3 };
                        default { false };
                    }}
                    && {_sakin || {(_vu distance2D _a) <= 6 && {_vu isEqualTo _buddy || {_a isEqualTo (_vu getVariable [QGVAR(buddy), objNull])}}}}
                    && {(_vu distance2D _a) <= 40}
                };
                if (_vAd isEqualTo []) then {
                    _say set ["vericiYok_" + _tur, (_say getOrDefault ["vericiYok_" + _tur, 0]) + 1];
                    if (_logN < 40 && {(time - (missionNamespace getVariable ["lambs_danger_cephaneNedenT", -999])) > 20}) then {
                        missionNamespace setVariable ["lambs_danger_cephaneNedenT", time];
                        _logN = _logN + 1;
                        diag_log format ["[CEPHANE-NEDEN] %1 | alici %2 (%3: %4 sarjor) | verici yok | sakin:%5 | grupta >= 5 sarjorlu: %6", groupId _g, name _a, _tur, _aTbl select 2, _sakin, {(_x select 2) >= 5} count _tablo];
                    };
                    continue
                };
                // sira: esi -> en cok stok -> yakin
                _vAd = _vAd apply {
                    private _vu = _x select 0;
                    [([0, 1000] select (_vu isEqualTo _buddy || {_a isEqualTo (_vu getVariable [QGVAR(buddy), objNull])})) + (_x select 2) * 10 + (_x select 5) + (_x select 6) - ((_vu distance2D _a) / 10), _x]
                };
                _vAd = [_vAd, [], {_x select 0}, "DESCEND"] call BIS_fnc_sortBy;
                private _v = ((_vAd select 0) select 1) select 0;
                private _vTbl = (_vAd select 0) select 1;
                private _sinif = switch (_tur) do {
                    case "SARJOR": {
                        // vericinin elindeki, alicinin silahina uyan sinif: alicinin kendi sinifi varsa o, yoksa vericinin en cok sarjoru olan uyumlu sinifi
                        private _vOrtak = (_vTbl select 9) select {_x in _aUyum};
                        if ((_aTbl select 1) in _vOrtak) then { _aTbl select 1 } else { _vOrtak param [0, ""] }
                    };
                    case "PARCALI": { ((magazines _v) select {(toLower _x) in _frag}) param [0, ""] };
                    case "DUMAN": { ((magazines _v) select {(toLower _x) in _dumanA}) param [0, ""] };
                    default { "" };
                };
                if (_sinif isEqualTo "") then { continue };
                // sarjor: alici 4 sarjora tamamlanir (en fazla 3), verici kendinde >= 4 birakir
                private _adet = if (_tur isEqualTo "SARJOR") then { (((4 - (_aTbl select 2)) max 1) min 3) min (((_vTbl select 2) - 4) max 1) } else { 1 };
                private _sebep = format ["alici %1 (kalan %2 sarjor / %3 parcali / %4 duman) | verici stok %5 | %6", _tur, _aTbl select 2, _aTbl select 5, _aTbl select 6, _vTbl select 2, ["buddy / en cok stok", "esi"] select (_v isEqualTo _buddy)];
                _basladi = true;
                _g setVariable [QGVAR(cephaneGrupT), time + 10];
                _say set [_tur, (_say getOrDefault [_tur, 0]) + 1];
                [_v, _a, ["BOMBA", "SARJOR"] select (_tur isEqualTo "SARJOR"), _sinif, _adet, _sebep] spawn _aktarFn;
            } forEach _aliciSec;
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!(_x getVariable ["lambs_danger_tarafKapali", false])}});
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[CEPHANE-OZET] son 90 sn aktarim baslatma: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_cephaneAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] cephane paylasimi betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_cephaneAdim", "?"]];
        sleep 5;
    };
};

true
