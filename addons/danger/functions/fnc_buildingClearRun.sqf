#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CATISMA SONRASI CEVRE EMNIYETI + BINA TEMIZLEME — uygulama (spawn ile cagrilir).
 *
 * DOKTRIN (US Army ATP 3-21.8 / USMC MCWP 3-11.1 binada CQB: izole et -> emniyet -> gir/temizle -> topla):
 *   1) EMNIYET (izolasyon): binanin etrafinda 360 derece halka. MG ve AT DISARIDA kalir:
 *      MG tehdit yonune (ates destegi), AT arac / kanat yollarina, nisanci arkaya (gozetleme).
 *      Saglikci arkada "yarali toplama noktasi"nda. Lider (sq/tm leader) disarida KOMUTA noktasinda:
 *      kontrolu elinde tutar, kapidan ilk girmez.
 *   2) GIRIS TAKIMI (2'li, 4+ kisi varsa 2 takim): SMG / hafif (karabina) / tufekli ONCELIKLI.
 *      Bunlar yoksa / olduyse siradaki: nisanci -> AT -> MG -> takim lideri -> kisim lideri
 *      (liderler EN SON; saglikci en son yedek). Kapi onunde yigilma, oda oda ilerleme (zemin kat
 *      once, ust katlar sonra), her odada tarama, temiz isareti, cikista disaridaki halkaya katilma.
 *   3) TOPLANMA: binalar bitince 360 derece savunma (konsolidasyon), sonra gruba don (doFollow).
 *
 * v8.36 DOKTRIN (TC 3-21.76 Ranger Handbook, Battle Drill 'Enter and clear a room' s. 8-18 ... 8-21; kaynaklar_doktrin/):
 *   - KAPI YIGILMASI: giris takimi kapinin TAM ONUNDE degil (ölüm hunisi / fatal funnel, s. A-9), kapi YANINDA duvar boyunca yiginir (kapi noktasi: bina 'Door_N_trigger' bellek noktasi, yoksa bina pozisyonu).
 *   - GIRIS: ilk iki asker NEREDEYSE ESZAMANLI girer; 1. asker en az direnc yolu ile iki kosenin birine, 2. asker ZIT kosesine hakimiyet noktasina gider (bina pozisyonlarina oturtulur), odaya dönük bakar ('point of domination').
 *   - TEMIZ: oda sonunda 'CLEAR' bildirimi ([ODA] log + olay OdaTemiz); sonraki odaya giris noktasi bir onceki oda.  Bombali giris YOK (ROE / sivil riski; doktrin 'consistent with ROE and building structure').
 * ABORT (aninda temizlik): dusman < 120 m, baski >= 0.45, baska taktik (bounding / geri cekilme /
 * evade / temas kes / AT taarruz), oyuncu lider, < 3 canli piyade, kapatma anahtari
 * (lambs_danger_buildingClearOff = true), 300 sn toplam sure sinirdir.
 * Sinirlar: en fazla 3 bina, bina basina 90 sn, 70 m yaricap, bina basina 10 oda noktasi.
 *
 * Arguments:
 * 0: group <GROUP>
 *
 * Return Value:
 * Calisti mi <BOOL>
 *
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_saldiri", false, [false]], ["_hedefBina", objNull, [objNull]]];   // v8.598: SALDIRI modu (fnc_binaSaldiri): temasta, binadaki dusmana koordineli giris
if (isNull _g || {!local _g}) exitWith {false};
if (_g getVariable [QGVAR(isSweeping), false]) exitWith {false};

private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
private _token = format ["%1-%2", time, floor (random 1000000)];
private _grpAd = groupId _g;

_g setVariable [QGVAR(sweepToken), _token];
_g setVariable [QGVAR(isSweeping), true];
_g setVariable [QGVAR(isExecutingTactic), true];

private _origBeh = behaviour (leader _g);
private _t0 = time;
private _iptalSebep = "";

// ---------------------------------------------------------------------------
// YARDIMCILAR
// ---------------------------------------------------------------------------

// Abort kosullari: true -> birak (sebep _iptalSebep'e yazilir)
private _iptalMi = {
    private _sb = "";
    private _l = leader _g;
    if (isNull _g) then { _sb = "grup yok"; } else {
        if ((_g getVariable [QGVAR(sweepToken), ""]) isNotEqualTo _token) then { _sb = "baska supurme"; } else {
            if (missionNamespace getVariable ["lambs_danger_buildingClearOff", false]) then { _sb = "kapatma anahtari"; } else {
                if (isNull _l || {isPlayer _l}) then { _sb = "lider gecersiz"; } else {
                    if ((_g getVariable [QGVAR(isBounding), false]) || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isATEngage), false]}) then { _sb = "taktik basladi"; } else {
                        if ((({alive _x && {isNull objectParent _x}} count (units _g)) < 3)) then { _sb = "az asker"; } else {
                            private _en = _l findNearestEnemy _l;
                            if (!_saldiri && {!isNull _en} && {alive _en} && {(_l distance2D _en) < 120}) then { _sb = "dusman yakin"; } else {
                                if (({alive _x && {(getSuppression _x) > ([0.45, 1.2] select _saldiri)}} count (units _g)) > 0) then { _sb = "baski"; };
                            };
                        };
                    };
                };
            };
        };
    };
    if (_sb isNotEqualTo "") then { _iptalSebep = _sb; };
    _sb isNotEqualTo ""
};

// CQB silah sinifi: "SMG" | "LIGHT" (karabina / kisa) | "RIFLE"
private _cqbFn = {
    params ["_u"];
    private _w = toUpper (primaryWeapon _u);
    private _sinif = "RIFLE";
    if (_w isNotEqualTo "") then {
        if ((["SMG", "PDW", "MP5", "MP7", "MP9", "MPX", "UMP", "VECTOR", "KRISS", "PM63", "VZ61", "SCORPION", "SKORPION", "UZI", "P90", "BIZON", "PP19", "MAC10", "SHOTGUN", "M1014", "SPAS", "AA12"] findIf {(_w find _x) >= 0}) > -1) then {
            _sinif = "SMG";
        } else {
            if ((["CARBINE", "MXC", "AKS", "MK18", "CQB", "M4A1", "SHORT", "_C_"] findIf {(_w find _x) >= 0}) > -1) then {
                _sinif = "LIGHT";
            };
        };
    };
    _sinif
};

// Giris onceligi (kucuk = once girer): SMG 0 / hafif 1 / tufekli 2 / nisanci 3 / AT 4 / MG 5 / TL 6 / SL 7 / saglikci 8
private _skorFn = {
    params ["_u"];
    private _tip = toLower (typeOf _u);
    private _skor = 2;
    if (_u isEqualTo (leader _g)) then {
        _skor = 7;
    } else {
        if ((_tip find "teamleader") >= 0 || {(_tip find "_tl") >= 0} || {(_tip find "sergeant") >= 0}) then {
            _skor = 6;
        } else {
            private _r = [_u] call _rolFn;
            if (_r isEqualTo "MEDIC") then { _skor = 8; } else {
                if (_r isEqualTo "MG") then { _skor = 5; } else {
                    if (_r isEqualTo "AT") then { _skor = 4; } else {
                        if (_r isEqualTo "MARKSMAN") then { _skor = 3; } else {
                            private _c = [_u] call _cqbFn;
                            if (_c isEqualTo "SMG") then { _skor = 0; } else {
                                if (_c isEqualTo "LIGHT") then { _skor = 1; };
                            };
                        };
                    };
                };
            };
        };
    };
    _skor
};

// Halka: dis emniyet noktalari [[asker, pos, bakis acisi], ...]
// MG tehdit yonune, AT kanatlara; lider komuta noktasinda, saglikci arkada (yarali toplama)
private _halkaFn = {
    params ["_c", "_r", "_yon", "_liste"];
    private _sonuc = [];
    private _lider = leader _g;
    private _merkezKadro = _liste select {_x isEqualTo _lider || {([_x] call _rolFn) isEqualTo "MEDIC"}};
    private _halka = _liste - _merkezKadro;
    _halka = [_halka, [], {
        private _rr = [_x] call _rolFn;
        if (_rr isEqualTo "MG") then {0} else {
            if (_rr isEqualTo "AT") then {1} else {
                [3, 2] select (_rr isEqualTo "MARKSMAN")
            }
        }
    }, "ASCEND"] call BIS_fnc_sortBy;
    private _n = (count _halka) max 1;
    {
        private _aci = _yon + (_forEachIndex * (360 / _n));
        _sonuc pushBack [_x, _c getPos [_r, _aci], _aci];
    } forEach _halka;
    private _arka = _yon + 180;
    {
        private _poz = if (_x isEqualTo _lider) then { _c getPos [4, _arka + 90] } else { _c getPos [6, _arka] };
        _sonuc pushBack [_x, _poz, _arka];
    } forEach _merkezKadro;
    _sonuc
};

// Noktalari uygula (hareket komutu 6 sn'de bir, varinca cok kisa bakis)
private _postUygula = {
    params ["_postlar"];
    {
        _x params ["_u", "_pos", "_aci"];
        if (alive _u && {isNull objectParent _u}) then {
            if ((_u distance2D _pos) > 5) then {
                if (time > (_u getVariable [QGVAR(swpMoveT), 0])) then {
                    _u setVariable [QGVAR(swpMoveT), time + 6];
                    _u setBehaviour "AWARE";
                    _u setUnitPos "UP";
                    _u doMove _pos;
                };
            } else {
                _u setUnitPos "MIDDLE";
                _u doWatch (_pos getPos [80, _aci]);
            };
        };
    } forEach _postlar;
};

// Belirli sure bekle (noktalar yerine otururken); abort olursa erken cik
private _bekle = {
    params ["_sure", "_postlar"];
    private _bit = time + _sure;
    while {time < _bit} do {
        [_postlar] call _postUygula;
        if (call _iptalMi) exitWith {};
        sleep 1;
    };
};

// ---------------------------------------------------------------------------
// ANA AKIS
// ---------------------------------------------------------------------------
// v8.36: bina kapi noktasi (Door_N_trigger bellek noktasi; AGL) — yoksa []
private _kapiBul = {
    params ["_b", "_ref"];
    private _en = [];
    private _enD = 9999;
    for "_n" from 1 to 8 do {
        private _sp = _b selectionPosition [format ["Door_%1_trigger", _n], "Memory"];
        if (_sp isNotEqualTo [0, 0, 0]) then {
            private _w = _b modelToWorld _sp;
            private _d = _w distance2D _ref;
            if (_d < _enD && {((_w select 2) < 2.5)}) then { _enD = _d; _en = _w; };
        };
    };
    _en
};
// v8.36: oda kosesi (hakimiyet noktasi): giris eksenine dik +-90 derece, 2.8 m; en yakin GECERLI bina pozisyonuna oturtulur (disari tasmasin)
private _koseSec = {
    params ["_poz", "_brg", "_isaret", "_poslar"];
    private _ideal = _poz getPos [2.8, _brg + (90 * _isaret)];
    private _en = +_poz;
    private _enD = 4.5;
    {
        private _d = _x distance2D _ideal;
        if (_d < _enD && {(_x distance2D _poz) > 1.2}) then { _enD = _d; _en = _x; };
    } forEach _poslar;
    _en
};

private _govde = {
    private _lider = leader _g;
    private _merkez = getPosATL _lider;
    private _dp = _g getVariable [QGVAR(sweepDusmanPos), []];
    private _tehditYonu = if (_dp isNotEqualTo []) then { _merkez getDir _dp } else { getDir _lider };

    private _uyeler0 = (units _g) select {
        alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
        && {(lifeState _x) in ["HEALTHY", "INJURED"]}
    };

    // Yakindaki binalar (en yakin 3, en az 2 bina pozisyonu olan)
    private _adaylar = (nearestObjects [_merkez, ["House"], 70]) select {(count (_x buildingPos -1)) >= 2};
    _adaylar = [_adaylar, [], {_x distance2D _merkez}, "ASCEND"] call BIS_fnc_sortBy;
    _adaylar = _adaylar select [0, 3];
    if (_saldiri && {!isNull _hedefBina}) then { _adaylar = [_hedefBina]; };   // v8.598: saldirida yalniz dusmanin bulundugu bina

    diag_log format [
        "[BINA-TEMIZLE] %1 | BASLA%5 | asker:%2 | bina:%3 | tehdit yonu:%4",
        _grpAd, count _uyeler0, count _adaylar, round _tehditYonu, ["", " (SALDIRI: temasta binadaki dusman)"] select _saldiri
    ];

    private _sonMerkez = _merkez;
    private _temizBina = 0;

    {
        private _b = _x;
        if (call _iptalMi) exitWith {};
        if ((time - _t0) > (300 max ((missionNamespace getVariable ["lambs_danger_binaSure", 240]) * 2))) exitWith {};

        // v8.600 KARIS KARIS (kullanici: 'evin odalarini karis karis tutsunlar'): oda noktasi azami (CBA binaOdaMaks, varsayilan 24; eskiden 10), aralik 3.2 -> 2.8 m, bina suresi CBA binaSure (varsayilan 240 sn; eskiden 90)
        private _odaMaks = ((missionNamespace getVariable ["lambs_danger_binaOdaMaks", 24]) max 4) min 60;
        private _binaSure = ((missionNamespace getVariable ["lambs_danger_binaSure", 240]) max 60) min 600;
        private _bPos = getPosATL _b;
        private _yaricap = (((sizeOf (typeOf _b)) / 2) max 6) + 8;
        _sonMerkez = _bPos;

        private _uyeler = (units _g) select {
            alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
            && {(lifeState _x) in ["HEALTHY", "INJURED"]}
        };
        if ((count _uyeler) < 3) exitWith {};

        // --- oda noktalari (zemin kat once, sonra ust katlar) ---
        private _poslar = _b buildingPos -1;
        private _girisAdaylari = [_poslar select {(_x select 2) < 2.2}, [], {_x distance2D _lider}, "ASCEND"] call BIS_fnc_sortBy;
        private _giris = if (_girisAdaylari isEqualTo []) then { _poslar select 0 } else { _girisAdaylari select 0 };
        private _kapi = [_b, _lider] call _kapiBul;
        // kapi noktasi yoksa: giris bina pozisyonunun 3.5 m DISINDA (eski davranisa yakin; bina icine yigilmasin)
        // v8.600 DISARI YON (kullanici: 'kapiyi bulamiyorlar'; RPT 7f50df26: buyuk kompleks, yigilma noktalari bina MERKEZINDEN kapiya yonle hesaplaniyordu -> duvar / cit icine dusuyor, 'YURUMUYOR'): en yakin ICERI bina pozisyonundan kapiya yon (<= 8 m ise), yoksa eski
        private _ic0 = if (_kapi isEqualTo []) then {[]} else {[_poslar select {(_x select 2) < 2.5}, [], {_x distance2D _kapi}, "ASCEND"] call BIS_fnc_sortBy};
        private _disYon = if (_kapi isEqualTo []) then {_bPos getDir _giris} else { if (_ic0 isNotEqualTo [] && {((_ic0 select 0) distance2D _kapi) <= 8}) then {(_ic0 select 0) getDir _kapi} else {_bPos getDir _kapi} };
        private _kapiPos = if (_kapi isEqualTo []) then {_giris getPos [3.5, _disYon]} else {+_kapi};
        private _yigYan = ([[90, -90], "binaYigYan", [_g] call FUNC(birimId), true] call FUNC(rastgeleSec));
        private _sirali = [_poslar, [], {((round ((_x select 2) / 3)) * 1000) + (_x distance2D _giris)}, "ASCEND"] call BIS_fnc_sortBy;
        private _secilen = [];
        {
            private _p = _x;
            if ((_secilen findIf {(_x distance _p) < 2.8}) < 0) then { _secilen pushBack _p; };
            if ((count _secilen) >= _odaMaks) exitWith {};
        } forEach _sirali;

        // --- giris takimi: oncelik SMG > hafif > tufekli; yoksa siradakiler (liderler en son) ---
        private _siraliUye = [_uyeler, [], {[_x] call _skorFn}, "ASCEND"] call BIS_fnc_sortBy;
        private _birincil = _siraliUye select {([_x] call _skorFn) <= 2};
        private _icerde = [];
        if ((count _birincil) >= 2) then {
            _icerde = _birincil select [0, 4];
        } else {
            _icerde = (_siraliUye select {([_x] call _skorFn) < 8}) select [0, 2];
            if ((count _icerde) < 2) then { _icerde = _siraliUye select [0, 2]; };
        };
        if ((count _icerde) < 2) exitWith {};

        private _takimlar = if ((count _icerde) >= 4) then {
            [_icerde select [0, 2], _icerde select [2, (count _icerde) - 2]]
        } else {
            [_icerde]
        };
        private _listeler = [[], []];
        { (_listeler select (_forEachIndex % (count _takimlar))) pushBack _x; } forEach _secilen;

        // --- dis emniyet halkasi (MG / AT dahil, giriste olmayanlar) ---
        private _disarda = _uyeler - _icerde;
        private _postlar = [_bPos, _yaricap, _tehditYonu, _disarda] call _halkaFn;

        diag_log format [
            "[BINA-TEMIZLE] %1 | BINA %2 | giris:%3 (%4) | disarda:%5 | oda:%6",
            _grpAd, typeOf _b, count _icerde,
            (_icerde apply {format ["%1:%2", [_x] call _skorFn, [_x] call _cqbFn]}) joinString ",",
            count _disarda, count _secilen
        ];

        // 1) Emniyet halkasi + KAPI YANINDA yigilma (kapinin onunde degil: fatal funnel); takim 1 bir yanda, takim 2 karsi yanda, duvar boyunca dizili
        {
            private _tkY = _x;
            private _yanY = [_yigYan, -_yigYan] select (_forEachIndex % 2);
            {
                if (alive _x) then {
                    private _sp = (_kapiPos getPos [0.8 + (0.9 * _forEachIndex), _disYon]) getPos [1.3, _disYon + _yanY];
                    _x setBehaviour "COMBAT";
                    _x setUnitPos "UP";
                    _x doMove _sp;
                };
            } forEach _tkY;
        } forEach _takimlar;
        diag_log format ["[ODA] %1 | BINA %2 | kapi:%3 (%4) | yigilma yani:%5 | takim:%6", _grpAd, typeOf _b, mapGridPosition _kapiPos, ["bina pozisyonu", "Door_N_trigger"] select (_kapi isNotEqualTo []), _yigYan, count _takimlar];
        // v8.600 VARIS KONTROLU: yigilma noktasina 10 sn'de varamayan (6 m'den uzak, duruyor) giris takimi askerine kapi onune (3 m) dogrudan yeniden hareket emri
        private _vb = time + 10;
        waitUntil { sleep 1; (time > _vb) || {call _iptalMi} || {(_icerde findIf {alive _x && {(_x distance2D _kapiPos) > 6}}) < 0} };
        { if (alive _x && {(_x distance2D _kapiPos) > 6} && {(speed _x) < 1}) then { _x forceSpeed -1; _x doMove (_kapiPos getPos [3, _disYon]); diag_log format ["[ODA] %1 | %2 | yigilma noktasina varamadi (%3 m) -> kapi onune yeniden emir", _grpAd, name _x, round (_x distance2D _kapiPos)]; }; } forEach _icerde;
        [([12, 6] select _saldiri), _postlar] call _bekle;   // v8.599: saldirida yigilma bekleme 12 -> 6 sn
        // v8.599 GIRIS BOMBASI (kapi yigilmasindan sonra, kapi ONUNDE duz yayla iceri; fnc_girisBombasi)
        if (_saldiri && {!(call _iptalMi)}) then { [_g, _icerde + (_uyeler - _icerde), _b, _kapiPos, _disYon, _poslar] call FUNC(girisBombasi); };
        // v8.598 BOMBA SENKRONU (SALDIRI): yigilma sonrasi <= 6 sn patlayici izleyicisinin bombasini bekle; atildiysa ~3.5 sn (fitil) sonra gir
        if (_saldiri && {!(call _iptalMi)}) then {
            private _bk = time + 6;
            waitUntil { sleep 0.5; (time > _bk) || {(time - (_g getVariable [QGVAR(bombaGT), -999])) < 5} || {call _iptalMi} };
            private _bt = _g getVariable [QGVAR(bombaGT), -999];
            if ((time - _bt) < 5) then { sleep ((3.5 - (time - _bt)) max 0); };
        };
        if (call _iptalMi) exitWith {};

        // 2) Oda oda temizle
        private _bT0 = time;
        private _odaSayi = 0;
        private _adim = (count (_listeler select 0)) max (count (_listeler select 1));
        // v8.603 LAMBS CQB (kullanici: 'cqbyi sifirdan yazmaya gerek yok, lambs cqb tetiklensin, daha profesyonel ve olumcul'): oda temizligini LAMBS taskCQB yurutur; ELITE: kapi yigilmasi + giris bombasi (oncesi), beceri artisi + sure / dusman denetimi + oda pususu (sonrasi)
        private _lambsMi = ((missionNamespace getVariable ["lambs_danger_cqbMotor", 1]) isEqualTo 1) && {!isNil "lambs_wp_fnc_taskCQB"};
        if (_lambsMi) then { _adim = 0; };
        for "_i" from 0 to (_adim - 1) do {
            if (call _iptalMi) exitWith {};
            if ((time - _bT0) > _binaSure) exitWith {};

            private _hedefler = [];
            {
                private _tk = _x;
                private _ti = _forEachIndex;
                private _lst = _listeler select _ti;
                if (_i < (count _lst)) then {
                    private _poz = _lst select _i;
                    private _onc = if (_i == 0) then {_kapiPos} else {_lst select (_i - 1)};
                    private _brg = _onc getDir _poz;
                    // en az direnc: engelsiz (gorus hatti acik) kose 1. askere
                    private _k1 = [_poz, _brg, 1, _poslar] call _koseSec;
                    private _k2 = [_poz, _brg, -1, _poslar] call _koseSec;
                    private _o = AGLToASL (_onc vectorAdd [0, 0, 1.4]);
                    private _b1 = lineIntersects [_o, AGLToASL (_k1 vectorAdd [0, 0, 1.4]), objNull, objNull];
                    private _b2 = lineIntersects [_o, AGLToASL (_k2 vectorAdd [0, 0, 1.4]), objNull, objNull];
                    if (_b1 && {!_b2}) then { private _t = _k1; _k1 = _k2; _k2 = _t; };
                    // atamalar: 1. asker _k1, 2. asker ZIT kose _k2 (varsa 3. / 4. ayni iki koseden zit sirayla)
                    private _atama = [];
                    { _atama pushBack [_x, [_k1, _k2] select (_forEachIndex % 2), [_k2, _k1] select (_forEachIndex % 2)]; } forEach _tk;
                    _hedefler pushBack [_tk, _poz, _atama];
                };
            } forEach _takimlar;

            // ESZAMANLI GIRIS: ilk iki asker ayni anda hakimiyet noktalarina hareket (TC 3-21.76: 'enter the room almost simultaneously')
            {
                _x params ["_tk", "_poz", "_atama"];
                {
                    _x params ["_u", "_kp", "_karsi"];
                    if (alive _u) then {
                        _u setBehaviour "COMBAT";
                        _u setUnitPos "UP";
                        _u doMove _kp;
                    };
                } forEach _atama;
            } forEach _hedefler;

            private _bekBit = time + 14;
            waitUntil {
                sleep 1;
                [_postlar] call _postUygula;
                (time > _bekBit)
                || {call _iptalMi}
                || {(_hedefler findIf {
                    _x params ["_tk", "_poz", "_atama"];
                    (_atama findIf {alive (_x select 0) && {((_x select 0) distance (_x select 1)) > 2.5}}) > -1
                }) < 0}
            };
            if (call _iptalMi) exitWith {};

            // HAKIMIYET NOKTASINDA tarama: her asker ZIT koseye / oda icine donuk (stance MIDDLE); 2 sn tarama, sonra CLEAR
            {
                _x params ["_tk", "_poz", "_atama"];
                {
                    _x params ["_u", "_kp", "_karsi"];
                    if (alive _u) then {
                        _u setUnitPos "MIDDLE";
                        _u doWatch _karsi;
                    };
                } forEach _atama;
            } forEach _hedefler;
            sleep 2;
            _odaSayi = _odaSayi + 1;
            {
                _x params ["_tk", "_poz", "_atama"];
                private _canliN = {alive (_x select 0)} count _atama;
                diag_log format ["[ODA] %1 | BINA %2 | oda %3/%4 CLEAR | tim:%5 asker | z:%6 m", _grpAd, typeOf _b, _odaSayi, count _secilen, _canliN, (_poz select 2) toFixed 1];
                [_g, "OdaTemiz", _odaSayi] call FUNC(olayGonder);
            } forEach _hedefler;
        };

        if (_lambsMi && {!(call _iptalMi)}) then {
            private _olumcul = missionNamespace getVariable ["lambs_danger_cqbOlumcul", true];
            private _eskiBec = [];
            if (_olumcul) then {
                {
                    private _uu = _x;
                    _eskiBec pushBack [_uu, _uu skill "aimingAccuracy", _uu skill "aimingSpeed", _uu skill "spotDistance", _uu skill "spotTime"];
                    _uu setSkill ["aimingAccuracy", ((_uu skill "aimingAccuracy") max 0.8)];
                    _uu setSkill ["aimingSpeed", ((_uu skill "aimingSpeed") max 0.9)];
                    _uu setSkill ["spotDistance", ((_uu skill "spotDistance") max 0.9)];
                    _uu setSkill ["spotTime", ((_uu skill "spotTime") max 0.9)];
                } forEach _uyeler;
            };
            _g setCombatMode "RED";
            private _minS = (20 + ((count _secilen) * 6)) min _binaSure;
            private _lh = [_g, _bPos, ((_yaricap max 15) min 60), 8, [], false] spawn (missionNamespace getVariable "lambs_wp_fnc_taskCQB");
            diag_log format ["[BINA-TEMIZLE] %1 | BINA %2 | LAMBS CQB (taskCQB) basladi | beceri artisi:%3 | en az %4 sn, en cok %5 sn", _grpAd, typeOf _b, _olumcul, round _minS, round _binaSure];
            private _dusYok = 0;
            waitUntil {
                sleep 1;
                private _ds = (_b nearEntities ["CAManBase", 30]) select {alive _x && {((side _g) getFriend (side (group _x))) < 0.6} && {(insideBuilding _x) > 0.2}};
                _dusYok = [_dusYok + 1, 0] select (_ds isNotEqualTo []);
                ((time - _bT0) > _binaSure) || {call _iptalMi} || {scriptDone _lh} || {((time - _bT0) > _minS) && {_dusYok > 20}}
            };
            terminate _lh;
            // taskCQB dongu sonu sifirlamasi terminate ile calismaz: elle geri al (disableAI bayragi, AUTOCOMBAT / SUPPRESSION, durus, saldiri izni, beceri)
            {
                if (alive _x) then {
                    _x setVariable ["lambs_danger_disableAI", nil];
                    _x enableAI "AUTOCOMBAT";
                    _x enableAI "SUPPRESSION";
                    _x setUnitPos "AUTO";
                };
            } forEach (units _g);
            _g setVariable ["lambs_main_currentTactic", nil];
            _g enableAttack true;
            { _x params ["_uu", "_ba", "_bs", "_bd", "_bt"]; if (alive _uu) then { _uu setSkill ["aimingAccuracy", _ba]; _uu setSkill ["aimingSpeed", _bs]; _uu setSkill ["spotDistance", _bd]; _uu setSkill ["spotTime", _bt]; }; } forEach _eskiBec;
            _odaSayi = count _secilen;
            diag_log format ["[BINA-TEMIZLE] %1 | BINA %2 | LAMBS CQB bitti | %3 sn%4", _grpAd, typeOf _b, round (time - _bT0), if (call _iptalMi) then { format [" | ABORT: %1", _iptalSebep] } else { "" }];
        };
        diag_log format [
            "[BINA-TEMIZLE] %1 | BINA %2 | %3/%4 oda temiz | %5 sn%6",
            _grpAd, typeOf _b, _odaSayi, count _secilen, round (time - _bT0),
            if (call _iptalMi) then { format [" | ABORT: %1", _iptalSebep] } else { "" }
        ];
        if (call _iptalMi) exitWith {};
        _temizBina = _temizBina + 1;

        // 2b) ODA PUSUSU (v8.598; kullanici: 'odalari arastirip onlarda pusabilsinler'): giris takimindan en cok 2 asker binanin en derin (giristen uzak, ayni kat) oda noktasinda bekler (fnc_odaPusu).
        //   LAMBS Garrison / CQB gorevi / kal-bekle waypoint'li grupta atama yok (senaryoKapi sabit kapisi).
        private _pusuS = missionNamespace getVariable ["lambs_danger_binaPusu", 90];
        if (_pusuS > 0 && {!([_g, "odaPusu", true] call FUNC(senaryoKapi))}) then {
            private _derin = [_secilen select {(abs ((_x select 2) - (_giris select 2))) < 1.8}, [], {-(_x distance2D _giris)}, "ASCEND"] call BIS_fnc_sortBy;
            private _pusuUye = (_icerde select {alive _x && {_x isNotEqualTo (leader _g)} && {([_x] call _rolFn) isNotEqualTo "MEDIC"}}) select [0, 2];
            {
                private _poz = _derin param [_forEachIndex, []];
                if (_poz isNotEqualTo []) then {
                    _x setVariable [QGVAR(odaPusuBit), time + _pusuS];
                    _x setVariable [QGVAR(odaPusuPoz), _poz];
                    _x setVariable [QGVAR(odaPusuKapi), _giris getPos [3, _bPos getDir _giris]];
                    _x setVariable [QGVAR(taktikKilit), time + _pusuS];
                    diag_log format ["[ODA-PUSU] %1 | %2 | pusu noktasi giristen %3 m (z %4 m) | %5 sn", _grpAd, name _x, round (_poz distance2D _giris), (_poz select 2) toFixed 1, _pusuS];
                };
            } forEach _pusuUye;
        };

        // 3) Cikis: giris takimi disarida halkaya katilir (pusudakiler haric)
        {
            if (alive _x) then {
                _x doWatch objNull;
                _x doMove (_giris getPos [8, _bPos getDir _giris]);
            };
        } forEach (_icerde select {(_x getVariable [QGVAR(odaPusuBit), 0]) <= time});
        [8, _postlar] call _bekle;
    } forEach _adaylar;

    // --- TOPLANMA: 360 derece savunma (konsolidasyon), sonra gruba don ---
    if !(call _iptalMi) then {
        private _tum = (units _g) select {
            alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
            && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {(_x getVariable [QGVAR(odaPusuBit), 0]) <= time}
        };
        if ((count _tum) >= 2) then {
            private _pk = [_sonMerkez, 14, _tehditYonu, _tum] call _halkaFn;
            diag_log format ["[BINA-TEMIZLE] %1 | TOPLANMA | 360 savunma | %2 bina temizlendi", _grpAd, _temizBina];
            [20, _pk] call _bekle;
        };
    };
};

call _govde;

// ---------------------------------------------------------------------------
// TEMIZLIK (her zaman): bayraklar + emirler
// ---------------------------------------------------------------------------
private _iptalOldu = (_iptalSebep isNotEqualTo "");
if (!isNull _g && {(_g getVariable [QGVAR(sweepToken), ""]) isEqualTo _token}) then {
    private _baskaTaktik = (_g getVariable [QGVAR(isBounding), false])
        || {_g getVariable [QGVAR(isRetreating), false]}
        || {_g getVariable [QGVAR(isEvading), false]}
        || {_g getVariable [QGVAR(isBreakingContact), false]}
        || {_g getVariable [QGVAR(isATEngage), false]};

    _g setVariable [QGVAR(sweepToken), nil];
    _g setVariable [QGVAR(isSweeping), nil];
    _g setVariable [QGVAR(sweepCooldown), time + 120];
    if (!_baskaTaktik) then { _g setVariable [QGVAR(isExecutingTactic), nil]; };

    {
        if (alive _x && {(_x getVariable [QGVAR(odaPusuBit), 0]) <= time}) then {   // v8.598: pusudakiler (fnc_odaPusu) kendi suresinde birakilir
            _x doWatch objNull;
            _x setUnitPos "AUTO";
            _x setVariable [QGVAR(swpMoveT), nil];
            if (!_baskaTaktik && {_x isNotEqualTo (leader _g)}) then { _x doFollow (leader _g); };
        };
    } forEach (units _g);
    if (!_baskaTaktik) then {
        _g setBehaviour ([_origBeh, "COMBAT"] select (_iptalOldu));
    };

    diag_log format [
        "[BINA-TEMIZLE] %1 | TAMAM | %2 sn%3",
        _grpAd, round (time - _t0),
        if (_iptalOldu) then { format [" | ABORT: %1", _iptalSebep] } else { "" }
    ];
};

true
