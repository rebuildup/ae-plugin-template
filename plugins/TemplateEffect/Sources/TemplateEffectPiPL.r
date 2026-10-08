/*
    TemplateEffectPiPL.r

    The PiPL resource is the plug-in's declaration to the host. It is compiled
    by Rez on macOS and embedded in the .plugin bundle.

    IMPORTANT: AE_Effect_Global_OutFlags and AE_Effect_Global_OutFlags_2 here
    must agree with out_data->out_flags / out_data->out_flags2 set in
    PF_Cmd_GLOBAL_SETUP. AE reads the PiPL for host compatibility decisions, so
    a mismatch causes confusing behaviour instead of a clear error.

    AeGeneral.r supplies the AE PiPL property macros (AEEffect,
    AE_Effect_Global_OutFlags, ...).
*/

#include "AEConfig.h"
#include "AE_EffectVers.h"

#ifndef AE_OS_WIN
    #include <AE_General.r>
#endif

resource 'PiPL' (16000) {
    {   /* array properties: 14 elements */
        /* [1] */
        Kind {
            AEEffect
        },
        /* [2] */
        Name {
            "Template Effect"
        },
        /* [3] */
        Category {
            "RBPL Template"
        },
#ifdef AE_OS_WIN
    #if defined(AE_PROC_INTELx64)
        CodeWin64X86 {"EffectMain"},
    #elif defined(AE_PROC_ARM64)
        CodeWinARM64 {"EffectMain"},
    #endif
#elif defined(AE_OS_MAC)
        CodeMacIntel64 {"EffectMain"},
        CodeMacARM64 {"EffectMain"},
#endif
        /* [6] */
        AE_PiPL_Version {
            2,
            0
        },
        /* [7] */
        AE_Effect_Spec_Version {
            PF_PLUG_IN_VERSION,
            PF_PLUG_IN_SUBVERS
        },
        /* [8] */
        AE_Effect_Version {
            524289 /* 1.0 */
        },
        /* [9] */
        AE_Effect_Info_Flags {
            0
        },
        /* [10] PF_OutFlag_DEEP_COLOR_AWARE (1 << 25) */
        AE_Effect_Global_OutFlags {
            0x02000000
        },
        /* [11] PF_OutFlag2_NONE */
        AE_Effect_Global_OutFlags_2 {
            0x00000000
        },
        /* [12] Must be unique and must never change once shipped. */
        AE_Effect_Match_Name {
            "RBPL TemplateEffect"
        },
        /* [13] */
        AE_Reserved_Info {
            0
        },
        /* [14] Shown in the Effects Manager. */
        AE_Effect_Support_URL {
            "https://example.invalid/"
        }
    }
};