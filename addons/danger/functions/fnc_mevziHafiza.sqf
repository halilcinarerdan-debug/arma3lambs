#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MEVZI HAFIZASI / OGRENME (v8.529; kullanici: 'siper hafizasi basta olmak uzere cikarim yapsinlar, hafizalari oturum boyunca olussun; dusmanin ates ettigi yonleri ve ufuk noktalarini gruplar hatirlasin, ayni yerden ikinci kez gecmesin').
 *
 * NE OGRENIR (taraf basina, oturum boyunca, dosya / SQL YOK; yari omur CBA mevziYariOmur, varsayilan 30 dk):
 *   1) SIPER HAFIZASI — 'iyi': siperde (fnc_siperTut) tehdit altinda >= 15 sn hasarsiz dayanildi | 'kotu': siperdeyken vuruldu (+1) / oldu (+3) | 'maruz': siper disinda vuruldu (+0.5).
 *      Tehdit yonu 8 sektore ayrilir (yalniz asker saldirganini BILIYORSA — knowsAbout >= SEZILDI): 'bu siper kuzeyden iyi, dogudan kotu' cikarimi.
 *   2) UFUK HAFIZASI — ufuk cizgisinde (saldirganin gozunden gokyuzu karsisinda siluet) vurulan noktalar 'ufuk kotu' (fnc_ufukAlgi yer degistirmede kacinilir).
 *   3) DUSMAN ATES NOKTASI — fnc_komutanZihin'in ayni DUYMA kuralina gore (dinleyici AI <= 450 m): duyulan atis noktasi (mesafenin %6'si gurultu) hucreye eklenir; >= 2.5 sonumlu atis = TAHMIN DUSMAN MEVZISI.
 *      HILE YOK: gercek konum bilgisi yalniz atis aninda, duyabilen dusman AI varsa (gurultulu); gizli birim hafizaya girmez.
 * NEREDE KULLANILIR (fnc_mevziPuan): main fnc_findCover (siper puani: bounding / DEFEND / OVERWATCH), fnc_acikSiper (aday maliyeti), fnc_ufukAlgi (yer degistirme). Kotu hucreler / tahmini dusman mevzisine acik siperler elenir,
 *   iyi calisan siperler tercih edilir = 'ayni yerden ikinci kez gecmez' (BOUNDING sicramasi ve siper secimi dolayisiyla). SINIR: waypoint rotasi yeniden cizilmez (tasarimci yolu); hafiza siper / hop secimini etkiler.
 * Olaylar tek yoldan: lambs_danger_mevziKayit (CBA globalEvent) -> her makine kendi hafizasina yazar (HC dahil ayni hafiza).
 * Kapatma: CBA lambs_danger_mevziHafiza = false.  Log: [MEVZI-OGREN] (ilk 40) + [MEVZI-OZET] 120 sn (sunucu).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_mevziHafizaStarted") exitWith {false};
lambs_danger_mevziHafizaStarted = true;
diag_log "[MEVZI-HAFIZA] siper / ufuk / dusman atis noktasi hafizasi baslatildi (v8.529): oturum boyunca, taraf basina, yari omur 30 dk";

private _yay = {
    params ["_s", "_tur", "_pos", ["_sek", -1], ["_w", 1]];
    ["lambs_danger_mevziKayit", [_s, _tur, _pos, _sek, _w]] call CBA_fnc_globalEvent;
};

// kayit olayi: her makine kendi hafizasina yazar
["lambs_danger_mevziKayit", {
    params ["_s", "_tur", "_pos", "_sek", "_w"];
    [_s, _tur, _pos, _sek, _w] call FUNC(mevziYaz);
    if (_tur isNotEqualTo "ates" && {(missionNamespace getVariable ["lambs_danger_mevziLogN", 0]) < 40}) then {
        missionNamespace setVariable ["lambs_danger_mevziLogN", (missionNamespace getVariable ["lambs_danger_mevziLogN", 0]) + 1];
        diag_log format ["[MEVZI-OGREN] %1 | %2 | hucre %3,%4 | sektor %5 | agirlik %6", _s, _tur, floor ((_pos select 0) / 40), floor ((_pos select 1) / 40), _sek, _w];
    };
}] call CBA_fnc_addEventHandler;

// yardimci: saldirgan yonu sektoru (yalniz asker saldirganini biliyorsa)
private _sektor = {
    params ["_u", "_k"];
    if (isNull _k) exitWith {-1};
    if ((_u knowsAbout _k) < (["SEZILDI"] call FUNC(bilgiEsik))) exitWith {-1};
    floor ((((_u getDir _k) + 22.5) mod 360) / 45)
};

// --- VURULDU (yerel AI) ---
["CAManBase", "Hit", {
    params ["_u", "_src", "_dmg", "_ins"];
    if (!local _u || {isPlayer _u} || {!(missionNamespace getVariable ["lambs_danger_mevziHafiza", true])}) exitWith {};
    private _s = side group _u;
    if (_s isEqualTo civilian || {time < (_u getVariable [QGVAR(mevziHitT), 0])} || {_dmg < 0.03}) exitWith {};
    _u setVariable [QGVAR(mevziHitT), time + 3];
    private _k = [_src, _ins] select (!isNull _ins);
    if (isNull _k || {(side group _k) isEqualTo _s} || {(_s getFriend (side group _k)) >= 0.6}) exitWith {};
    private _sek = -1;
    if ((_u knowsAbout _k) >= (["SEZILDI"] call FUNC(bilgiEsik))) then { _sek = floor ((((_u getDir _k) + 22.5) mod 360) / 45); };
    private _poz = getPosATL _u;
    private _hedef = _u getVariable [QGVAR(acikSiperHedef), [[], -999, ""]];
    private _sipDe = ((_u getVariable [QGVAR(siperTutBit), 0]) > time) || {(time - (_hedef select 1)) < 40};
    if (_sipDe) then {
        ["lambs_danger_mevziKayit", [_s, "kotu", _poz, _sek, 1]] call CBA_fnc_globalEvent;
    } else {
        ["lambs_danger_mevziKayit", [_s, "maruz", _poz, _sek, 0.5]] call CBA_fnc_globalEvent;
    };
    private _h = [1.7, 1.0, 0.4] select ((["STAND", "CROUCH", "PRONE"] find (stance _u)) max 0);
    private _ufukFn = missionNamespace getVariable ["lambs_danger_fnc_ufukMu", {false}];
    if ([eyePos _k, _poz, _h] call _ufukFn) then {
        ["lambs_danger_mevziKayit", [_s, "ufuk", _poz, _sek, 1]] call CBA_fnc_globalEvent;
    };
}, true, [], true] call CBA_fnc_addClassEventHandler;

// --- OLDU (yerel AI): siperdeki / acikta olum = guclu 'kotu' ---
["CAManBase", "Killed", {
    params ["_u", "_killer", "_ins"];
    if (!local _u || {isPlayer _u} || {!(missionNamespace getVariable ["lambs_danger_mevziHafiza", true])}) exitWith {};
    private _s = side group _u;
    if (_s isEqualTo civilian) exitWith {};
    private _k = [_killer, _ins] select (!isNull _ins);
    if (isNull _k || {(side group _k) isEqualTo _s} || {(_s getFriend (side group _k)) >= 0.6}) exitWith {};
    private _sek = -1;
    if (((group _u) knowsAbout _k) >= (["SEZILDI"] call FUNC(bilgiEsik))) then { _sek = floor ((((_u getDir _k) + 22.5) mod 360) / 45); };
    ["lambs_danger_mevziKayit", [_s, "kotu", getPosATL _u, _sek, 3]] call CBA_fnc_globalEvent;
}, true, [], true] call CBA_fnc_addClassEventHandler;

// --- SUNUCU: duyulan dusman atis noktasi (komutanZihin'in ayni 'zihinAtis' olayi; duyma menzili 450 m) ---
if (isServer) then {
    ["lambs_danger_zihinAtis", {
        params ["_s", "_pos", "_tip"];
        if (_tip isNotEqualTo "ATIS" || {!(missionNamespace getVariable ["lambs_danger_mevziHafiza", true])}) exitWith {};
        private _dedupe = missionNamespace getVariable ["lambs_danger_mevziAtesT", createHashMap];
        missionNamespace setVariable ["lambs_danger_mevziAtesT", _dedupe];
        {
            private _s2 = _x;
            if (_s2 isNotEqualTo _s && {(_s2 getFriend _s) < 0.6}) then {
                private _dd = 1e9;
                { if (alive _x && {(side group _x) isEqualTo _s2} && {!isPlayer _x}) then { _dd = _dd min (_x distance2D _pos); }; } forEach (_pos nearEntities ["CAManBase", 450]);
                if (_dd <= 450) then {
                    private _an = format ["%1|%2|%3", _s2, floor ((_pos select 0) / 40), floor ((_pos select 1) / 40)];
                    if (time >= (_dedupe getOrDefault [_an, 0])) then {
                        _dedupe set [_an, time + 4];
                        private _p2 = _pos getPos [random (_dd * 0.06), random 360];
                        ["lambs_danger_mevziKayit", [_s2, "ates", _p2, -1, 1]] call CBA_fnc_globalEvent;
                    };
                };
            };
        } forEach [west, east, resistance];
    }] call CBA_fnc_addEventHandler;
};

// --- 3 sn: siperde dayanan asker = 'iyi' (>= 15 sn, hasarsiz, grup temasta) ---
[] spawn {
    private _ozetT = time + 120;
    while {true} do {
        sleep 3;
        if (missionNamespace getVariable ["lambs_danger_mevziHafiza", true]) then {
            {
                private _u = _x;
                if (local _u && {alive _u} && {!isPlayer _u} && {(_u getVariable [QGVAR(siperTutBit), 0]) > time} && {((group _u) getVariable [QGVAR(contact), 0]) > (time - 10)}) then {
                    private _iz = _u getVariable [QGVAR(mevziIz), []];   // [baslangic zamani, hasar0, pozisyon]
                    if (_iz isEqualTo [] || {(_u distance2D (_iz select 2)) > 6}) then {
                        _u setVariable [QGVAR(mevziIz), [time, damage _u, getPosATL _u]];
                    } else {
                        if ((damage _u) > ((_iz select 1) + 0.02)) then {
                            _u setVariable [QGVAR(mevziIz), []];
                        } else {
                            if ((time - (_iz select 0)) >= 15 && {time >= (_u getVariable [QGVAR(mevziIyiT), 0])}) then {
                                _u setVariable [QGVAR(mevziIyiT), time + 40];
                                private _en = _u findNearestEnemy _u;
                                private _sek = -1;
                                if (!isNull _en && {(_u knowsAbout _en) >= (["SEZILDI"] call FUNC(bilgiEsik))}) then { _sek = floor ((((_u getDir _en) + 22.5) mod 360) / 45); };
                                ["lambs_danger_mevziKayit", [side group _u, "iyi", getPosATL _u, _sek, 1]] call CBA_fnc_globalEvent;
                            };
                        };
                    };
                };
            } forEach allUnits;
        };
        if (isServer && {time > _ozetT}) then {
            _ozetT = time + 120;
            private _h = missionNamespace getVariable ["lambs_danger_mevziH", createHashMap];
            private _a = missionNamespace getVariable ["lambs_danger_mevziAtes", createHashMap];
            if ((count _h) > 0 || {(count _a) > 0}) then {
                private _ozet = [];
                {
                    private _sk = _x;
                    private _m = _h getOrDefault [_sk, createHashMap];
                    private _hucre = (keys _m) select {(count (_x splitString "|")) isEqualTo 2};
                    private _kotu = _hucre select {(((_m get _x) select 1) >= 1)};
                    private _iyi = _hucre select {(((_m get _x) select 0) >= 1)};
                    private _am = _a getOrDefault [_sk, createHashMap];
                    private _kume = (keys _am) select {((_am get _x) select 0) >= 2.5};
                    _ozet pushBack format ["%1: hucre %2 | kotu %3 | iyi %4 | tahmini dusman mevzisi %5", _sk, count _hucre, count _kotu, count _iyi, count _kume];
                } forEach (keys _h + (keys _a select {!(_x in (keys _h))}));
                diag_log format ["[MEVZI-OZET] %1", _ozet joinString " || "];
            };
        };
    };
};
true
