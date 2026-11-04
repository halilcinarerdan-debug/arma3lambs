#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2 ISTEMCI: MENU SECIMI (v8.391; v8.392: ROTA + OBJEKTIF) — ACE menusu / addAction yaprak komutu. Haritayi acar ve tiklama bekler (fnc_c2Tikla, 90 sn); tiklama gerekmeyen komutlar dogrudan sunucuya gider.
 *   TOPCU        : [tur "HE" / "SMOKE" / "ILLUM"] -> haritada HEDEF nokta -> sunucu fnc_c2TopcuIste
 *   TOPCU_IPTAL  : henuz atmamis toplari durdur (fnc_c2TopcuIptal)
 *   EMIR         : [kod "MOVE" / "SAD" / "ROTA" / "TUT" / "SERBEST"] -> haritada bot grubuna tikla (+ MOVE / SAD icin hedef nokta; ROTA icin art arda noktalar) -> sunucu fnc_c2Emir
 *   ROTA_BITIR   : rota ekleme beklemesini bitirir (yalniz istemci)
 *   OBJ          : [kod "ELE" / "SAVUN" / "SECILI_SAVUN" / "IPTAL" / "DURUM"] -> ELE / SAVUN haritada OBJEKTIF noktasi; SECILI_SAVUN once bot grubu sonra nokta; IPTAL / DURUM dogrudan -> sunucu fnc_c2Objektif
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
            if (_amac isEqualTo "ROTA_BITIR") then {
                missionNamespace setVariable ["lambs_danger_c2Bekle", []];
                systemChat "[C2] Rota ekleme bitti (grup waypoint'leri sirayla gezer; 'Serbest birak' ile ELITE'e don).";
            } else {
                if !([player] call FUNC(c2Yetkili)) then {
                    systemChat "[C2] Yetkin yok (grup lideri / komutan degiskeni / aktif telsiz gerekli).";
                } else {
                    private _kod = _veri param [0, ""];
                    if (_amac isEqualTo "OBJ" && {_kod in ["IPTAL", "DURUM"]}) then {
                        [_kod, [], player, ""] remoteExecCall ["lambs_danger_fnc_c2Objektif", 2];
                    } else {
                        private _metin = switch (_amac) do {
                            case "TOPCU": { format ["[C2] Topcu (%1): haritada HEDEF noktaya tikla (90 sn).", _kod] };
                            case "OBJ": {
                                if (_kod isEqualTo "SECILI_SAVUN") then {
                                    "[C2] Objektif (savun): once haritada BOT GRUBUNA, sonra OBJEKTIF noktasina tikla (90 sn)."
                                } else {
                                    format ["[C2] Objektif (%1): haritada OBJEKTIF noktasina tikla (90 sn).", _kod]
                                }
                            };
                            default {
                                if (_kod in ["TUT", "SERBEST"]) then {
                                    format ["[C2] Emir (%1): haritada BOT GRUBUNA tikla (lider simgesine yakin).", _kod]
                                } else {
                                    if (_kod isEqualTo "ROTA") then {
                                        "[C2] Rota: once haritada BOT GRUBUNA tikla, sonra rota noktalarina art arda tikla (bitince menuden 'Rotayi bitir')."
                                    } else {
                                        format ["[C2] Emir (%1): once haritada BOT GRUBUNA, sonra HEDEF noktaya tikla (90 sn).", _kod]
                                    }
                                }
                            };
                        };
                        missionNamespace setVariable ["lambs_danger_c2Bekle", [_amac, _veri, diag_tickTime + 90, 0, ""]];
                        openMap [true, false];
                        systemChat _metin;
                    };
                };
            };
        };
    };
};
