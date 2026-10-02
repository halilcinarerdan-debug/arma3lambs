#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ORTAM BECERI DUSUSU (in-the-box; CF_BAI benzeri) — AI alt becerileri ortam kosullarina gore dinamik azalir:
 *   gece (NVG'siz agir, NVG'li az), sis, yagmur, bitki ortusu (X^2, CF_BAI'deki gibi dogrusal degil), baski, yara, yorgunluk.
 *
 * Etkilenen alt beceriler (taban deger ilk dokunusta saklanir, her zaman TABAN x carpan uygulanir):
 *   spotDistance, spotTime, aimingAccuracy, aimingShake, aimingSpeed
 *
 * Carpanlar (S = lambs_danger_ortamSkillOlcek, varsayilan 1):
 *   gece    : n = 1 - sunOrMoon; ceza = n x (NVG varsa 0.10, yoksa 0.45) x S
 *   sis     : fog x 0.5 (spotDistance), x 0.2 (nisan)
 *   yagmur  : rain x 0.15 (spotDistance)
 *   bitki   : (min(25 m'deki agac/cali sayisi / 18, 1))^2 x 0.30 x S   (CF_BAI'daki gibi: yarim yogunluk %25 dusurur)
 *   baski   : min(getSuppression, 1) x 0.45 (nisan), x 0.31 (titreme)
 *   yara    : damage x 0.5 (nisan)       yorgunluk: getFatigue x 0.3 (titreme / hiz)
 *   alt sinir: taban x 0.35
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
    private _beceriler = ["spotDistance", "spotTime", "aimingAccuracy", "aimingShake", "aimingSpeed"];
    while {true} do {
        sleep 3;
        if (!(missionNamespace getVariable ["lambs_danger_ortamSkillV1", true])) then { continue };
        if (_cfbai && {!(missionNamespace getVariable ["lambs_danger_ortamSkillZorla", false])}) then { continue };

        private _S = missionNamespace getVariable ["lambs_danger_ortamSkillOlcek", 1];
        private _gece = (1 - sunOrMoon) max 0;
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

            private _nvg = (hmd _u) isNotEqualTo "";
            private _geceCeza = _gece * ([0.45, 0.10] select _nvg) * _S;
            private _nesne = count (nearestTerrainObjects [_u, ["TREE", "SMALL TREE", "BUSH"], 25, false, true]);
            private _bitki = (((_nesne / 18) min 1) ^ 2) * 0.30 * _S;
            private _bsk = (getSuppression _u) min 1;
            private _yara = (damage _u) min 1;
            private _yorgun = (getFatigue _u) min 1;

            private _mSD = (1 - _geceCeza) * (1 - (_sis * 0.5 * _S)) * (1 - (_yagmur * 0.15 * _S)) * (1 - _bitki);
            private _mST = (1 - (_geceCeza * 0.7)) * (1 - (_sis * 0.25 * _S)) * (1 - (_bitki * 0.5));
            private _mAA = (1 - (_geceCeza * 0.6)) * (1 - (_sis * 0.2 * _S)) * (1 - _bitki) * (1 - (_bsk * 0.45 * _S)) * (1 - (_yara * 0.5));
            private _mSH = (1 - (_geceCeza * 0.3)) * (1 - (_bsk * 0.31 * _S)) * (1 - (_yorgun * 0.3)) * (1 - (_yara * 0.25));
            private _mSP = (1 - (_geceCeza * 0.4)) * (1 - (_yorgun * 0.3)) * (1 - (_bsk * 0.22 * _S));
            private _carpanlar = [_mSD, _mST, _mAA, _mSH, _mSP] apply {_x max 0.35};

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
                    diag_log format ["[ORTAM-SKILL] %1 | gece:%2 nvg:%3 sis:%4 yagmur:%5 bitki:%6 (%7 nesne) baski:%8 yara:%9 | carpan spotD:%10 aim:%11 shake:%12", name _u, _gece toFixed 2, _nvg, _sis toFixed 2, _yagmur toFixed 2, _bitki toFixed 2, _nesne, _bsk toFixed 2, _yara toFixed 2, _mSD toFixed 2, _mAA toFixed 2, _mSH toFixed 2];
                };
            };
        };
        _indeks = _indeks + _kesit;
    };
};

true
