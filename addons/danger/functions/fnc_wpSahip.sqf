#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * WAYPOINT SAHIBI (v8.504; sade-waypoint): bir grubu su an kimin yonettigini soyler; ELITE hareket / taktik katmanlari buna gore geri cekilir.
 * Tasarimci = 3DEN'de elle verilen vanilla waypoint'ler, LAMBS Waypoints (lambs_wp) gorevleri ve LAMBS grup anahtarlari.
 *
 *   "LAMBS"    LAMBS gorevi (taskGarrison / taskCamp / taskPatrol / taskHunt / taskCQB / taskCreep / taskRush ...: grup degiskeni lambs_main_currentTactic 'task...' ile baslar
 *              YA DA aktif waypoint'in script'i lambs_wp icerir) veya grup lambs_danger_disableGroupAI = true (LAMBS'in kendi 'LAMBS Danger: AI Kapat' modulu).
 *   "TUTAN"    Gorev Ata 'HARIC' grubu ya da aktif vanilla waypoint 'kal / bekle / senaryo' turunde: HOLD, SENTRY, GUARD, LOITER, SCRIPTED, DISMISS, SUPPORT, GETIN, GETOUT, TR UNLOAD, UNLOAD, JOIN, LEADER ...
 *   "HAREKET"  aktif vanilla waypoint hareket turunde: MOVE, SAD, DESTROY, CYCLE (tasarimci rotasi; yalniz 'Senaryo modu' aciksa ELITE geri ceker)
 *   ""         tasarimci waypoint'i yok / bitti (ELITE tepkileri serbest)
 * Aktif waypoint = indeks >= 1 ve >= currentWaypoint olan ilk waypoint (indeks 0 grup baslangicidir). ELITE'in eski kendi waypoint'leri (adi 'ELITE...') sayilmaz.
 *
 * Arguments:
 * 0: Grup <GROUP>
 *
 * Return Value: "LAMBS" / "TUTAN" / "HAREKET" / "" <STRING>
 * Public: No
*/

params [["_g", grpNull, [grpNull]]];
if (isNull _g) exitWith {""};

// Zeus / 3DEN Gorev Ata 'HARIC': ELITE dokunmasin
if ((_g getVariable ["lambs_danger_gorev", ""]) isEqualTo "HARIC") exitWith {"TUTAN"};
// LAMBS'in kendi kapatma anahtari + lambs_wp gorevi
if (_g getVariable ["lambs_danger_disableGroupAI", false]) exitWith {"LAMBS"};
private _tak = _g getVariable ["lambs_main_currentTactic", ""];
if (_tak isEqualType "" && {(_tak find "task") isEqualTo 0}) exitWith {"LAMBS"};

private _wps = waypoints _g;
private _cur = (currentWaypoint _g) max 1;
private _w = _wps select {((waypointName _x) find "ELITE") != 0 && {(_x select 1) >= _cur}};
if (_w isEqualTo []) exitWith {""};
private _wp = _w select 0;
if (((toLower (waypointScript _wp)) find "lambs_wp") >= 0) exitWith {"LAMBS"};
private _tur = toUpper (waypointType _wp);
if (_tur in ["MOVE", "SAD", "DESTROY", "CYCLE", ""]) exitWith {"HAREKET"};
"TUTAN"
