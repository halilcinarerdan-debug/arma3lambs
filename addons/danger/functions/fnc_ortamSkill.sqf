#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ORTAM BECERI DUSUSU v2 (in-the-box; CF_BAI'den SADELESTIRILMIS) — 3 etken, 4 alt beceri:
 *
 *   1) BITKI ORTUSU (CF_BAI ile ayni fikir ve rakamlar): askerin 25 m cevresindeki agac / cali sayisi, 30 nesne = tam; kayip X^2:
 *        carpan = 1 - (1 - min) x x^2   (x = min(sayi/30, 1));  min: spotDistance 0.35, aimingAccuracy 0.41
 *   2) GORUS KOSULU (gece NVG'siz / sis): spotDistance ve spotTime icin
 *        gece n = 1 - sunOrMoon;  NVG'siz: spotDistance 1 - 0.6 n, spotTime 1 - 0.4 n;  NVG'li: 1 - 0.1 n
 *        sis f = fog: spotDistance x (1 - 0.5 f), spotTime x (1 - 0.25 f)
 *   3) BASKI (hafif; motor zaten nisani dusurur): min(getSuppression, 1) -> aimingAccuracy x (1 - 0.35 s), aimingShake x (1 - 0.30 s)
 *   alt sinir taban x 0.30
 *
 * CF_BAI'den BILEREK ALINMAYANLAR: courage / commanding / reloadSpeed / general (FSM ve komutan beynimiz var), yara + yorgunluk (ACE / motor zaten),
 *   yagmur (etkisi kucuk), arka arkaya atis boost'u (en fazla x1.10, ihmal edilebilir), oyuncu gruplarina gore ozel etki.
 *
 * Taban deger ilk dokunusta saklanir; her zaman TABAN x carpan uygulanir. Olcek: lambs_danger_ortamSkillOlcek (1 = varsayilan, 0 = etkisiz).
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
    private _beceriler = ["spotDistance", "spotTime", "aimingAccuracy", "aimingShake"];
    while {true} do {
        sleep 3;
        if (!(missionNamespace getVariable ["lambs_danger_ortamSkillV1", true])) then { continue };
        if (_cfbai && {!(missionNamespace getVariable ["lambs_danger_ortamSkillZorla", false])}) then { continue };

        private _S = missionNamespace getVariable ["lambs_danger_ortamSkillOlcek", 1];
        private _gece = (1 - sunOrMoon) max 0;
        private _sis = (fog min 1) max 0;

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
            private _nesne = count (nearestTerrainObjects [_u, ["TREE", "SMALL TREE", "BUSH"], 25, false, true]);
            private _x2 = (((_nesne / 30) min 1) ^ 2) * _S;
            private _bsk = ((getSuppression _u) min 1) * _S;
            private _gCeza = _gece * ([0.6, 0.1] select _nvg) * _S;

            private _mSD = (1 - ((1 - 0.35) * _x2)) * (1 - _gCeza) * (1 - (_sis * 0.5 * _S));
            private _mST = (1 - (_gCeza * 0.67)) * (1 - (_sis * 0.25 * _S));
            private _mAA = (1 - ((1 - 0.41) * _x2)) * (1 - (_bsk * 0.35));
            private _mSH = (1 - (_bsk * 0.30));
            private _carpanlar = [_mSD, _mST, _mAA, _mSH] apply {_x max 0.30};

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
                    diag_log format ["[ORTAM-SKILL] %1 | gece:%2 nvg:%3 sis:%4 | bitki:%5 nesne x^2:%6 | baski:%7 | carpan spotD:%8 spotT:%9 aim:%10 shake:%11", name _u, _gece toFixed 2, _nvg, _sis toFixed 2, _nesne, _x2 toFixed 2, _bsk toFixed 2, _mSD toFixed 2, _mST toFixed 2, _mAA toFixed 2, _mSH toFixed 2];
                };
            };
        };
        _indeks = _indeks + _kesit;
    };
};

true
