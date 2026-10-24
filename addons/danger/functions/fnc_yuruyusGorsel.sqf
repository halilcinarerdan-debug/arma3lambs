#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YURUNEBILIR ALAN GORSELI + DURUM RAPORU (v8.333; v8.335 renk / tarama) — kullanici: 'marker oyunda gozukmedi' + 'kullanimi kolay olsun, nerede ne koyabilecegimizi bilelim'.
 * Istemci (hasInterface), 3 sn'de bir: alan listesi (fnc_yuruyusAlani) icin YEREL harita isareti (ELITE_YURU_<id>; dikdortgen / elips) olusturur / gunceller / siler ve Zeus kamerasi icin 600 m icindeki alanlarin 3D cerceve + etiketini cizer.
 * v8.335 TARAMA: her alan fnc_yuruyusTara ile olculur (alan degisince ya da 60 sn'de bir) -> isaret + cerceve RENGI durumu gosterir:
 *   YESIL = TAMAM (yurunebilir, nesneli) | TURUNCU = UYARI (bazi noktalar 3 m ustu / bina var) | KIRMIZI = HATA (cogu tirmanilamaz / su / cok kucuk) | SARI = BOS (nesne yok - AI zaten yurur, alani nesneli hendegin USTUNE koy).
 *   Isaret metni + 3D etiket durumu ve ozeti yazar; durum DEGISINCE Zeus'a sohbet raporu (dakikada en cok 6): '[ELITE] Yurunebilir alan 090043: UYARI - ...'.
 * Gorunurluk: Zeus (curator atanmis) VEYA CBA 'Yurunebilir alanlari herkes gorsun' (lambs_danger_yuruGorunum) VEYA Eden onizleme (is3DENPreview). Diger oyuncular gormez. Kapatma: lambs_danger_yuruGorselOff = true.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!hasInterface) exitWith {false};
if (!isNil "lambs_danger_yuruGorselStarted") exitWith {false};
lambs_danger_yuruGorselStarted = true;
lambs_danger_yuruCiz = false;
lambs_danger_yuruDurum = createHashMap;   // modul netId -> [durum, kisa metin]

addMissionEventHandler ["Draw3D", {
    if (!lambs_danger_yuruCiz) exitWith {};
    private _kam = positionCameraToWorld [0, 0, 0];
    private _renkler = [[0.2, 0.9, 0.2, 1], [1, 0.55, 0, 1], [1, 0.15, 0.15, 1], [1, 0.9, 0.1, 1]];
    {
        _x params ["_c", "_a", "_b", "_dir", "_rect", "_modul"];
        if ((_kam distance2D _c) < 600) then {
            private _dr = lambs_danger_yuruDurum getOrDefault [netId _modul, [3, ""]];
            private _renk = _renkler select ((_dr select 0) min 3);
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
            drawIcon3D ["", _renk, ASLToAGL [(_c select 0), (_c select 1), (getTerrainHeightASL _c) + 2], 0, 0, 0, format ["Yurunebilir alan %1 x %2 m %3", round (_a * 2), round (_b * 2), _dr select 1], 2, 0.035, "RobotoCondensed", "center"];
        };
    } forEach (["LISTE"] call FUNC(yuruyusAlani));
}];

[] spawn {
    waitUntil { sleep 1; !isNull player };
    private _isaretler = createHashMap;   // modul netId -> isaret adi
    private _imza = createHashMap;        // modul netId -> [imza, tarama zamani]
    private _bildirim = [];               // sohbet raporu zamanlari
    private _renkAd = ["ColorGreen", "ColorOrange", "ColorRed", "ColorYellow"];
    private _kisa = ["TAMAM", "UYARI", "HATA", "BOS"];
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
            // ---- tarama (alan degisince / 60 sn'de bir) ----
            private _im = format ["%1_%2_%3_%4_%5_%6", round _a, round _b, round _dir, _rect, round (_c select 0), round (_c select 1)];
            private _eski = _imza getOrDefault [_id, ["", -999]];
            if ((_eski select 0) isNotEqualTo _im || {(time - (_eski select 1)) > 60}) then {
                private _rap = [_x] call FUNC(yuruyusTara);
                _imza set [_id, [_im, time]];
                private _once = lambs_danger_yuruDurum getOrDefault [_id, [-1, ""]];
                lambs_danger_yuruDurum set [_id, [_rap select 0, (_kisa select ((_rap select 0) min 3))]];
                if ((_once select 0) isNotEqualTo (_rap select 0) || {(_eski select 0) isNotEqualTo _im}) then {
                    _bildirim = _bildirim select {(time - _x) < 60};
                    if ((count _bildirim) < 6) then {
                        _bildirim pushBack time;
                        systemChat format ["[ELITE] Yurunebilir alan %1: %2", mapGridPosition _c, _rap select 1];
                    };
                    diag_log format ["[YURUYUS-ALANI] tarama %1: %2", mapGridPosition _c, _rap select 1];
                };
            };
            private _dr = lambs_danger_yuruDurum getOrDefault [_id, [3, ""]];
            private _ad = _isaretler getOrDefault [_id, ""];
            if (_ad isEqualTo "") then {
                _ad = format ["ELITE_YURU_%1", _id];
                _isaretler set [_id, _ad];
                createMarkerLocal [_ad, _c];
                _ad setMarkerBrushLocal "SolidBorder";
                _ad setMarkerAlphaLocal 0.5;
            };
            _ad setMarkerColorLocal (_renkAd select ((_dr select 0) min 3));
            _ad setMarkerTextLocal format ["Yurunebilir alan %1", _dr select 1];
            _ad setMarkerPosLocal _c;
            _ad setMarkerShapeLocal (["ELLIPSE", "RECTANGLE"] select _rect);
            _ad setMarkerSizeLocal [_a, _b];
            _ad setMarkerDirLocal _dir;
        } forEach _alanlar;
        // silinen / artik gosterilmeyen alanlarin isaretleri
        {
            if !(_x in _var) then { deleteMarkerLocal (_isaretler get _x); _isaretler deleteAt _x; _imza deleteAt _x; lambs_danger_yuruDurum deleteAt _x; };
        } forEach (keys _isaretler);
    };
};
true
