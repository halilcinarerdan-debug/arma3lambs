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
        displayName = "ELITE Koordinasyon (gruplar arasi telsiz agi; HQ / US degil)";
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
        displayName = "ELITE Karakol / Mevzi (savunma noktasi)";
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

    class GVAR(HQ) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(HQ);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE HQ / US Kur (kategori + squad atama)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\move_ca.paa";
        function = QFUNC(moduleHQ);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(TopcuTest) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(TopcuTest);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE Topcu TEST (bu noktaya 3 mermi)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\destroy_ca.paa";
        function = QFUNC(moduleTopcuTest);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(KarakolKaldir) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(KarakolKaldir);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE Karakol / Mevzi / HQ KALDIR (listeden sec)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\move_ca.paa";
        function = QFUNC(moduleKarakolKaldir);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    // ELITE fork (v8.237, Dilim A0): cephe simulasyonu paneli - faction listesinden asker sayisi (sanal profil) + Personnel Replacement ayarlari
    class GVAR(Cephe) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(Cephe);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE Cephe Paneli (faction asker sayisi + takviye)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\run_ca.paa";
        function = QFUNC(moduleCephe);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    // ELITE fork (v8.239): AI surucu A/B testi - ayni arac sinifi, temiz murettebat, ELITE kapali / acik, doMove / waypoint, yolcusuz / yolcuyla
    class GVAR(SurusAB) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(SurusAB);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE Arac SURUS A/B Testi (AI surucu tani)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\move_ca.paa";
        function = QFUNC(moduleSurusAB);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(GozetleAta) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(GozetleAta);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE Gozetleme Ata (squad -> karakol / mevzi nobeti)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\scout_ca.paa";
        function = QFUNC(moduleGozetleAta);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(IhaGorev) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(IhaGorev);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE IHA Gorevi (FPV / bomba / gozlem)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\scout_ca.paa";
        function = QFUNC(moduleIhaGorev);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(KarakolGarnizon) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(KarakolGarnizon);
        scope = 1;
        scopeCurator = 2;
        displayName = "ELITE Karakol Garnizon (nobet / devriye / arac)";
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\move_ca.paa";
        function = QFUNC(moduleKarakolGarnizon);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };
    // ELITE fork (v8.331): Eden (3D editor) modulu - yogun objeli hendeklerde AI nesnelerin USTUNDEN yurusun; ad yazmaya gerek yok, alan modulun kendi tutamaclariyla ayarlanir
    class GVAR(YuruyusAlani) : Module_F {
        author = "ELITE fork";
        _generalMacro = QGVAR(YuruyusAlani);
        scope = 2;
        scopeCurator = 2;   // v8.333: Zeus uyumlu (birakilinca ayar paneli)
        displayName = "ELITE Yurunebilir Alan (yogun objeli hendek)";
        isGlobal = 0;
        isTriggerActivated = 0;
        isDisposable = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\move_ca.paa";
        function = QFUNC(moduleYuruyusAlani);
        functionPriority = 5;
        canSetArea = 1;
        canSetAreaShape = 1;
        canSetAreaHeight = 0;
        class AttributeValues {
            size3[] = {12, 4, -1};
            isRectangle = 1;
        };
    };
};
