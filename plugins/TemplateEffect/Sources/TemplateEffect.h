/*******************************************************************/
/*                                                                 */
/* After Effects C++ Plugin Template                              */
/*                                                                 */
/* Derived from the Adobe After Effects SDK "Skeleton" sample.    */
/* The Adobe SDK headers and support utilities remain under the    */
/* Adobe license and are NOT redistributed in this repository.     */
/*                                                                 */
/*******************************************************************/

#pragma once

#ifndef TEMPLATE_EFFECT_H
#define TEMPLATE_EFFECT_H

/*  AE_Effect.h checks for PF_DEEP_COLOR_AWARE and provides 16bpc pixel types. */
#define PF_DEEP_COLOR_AWARE 1

#include "AEConfig.h"

/*  entry.h defines DllExport, AE_ENTRY_POINT and the PF_REGISTER_EFFECT_*
 *  macros, and must be included before AE_PluginData.h (which it pulls in). */
#include "entry.h"

#include "AE_Effect.h"
#include "AE_EffectCB.h"
#include "AE_Macros.h"
#include "AE_EffectCBSuites.h"
#include "AE_GeneralPlug.h"
#include "Param_Utils.h"
#include "String_Utils.h"
#include "Smart_Utils.h"
#include "AEGP_SuiteHandler.h"

#include "TemplateEffect_Strings.h"

/* Plug-in version. AE uses this to decide which of duplicate effects to load,
 * so bump it whenever the rendering behaviour changes. */
#define MAJOR_VERSION 1
#define MINOR_VERSION 0
#define BUG_VERSION 0
#define STAGE_VERSION PF_Stage_DEVELOP
#define BUILD_VERSION 1

/* Parameters */

#define TEMPLATE_GAIN_MIN 0.0
#define TEMPLATE_GAIN_MAX 100.0
#define TEMPLATE_GAIN_DFLT 10.0

enum
{
    TEMPLATE_INPUT = 0,
    TEMPLATE_GAIN,
    TEMPLATE_COLOR,
    TEMPLATE_NUM_PARAMS
};

/* Disk IDs. These persist in the .aep project file, so never renumber or
 * reuse an existing value. */
enum
{
    GAIN_DISK_ID = 1,
    COLOR_DISK_ID = 2,
};

/* Per-render state handed to the pixel callback through `refcon`. */
typedef struct GainInfo
{
    PF_FpLong gainF;
    PF_FpShort redF;
    PF_FpShort greenF;
    PF_FpShort blueF;
    PF_FpShort alphaF;
} GainInfo, *GainInfoP, **GainInfoH;

extern "C"
{
    DllExport PF_Err EffectMain(
        PF_Cmd          cmd,
        PF_InData*      in_data,
        PF_OutData*     out_data,
        PF_ParamDef*    params[],
        PF_LayerDef*    output,
        void*           extra);
}

#endif // TEMPLATE_EFFECT_H