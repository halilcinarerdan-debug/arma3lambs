#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * IED FARKINDALIGI (v8.47, v8.50: ACE EOD entegrasyonu)
 *
 * Doktrin (MCWP 3-11.1 "IED or possible IED" drill): durma, bolgeyi tarama, supheli noktayi gozetleme, dagilma; molalarda IED taramasi.
 * Sayisal degerler yoktur (TASARIM):
 *   - TESPIT: lider grubun askerlerinden birinin <= 35 m'sinde (mayin dedektoru / explosiveSpecialist <= 50 m) ve gorus hatti acik supheli nesne
 *     (allMines + sinif adinda "ied" gecen nesneler, mod IED'leri dahil) -> taraf icin revealMine (AI yol planlamasi bunu otomatik atlar).
 *   - TEPKI: 50 m yaricapta askerler IED'den uzaklasir (55 m'ye), yatarak degil ortu / dagilma; grup 60 sn LIMITED hizda, AWARE.
 *   - IMHA: grupta explosiveSpecialist varsa ve temas YOKSA, vanilla mayinda (MineBase) 3 m'ye gidip "Deactivate" dener (45 sn zaman asimi).
 *     Uzaktan tetikli / mod IED'lerinde imha denenmez, yalnizca kacinilir.
 *   - Cooldown: ayni IED icin grup basina 5 dk. ATLANIR: oyuncu lider, arac, retreat / evade / breakContact.
 *   - v8.50: EOD = explosiveSpecialist ozelligi VEYA ACE_isEOD degiskeni (ACE: ace_common_fnc_isEOD ile ayni kosul). EOD / mayin dedektorlu asker
 *     erken tespit eder (90 m, gorus hatti kosulsuz 50 m'ye kadar); diger askerler 60 m (25 m icinde gorus hatti aranmaz).
 *     EOD varsa, imha kiti (ACE_DefusalKit veya ToolKit) tasiyorsa ve temas yoksa HER tur IED'e (vanilla mayin + mod / ACE IED) gidip diz coker, ~8 sn calisip etkisizlestirir (ACE yuklu ise ACE EOD sureci simule edilir).
 *     Digerleri 55 m'ye acilir; bounding / taktik kilidi olan askerler dahil (IED tehlikesi kilidi gecer), 60 sn boyunca 4 sn'de bir geri itilir.
 *     EOD yoksa ya da EOD'da imha kiti yoksa grup yalnizca kacinir (imha denenmez; EOD yine erken tespit eder).
 * Kapatma: lambs_danger_iedOff = true.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_iedFarkStarted") exitWith {false};
lambs_danger_iedFarkStarted = true;

diag_log "[IED-FARK] IED farkindaligi watchdog baslatildi";

[] spawn {
    private _logN = 0;
    while {true} do {
        sleep 4;
        if (missionNamespace getVariable ["lambs_danger_iedOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
            ) then { continue };
            private _lp = getPosATL _l;
            // v8.50c: tarama merkezi yalniz lider degil, EOD / dedektorlu askerler de (EOD liderden uzaklasinca ikinci IED 4 m'de fark ediliyordu)
            private _merkezler = [_lp] + ((units _g) select {alive _x && {isNull objectParent _x} && {(_x getUnitTrait "explosiveSpecialist") || {_x getVariable ["ACE_isEOD", false]} || {"MineDetector" in (items _x)}}} apply {getPosATL _x});
            private _adaylar = [];
            {
                private _c = _x;
                {
                    if !(_x in _adaylar) then { _adaylar pushBack _x };
                } forEach ((allMines select {(_x distance2D _c) < 130}) + ((_c nearObjects 130) select {(toLower (typeOf _x)) find "ied" >= 0 && {!(_x in allMines)}}));
            } forEach _merkezler;
            if (_adaylar isEqualTo []) then { continue };
            private _bilinen = _g getVariable [QGVAR(iedBilinen), []];
            private _us = (units _g) select {alive _x && {isNull objectParent _x}};
            {
                private _m = _x;
                private _mp = getPosATL _m;
                if ((_bilinen findIf {(_x select 0) distance2D _mp < 3 && {(time - (_x select 1)) < 300}}) >= 0) then { continue };
                private _tespit = objNull;
                {
                    private _u = _x;
                    private _eodU = (_u getUnitTrait "explosiveSpecialist") || {_u getVariable ["ACE_isEOD", false]};
                    private _menzil = [60, 90] select (_eodU || {"MineDetector" in (items _u)});
                    private _d = _u distance2D _m;
                    if (_d <= _menzil) then {
                        private _e = eyePos _u;
                        private _t = (getPosASL _m) vectorAdd [0, 0, 0.2];
                        // yakinda (25 m) herkes gorur; EOD 50 m'ye kadar gorus hatti aramaz; digerleri icin acik gorus sart
                        if (_d <= ([25, 50] select _eodU) || {!(lineIntersects [_e, _t, _u, _m]) && {!(terrainIntersectASL [_e, _t])}}) exitWith { _tespit = _u; };
                    };
                } forEach _us;
                if (isNull _tespit) then { continue };

                _bilinen pushBack [_mp, time];
                _g setVariable [QGVAR(iedBilinen), _bilinen];
                (side _g) revealMine _m;

                // EOD secimi: explosiveSpecialist ozelligi veya ACE_isEOD (IED'e en yakin)
                private _eodlar = _us select {(_x getUnitTrait "explosiveSpecialist") || {_x getVariable ["ACE_isEOD", false]}};
                _eodlar = _eodlar apply {[_x distance2D _m, _x]};
                _eodlar sort true;
                private _eodU = if (_eodlar isEqualTo []) then {objNull} else {(_eodlar select 0) select 1};
                // imha icin imha kiti sart: ACE_DefusalKit (ACE) veya ToolKit (vanilla); kitli EOD'lar arasindan en yakini
                private _kitli = _eodlar select {private _it = items (_x select 1); ("ACE_DefusalKit" in _it) || {"ToolKit" in _it}};
                private _imhaU = if (_kitli isEqualTo []) then {objNull} else {(_kitli select 0) select 1};
                private _temas = (_g getVariable [QGVAR(contact), 0]) > time;
                private _sinif = toLower (typeOf _m);
                // tehlike yaricapi: buyuk IED 55 m, digerleri 30 m
                private _yaricap = [30, 55] select ((_sinif find "big") >= 0);
                // ikincil cihaz suphesi: hedefin 40 m cevresinde baska IED adayi var mi (IED'ler kumelenir); yakinlik tetikli (range / pressure) tiplere EOD yurumez
                private _ikincil = (_adaylar select {!(_x isEqualTo _m) && {(_x distance2D _m) < 40}}) isNotEqualTo [];
                private _yakinlik = ((_sinif find "range") >= 0) || {(_sinif find "pressure") >= 0} || {(_sinif find "tripwire") >= 0};
                private _imhaMi = !isNull _imhaU && {!_temas} && {!_ikincil} && {!_yakinlik} && {(_imhaU distance2D _m) < 110} && {(time - (_g getVariable [QGVAR(iedImhaT), -999])) > 100};
                if (_imhaMi) then { _eodU = _imhaU; _g setVariable [QGVAR(iedImhaT), time]; };
                // yeni IED bulundu: devam eden imha varsa (ikincil cihaz) iptal et, EOD de geri cekilir
                _g setVariable [QGVAR(iedAbort), time];

                // uzaklasma (yaricap + 8 m); EOD imha edecekse kalir. Taktik kilidi (bounding vb.) IED tehlikesinde gecilir.
                // TEMASTA: yaricap icindekiler yere yatar, surunerek uzaklasir (parca etkisi azalir); disindakiler siperde ates etmeye devam eder, IED'e dogru yurumez
                private _uzaklasan = 0;
                {
                    if ((_x distance2D _m) < _yaricap && {!(_imhaMi && {_x isEqualTo _eodU})}) then {
                        _x setVariable [QGVAR(taktikKilit), nil];
                        if (_temas) then {
                            _x setUnitPos "DOWN";
                            [{ params ["_uu"]; if (alive _uu) then { _uu setUnitPos "AUTO"; }; }, [_x], 14] call CBA_fnc_waitAndExecute;
                        };
                        private _yon = _mp getDir _x;
                        _x doMove (_mp getPos [_yaricap + 8 + (random 6), _yon + (random 40) - 20]);
                        _uzaklasan = _uzaklasan + 1;
                    };
                } forEach _us;
                if (!_temas) then {
                    _g setBehaviour "AWARE";
                    _g setSpeedMode "LIMITED";
                    [{ params ["_gg"]; if (!isNull _gg && {!(_gg getVariable [QGVAR(isExecutingTactic), false])}) then { _gg setSpeedMode "NORMAL"; }; }, [_g], 60] call CBA_fnc_waitAndExecute;
                };

                // bekletme: bounding / formasyon komutlari geri cevirmesin, 60 sn'de 4 sn'de bir 50 m icindekileri geri it
                [_g, _m, _mp, _eodU, _imhaMi, _yaricap] spawn {
                    params ["_grp", "_mine", "_pos", "_eod", "_imhaVar", "_yar"];
                    private _t0 = time;
                    while {(time - _t0) < 60 && {!isNull _grp} && {_grp getVariable [QGVAR(iedPos), _pos] isEqualTo _pos}} do {
                        sleep 4;
                        if (isNull _mine && {!_imhaVar}) exitWith {};
                        {
                            if (alive _x && {(_x distance2D _pos) < (_yar - 2)} && {!(_imhaVar && {_x isEqualTo _eod})} && {isNull objectParent _x}) then {
                                _x doMove (_pos getPos [_yar + 8 + (random 6), _pos getDir _x]);
                            };
                        } forEach (units _grp);
                    };
                };
                _g setVariable [QGVAR(iedPos), _mp];

                // imha: EOD varsa ve temas yoksa (vanilla mayin + ACE / mod IED); EOD yoksa yalniz kacinilir
                private _imha = "yok(EOD yok)";
                if (!isNull _eodU && {isNull _imhaU}) then { _imha = "yok(imha kiti yok: ACE_DefusalKit / ToolKit)"; };
                if (_temas && {!isNull _imhaU}) then { _imha = "yok(temas var: yere yat + uzaklas)"; };
                if (!_temas && {!isNull _imhaU} && {_ikincil}) then { _imha = "yok(ikincil cihaz suphesi: 40 m cevrede baska IED)"; };
                if (!_temas && {!isNull _imhaU} && {_yakinlik}) then { _imha = "yok(yakinlik tetikli IED: EOD yurumez)"; };
                if (_imhaMi) then {
                    _imha = "deneniyor";
                    [_eodU, _m, _g, typeOf _m, _yaricap] spawn {
                        params ["_u", "_mine", "_grp", "_mineTip", "_yariC"];
                        private _t0 = time;
                        private _ab = _grp getVariable [QGVAR(iedAbort), 0];
                        waitUntil {
                            sleep 1;
                            _u doMove (getPosATL _mine);
                            isNull _mine || {!alive _u} || {(_u distance2D _mine) < 4} || {(time - _t0) > 90} || {(_grp getVariable [QGVAR(contact), 0]) > time} || {(_grp getVariable [QGVAR(iedAbort), 0]) > _ab}
                        };
                        if (isNull _mine || {!alive _u} || {(_u distance2D _mine) >= 5.5}) exitWith {
                            private _sn = if ((_grp getVariable [QGVAR(iedAbort), 0]) > _ab) then {"ikincil cihaz / yeni IED"} else {if (isNull _mine) then {"IED yok (patladi / silindi)"} else {"sure / temas / olu"}};
                            diag_log format ["[IED-FARK] %1 | imha YARIM KALDI (%3) | %2", name _u, _mineTip, _sn];
                            // iptal / temas: EOD da IED'den yaricap disina cekilir
                            if (alive _u && {!isNull _mine}) then { _u doMove ((getPosATL _mine) getPos [_yariC + 8, (getPosATL _mine) getDir _u]); };
                        };
                        // calisma: dur, diz coker, IED'e bak (ACE EOD sureci ~8 sn simule edilir)
                        _u doWatch _mine;
                        _u setUnitPos "MIDDLE";
                        private _bitti = false;
                        private _t1 = time;
                        waitUntil {
                            sleep 1;
                            (time - _t1) > 8 || {!alive _u} || {isNull _mine} || {(_grp getVariable [QGVAR(contact), 0]) > time} || {(_grp getVariable [QGVAR(iedAbort), 0]) > _ab} || {(_u distance2D _mine) > 5}
                        };
                        if (alive _u && {!isNull _mine} && {(_u distance2D _mine) <= 5} && {(_grp getVariable [QGVAR(contact), 0]) <= time}) then {
                            if (_mine isKindOf "MineBase") then { _u action ["Deactivate", _u, _mine]; sleep 1; };
                            if (!isNull _mine) then { deleteVehicle _mine; };
                            _bitti = true;
                        };
                        _u doWatch objNull;
                        _u setUnitPos "AUTO";
                        diag_log format ["[IED-FARK] %1 | imha %2 | %3 | ACE:%4 | kit:%5", name _u, ["BASARISIZ", "TAMAM"] select _bitti, _mineTip, !isNil "ace_explosives_fnc_defuseExplosive", "ACE_DefusalKit" in (items _u)];
                    };
                };
                if (_logN < 100) then {
                    _logN = _logN + 1;
                    diag_log format ["[IED-FARK] %1 | %2 | lider %3 m | tespit:%4 (%7 m) | uzaklasan:%5 (yaricap %8 m, temas:%9) | imha:%6", groupId _g, typeOf _m, round (_lp distance2D _m), name _tespit, _uzaklasan, _imha, round (_tespit distance2D _m), _yaricap, _temas];
                    if (!isNull _eodU) then { diag_log format ["[IED-FARK] %1 | EOD:%2 (explosiveSpecialist:%3 ACE_isEOD:%4)", groupId _g, name _eodU, _eodU getUnitTrait "explosiveSpecialist", _eodU getVariable ["ACE_isEOD", false]]; };
                };
            } forEach _adaylar;
        } forEach (allGroups select {local _x && {!isNull leader _x}});
    };
};

true
