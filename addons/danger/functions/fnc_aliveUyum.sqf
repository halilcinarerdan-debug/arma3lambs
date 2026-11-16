#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ALIVE UYUMU (v8.561; kullanici: 'ALiVE populasyonu ile uyumlu hale getirme ayari ekle, wikilerini incele, ALiVE ile cakismasin').
 * NOT (kaynak): alivemod.com wiki'sine bu ortamdan ERISILEMEDI (ag izni yok); bilgi ALiVE'in KAYNAK KODUNDAN (github ALiVEOS/alive.os, addons/main CfgALiVEModConflicts.hpp + fnc_modConflicts.sqf, sys_profile, sys_aiskill, mil_cqb) cikarildi.
 *
 * ALIVE'IN KENDI TARAFI (kaynak kodda):
 *   - ALiVE (Required) modulunde 'Other AI mods' ayari GUARD (varsayilan) / WARN / OFF; LAMBS Danger algilanir (CfgPatches 'lambs_danger'); GUARD'da ALiVE'in yaptigi HER gruba (profil ile spawn, CQB, roadblock, IED pusu,
 *     Combat Support CAS / tasima / topcu) PUBLIC 'lambs_danger_disableGroupAI = true' koyar (oyuncu liderli grup haric); birimlere 'lambs_danger_disableAI = true' YALNIZ ALiVE'in 'Soldier Behaviour' (sys_aiskill AIBehaviour: siper / PATH / setUnitPos / doMove) acikken.
 *     Yani LAMBS: grup taktikleri kapali, her asker KENDI refleksini korur (ALiVE'in cumlesi: 'each soldier keeps his own LAMBS reactions, unless ALiVE's Soldier Behaviour is on').
 *   - ALiVE AI Skill modulu fraksiyon bazli beceri atar (recruit / regular / veteran / expert / custom): varsayilan beceri sistemimiz (fnc_varsayilanSkill) bunu EZERDI.
 *   - Profil sistemi: gruplar (despawn) silinir / (spawn) yeniden yaratilir; birimlerde profileID, CQB birimlerinde ALIVE_profileIgnore / ALIVE_cqb_instance, sivil ajanlarda agentID var.
 * BU FONKSIYON (CBA 'lambs_danger_aliveUyum': 0 Kapali | 1 Uyumlu [varsayilan] | 2 Tam el cekme; yalniz ALiVE yukluyse etkili):
 *   - Acilista ALiVE'i algilar (CfgPatches ALiVE_main / ALiVE_fnc_modConflicts) ve BIR KEZ [ALIVE-UYUM] yazar (ALiVE modConflicts modu, Soldier Behaviour, AI Skill).
 *   - Her 3 sn yerel AI gruplarini tarar: ALiVE'in grubu (fnc_aliveSahip) ELITE'in grup katmanlarindan CIKARILIR: grup lambs_danger_disableGroupAI = true (ALiVE Guard'in yaptigi AYNI anahtar; onceki deger saklanir; ELITE'in 48 yerdeki
 *     kontrolu + fnc_wpSahip + fnc_tactics bunu zaten sayiyor) -> ALiVE Guard WARN / OFF ya da isaretlemeyen ALiVE parcasi olsa bile OPCOM / profil gruplarinin emri bozulmaz. Oyunculu gruba dokunulmaz.
 *   - Mod 1: asker refleksleri KALIR (ALiVE kuralinin aynisi); ALiVE Soldier Behaviour aciksa ALiVE'in birimlerine lambs_danger_disableAI = true. Mod 2: ALiVE'in TUM birimlerine disableAI = true (ELITE hic dokunmaz).
 *   - Mod 0'a donulunce bizim koydugumuz isaretler eski haline alinir (ALiVE'in kendi Guard isareti korunur).
 *   - Ayrica: fnc_varsayilanSkill / fnc_dogrulukArtis / fnc_cqbKume / fnc_hedefSiper (ates tutma) / fnc_tankBilinenAtes ALiVE birimlerinde (fnc_aliveSahip) ya da disableGroupAI'li grupta calismaz.
 * Log: [ALIVE-UYUM] (acilis), [ALIVE-UYUM-OZET] (60 sn'de bir, degisiklik varsa).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_aliveUyumStarted") exitWith {false};
lambs_danger_aliveUyumStarted = true;

lambs_danger_aliveVar = (isClass (configFile >> "CfgPatches" >> "ALiVE_main")) || {!isNil "ALiVE_fnc_modConflicts"} || {isClass (configFile >> "CfgPatches" >> "alive_main")};
if (!lambs_danger_aliveVar) exitWith {
    diag_log "[ALIVE-UYUM] ALiVE yuklu degil: uyum katmani pasif";
    false
};

[] spawn {
    sleep 15;   // ALiVE modConflicts init'i 10 sn bekler
    private _mod = "?";
    { private _v = missionNamespace getVariable _x; if (!isNil "_v") exitWith { _mod = str _v; }; } forEach ["ALiVE_MODCONFLICTS_MODE", "ALIVE_MODCONFLICTS_MODE", "ALiVE_main_MODCONFLICTS_MODE"];
    private _sb = if (!isNil "ALiVE_fnc_AIBehaviour") then { str (["setting", ["behaviourEnabled", false]] call ALiVE_fnc_AIBehaviour) } else { "yok" };
    diag_log format ["[ALIVE-UYUM] ALiVE ALGILANDI | CBA aliveUyum=%1 (0 kapali / 1 uyumlu / 2 tam el cekme) | ALiVE 'Other AI mods' (modConflicts) modu: %2 | Soldier Behaviour: %3 | AI Skill modulu sinifi: %4 | ALiVE grubu = profileID / ALIVE_profileIgnore / ALIVE_cqb_instance / agentID isaretli",
        missionNamespace getVariable ["lambs_danger_aliveUyum", 1], _mod, _sb, ["yok", "var"] select (isClass (configFile >> "CfgPatches" >> "ALiVE_sys_aiskill"))];
    private _isaretli = 0;
    private _geriAlinan = 0;
    private _logN = 0;
    private _ozetT = time + 60;
    while {true} do {
        sleep 3;
        private _mode = missionNamespace getVariable ["lambs_danger_aliveUyum", 1];
        private _sbAcik = (!isNil "ALiVE_fnc_AIBehaviour") && {["setting", ["behaviourEnabled", false]] call ALiVE_fnc_AIBehaviour};
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {(units _g) isEqualTo []}) then { continue };
            private _bizim = _g getVariable [QGVAR(aliveSahip), false];
            if (_mode isEqualTo 0) then {
                if (_bizim) then {
                    // eski haline al (ALiVE'in kendi Guard isareti varsa korunur: eski deger true saklanmisti)
                    _g setVariable [QGVAR(disableGroupAI), [nil, true] select (_g getVariable [QGVAR(aliveEskiDGA), false]), true];
                    _g setVariable [QGVAR(aliveSahip), nil];
                    { _x setVariable [QGVAR(disableAI), [nil, true] select (_x getVariable [QGVAR(aliveEskiDAI), false])]; } forEach (units _g);
                    _geriAlinan = _geriAlinan + 1;
                };
                continue
            };
            if (((units _g) findIf {isPlayer _x}) > -1) then { continue };
            if (!_bizim && {!([_g] call FUNC(aliveSahip))}) then { continue };
            if (!_bizim) then {
                _g setVariable [QGVAR(aliveEskiDGA), _g getVariable [QGVAR(disableGroupAI), false]];
                _g setVariable [QGVAR(disableGroupAI), true, true];
                _g setVariable [QGVAR(aliveSahip), true];
                _isaretli = _isaretli + 1;
                if (_logN < 15) then {
                    _logN = _logN + 1;
                    diag_log format ["[ALIVE-UYUM] %1 %2 | ALiVE grubu -> ELITE grup katmanlari KAPALI (lambs_danger_disableGroupAI) | onceki deger %3 (true ise ALiVE Guard zaten koymustu) | asker %4 | mod %5", str (side _g), groupId _g, _g getVariable [QGVAR(aliveEskiDGA), false], count (units _g), _mode];
                };
            };
            // birim duzeyi: mod 2 her zaman; mod 1 yalniz ALiVE Soldier Behaviour acikken (ALiVE Guard'in kurali)
            if (_mode isEqualTo 2 || {_sbAcik}) then {
                {
                    if (alive _x && {isNil {_x getVariable QGVAR(aliveEskiDAI)}}) then {
                        _x setVariable [QGVAR(aliveEskiDAI), _x getVariable [QGVAR(disableAI), false]];
                        _x setVariable [QGVAR(disableAI), true];
                    };
                } forEach (units _g);
            };
        } forEach allGroups;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (_isaretli > 0 || {_geriAlinan > 0}) then {
                diag_log format ["[ALIVE-UYUM-OZET] 60 sn: yeni isaretlenen ALiVE grubu %1 | geri alinan %2 | mod %3 | Soldier Behaviour %4", _isaretli, _geriAlinan, _mode, _sbAcik];
            };
            _isaretli = 0; _geriAlinan = 0;
        };
    };
};
true
