#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Peel (Sirayla Cekilme) — ARTIK Retreat'e yonlendirilir.
 *
 * Eski Peel LAMBS formasyon override'ina yenildi ve disableAI "PATH"/"MOVE"
 * kilitleriyle askerleri dondurabiliyordu. Zeus test komutu (fnc_tacticsPeel'i
 * dogrudan cagiran) eski kodu calistirip "askerler aptallasiyor" izlenimi veriyordu.
 * Bu dosya sadece tacticsRetreat'i cagirir; tum caller'lar guvenli yola gider.
 *
 * Arguments:
 * 0: group <GROUP> or leader <OBJECT>
 * 1: known enemy <OBJECT> or position <ARRAY>
 * 2: (kullanilmiyor, uyumluluk icin) <NUMBER>
 *
 * Return Value:
 * Bool
 *
 * Public: No
*/

params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_target", objNull, [objNull, []]],
    ["_peelStep", 35, [0]]
];

[_group, _target] call FUNC(tacticsRetreat)
