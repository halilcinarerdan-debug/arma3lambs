#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * LAMBS TURRETS TELAFISI (v8.369; kullanici: 'lambs suppression ve lambs turrets kullaniyorum, sistemi onlarla entegre et').
 *
 * LAMBS Turrets (nk3nny/LambsMods addons/turrets/config.cpp, SQF YOK, yalniz config) arac silahlarini AI icin KASITLI kotulestirir: LMG_RCWS / HMG_127 / LMG_coax aiDispersionCoefX/Y 5-7 (close/short/medium/far 6 / 7),
 *   autocannon_Base_F 6 / 5, CfgBrains maxAngularErrorTurrets 0.15, ve aiBurstTerminable = 0 (ates serisi hedef olse bile KESILEMEZ: uzun seri). Sonuc: tank DISINDaki silahli araclar (IFV / APC / HMG'li arac) ve statik silahlar
 *   (HMG / GMG) hedefi iskaliyor. Tanklarin ekibi zaten fnc_tankIzle ile becerisi >= 0.95'e cekiliyor ([TANK-ATIS]); digerlerinin yok.
 * BU MODUL yalniz LAMBS Turrets YUKLUYSE (CfgPatches lambs_turrets) calisir: tank / hava DISI, AI muretttebatli silahli araclar ve statik silahlarin YEREL AI muretttebatinin aimingAccuracy / aimingShake / aimingSpeed becerisini
 *   CBA tabana (lambs_danger_turretEkipSkill, varsayilan 0.85) YUKSELTIR (yalniz artar). Dispersiyon katsayisi config'te oldugu icin bu TELAFIDIR, tam esitleme degil.
 * Aracin ates serisi KESILEMEZ oldugu icin mermi israfi mod tasarimidir; bu modul ona dokunmaz (not: DOGRULANMAYANLAR).
 * 5 sn'de bir tarama; asker basina bir kez. Kapatma: CBA 'ELITE siper' > LAMBS Turrets telafisi (lambs_danger_turretEkipAktif). Log: [TURRET-EKIP] (ilk 20).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_turretEkipStarted") exitWith {false};
lambs_danger_turretEkipStarted = true;

if (!isClass (configFile >> "CfgPatches" >> "lambs_turrets")) exitWith {
    diag_log "[TURRET-EKIP] LAMBS Turrets yuklu degil -> telafi modulu kapali";
    false
};
diag_log "[TURRET-EKIP] LAMBS Turrets algilandi: tank/hava disi silahli arac + statik silah muretttebati beceri tabanina cekilecek (v8.369)";

[] spawn {
    private _logN = 0;
    while {true} do {
        sleep 5;
        if (!(missionNamespace getVariable ["lambs_danger_turretEkipAktif", true])) then { continue };
        private _sk = missionNamespace getVariable ["lambs_danger_turretEkipSkill", 0.85];
        if (_sk <= 0) then { continue };
        {
            private _v = _x;
            {
                private _u = _x;
                if (!isPlayer _u && {local _u} && {alive _u} && {!(_u getVariable [QGVAR(turretEkipU), false])}) then {
                    _u setVariable [QGVAR(turretEkipU), true];
                    private _once = _u skill "aimingShake";
                    { if ((_u skill _x) < _sk) then { _u setSkill [_x, _sk]; }; } forEach ["aimingAccuracy", "aimingShake", "aimingSpeed"];
                    if (_logN < 20) then {
                        _logN = _logN + 1;
                        diag_log format ["[TURRET-EKIP] %1 | %2 (%3) | aimingShake %4 -> %5 (taban %6)", getText (configOf _v >> "displayName"), name _u, groupId (group _u), _once toFixed 2, (_u skill "aimingShake") toFixed 2, _sk];
                    };
                };
            } forEach (crew _v);
        } forEach (vehicles select {
            local _x && {alive _x} && {!(_x isKindOf "Tank")} && {!(_x isKindOf "Air")} && {!(_x isKindOf "Ship")}
            && {(_x isKindOf "StaticWeapon") || {(count (allTurrets [_x, false])) > 0}}
            && {((crew _x) findIf {!isPlayer _x && {alive _x}}) > -1}
        });
    };
};

true
