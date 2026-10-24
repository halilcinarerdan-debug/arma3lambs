#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * IHA GOZLEMI -> ORTAK RESIM (v8.232; kullanici: "dron savasi basliyor") — AI muretttebatli (oyuncu kumandasinda olmayan) keşif IHA'larinin (unitIsUAV; Zeus / Eden'de AI ile konan) 1500 m icinde gordugu
 * DUSMAN birimleri, IHA tarafinin yerel AI gruplarina (liderleri IHA'dan <= 3000 m) bildirilir: reveal 1.5. Boylece:
 *   - topcu dogrulamasi (liderlerin knowsAbout > 0.5, hedefe <= 500 m) IHA gozlemiyle saglanabilir (canli gozlem);
 *   - komutan / HQ istihbarat agi bu bilgiyi normal yoldan kullanir (SPOTREP / bilgi sisi mantigi bozulmaz).
 * Dengeleme (hile hissi olmasin): IHA'nin KENDI AI hedef listesi (nearTargets, gercek algi) kullanilir — haritadan konum OKUNMAZ; en cok 12 hedef / 5 sn / IHA; dogruluk (accuracy) < 0.3 olan hedef yok sayilir.
 * Kaynak ilkesi: ATP 3-04.1 (insansiz hava araci) / FM 3-98 kesif — IHA gorevi bilgi toplayip HIZLI dagitmaktir; sayilar TASARIM degeri.
 * Bu surumde IHA'yi UCURMAZ (gorev / devriye waypoint'ini Zeus verir) ve FPV / kamikaze YOK (sonraki dilim). Kapatma: lambs_danger_ihaGozlemOff = true.  Log: [IHA-GOZLEM] (30 sn'de bir).
 *
 * Arguments: None (acilista bir kez)
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_ihaGozlemStarted") exitWith {false};
lambs_danger_ihaGozlemStarted = true;

// ---- her makine: yerel gruplara bildir ----
["lambs_danger_ihaGordu", {
    params ["_taraf", "_netIdler", "_ihaPoz"];
    private _hedefler = _netIdler apply {objectFromNetId _x} select {!isNull _x && {alive _x}};
    if (_hedefler isEqualTo []) exitWith {};
    private _sayi = 0;
    {
        private _g = _x;
        if (local _g && {(side _g) isEqualTo _taraf} && {!isNull leader _g} && {!isPlayer leader _g} && {((leader _g) distance2D _ihaPoz) <= 3000}) then {
            { _g reveal [_x, 1.5]; } forEach _hedefler;
            _sayi = _sayi + 1;
        };
    } forEach allGroups;
    missionNamespace setVariable ["lambs_danger_ihaGrupSay", (missionNamespace getVariable ["lambs_danger_ihaGrupSay", 0]) + _sayi];
}] call CBA_fnc_addEventHandler;

// ---- IHA'nin yerel oldugu makine: hedef listesi ----
[] spawn {
    private _logT = 0;
    while {true} do {
        sleep 5;
        if (missionNamespace getVariable ["lambs_danger_ihaGozlemOff", false]) then { continue };
        {
            private _u = _x;
            if (!local _u || {!alive _u} || {!(unitIsUAV _u)}) then { continue };
            private _mur = (crew _u) select {alive _x && {!isPlayer _x}};
            if (_mur isEqualTo [] || {({isPlayer _x} count (crew _u)) > 0}) then { continue };
            private _taraf = side (group (_mur select 0));
            private _tg = (_u nearTargets 1500) select {
                (_x select 4) isNotEqualTo objNull && {alive (_x select 4)} && {(_x select 5) >= 0.3} && {(_taraf getFriend (_x select 2)) < 0.6} && {(_u distance (_x select 4)) <= (1500 * ([_u, _x select 4] call lambs_danger_fnc_ihaGorus))} && {((_x select 4) isKindOf "CAManBase" || {(_x select 4) isKindOf "LandVehicle"})}
            };
            // v8.345 KAMERA TARAMASI (kullanici: 'dron hic iyi spotlayamiyor'; RPT 01-19: gozlem dronu 3 dk boyunca hep '1 hedef goruldu'): AI IHA muretttebatinin kendi algisi (nearTargets) zayif. Dronun kamerasi gibi,
            //   1200 m icindeki DUSMANI gorus hatti (arazi + nesne) ACIKSA ve fnc_ihaGorus katsayili menzil icindeyse (gunduz 1200 m, gece termalsiz ~300 m, sis / yagmur / kamuflaj / yatik azaltir) tarama basina %60 ihtimalle gorur.
            //   Haritadan konum OKUNMAZ; kapatma lambs_danger_ihaTaramaOff = true. Muretttebat spotDistance / spotTime 1.0'a cekilir (bir kez).
            if (!(_u getVariable ["lambs_danger_ihaSpotSkill", false])) then {
                _u setVariable ["lambs_danger_ihaSpotSkill", true];
                { _x setSkill ["spotDistance", 1]; _x setSkill ["spotTime", 1]; } forEach (crew _u);
            };
            if (!(missionNamespace getVariable ["lambs_danger_ihaTaramaOff", false])) then {
                private _gozU = getPosASL _u;
                private _mevcut = _tg apply {_x select 4};
                private _ek = (_u nearEntities [["CAManBase", "LandVehicle"], 1200]) select {
                    alive _x && {!(_x in _mevcut)} && {!(captive _x)}
                    && {
                        private _sd = if (_x isKindOf "CAManBase") then { side (group _x) } else { private _cm = (crew _x) select {alive _x}; if (_cm isEqualTo []) then {civilian} else { side (group (_cm select 0)) } };
                        (_taraf getFriend _sd) < 0.6 && {_sd isNotEqualTo civilian}
                    }
                };
                {
                    if ((count _tg) < 24 && {random 1 < 0.6}) then {
                        private _hp = (getPosASL _x) vectorAdd [0, 0, 1.2];
                        if ((_u distance _x) <= (1200 * ([_u, _x] call lambs_danger_fnc_ihaGorus)) && {!(terrainIntersectASL [_gozU, _hp])} && {!(lineIntersects [_gozU, _hp, _u, _x])}) then {
                            _tg pushBack [getPosATL _x, "", _taraf, 0, _x, 1];
                        };
                    };
                } forEach (_ek select [0, 30]);
            };
            _u setVariable ["lambs_danger_ihaGorulen", [time, _tg apply {_x select 4}]];   // v8.338: gozlemli topcu (fnc_dronTopcu) icin gercek algi listesi (yalniz bu makinede)
            if (_tg isEqualTo []) then { continue };
            private _ids = (_tg select [0, 12]) apply {netId (_x select 4)};
            ["lambs_danger_ihaGordu", [_taraf, _ids, getPosATL _u]] call CBA_fnc_globalEvent;
            if (time > _logT) then {
                _logT = time + 30;
                diag_log format ["[IHA-GOZLEM] %1 (%2) | %3 hedef goruldu, ortak resme verildi | irtifa %4 m | bildirilen grup (toplam) %5", typeOf _u, _taraf, count _ids, round ((getPosATL _u) select 2), missionNamespace getVariable ["lambs_danger_ihaGrupSay", 0]];
            };
        } forEach (vehicles select {unitIsUAV _x});
    };
};

diag_log "[IHA-GOZLEM] IHA gozlemi -> ortak resim baslatildi (v8.232): nearTargets (gercek algi), reveal 1.5, <= 3000 m";
true
