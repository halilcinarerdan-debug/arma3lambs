#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MURETTEBAT KORUMA (v8.149) — kullanici: "apc crewi iniyor" (RPT 6c8708da / 16fa2656: Stryker komutani "komut:GET OUT" ile baslangicta aractan indi, 17 m disarida ayakta kaldi
 * -> arac "grubundan biri disarida" diye nakilden elendi, sonra sofor da yalniz kaldi).
 * Her makinede 1 sn'de bir, yerel kara araclarinda: surucu / komutan / nisanci / taret koltugundaki AI askerler KAYDEDILIR (arac degiskeni lambs_danger_murKayit = [[birim, rol, taretYolu]]).
 *   - Kayitli murettebat araca aitken "GET OUT" emri alirsa -> doStop (iptal) + log.
 *   - Kayitli murettebat disarida ise (aractan <= 60 m, yaya, saglikli / yarali, grup 20 sn temassiz, arac hareket edebilir ve hasar <= 0.6, oyuncu araca binmemis):
 *     6 sn'de bir kendi koltuguna geri doner (30 m icinde moveIn, uzakta orderGetIn). Mürettebat kaydi koltugu bossa gecerli; doluysa bir sonraki bos murettebat koltugu.
 * Atlanir: araba oyuncu icerir, arac devrik / yaniyor (canMove false veya hasar > 0.6), ELITE taşıma indirmesi (tasimaMesgul ve yolcuBirak), kapatma: lambs_danger_murKoruOff = true.
 * Log: [MURETTEBAT-KORU] (ilk inme emri / geri donus; arac basina 20 sn'de en fazla bir).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_murKoruStarted") exitWith {false};
lambs_danger_murKoruStarted = true;

diag_log "[MURETTEBAT-KORU] murettebat koruma watchdog'u baslatildi (v8.149)";

private _calis = {
    while {true} do {
        sleep 1;
        if (missionNamespace getVariable ["lambs_danger_murKoruOff", false]) then { continue };
        {
            private _v = _x;
            if (!local _v || {!canMove _v} || {(damage _v) > 0.6}) then { continue };
            if ((crew _v) findIf {isPlayer _x} >= 0) then { continue };
            private _kayit = _v getVariable [QGVAR(murKayit), []];
            // yeni murettebati kaydet
            {
                private _u = _x;
                if (!alive _u || {isPlayer _u}) then { continue };
                private _rol = assignedVehicleRole _u;
                if (_rol isEqualTo [] || {((_rol select 0) isEqualTo "Cargo") || {(_rol select 0) isEqualTo "cargo"}}) then { continue };
                if (_kayit findIf {(_x select 0) isEqualTo _u} < 0) then { _kayit pushBack [_u, _rol select 0, if (count _rol > 1) then {_rol select 1} else {[]}]; };
            } forEach (crew _v);
            _kayit = _kayit select {alive (_x select 0)};
            _v setVariable [QGVAR(murKayit), _kayit];
            if (_kayit isEqualTo []) then { continue };
            // ELITE nakil indirmesi sirasinda dokunma
            if ((_v getVariable [QGVAR(tasimaMesgul), false]) && {_v getVariable [QGVAR(yolcuBirak), false]}) then { continue };
            {
                _x params ["_u", "_rolAd"];
                private _gr = group _u;
                if ((vehicle _u) isEqualTo _v) then {
                    if ((currentCommand _u) isEqualTo "GET OUT") then {
                        doStop _u;
                        if ((time - (_v getVariable [QGVAR(murLogT), -999])) > 20) then {
                            _v setVariable [QGVAR(murLogT), time];
                            diag_log format ["[MURETTEBAT-KORU] %1 | %2 (%3) INME EMRI IPTAL | arac hizi %4 km/s | grup %5 | grup lideri aracta mi: %6", getText (configOf _v >> "displayName"), name _u, _rolAd, round speed _v, groupId _gr, (vehicle (leader _gr)) isEqualTo _v];
                        };
                    };
                } else {
                    if ((time - (_u getVariable [QGVAR(murDonT), -999])) < 6) then { continue };
                    // atama kaldirildiysa (Zeus / baska script bilerek unassign) geri cagirma
                    if !((assignedVehicle _u) isEqualTo _v) then { continue };
                    if ((_u distance2D _v) > 60 || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}) then { continue };
                    if ((time - (_gr getVariable [QGVAR(contact), -999])) < 20) then { continue };
                    _u setVariable [QGVAR(murDonT), time];
                    _u enableAI "PATH";
                    private _yakin = (_u distance2D _v) < 30;
                    switch (toLower _rolAd) do {
                        case "driver": { _u assignAsDriver _v; if (_yakin) then { _u moveInDriver _v; } else { [_u] orderGetIn true; }; };
                        case "commander": { _u assignAsCommander _v; if (_yakin) then { _u moveInCommander _v; } else { [_u] orderGetIn true; }; };
                        case "gunner": { _u assignAsGunner _v; if (_yakin) then { _u moveInGunner _v; } else { [_u] orderGetIn true; }; };
                        default { _u assignAsTurret [_v, (_x select 2)]; if (_yakin) then { _u moveInTurret [_v, (_x select 2)]; } else { [_u] orderGetIn true; }; };
                    };
                    if ((time - (_v getVariable [QGVAR(murLogT), -999])) > 20) then {
                        _v setVariable [QGVAR(murLogT), time];
                        diag_log format ["[MURETTEBAT-KORU] %1 | %2 (%3) disarida (%4 m) -> koltuguna dondu | grup %5", getText (configOf _v >> "displayName"), name _u, _rolAd, round (_u distance2D _v), groupId _gr];
                    };
                };
            } forEach _kayit;
        } forEach (vehicles select {_x isKindOf "LandVehicle" && {alive _x} && {local _x}});
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] murettebatKoru betigi sonlandi (hata?)";
        sleep 5;
    };
};

true
