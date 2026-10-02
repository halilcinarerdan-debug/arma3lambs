// ===========================================================================
// NE BULACAKSIN — PREP KAYIT KONTROLU
// ===========================================================================
// Yeni fonksiyon `tacticsBounding` burada PREP edilmeli.
// Eksikse: RPT'de "lambs_danger_fnc_tacticsBounding is not defined" hatasi.
// Dogruysa : fnc_tactics.sqf'ten cagirabilirsin.
// Kontrol  : HEMTT build sonrasi ".hemttout" icinde
//            "fnc_tacticsBounding.sqf" ciktisi var mi?
// ===========================================================================

PREP(brain);
PREP(brainAdjust);
PREP(brainAssess);
PREP(brainEngage);
PREP(brainForced);
PREP(brainHide);
PREP(brainReact);
PREP(brainVehicle);
PREP(fsmAllowAnimation);
PREP(isForced);
PREP(isForcedExit);
PREP(isLeader);

PREP(contact);

PREP(tactics);
PREP(commanderAssess);
PREP(splitFireTeams);
PREP(getUnitRole);
PREP(buddyPairs);
PREP(tacticalSmoke);
PREP(classifyVehicle);
PREP(armorSupport);
PREP(tacticsRetreat);
PREP(tacticsPeel);
PREP(tacticsEvadeArmor);
PREP(tacticsATEngage);
PREP(tacticsBreakContact);
PREP(dispersion);
PREP(buddyBond);
PREP(leaderSync);
PREP(firedHub);
PREP(soundAwareness);
PREP(cqbReflex);
PREP(isSniper);
PREP(sniperTeam);
PREP(buildingClear);
PREP(buildingClearRun);
PREP(coverHug);
PREP(rpgReaction);
PREP(fireSupport);
PREP(buddyDebug);
PREP(hasUGL);
PREP(roleStation);
PREP(reloadCover);
PREP(grenadeAwareness);
PREP(tacticalUGL);
PREP(isATUnit);
PREP(atFire);
PREP(orphanWatchdog);
PREP(tacticsAssault);
PREP(tacticsBounding);
PREP(selectFormation);
PREP(commanderFormation);
PREP(moveAssist);
PREP(fireLine);
PREP(tacticsAssess);
PREP(tacticsAttack);
PREP(tacticsCQB);
PREP(tacticsFlank);
PREP(tacticsGarrison);
PREP(tacticsHide);
PREP(tacticsHold);
PREP(tacticsProfiles);
PREP(tacticsReinforce);
PREP(tacticsSuppress);
PREP(eliteCover);

SUBPREP(ZeusModules,moduleConfigureGroupAI);
SUBPREP(ZeusModules,moduleDisableAI);
SUBPREP(ZeusModules,moduleSetRadio);

SUBPREP(ZEN,setDisableAI);
SUBPREP(ZEN,setDisableGroupAI);
SUBPREP(ZEN,setHasRadio);
SUBPREP(ZEN,setReinforcement);
SUBPREP(ZEN,showHasRadio);
SUBPREP(ZEN,showReinforcement);
SUBPREP(ZEN,showSetDisableAI);
SUBPREP(ZEN,showSetDisableGroupAI);

// ===========================================================================
// ELITE-BOOT — dagitim dogrulamasi + watchdog'lari ilk temasi beklemeden baslat
// (bu dosya XEH_preInit'e include edilir: asagidaki satirlar acilista RPT'ye yazar,
//  LAMBS debug acik olmasa da gorunur)
// ===========================================================================
diag_log "[ELITE-BOOT] lambs_danger ELITE build v7.10 (ates hatti + hizli retreat + donus x1.2 + duvar korumasi + sikisma + komutan formasyon + lider arkada) yuklendi (XEH_PREP preInit)";
[{
    // HER makinede: Zeus'la yaratilan AI'lar istemcide yerel olur; watchdog'lar yalnizca YEREL gruplara dokunur
    if (true) then {
        private _fns = [
            "tactics", "commanderAssess", "tacticsBounding", "tacticsRetreat", "tacticsEvadeArmor", "tacticsATEngage",
            "tacticsBreakContact", "roleStation", "buddyBond", "dispersion", "reloadCover", "grenadeAwareness",
            "leaderSync", "firedHub", "soundAwareness", "cqbReflex", "isSniper", "sniperTeam", "buildingClear", "buildingClearRun", "coverHug", "rpgReaction", "fireSupport", "buddyDebug", "tacticalUGL", "tacticalSmoke", "getUnitRole", "buddyPairs", "commanderFormation", "moveAssist"
        ];
        diag_log format [
            "[ELITE-BOOT] makine: isServer=%1 hasInterface=%2 | fonksiyonlar: %3",
            isServer, hasInterface,
            _fns apply {format ["%1=%2", _x, !isNil (format ["lambs_danger_fnc_%1", _x])]}
        ];

        // watchdog'lar ilk temasta degil, acilista baslasin
        {
            [] call (missionNamespace getVariable [format ["lambs_danger_fnc_%1", _x], {false}]);
        } forEach ["firedHub", "buddyDebug", "dispersion", "buddyBond", "leaderSync", "roleStation", "reloadCover", "grenadeAwareness", "cqbReflex", "sniperTeam", "buildingClear", "coverHug", "fireSupport", "commanderFormation", "moveAssist", "fireLine"];

        // nabiz: 60 sn'de bir (yerel AI grubu varsa) — temas / taktik bayraklari RPT'de gorunsun
        [] spawn {
            while {true} do {
                sleep 60;
                private _gr = allGroups select {local _x && {!isNull leader _x} && {!isPlayer leader _x} && {({alive _x} count units _x) > 0}};
                if (_gr isNotEqualTo []) then {
                    diag_log format [
                        "[ELITE-HB] t=%1 | yerel AI grup:%2 | temasta:%3 | bounding:%4 retreat:%5 evade:%6 atEngage:%7 breakContact:%8 | disableGroupAI:%9 | lambs_debug:%10",
                        round time, count _gr,
                        {(_x getVariable ["lambs_danger_contact", 0]) > time} count _gr,
                        {_x getVariable ["lambs_danger_isBounding", false]} count _gr,
                        {_x getVariable ["lambs_danger_isRetreating", false]} count _gr,
                        {_x getVariable ["lambs_danger_isEvading", false]} count _gr,
                        {_x getVariable ["lambs_danger_isATEngage", false]} count _gr,
                        {_x getVariable ["lambs_danger_isBreakingContact", false]} count _gr,
                        {_x getVariable ["lambs_danger_disableGroupAI", false]} count _gr,
                        missionNamespace getVariable ["lambs_main_debug_Functions", "ayar yok"]
                    ];
                };
            };
        };
    };
}, [], 8] call CBA_fnc_waitAndExecute;
