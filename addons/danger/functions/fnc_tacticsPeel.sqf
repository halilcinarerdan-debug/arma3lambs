#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PEEL (SIRAYLA / KADEMELI GERI CEKILME) — v8.365'te CANLANDIRILDI: fnc_tactics 'PEEL' karari artik bu fonksiyon uzerinden yurur (eskiden dogrudan tacticsRetreat'e giderdi ve bu dosya hic cagrilmiyordu;
 * 'isPeeling' bayragi 5 sistem tarafindan OKUNUYORDU ama hicbir yerde YAZILMIYORDU).
 *
 * NEDEN: PEEL karari (commanderAssess: guc dezavantaji >= 1.6x + kayip >= %10, ya da kayip + yakin temas — NATO doktrini: kademeli cekilme, bir unsur ortu verirken digeri cekilir) ile WITHDRAW karari (tam cekilme)
 *   ayni hareketi (tacticsRetreat: waypoint kademeleri + ortu / baski) kullanir; fark KARARIN NEDENI ve izlenebilirligidir.
 * Eski Peel (LAMBS formasyon override'ina yenilen, disableAI PATH / MOVE ile askerleri donduran kod) YENIDEN CANLANDIRILMADI; yalniz guvenli tacticsRetreat kullanilir.
 *
 * NE YAPAR: (1) [PEEL] logu (karar nedeni WITHDRAW'dan ayrilsin), (2) tacticsRetreat basarili baslarsa grup 'isPeeling' = true isaretlenir —
 *   bu bayragi okuyanlar: fnc_selectFormation (PEEL aktifken FILE kilidi), fnc_commanderFormation, fnc_fieldCraft, fnc_tehditBakis, fnc_orphanWatchdog — (3) retreat bitince (isRetreating false) ya da 300 sn'de bayrak
 *   temizlenir (takili kalmasin). Retreat baslamazsa (zaten cekiliyor / 45 sn soguma / CQB) bayrak KOYULMAZ.
 *
 * Arguments:
 * 0: Grup ya da lider <GROUP / OBJECT>
 * 1: Bilinen dusman <OBJECT> ya da konum <ARRAY>
 * 2: (kullanilmiyor, uyumluluk icin) <NUMBER>
 *
 * Return Value: Retreat basladi mi <BOOL>
 * Public: No
*/

params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_target", objNull, [objNull, []]],
    ["_peelStep", 35, [0]]
];

private _g = if (_group isEqualType objNull) then {group _group} else {_group};
if (isNull _g) exitWith {false};
if (_g getVariable [QGVAR(isPeeling), false]) exitWith {false};

private _ok = [_g, _target] call FUNC(tacticsRetreat);
if (_ok isEqualType true && {_ok}) then {
    _g setVariable [QGVAR(isPeeling), true];
    diag_log format ["[PEEL] %1 | kademeli geri cekilme basladi (PEEL karari; tacticsRetreat uzerinden) | uye %2 | hedef %3", groupId _g, {alive _x} count (units _g), if (_target isEqualType objNull) then {typeOf _target} else {"konum"}];
    [_g] spawn {
        params ["_gp"];
        private _bit = time + 300;
        sleep 3;
        waitUntil { sleep 3; isNull _gp || {!(_gp getVariable [QGVAR(isRetreating), false])} || {time > _bit} };
        if (!isNull _gp) then { _gp setVariable [QGVAR(isPeeling), nil]; };
    };
};
_ok
