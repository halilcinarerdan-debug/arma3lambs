#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOMUTLA PATLAYAN EYP PUSUSU (v8.777; kullanici referansi: eyp_deme.txt 'fn_iedDeployer'; ATP 3-34.20: uzaktan tetiklenen cihaz = kurucu gozetlemede kalir).
 * SIRA: (1) asker EYP noktasina sizar (AWARE, NORMAL hiz, 15 sn) (2) cokmus durusla 5 sn kurma animasyonu (AinvPknlMstpSnonWnonDnon_medic_1) (3) yere DemoCharge_Remote_Ammo_Scripted + ustune Land_Garbage_square3_F (kamuflaj)
 *   (4) EYP'nin DUSMAN GELIS yonunun tersindeki, EYP'yi ARAZI hatti acik goren gozetleme noktasina (20 / 28 / 45 m; eypPatlamaGucu 0 / 1 / 2) cekilir (25 sn), cokmus, EYP'ye bakar (5) TETIK DISIPLINI: EYP'ye 12 m icinde dusman (CAManBase / LandVehicle, side dost degil, sivil / captive degil)
 *   + 8 m icinde dost YOK -> 0.4 sn insan tepkisi -> fnc_eypPatlat 'ied' (referans: yuksek tahrip) -> EYP + kamuflaj silinir -> AI kontrolu geri verilir. Asker olurse EYP etkisiz kalir (120 sn sonra silinir); 600 sn tetiklenmezse silinir.
 * Aktif sayac: lambs_danger_eypKomutAktif_<taraf> (fnc_eypSistem butce hesabi). Loglar [EYP-KOMUT] (ilk 30: KURULDU / SONUC).
 * SINIR: oyunda DENENMEDI; asker tek basina geride kalir (grup geri cekilmesiyle cakisabilir); kurma animasyonu temas altinda yarim kalabilir (olurse 'olu'); ACE yuklu ortamda DemoCharge nesnesi ACE etkilesimiyle (EOD) etkisiz hale getirilebilir ve oyuncu ACE ile defuse edebilir.
 *
 * Arguments:
 * 0: Kurucu asker <OBJECT>
 * 1: EYP konumu (AGL) <ARRAY>
 * 2: Gozetleme noktasi (AGL; [] = otomatik) <ARRAY> (editor / Zeus: referans eyp_deme.txt'deki 'hidePos')
 * 3: Dusman konumu (AGL; EYP'ye geldigi yon; [] = kurucunun tersi) <ARRAY>
 * 4: Tetik mesafesi (m) <NUMBER> (varsayilan 12)
 * 5: Patlama gucu 0-2 <NUMBER> (varsayilan -1 = CBA)
 *
 * Return Value: Sonuc metni <STRING> ("PATLADI" / "olu" / "zaman asimi" / "kurulamadi")
 *
 * EDITOR INIT SATIRI (referans eyp_deme.txt benzeri): [this, getMarkerPos "eyp_noktasi", getMarkerPos "pusu_noktasi"] spawn lambs_danger_fnc_eypKomut;
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_ip", [], [[]]], ["_hide0", [], [[]]], ["_ep", [], [[]]], ["_tetikM", 12, [0]], ["_gucOv", -1, [0]]];
if (isNull _u || {!alive _u} || {_ip isEqualTo []}) exitWith {"olu"};
if (!isNil {_u getVariable QGVAR(eypBomba)}) exitWith {"mesgul (canli bomba)"};
// dusman gelis yonu verilmediyse: kurucunun bulundugu yonun TERSI (dusman EYP'ye karsi taraftan gelir)
if (_ep isEqualTo []) then { _ep = _ip getPos [100, (_ip getDir _u) + 180]; };
_tetikM = (_tetikM max 5) min 40;

private _taraf = side group _u;
private _akAd = format ["lambs_danger_eypKomutAktif_%1", str _taraf];
missionNamespace setVariable [_akAd, (missionNamespace getVariable [_akAd, 0]) + 1];
private _guc = round (((if (_gucOv >= 0) then {_gucOv} else {missionNamespace getVariable ["lambs_danger_eypPatlamaGucu", 1]}) max 0) min 2);
private _t0 = time;
private _sonuc = "kurulamadi";
private _ied = objNull;
private _cover = objNull;
private _hide = [];
private _ln = missionNamespace getVariable ["lambs_danger_eypKomutLogN", 0];

_u setVariable [QGVAR(disableAI), true];
_u setBehaviour "AWARE";
_u setSpeedMode "NORMAL";

// (1) EYP noktasina sizma
_u doMove _ip;
private _tB = time + 15;
waitUntil { sleep 0.5; !alive _u || {(_u distance2D _ip) < 3} || {time > _tB} || {!isNil {_u getVariable QGVAR(eypBomba)}} };
private _devam = alive _u && {(_u distance2D _ip) < 6} && {isNil {_u getVariable QGVAR(eypBomba)}};

// (2) kurma animasyonu
if (_devam) then {
    doStop _u;
    _u playMove "AinvPknlMstpSnonWnonDnon_medic_1";
    private _tK = time + 5;
    waitUntil { sleep 0.5; !alive _u || {time > _tK} || {!isNil {_u getVariable QGVAR(eypBomba)}} };
    _devam = alive _u && {isNil {_u getVariable QGVAR(eypBomba)}};
};

// (3) EYP + kamuflaj
if (_devam) then {
    private _pp = [_ip select 0, _ip select 1, 0];
    _ied = createVehicle ["DemoCharge_Remote_Ammo_Scripted", _pp, [], 0, "CAN_COLLIDE"];
    _ied setPosATL _pp;
    _cover = createVehicle ["Land_Garbage_square3_F", _pp, [], 0, "CAN_COLLIDE"];
    _cover setPosATL _pp;
    // (4) gozetleme noktasi: EYP'yi arazi hatti ile goren, dusmanin gelis yonunun tersi
    private _yon = _ep getDir _ip;
    private _mes = [20, 28, 45] select _guc;
    if (_hide0 isNotEqualTo []) then {
        _hide = _hide0;   // editor / Zeus: gozetleme noktasi elle verildi
        _mes = _ip distance2D _hide;
    } else {
        private _iz = AGLToASL [_ip select 0, _ip select 1, 0.5];
        {
            private _c = _ip getPos [_mes, _yon + _x];
            if (!surfaceIsWater _c && {!(terrainIntersectASL [AGLToASL [_c select 0, _c select 1, 1.0], _iz])}) exitWith { _hide = _c; };
        } forEach [0, 35, -35, 70, -70];
        if (_hide isEqualTo []) then { _hide = _ip getPos [_mes, _yon]; };
    };
    if (_ln < 30) then {
        _ln = _ln + 1;
        missionNamespace setVariable ["lambs_danger_eypKomutLogN", _ln];
        diag_log format ["[EYP-KOMUT] KURULDU | %1 (%2) | %3 | EYP xy %4 | gozetleme %5 m | patlama gucu %6", groupId group _u, str _taraf, name _u, _ip select [0, 2] apply { round _x }, round _mes, _guc];
    };
    _u doMove _hide;
    _tB = time + 25;
    waitUntil { sleep 1; !alive _u || {(_u distance2D _hide) < 4} || {time > _tB} || {!isNil {_u getVariable QGVAR(eypBomba)}} };
    if (alive _u && {isNil {_u getVariable QGVAR(eypBomba)}}) then {
        doStop _u;
        _u setUnitPos "MIDDLE";
        _u doWatch _ip;
        // (5) tetik disiplini
        private _tEnd = time + 600;
        private _patla = false;
        while {alive _u && {!isNull _ied} && {time < _tEnd} && {!_patla} && {isNil {_u getVariable QGVAR(eypBomba)}}} do {
            private _yak = (_ied nearEntities [["CAManBase", "LandVehicle"], _tetikM]) select {alive _x && {!captive _x} && {(side _x) isNotEqualTo civilian} && {(_taraf getFriend (side _x)) < 0.6}};
            private _dost = ((_ied nearEntities [["CAManBase", "LandVehicle"], 8]) findIf {alive _x && {(_taraf getFriend (side _x)) >= 0.6}}) >= 0;
            if (_yak isNotEqualTo [] && {!_dost}) then {
                sleep 0.4;
                if (alive _u && {!isNull _ied}) then { _patla = true; };
            };
            if (!_patla) then { sleep 0.5; };
        };
        if (_patla) then {
            [getPosATL _ied, "ied", _gucOv] call FUNC(eypPatlat);
            deleteVehicle _ied;
            deleteVehicle _cover;
            _sonuc = "PATLADI";
        } else {
            _sonuc = if (!alive _u) then {"olu"} else { if (!isNil {_u getVariable QGVAR(eypBomba)}) then {"iptal (canli bomba oldu)"} else {"zaman asimi"} };
        };
    } else {
        _sonuc = if (alive _u) then {"iptal (canli bomba oldu)"} else {"olu"};
    };
    // etkisiz kalan EYP: olu kurucu -> 120 sn sonra, zaman asimi -> hemen
    if (!isNull _ied) then {
        if (_sonuc isEqualTo "olu" || {(_sonuc find "iptal") == 0}) then { [_ied, _cover] spawn { params ["_i", "_c"]; sleep 120; deleteVehicle _i; deleteVehicle _c; }; } else { deleteVehicle _ied; deleteVehicle _cover; };
    };
};
if (alive _u && {isNil {_u getVariable QGVAR(eypBomba)}}) then {
    _u setVariable [QGVAR(disableAI), false];
    _u setUnitPos "AUTO";
    _u doWatch objNull;
};
missionNamespace setVariable [_akAd, ((missionNamespace getVariable [_akAd, 1]) - 1) max 0];
if (_ln < 30) then {
    _ln = _ln + 1;
    missionNamespace setVariable ["lambs_danger_eypKomutLogN", _ln];
    diag_log format ["[EYP-KOMUT] SONUC | %1 | %2 | %3 sn", name _u, _sonuc, (time - _t0) toFixed 1];
};
_sonuc
