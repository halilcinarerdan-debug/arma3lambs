#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2 ISTEMCI: MENU SECIMI (v8.391) — ACE menusu / addAction yaprak komutu. Haritayi acar ve tiklama bekler (fnc_c2Tikla, 90 sn); tiklama gerekmeyen komutlar dogrudan sunucuya gider.
 *   TOPCU        : [tur "HE" / "SMOKE" / "ILLUM"] -> haritada HEDEF nokta -> sunucu fnc_c2TopcuIste
 *   TOPCU_IPTAL  : henuz atmamis toplari durdur (fnc_c2TopcuIptal)
 *   EMIR         : [kod "MOVE" / "SAD" / "TUT" / "SERBEST"] -> haritada bot grubuna tikla (+ MOVE / SAD icin hedef nokta) -> sunucu fnc_c2Emir
 *   IKMAL        : yakindaki botlara ikmal dagit (fnc_c2IkmalVer; yetki sarti yok, pilot / sofor kullanir)
 *
 * Arguments:
 * 0: Amac <STRING>
 * 1: Veri <ARRAY>
 *
 * Return Value: None
 * Public: No
*/

params [["_amac", "", [""]], ["_veri", [], [[]]]];

if (hasInterface) then {
    if (_amac isEqualTo "TOPCU_IPTAL") then {
        [player] remoteExecCall ["lambs_danger_fnc_c2TopcuIptal", 2];
    } else {
        if (_amac isEqualTo "IKMAL") then {
            [player] remoteExecCall ["lambs_danger_fnc_c2IkmalVer", 2];
        } else {
            if !([player] call FUNC(c2Yetkili)) then {
                systemChat "[C2] Yetkin yok (grup lideri / komutan degiskeni / aktif telsiz gerekli).";
            } else {
                private _kod = _veri param [0, ""];
                private _metin = if (_amac isEqualTo "TOPCU") then {
                    format ["[C2] Topcu (%1): haritada HEDEF noktaya tikla (90 sn).", _kod]
                } else {
                    if (_kod in ["TUT", "SERBEST"]) then {
                        format ["[C2] Emir (%1): haritada BOT GRUBUNA tikla (lider simgesine yakin).", _kod]
                    } else {
                        format ["[C2] Emir (%1): once haritada BOT GRUBUNA, sonra HEDEF noktaya tikla (90 sn).", _kod]
                    }
                };
                missionNamespace setVariable ["lambs_danger_c2Bekle", [_amac, _veri, diag_tickTime + 90, 0, ""]];
                openMap [true, false];
                systemChat _metin;
            };
        };
    };
};
