#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC FFV DUZELT (v8.240) — KOK NEDEN DUZELTMESI. A/B testi (kullanici RPT eb4c3abb, RHS Stryker): yolcu FFV (personTurret) koltuguna oturunca arac surucuye verilen emri YAPMIYOR
 * (0 m, bekl.hedef DoNotPlan, motor kapanabiliyor; ELITE kapaliyken de); ayni yolcu DUZ cargo koltugundayken (1 ya da 4 yolcu) 54-56 km/s gidiyor. Ayni grup / JOIN / rutbe / yolcu AI kapali DUZELTMEDI.
 * 1 sn'de bir, YEREL kara araclarinda: ELITE nakil / recon / taksi akislarindaki (tasimaMesgul ya da reconArac bayragi; ya da lambs_danger_ffvDuzelt = true; ya da lambs_danger_ffvHepsi = true ise
 * her AI suruculu arac) araclarda, oyuncusuz, AI surucu varken FFV koltugundaki AI YOLCU (oyuncu degil) bulunursa:
 *   - bos DUZ cargo koltuk varsa: oraya tasinir (moveOut + moveInCargo [arac, indeks]),
 *   - yoksa: aractan cikarilir ve atamasi kaldirilir (unassignVehicle; arac dolu = gercek kapasite duz koltuk sayisi). Cikan birim 'lambs_danger_ffvAtilanT' ile isaretlenir.
 * Murettebat (surucu / nisanci / komutan koltuklari: rol gunner / commander, personTurret isaretli olsa da) ve surucu grubunun uyeleri dokunulmaz (v8.240b). Statik / park halindeki garnizon araclarina dokunulmaz (bayraksiz arac).
 * Kapatma: lambs_danger_ffvDuzeltOff = true.  Log: [FFV-DUZELT] (arac basina 20 sn'de en fazla bir).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_ffvDuzeltStarted") exitWith {false};
lambs_danger_ffvDuzeltStarted = true;

diag_log "[FFV-DUZELT] FFV yolcu duzeltme watchdog'u baslatildi (v8.240): AI suruculu nakil araclarinda FFV koltugundaki yolcu duz cargo koltuguna tasinir / indirilir";

private _calis = {
    while {true} do {
        sleep 1;
        if (missionNamespace getVariable ["lambs_danger_ffvDuzeltOff", false]) then { continue };
        private _hepsi = missionNamespace getVariable ["lambs_danger_ffvHepsi", false];
        {
            private _v = _x;
            if (!local _v || {!alive _v}) then { continue };
            if !(_hepsi || {_v getVariable [QGVAR(tasimaMesgul), false]} || {_v getVariable [QGVAR(reconArac), false]} || {_v getVariable [QGVAR(ffvDuzelt), false]}) then { continue };
            private _d = driver _v;
            if (isNull _d || {isPlayer _d} || {(crew _v) findIf {isPlayer _x} >= 0}) then { continue };
            // ELITE nakil inis surecinde (yolcuBirak) dokunma
            if (_v getVariable [QGVAR(yolcuBirak), false]) then { continue };
            private _kolt = fullCrew [_v, "", true];
            // YALNIZ rol 'turret' (FFV yolcu koltugu): nisanci / komutan koltuklari (rol gunner / commander) personTurret isaretli olsa da MURETTEBATTIR, dokunulmaz
            // (v8.240 ilk testinde nisanci da FFV sanilip kargoya tasindi / indirildi: koltuklar 'driver' kaldi)
            private _ffv = _kolt select { ((toLower (_x select 1)) isEqualTo "turret") && {_x param [4, false]} && {!isNull (_x select 0)} && {!isPlayer (_x select 0)} && {alive (_x select 0)} && {(group (_x select 0)) isNotEqualTo (group _d)} };
            if (_ffv isEqualTo []) then { continue };
            private _bos = (_kolt select { ((toLower (_x select 1)) isEqualTo "cargo") && {isNull (_x select 0)} }) apply { _x select 2 };
            private _tasinan = 0;
            private _atilan = 0;
            {
                private _u = _x select 0;
                if (_bos isNotEqualTo []) then {
                    private _ci = _bos deleteAt ((count _bos) - 1);
                    moveOut _u;
                    _u moveInCargo [_v, _ci];
                    _tasinan = _tasinan + 1;
                } else {
                    moveOut _u;
                    unassignVehicle _u;
                    _u setVariable [QGVAR(ffvAtilanT), time];
                    _atilan = _atilan + 1;
                };
            } forEach _ffv;
            if ((time - (_v getVariable [QGVAR(ffvLogT), -999])) > 20) then {
                _v setVariable [QGVAR(ffvLogT), time];
                diag_log format ["[FFV-DUZELT] %1 | surucu %2 | FFV'de %3 yolcu: %4 duz cargo koltuguna tasindi, %5 aractan cikarildi (duz koltuk dolu) | duz bos kalan %6", getText (configOf _v >> "displayName"), name _d, count _ffv, _tasinan, _atilan, count _bos];
            };
        } forEach (vehicles select {_x isKindOf "LandVehicle" && {alive _x} && {local _x}});
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] aracFfvDuzelt betigi sonlandi (hata?)";
        sleep 5;
    };
};

true
