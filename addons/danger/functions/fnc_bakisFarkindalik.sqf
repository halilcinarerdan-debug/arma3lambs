#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BAKIS FARKINDALIGI (v8.693; kullanici: 'oyuncularin kendisine baktigini goren botlar siperde mikro duzeltecek ya da kacacak; oyuncunun anlik konumuna gore fazla yormayan bir raycast daha cizilsin; oyuncunun bakis acisindan bot bizim nereye baktigimizi gorunce bunlari yap').
 * Yalniz INSAN OYUNCU (bakis yonu: yerel oyuncuda getCameraViewDirection, uzak oyuncuda eyeDirection). 0.5 sn'de bir, oyuncu basina TEK isin (bakis dogrultusunda ilk engel; VIEW LOD) + bot basina ucuz aci hesabi:
 *   bot, oyuncunun bakis konisinde (bakisFarkAci, 5 derece) VE isin engeline gelmeden (bot mesafesi <= isin mesafesi + 4 m) VE oyuncu-bot gorus hatti acik VE bot oyuncuyu biliyor (knowsAbout >= SUPHE)
 *   ise 'bakiliyor' sayilir; bakisFarkBekle (0.8 sn) sureyle bakilirsa TEPKI (bot basina bakisFarkSure = 8 sn bekleme; tur basina en cok 6 tepki):
 *     bakisFarkKacisOran (0.3) olasilikla KACIS: oyuncu-bot hattina dik 12-18 m yan adim (oyuncu gozunden gizli olan taraf tercih edilir), 6 sn kilit;
 *     aksi halde SIPER MIKRO: fnc_acikSiper (oyuncuyu dusman alarak nesne / bina arkasi); olmazsa kisa sureli COMEL / YAT (4 sn).
 * ATLANIR: geri cekilme / temas kes / kacis / bounding / taktik kosucusu (forceMove), kilitli (taktikKilit), binada, esir / teslim, yem birimi, TCCC mesgul.
 * CBA: lambs_danger_bakisFarkAktif (varsayilan KAPALI), bakisFarkAci, bakisFarkMenzil, bakisFarkBekle, bakisFarkKacisOran, bakisFarkSure. Log: [BAKIS-FARK] (ilk 25) + [BAKIS-FARK-OZET] 60 sn.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_bakisFarkStarted") exitWith {false};
lambs_danger_bakisFarkStarted = true;
diag_log "[BAKIS-FARK] bakis farkindaligi (oyuncu bota bakinca bot siper mikro / kacis) baslatildi (v8.693)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["bakilan", 0], ["kacis", 0], ["siper", 0], ["comel", 0], ["atlandi", 0]];
    private _ozetT = time + 60;
    while {true} do {
        sleep 0.5;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if ((_say get "bakilan") + (_say get "kacis") + (_say get "siper") + (_say get "comel") > 0) then { diag_log format ["[BAKIS-FARK-OZET] 60 sn: tepki: kacis %1 | siper mikro %2 | comel / yat %3 | bakilip tepki verilmeyen (kilit / bina / tactic) %4", _say get "kacis", _say get "siper", _say get "comel", _say get "atlandi"]; };
            { _say set [_x, 0]; } forEach (keys _say);
        };
        if !(missionNamespace getVariable ["lambs_danger_bakisFarkAktif", false]) then { continue };
        private _aci = ((missionNamespace getVariable ["lambs_danger_bakisFarkAci", 5]) max 1) min 15;
        private _menzil = ((missionNamespace getVariable ["lambs_danger_bakisFarkMenzil", 350]) max 100) min 600;
        private _bekle = ((missionNamespace getVariable ["lambs_danger_bakisFarkBekle", 0.8]) max 0.2) min 3;
        private _kacisO = ((missionNamespace getVariable ["lambs_danger_bakisFarkKacisOran", 0.3]) max 0) min 1;
        private _cool = ((missionNamespace getVariable ["lambs_danger_bakisFarkSure", 8]) max 3) min 30;
        private _esik = ["SUPHE"] call FUNC(bilgiEsik);
        private _tepkiN = 0;
        {
            private _p = _x;
            if (!alive _p || {!isNull objectParent _p} || {(lifeState _p) in ["INCAPACITATED", "UNCONSCIOUS"]}) then { continue };
            private _eye = eyePos _p;
            private _dir = if (local _p) then { getCameraViewDirection _p } else { eyeDirection _p };
            if ((vectorMagnitude _dir) < 0.1) then { continue };
            _dir = vectorNormalized _dir;
            // oyuncu basina TEK isin: bakis dogrultusundaki ilk engel
            private _ray = lineIntersectsSurfaces [_eye, _eye vectorAdd (_dir vectorMultiply _menzil), _p, objNull, true, 1, "VIEW", "NONE"];
            private _hitD = if (_ray isEqualTo []) then { _menzil } else { _eye distance ((_ray select 0) select 0) };
            private _pSide = side group _p;
            {
                private _u = _x;
                if (_tepkiN >= 6) exitWith {};
                if (!local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {captive _u} || {(_pSide getFriend (side group _u)) >= 0.6}) then { continue };
                private _tgt = (getPosASL _u) vectorAdd [0, 0, 1.3];
                private _v = _tgt vectorDiff _eye;
                private _d = vectorMagnitude _v;
                if (_d < 5 || {_d > (_hitD + 4)}) then { continue };
                private _ac = acos ((((_dir vectorDotProduct _v) / _d) min 1) max -1);
                if (_ac > _aci) then {
                    if (!isNil {_u getVariable QGVAR(bakilmaT)} && {time > ((_u getVariable [QGVAR(bakilmaSon), 0]) + 1.5)}) then { _u setVariable [QGVAR(bakilmaT), nil]; };
                    continue
                };
                if ((terrainIntersectASL [_eye, _tgt]) || {lineIntersects [_eye, _tgt, _p, _u]} || {(_u knowsAbout _p) < _esik}) then { continue };
                _u setVariable [QGVAR(bakilmaSon), time];
                private _t0 = _u getVariable [QGVAR(bakilmaT), -1];
                if (_t0 < 0) then { _u setVariable [QGVAR(bakilmaT), time]; continue };
                if ((time - _t0) < _bekle) then { continue };
                if (time < (_u getVariable [QGVAR(bakisTepkiT), 0])) then { continue };
                private _g = group _u;
                if (
                    (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBounding), false]}
                    || {(_u getVariable [QGVAR(forceMove), false]) isEqualTo true} || {time < (_u getVariable [QGVAR(taktikKilit), 0])} || {(insideBuilding _u) > 0.5}
                    || {_u getVariable [QGVAR(teslim), false]} || {(_u getVariable [QGVAR(yemBirim), false]) isEqualTo true} || {time < (_u getVariable [QGVAR(tcccBusy), 0])}
                ) then { _say set ["atlandi", (_say get "atlandi") + 1]; _u setVariable [QGVAR(bakisTepkiT), time + 3]; continue };
                _u setVariable [QGVAR(bakisTepkiT), time + _cool];
                _u setVariable [QGVAR(bakilmaT), nil];
                _tepkiN = _tepkiN + 1;
                private _tepki = "";
                if ((random 1) < _kacisO) then {
                    // gorus hattindan cik: oyuncu-bot hattina dik yan adim, oyuncu gozunden gizli taraf tercih
                    private _perp = (_p getDir _u) + 90;
                    private _best = [];
                    {
                        private _c = (getPosATL _u) getPos [12 + (random 6), _perp + _x];
                        if (!surfaceIsWater _c && {((surfaceNormal _c) select 2) > 0.8}) then {
                            private _cA = AGLToASL (_c vectorAdd [0, 0, 1]);
                            private _gizli = (terrainIntersectASL [_eye, _cA]) || {lineIntersects [_eye, _cA, _p, objNull]};
                            if (_best isEqualTo [] || {_gizli && {!(_best select 1)}}) then { _best = [_c, _gizli]; };
                        };
                    } forEach [0, 180];
                    if (_best isNotEqualTo []) then {
                        _u setVariable [QGVAR(taktikKilit), time + 6];
                        _u forceSpeed -1;
                        _u setSpeedMode "FULL";
                        _u doMove (_best select 0);
                        _tepki = ["kacis (yan adim, oyuncuya gorunur)", "kacis (yan adim, oyuncu gozunden gizli)"] select (_best select 1);
                        _say set ["kacis", (_say get "kacis") + 1];
                    };
                } else {
                    if ([_u, _p] call FUNC(acikSiper)) then { _tepki = "siper mikro (acikSiper)"; _say set ["siper", (_say get "siper") + 1]; };
                };
                if (_tepki isEqualTo "") then {
                    _u setUnitPosWeak "DOWN";
                    [{ params ["_uu"]; if (alive _uu && {!((_uu getVariable [QGVAR(forceMove), false]) isEqualTo true)} && {!((group _uu) getVariable [QGVAR(isRetreating), false])}) then { _uu setUnitPosWeak "AUTO"; }; }, [_u], 4] call CBA_fnc_waitAndExecute;
                    _tepki = "comel / yat (yedek)";
                    _say set ["comel", (_say get "comel") + 1];
                };
                if (_logN < 25) then {
                    _logN = _logN + 1;
                    diag_log format ["[BAKIS-FARK] %1 | %2 | oyuncu %3 bakiyor: aci %4 derece, mesafe %5 m, isin %6 m | tepki: %7", groupId _g, name _u, name _p, _ac toFixed 1, round _d, round _hitD, _tepki];
                };
            } forEach (_p nearEntities ["CAManBase", _menzil]);
        } forEach allPlayers;
    };
};
true
