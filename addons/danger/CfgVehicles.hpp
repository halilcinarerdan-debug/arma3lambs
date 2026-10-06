class CBA_Extended_EventHandlers_base;
class CfgVehicles {
    class CAManBase;
    class Civilian;
    class SoldierWB: CAManBase {
        fsmDanger = QUOTE(PATHTOF2_SYS(PREFIX,COMPONENT,scripts\lambs_danger.fsm));
    };
    class SoldierEB: CAManBase {
        fsmDanger = QUOTE(PATHTOF2_SYS(PREFIX,COMPONENT,scripts\lambs_danger.fsm));
    };
    class SoldierGB: CAManBase {
        fsmDanger = QUOTE(PATHTOF2_SYS(PREFIX,COMPONENT,scripts\lambs_danger.fsm));
    };
    class Civilian_F: Civilian {
        fsmDanger = QUOTE(PATHTOF2_SYS(PREFIX,COMPONENT,scripts\lambs_dangerCivilian.fsm));
    };

    class Module_F;

    class GVAR(SetRadio) : Module_F {
        author = "LAMBS Dev Team";
        _generalMacro = QGVAR(SetRadio);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_SetRadio_DisplayName);
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
        function = QFUNC(moduleSetRadio);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(DisableAI) : Module_F {
        author = "LAMBS Dev Team";
        _generalMacro = QGVAR(DisableAI);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_DisableAI_DisplayName);
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
        function = QFUNC(moduleDisableAI);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(ConfigureGroupAI) : Module_F {
        _generalMacro = QGVAR(ConfigureGroupAI);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_ConfigureGroupAI_DisplayName);
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
        function = QFUNC(moduleConfigureGroupAI);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    // ELITE fork (v8.33): kumanda (HQ) - yalniz bu modul yerlestirilince aktif olur (fnc_hq / lambs_danger_hqAktif)
    class GVAR(Kumanda) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(Kumanda);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE Kumanda (HQ)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
        function = QFUNC(moduleKumanda);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    // ELITE fork (v8.113): objektif (komutan plani) - Zeus'tan objektif + duşman bilgisi verilir, komutan harekat plani + waypoint uretir
    class GVAR(Objektif) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(Objektif);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE Objektif (komutan plani)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\attack_ca.paa";
        function = QFUNC(moduleObjektif);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    // ELITE fork (v8.115): manuel plan noktasi - Zeus rally point / ORP / destek / kanat / CCP noktasini kendisi secer (komutan uygular, uyari loglar)
    class GVAR(PlanNokta) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(PlanNokta);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE Plan Noktasi (manuel)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\move_ca.paa";
        function = QFUNC(modulePlanNokta);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(GorevAta) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(GorevAta);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE Gorev Ata (plan / medevac / topcu)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\move_ca.paa";
        function = QFUNC(moduleGorevAta);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(Karakol) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(Karakol);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE Karakol / HQ (haritadan)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\move_ca.paa";
        function = QFUNC(moduleKarakol);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };
};
