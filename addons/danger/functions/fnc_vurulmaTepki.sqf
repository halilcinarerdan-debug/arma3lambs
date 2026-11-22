#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * VURULUNCA SIPERI YENIDEN DEGERLENDIR (v8.737; kullanici: 'sus niyetine gizlenmesin, bir yerden yemesin'): siper SECIMI bilinen dusmana gore yapilir; ama asker 'gizli / korunakli' bir yerde durup BASKA bir yonden / yumusak siperden vurulabilir.
 * Yerel AI, temasli grup, hareketsiz (hiz < 2) asker hasar alirsa (damage artisi >= 0.03, 8 sn'de bir): vurulduT yazilir (acikSiper: 'kendi siperinde kal' hafizasi 20 sn atlanir, cok yonlu kapalilik cezasi x3),
 * acikSiper / siperOnTarama beklemeleri sifirlanir ve fnc_acikSiper hemen cagrilir (en yakin bilinen dusman). Log: [VURULDU-TEPKI] (ilk 20) + 60 sn OZET. CBA vurulmaTepki (varsayilan ACIK).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_vurulmaTepkiStarted") exitWith {false};
lambs_danger_vurulmaTepkiStarted = true;
diag_log "[VURULDU-TEPKI] vurulunca siperi yeniden degerlendirme (hareketsiz asker hasar alirsa) baslatildi (v8.737)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["vurulan", 0], ["siperBulundu", 0]];
    private _ozetT = time + 60;
    while {true} do {
        sleep ([1, true, false, "vurulmaTepki"] call FUNC(dusunSure));
        if !(missionNamespace getVariable ["lambs_danger_vurulmaTepki", true]) then { continue };
        {
            private _u = _x;
            if (!local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u}) then { continue };
            private _d0 = _u getVariable [QGVAR(hasar0), -1];
            private _d1 = damage _u;
            _u setVariable [QGVAR(hasar0), _d1];
            if (_d0 < 0 || {(_d1 - _d0) < 0.03}) then { continue };
            if (((group _u) getVariable [QGVAR(contact), 0]) <= time || {(speed _u) >= 2} || {time < (_u getVariable [QGVAR(vurulTepkiT), 0])}) then { continue };
            if (!((lifeState _u) in ["HEALTHY", "INJURED"]) || {captive _u} || {_u getVariable ["ACE_isUnconscious", false]}) then { continue };
            _u setVariable [QGVAR(vurulTepkiT), time + 8];
            _u setVariable [QGVAR(vurulduT), time];
            _u setVariable [QGVAR(acikSiperT), 0];
            _u setVariable [QGVAR(onTaramaT), 0];
            _u setVariable [QGVAR(acikSiperHedef), []];
            _say set ["vurulan", (_say get "vurulan") + 1];
            private _en = _u findNearestEnemy _u;
            if (isNull _en || {!alive _en}) then { continue };
            if ([_u, _en] call FUNC(acikSiper)) then {
                _say set ["siperBulundu", (_say get "siperBulundu") + 1];
                if (_logN < 20) then {
                    _logN = _logN + 1;
                    diag_log format ["[VURULDU-TEPKI] %1 | %2 | korunakliyken hasar aldi (+%3) -> siper yeniden degerlendirildi (dusman %4 m)", groupId group _u, name _u, (_d1 - _d0) toFixed 2, round (_u distance2D _en)];
                };
            };
        } forEach allUnits;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if ((_say get "vurulan") > 0) then {
                diag_log format ["[VURULDU-TEPKI-OZET] 60 sn: hareketsizken vurulan %1 | yeni siper bulunup gonderilen %2", _say get "vurulan", _say get "siperBulundu"];
            };
            { _say set [_x, 0]; } forEach ["vurulan", "siperBulundu"];
        };
    };
};
true
