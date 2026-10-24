#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YURUNEBILIR ALAN GORSELI (v8.333) — kullanici: 'trench markerlari Zeus uyumlu olsun ve marker oyunda gozukmedi'. 'ELITE Yurunebilir Alan' modul alanlari oyunda gorunmuyordu (modul gizli bir mantik nesnesi).
 * Istemci (hasInterface), 3 sn'de bir: alan listesi (fnc_yuruyusAlani) icin YEREL harita isareti (ELITE_YURU_<id>; dikdortgen / elips, turuncu, yari saydam, 'Yurunebilir alan') olusturur / gunceller / siler,
 * ve Zeus kamerasi (ya da gorunum acikken oyuncu) icin 600 m icindeki alanlarin 3D cerceve cizgisini + etiketini cizer (Draw3D). Gorunurluk: Zeus (curator atanmis) VEYA CBA 'Yurunebilir alanlari herkes gorsun'
 * (lambs_danger_yuruGorunum) VEYA Eden onizleme (is3DENPreview). Diger oyuncular alani GORMEZ. Kapatma: lambs_danger_yuruGorselOff = true.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!hasInterface) exitWith {false};
if (!isNil "lambs_danger_yuruGorselStarted") exitWith {false};
lambs_danger_yuruGorselStarted = true;
lambs_danger_yuruCiz = false;

addMissionEventHandler ["Draw3D", {
    if (!lambs_danger_yuruCiz) exitWith {};
    private _kam = positionCameraToWorld [0, 0, 0];
    private _renk = [1, 0.55, 0, 1];
    {
        _x params ["_c", "_a", "_b", "_dir", "_rect"];
        if ((_kam distance2D _c) < 600) then {
            private _ex = [cos _dir, -(sin _dir)];
            private _ey = [sin _dir, cos _dir];
            private _nokta = {
                params ["_lx", "_ly"];
                private _wx = (_c select 0) + ((_ex select 0) * _lx) + ((_ey select 0) * _ly);
                private _wy = (_c select 1) + ((_ex select 1) * _lx) + ((_ey select 1) * _ly);
                ASLToAGL [_wx, _wy, (getTerrainHeightASL [_wx, _wy]) + 0.5]
            };
            private _pts = [];
            if (_rect) then {
                _pts = [[-_a, -_b] call _nokta, [_a, -_b] call _nokta, [_a, _b] call _nokta, [-_a, _b] call _nokta];
            } else {
                for "_k" from 0 to 23 do {
                    private _t = _k * 15;
                    _pts pushBack ([_a * (sin _t), _b * (cos _t)] call _nokta);
                };
            };
            private _n = count _pts;
            for "_i" from 0 to (_n - 1) do { drawLine3D [_pts select _i, _pts select ((_i + 1) mod _n), _renk]; };
            drawIcon3D ["", _renk, ASLToAGL [(_c select 0), (_c select 1), (getTerrainHeightASL _c) + 2], 0, 0, 0, format ["Yurunebilir alan %1 x %2 m", round (_a * 2), round (_b * 2)], 2, 0.035, "RobotoCondensed", "center"];
        };
    } forEach (["LISTE"] call FUNC(yuruyusAlani));
}];

[] spawn {
    waitUntil { sleep 1; !isNull player };
    private _isaretler = createHashMap;   // modul netId -> isaret adi
    while {true} do {
        sleep 3;
        private _goster = !(missionNamespace getVariable ["lambs_danger_yuruGorselOff", false])
            && {(!isNull (getAssignedCuratorLogic player)) || {missionNamespace getVariable ["lambs_danger_yuruGorunum", false]} || {is3DENPreview}};
        lambs_danger_yuruCiz = _goster;
        private _alanlar = if (_goster) then { ["LISTE"] call FUNC(yuruyusAlani) } else { [] };
        private _var = [];
        {
            _x params ["_c", "_a", "_b", "_dir", "_rect", "_modul"];
            private _id = netId _modul;
            _var pushBack _id;
            private _ad = _isaretler getOrDefault [_id, ""];
            if (_ad isEqualTo "") then {
                _ad = format ["ELITE_YURU_%1", _id];
                _isaretler set [_id, _ad];
                createMarkerLocal [_ad, _c];
                _ad setMarkerBrushLocal "SolidBorder";
                _ad setMarkerColorLocal "ColorOrange";
                _ad setMarkerAlphaLocal 0.5;
                _ad setMarkerTextLocal "Yurunebilir alan";
            };
            _ad setMarkerPosLocal _c;
            _ad setMarkerShapeLocal (["ELLIPSE", "RECTANGLE"] select _rect);
            _ad setMarkerSizeLocal [_a, _b];
            _ad setMarkerDirLocal _dir;
        } forEach _alanlar;
        // silinen / artik gosterilmeyen alanlarin isaretleri
        {
            if !(_x in _var) then { deleteMarkerLocal (_isaretler get _x); _isaretler deleteAt _x; };
        } forEach (keys _isaretler);
    };
};
true
