#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KORKU / YAKIN MERMI TEPKISI (v8.835; kullanici: 'elemanlar olmekten korksun', 'olmemek icin ayik ve zeki olsunlar', 'supresyon var degil mi' -> 'yap'): RPT 5057c18e / 8dd900cd: grup baskisi en cok 0.25 (93 + 89 telemetri) -> baski esikli korku davranislari uykudaydi (dusman nadiren yakindan ates ediyor).
 * MEKANIK: yerel AI askere dusman mermisi YAKINDAN gectiginde ('FiredNear', korkuM m icinde, yalniz mermi): korku degeri artar (<= 5 m +0.35, <= 12 m +0.20, <= korkuM +0.08; 6 sn'lik ussel azalma; fnc_korkuDeger) ve:
 *   (1) GRUP UYARISI: grup temas bayragi (+12 sn) ve ates edene reveal 1.5 (3 sn'de bir) = 'ayik': kim nereden ates ediyor biliniyor;
 *   (2) ALCALMA (korku >= 0.25): hareketsiz (hiz < 2) ve ayaktaysa COMEL (korku >= 0.55: YAT), korkuSure sn (sonra AUTO; siper duruşu tutuluyorsa dokunulmaz) - yalniz kosucu / retreat / temas kes / hekim / bina ici / oyuncu komutasi DEGILSE;
 *   (3) SIPER ARAMA (korku >= 0.5, CBA korkuSiper): fnc_acikSiper (10 sn'de bir; fonksiyonun kendi kapilari gecerli);
 *   (4) fnc_baskiEf: motor baskisi yetmezse korku (x0.7) siper duruşu / panik gerilimi / moral hesabinda baskinin yerine gecer.
 * Panik DEGIL: ozguven / panicChance'e dokunulmaz ('ayik': donmaz, sadece alcalir / siper arar / bilir).
 *   (4) v8.845 EGITIMSIZLIK: CBA egitimsizlik > 0 ise egitimsiz asker olasilikla SABITLENIR (3-6 sn yatar, karsilik ates yok).
 * CBA: lambs_danger_korku (acik), korkuM (25 m), korkuSure (4 sn), korkuSiper (acik), egitimsizlik (0). Log: [KORKU] (ilk 20, sonra 30 sn'de bir) + 60 sn [KORKU-OZET].
 * Arguments: None | Return Value: Baslatildi mi <BOOL> | Public: No
*/
if (!isNil "lambs_danger_korkuStarted") exitWith {false};
lambs_danger_korkuStarted = true;
diag_log "[KORKU] yakin mermi korkusu (FiredNear) baslatildi (v8.835)";
lambs_danger_korkuSay = createHashMap;
[] spawn {
    while {true} do {
        sleep 60;
        private _s = lambs_danger_korkuSay;
        if (count _s > 0) then {
            diag_log format ["[KORKU-OZET] 60 sn: %1", (keys _s) apply { format ["%1=%2", _x, _s get _x] }];
            lambs_danger_korkuSay = createHashMap;
        };
    };
};
// v8.836 (RPT 2ac21bb3, v8.835: [KORKU] olay 0; 446 bot atisi, 18 isabet ama grup baskisi en cok 0.05): 'FiredNear' mermi GECISINI degil, ATEŞ EDENIN yakinligini bildirir (ates eden askerin korkuM icinde olmasi) -> yalniz CQB'de tetiklenirdi.
//   MERMI GECISI icin motorun 'Suppressed' olayi eklendi (mermi askerin yanindan gecti: distance = merminin gecis mesafesi; <= 1.5 m +0.35, <= 4 m +0.20, digeri +0.10). Her iki olay ortak isleme kodunu kullanir; olay isleyicileri CBA sinif olayi yerine
//   10 sn'de bir TUM yerel AI askerlere addEventHandler ile baglanir (XEH 'FiredNear' / 'Suppressed' destegine bagimlilik yok).
lambs_danger_korkuIsle = {
    params ["_u", "_f", "_d", "_agirlik", "_kaynak"];
    if (!local _u || {isPlayer _u} || {!alive _u}) exitWith {};
    if !(missionNamespace getVariable ["lambs_danger_korku", true]) exitWith {};
    if (time < (_u getVariable [QGVAR(korkuIslT), 0])) exitWith {};
    _u setVariable [QGVAR(korkuIslT), time + 0.25];
    if (isNull _f || {!alive _f} || {_f isEqualTo _u} || {((side group _u) getFriend (side group _f)) >= 0.6} || {(side group _f) isEqualTo civilian}) exitWith {};
    private _s = lambs_danger_korkuSay;
    _s set [_kaynak, (_s getOrDefault [_kaynak, 0]) + 1];
    _s set ["olay", (_s getOrDefault ["olay", 0]) + 1];
    private _v = (([_u] call FUNC(korkuDeger)) + _agirlik) min 1;
    _u setVariable [QGVAR(korkuD), [_v, time]];
    if (_v < 0.25) exitWith {};
    private _g = group _u;
    private _eylem = [];
    // (1) grup uyarisi
    if (time > (_g getVariable [QGVAR(korkuGrupT), 0])) then {
        _g setVariable [QGVAR(korkuGrupT), time + 3];
        _g setVariable [QGVAR(contact), (time + 12) max (_g getVariable [QGVAR(contact), 0])];
        _g reveal [_f, 1.5];
        _s set ["grup_uyari", (_s getOrDefault ["grup_uyari", 0]) + 1];
        _eylem pushBack "grup uyari";
    };
    // (2) alcalma
    // v8.840 (RPT eaa99885: 'korku 0.66' sonrasi hicbir eylem yok; asker forceMove=true iken ayakta durdugu icin alcalma muaf sayiliyordu): YUKSEK korkuda (>= 0.55) forceMove tek basina muafiyet DEGIL (hayatta kalma > komutan); kosarken (hiz >= 2) alcalma zaten yapilmaz
    private _muaf = (((_u getVariable [QGVAR(forceMove), false]) isEqualTo true) && {_v < 0.55}) || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
        || {time < (_u getVariable [QGVAR(tcccBusy), 0])} || {_u getVariable [QGVAR(disableAI), false]} || {(insideBuilding _u) > 0.5} || {(_u getVariable [QGVAR(bombaKosuyor), false]) isEqualTo true} || {[_u] call FUNC(oyuncuKomutaMi)} || {captive _u} || {!isNull objectParent _u};
    if (!_muaf && {(speed _u) < 2} && {(stance _u) isEqualTo "STAND" || {(_v >= 0.55) && {(stance _u) isEqualTo "CROUCH"}}}) then {
        private _hd = ["MIDDLE", "DOWN"] select (_v >= 0.55);
        private _tok = time + (random 0.001);
        _u setVariable [QGVAR(korkuTok), _tok];
        _u setUnitPosWeak _hd;
        _s set ["alcalma", (_s getOrDefault ["alcalma", 0]) + 1];
        _eylem pushBack format ["%1 (durus %2)", _hd, stance _u];
        [{
            params ["_uu", "_tk"];
            if (alive _uu && {(_uu getVariable [QGVAR(korkuTok), 0]) isEqualTo _tk} && {isNil {_uu getVariable QGVAR(siperDurusTut)}}) then { _uu setUnitPosWeak "AUTO"; };
        }, [_u, _tok], ((missionNamespace getVariable ["lambs_danger_korkuSure", 4]) max 2) min 12] call CBA_fnc_waitAndExecute;
    };
    // (3) siper arama
    if (!_muaf && {_v >= 0.5} && {(_u getVariable [QGVAR(forceMove), false]) isNotEqualTo true} && {missionNamespace getVariable ["lambs_danger_korkuSiper", true]} && {time > (_u getVariable [QGVAR(korkuSiperT), 0])}) then {
        _u setVariable [QGVAR(korkuSiperT), time + 10];
        [_u, _f] call FUNC(acikSiper);
        _s set ["siper", (_s getOrDefault ["siper", 0]) + 1];
        _eylem pushBack "siper ara";
    };
    // (4) EGITIMSIZLIK (v8.845; CBA egitimsizlik; kullanici: 'ISIS gercekten egitimsizligini bir noktada hissettirsin'): egitimsiz asker (DUZENSIZ doktrin / tecrubesiz) ates altinda olasilikla SABITLENIR: yere yatar, 3-6 sn basini kaldirmaz (hedef alma / karsilik ates kapali).
    //   Olasilik = egitimsizlik x (tecrubesiz 1, diger DUZENSIZ 0.6, egitimli doktrinde tecrubesiz 0.3) x (0.5 + korku); birim basina 15 sn'de bir; retreat / kacis / hekim / oyuncu komutasi muaf (_muaf).
    private _egit = missionNamespace getVariable ["lambs_danger_egitimsizlik", 0];
    if (_egit > 0 && {!_muaf} && {_v >= 0.35} && {time > (_u getVariable [QGVAR(sabitT), 0])}) then {
        private _acemi = (_u getVariable [QGVAR(acemi), false]) isEqualTo true;
        private _dz = ([_g, "ad", "GENEL"] call FUNC(dk)) isEqualTo "DUZENSIZ";
        private _faktor = if (_dz) then { [0.6, 1] select _acemi } else { [0, 0.3] select _acemi };
        if (_faktor > 0 && {(random 1) < (_egit * _faktor * (0.5 + _v))}) then {
            private _sure = 3 + (random 3);
            private _tk = time + (random 0.001);
            _u setVariable [QGVAR(sabitT), time + _sure + 15];
            _u setVariable [QGVAR(sabitTok), _tk];
            _u setUnitPosWeak "DOWN";
            _u disableAI "AUTOTARGET";
            _u disableAI "TARGET";
            _s set ["sabitlendi", (_s getOrDefault ["sabitlendi", 0]) + 1];
            _eylem pushBack format ["SABITLENDI %1 sn (%2%3)", _sure toFixed 1, ["egitimli doktrin", "DUZENSIZ"] select _dz, [", tecrubeli", ", tecrubesiz"] select _acemi];
            [{
                params ["_uu", "_tk2"];
                if (!alive _uu || {(_uu getVariable [QGVAR(sabitTok), 0]) isNotEqualTo _tk2}) exitWith {};
                _uu enableAI "AUTOTARGET";
                _uu enableAI "TARGET";
                if (isNil {_uu getVariable QGVAR(siperDurusTut)}) then { _uu setUnitPosWeak "AUTO"; };
            }, [_u, _tk], _sure] call CBA_fnc_waitAndExecute;
        };
    };
    if (_eylem isNotEqualTo [] && {["korku", 20, 30] call FUNC(logIzin)}) then {
        diag_log format ["[KORKU] %1 | %2 | ates eden %3 %4 m (%5) | korku %6 | %7", groupId _g, name _u, typeOf _f, round _d, _kaynak, _v toFixed 2, _eylem joinString " + "];
    };
};
// olay isleyicilerini tum yerel AI askerlere bagla (10 sn'de bir)
[] spawn {
    while {true} do {
        sleep 10;
        if !(missionNamespace getVariable ["lambs_danger_korku", true]) then { continue };
        {
            private _u = _x;
            if (local _u && {!isPlayer _u} && {isNil {_u getVariable QGVAR(korkuEH)}}) then {
                _u setVariable [QGVAR(korkuEH), true];
                _u addEventHandler ["Suppressed", { params ["_unit", "_dist", "_shooter", "_instigator"]; private _f = if (isNull _shooter) then {_instigator} else {_shooter}; [_unit, _f, _dist, (if (_dist <= 1.5) then {0.35} else { if (_dist <= 4) then {0.2} else {0.1} }), "gecis"] call lambs_danger_korkuIsle; }];
                _u addEventHandler ["FiredNear", {
                    params ["_unit", "_firer", "_dist", "_w", "_mz", "_mod", "_ammo"];
                    private _m = ((missionNamespace getVariable ["lambs_danger_korkuM", 25]) max 8) min 60;
                    if (_dist <= _m && {_ammo isKindOf ["BulletBase", configFile >> "CfgAmmo"]}) then { [_unit, _firer, _dist, (if (_dist <= 5) then {0.25} else { if (_dist <= 12) then {0.12} else {0.05} }), "yakin_atis"] call lambs_danger_korkuIsle; };
                }];
            };
        } forEach allUnits;
    };
};
true
