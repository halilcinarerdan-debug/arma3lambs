#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BIRIM KIMLIGI (v8.501): tohumlu rastgelelik icin KOSULAR ARASI KARARLI baglam dizesi. netId / nesne numarasi yeniden baslatmada degisir; grup adi + gruptaki sira editorde yerlestirilen birimlerde sabit kalir.
 *   Asker: "<grup adi>:<sira>"; arac: "<surucu / komutan grubu>:V"; grup: grup adi. Zeus ile sonradan yaratilanlar da calisir ama kosular arasi ayni olmayabilir (bkz. RNG_ENVANTERI.md).
 *
 * Arguments:
 * 0: Birim / arac / grup <OBJECT veya GROUP>
 *
 * Return Value: kimlik <STRING>
 * Public: No
*/

params [["_o", objNull]];
if (_o isEqualType grpNull) exitWith { groupId _o };
if (isNull _o) exitWith {"?"};
if (_o isKindOf "CAManBase") exitWith { format ["%1:%2", groupId (group _o), (units (group _o)) find _o] };
private _c = effectiveCommander _o;
if (isNull _c) exitWith { typeOf _o };
format ["%1:V", groupId (group _c)]
