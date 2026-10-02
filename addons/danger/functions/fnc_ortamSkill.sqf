#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ORTAM BECERI DUSUSU v3 (in-the-box) — SADECE ORTAM (isik + gorus cihazi + hava); baski LAMBS'te, bitki ortusu kullanici modunda.
 *
 * Etkilenen: spotDistance (asil), spotTime, aimingAccuracy (hafif). Taban deger ilk dokunusta saklanir; her zaman TABAN x carpan.
 *
 * GORUS CIHAZI (askerin NVG / termal gozlugu + birincil silah optigi; sinif config'inden visionMode: "NVG" / "Ti"):
 *   YOK / normal : isik cezasi tam  | NVG: isik cezasi kucuk (FOV / parazit)  | TERMAL: isik cezasi YOK (gece de gorur)
 * ISIK  n = (1 - sunOrMoon) + 0.25 x overcast x sunOrMoon  (kapali / firtinali gunduz biraz karanlik), en fazla 1
 *   spotDistance carpani: normal 1 - 0.60 n | NVG 1 - 0.15 n | termal 1
 * HAVA (cihaza gore):
 *   sis f     : normal / NVG 1 - 0.55 f | termal 1 - 0.25 f
 *   yagmur r  : normal 1 - 0.25 r | NVG 1 - 0.35 r (parazit / hale) | termal 1 - 0.20 r (su sogurur)
 * spotTime  = 1 - 0.6 x (1 - spotDistance carpani);  aimingAccuracy = 1 - 0.3 x (1 - spotDistance carpani);  alt sinir x0.25
 * Cihaz tipi sinif basina onbellekte (hashmap). Olcek: lambs_danger_ortamSkillOlcek (1 varsayilan, 0 etkisiz).
 *
 * CF_BAI (ya da baska beceri modu) yuklu ise CAKISMA olmasin diye KAPALI baslar (RPT'de uyari);
 * lambs_danger_ortamSkillZorla = true ile zorla acilir. Genel kapatma: lambs_danger_ortamSkillV1 = false.
 * Her 3 sn'de en fazla 25 yerel, oyuncusuz AI askeri (donusumlu). Log: [ORTAM-SKILL] (ilk 40 degisim).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_ortamSkillStarted") exitWith {false};
lambs_danger_ortamSkillStarted = true;

private _cfbai = (configProperties [configFile >> "CfgPatches", "((toLower configName _x) find 'cf_bai') >= 0", true]) isNotEqualTo [];
diag_log format ["[ORTAM-SKILL] ortam beceri dususu baslatildi | CF_BAI algilandi:%1 | %2", _cfbai, ["aktif", "CAKISMA ONLEME: kapali (lambs_danger_ortamSkillZorla = true ile zorla)"] select _cfbai];

[_cfbai] spawn {
    params ["_cfbai"];
    private _indeks = 0;
    private _beceriler = ["spotDistance", "spotTime", "aimingAccuracy"];
    private _cihazOnb = createHashMap;
    // cihaz sinifi -> 0 normal, 1 NVG, 2 termal (CfgWeapons visionMode / OpticsModes)
    private _cihazTipi = {
        params ["_sinif"];
        if (_sinif isEqualTo "") exitWith {0};
        private _kay = _cihazOnb getOrDefault [_sinif, -1];
        if (_kay > -1) exitWith {_kay};
        private _cfg = configFile >> "CfgWeapons" >> _sinif;
        private _modlar = getArray (_cfg >> "visionMode");
        {
            _modlar append (getArray (_x >> "visionMode"));
        } forEach (configProperties [_cfg >> "ItemInfo" >> "OpticsModes", "isClass _x", true]);
        private _t = 0;
        if ("NVG" in _modlar) then { _t = 1; };
        if ("Ti" in _modlar) then { _t = 2; };
        _cihazOnb set [_sinif, _t];
        _t
    };
    while {true} do {
        sleep 3;
        if (!(missionNamespace getVariable ["lambs_danger_ortamSkillV1", true])) then { continue };
        if (_cfbai && {!(missionNamespace getVariable ["lambs_danger_ortamSkillZorla", false])}) then { continue };

        private _S = missionNamespace getVariable ["lambs_danger_ortamSkillOlcek", 1];
        private _sis = (fog min 1) max 0;
        private _yagmur = (rain min 1) max 0;

        private _askerler = [];
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {(side _g) isEqualTo civilian}) then { continue };
            if ((units _g) findIf {isPlayer _x} > -1) then { continue };
            { if (alive _x && {local _x}) then { _askerler pushBack _x; }; } forEach (units _g);
        } forEach allGroups;
        private _n = count _askerler;
        if (_n isEqualTo 0) then { continue };
        private _kesit = 25 min _n;

        for "_i" from 0 to (_kesit - 1) do {
            private _u = _askerler select ((_indeks + _i) mod _n);
            private _taban = _u getVariable [QGVAR(ortamTaban), []];
            if (_taban isEqualTo []) then {
                _taban = _beceriler apply {_u skill _x};
                _u setVariable [QGVAR(ortamTaban), _taban];
                _u setVariable [QGVAR(ortamSon), +_taban];
            };

            // gorus cihazi: gozluk + birincil silah optigi, en iyisi (termal > NVG > normal)
            private _optik = (primaryWeaponItems _u) param [2, ""];
            private _cihaz = ([hmd _u] call _cihazTipi) max ([_optik] call _cihazTipi);
            private _kapali = ([0, 0.25] select (sunOrMoon > 0.5)) * (overcast min 1);
            private _isik = (((1 - sunOrMoon) + (_kapali * sunOrMoon)) min 1) max 0;
            private _isikCeza = _isik * ([0.60, 0.15, 0] select _cihaz);
            private _sisCeza = _sis * ([0.55, 0.55, 0.25] select _cihaz);
            private _yagCeza = _yagmur * ([0.25, 0.35, 0.20] select _cihaz);
            private _mSD = (1 - (_isikCeza * _S)) * (1 - (_sisCeza * _S)) * (1 - (_yagCeza * _S));
            private _mST = 1 - (0.6 * (1 - _mSD));
            private _mAA = 1 - (0.3 * (1 - _mSD));
            private _carpanlar = [_mSD, _mST, _mAA] apply {_x max 0.25};

            private _son = _u getVariable [QGVAR(ortamSon), _taban];
            private _yeni = [];
            private _degisti = false;
            {
                private _v = (_taban select _forEachIndex) * (_carpanlar select _forEachIndex);
                _yeni pushBack _v;
                if ((abs (_v - (_son select _forEachIndex))) >= 0.02) then {
                    _u setSkill [_x, _v];
                    _degisti = true;
                } else {
                    _yeni set [_forEachIndex, _son select _forEachIndex];
                };
            } forEach _beceriler;

            if (_degisti) then {
                _u setVariable [QGVAR(ortamSon), _yeni];
                if (isNil "lambs_danger_ortamLogN") then { lambs_danger_ortamLogN = 0; };
                if (lambs_danger_ortamLogN < 40) then {
                    lambs_danger_ortamLogN = lambs_danger_ortamLogN + 1;
                    diag_log format ["[ORTAM-SKILL] %1 | isik:%2 cihaz:%3 (%4) sis:%5 yagmur:%6 | carpan spotD:%7 spotT:%8 aim:%9", name _u, _isik toFixed 2, _cihaz, ["normal", "NVG", "termal"] select _cihaz, _sis toFixed 2, _yagmur toFixed 2, _mSD toFixed 2, _mST toFixed 2, _mAA toFixed 2];
                };
            };
        };
        _indeks = _indeks + _kesit;
    };
};

true
