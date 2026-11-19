#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * FOV OLCUMU (v8.669; yol haritasi Asama 12 madde 13; kullanici: 'askerlerin fovlarini gercekci hale getirmeyi de ekle' -> ONCE OLC, sonra karar): DAVRANIS DEGISTIRMEZ, yalniz RPT'ye sayi yazar.
 *
 * SORU: AI, bakmadigi yondeki (yan / arka) dusmani da bakiyormus gibi ayni oranda biliyor mu? Insan: net merkezi gorus dar (~+-30 derece), cevresel gorus ~+-100-120 derece, arka kor;
 *   Arma AI'sinda sert bir gorus konisi yok, 'knowsAbout' mesafe / gorunurluk / isik ile artar.
 * YONTEM (3 sn'de bir; en cok 25 asker): grubu temasli (60 sn) yerel AI piyade -> en yakin dusman (15-250 m) ->
 *   bakis acisi = |goz yonu (eyeDirection) ile dusman yonu arasi aci|; gorus hatti ACIK (arazi + nesne) ciftler 5 kovaya (0-30 / 30-60 / 60-90 / 90-120 / 120-180 derece) sayilir;
 *   her kovada 'bilen' = knowsAbout >= SUPHE (0.5) ve >= TESPIT (0.8) orani. Sadece HAT ACIK cift sayilir (hat kapaliysa bilmemesi gorus konisiyle ilgili degil).
 * YORUM: oranlar kovalar arasinda yaklasik esitse (ornegin 120-180 derece >= %70 bilen) AI arkasini da goruyor = gercekci FOV yok; 0-30 -> 120-180 arasi belirgin dusus = FOV benzeri bir algi var.
 *   Karar (FOV uygulansin mi, hangi daralma): bu olcumden sonra.
 * CBA: lambs_danger_fovOlcum (acik / kapali). Log: [FOV-OLCUM] 60 sn ozeti (en az 20 cift varsa).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_fovOlcumStarted") exitWith {false};
lambs_danger_fovOlcumStarted = true;

diag_log "[FOV-OLCUM] FOV olcumu (bakis acisi kovalarina gore bilinen dusman orani; davranis degistirmez) baslatildi (v8.669)";

[] spawn {
    private _kova = [[0, 30], [30, 60], [60, 90], [90, 120], [120, 181]];
    private _n = _kova apply {0};
    private _b1 = _kova apply {0};
    private _b2 = _kova apply {0};
    private _ozetT = time + 60;
    while {true} do {
        sleep 3;
        if !(missionNamespace getVariable ["lambs_danger_fovOlcum", true]) then { continue };
        private _e1 = ["SUPHE"] call FUNC(bilgiEsik);
        private _e2 = ["TESPIT"] call FUNC(bilgiEsik);
        private _k = 0;
        {
            private _u = _x;
            if (_k >= 25) exitWith {};
            if (
                !local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}
                || {captive _u} || {(insideBuilding _u) > 0.5} || {((group _u) getVariable [QGVAR(contact), 0]) < (time - 60)}
            ) then { continue };
            private _e = _u findNearestEnemy _u;
            if (isNull _e || {!alive _e} || {!(_e isKindOf "CAManBase")}) then { continue };
            private _d = _u distance2D _e;
            if (_d < 15 || {_d > 250}) then { continue };
            private _eye = eyePos _u;
            private _eEye = eyePos _e;
            if ((terrainIntersectASL [_eye, _eEye]) || {lineIntersects [_eye, _eEye, _u, _e]}) then { continue };
            _k = _k + 1;
            private _ed = eyeDirection _u;
            private _gaz = (_ed select 0) atan2 (_ed select 1);
            private _ang = abs ((((_u getDir _e) - _gaz) + 540) mod 360 - 180);
            private _i = _kova findIf { _ang >= (_x select 0) && {_ang < (_x select 1)} };
            if (_i < 0) then { continue };
            private _kn = _u knowsAbout _e;
            _n set [_i, (_n select _i) + 1];
            if (_kn >= _e1) then { _b1 set [_i, (_b1 select _i) + 1]; };
            if (_kn >= _e2) then { _b2 set [_i, (_b2 select _i) + 1]; };
        } forEach allUnits;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_n select 0) + (_n select 1) + (_n select 2) + (_n select 3) + (_n select 4)) >= 20) then {
                private _sat = [];
                {
                    private _c = _n select _forEachIndex;
                    private _y1 = if (_c > 0) then { round (100 * (_b1 select _forEachIndex) / _c) } else { 0 };
                    private _y2 = if (_c > 0) then { round (100 * (_b2 select _forEachIndex) / _c) } else { 0 };
                    _sat pushBack format ["%1-%2 derece: %3 cift, bilen %4 %% (suphe) / %5 %% (tespit)", _x select 0, (_x select 1) min 180, _c, _y1, _y2];
                } forEach _kova;
                diag_log format ["[FOV-OLCUM] 60 sn (hatti acik dusman 15-250 m): %1", _sat joinString " | "];
            };
            _n = _kova apply {0};
            _b1 = _kova apply {0};
            _b2 = _kova apply {0};
        };
    };
};
true
