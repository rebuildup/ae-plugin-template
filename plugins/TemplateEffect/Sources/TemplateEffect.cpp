/*******************************************************************/
/*                                                                 */
/* After Effects C++ Plugin Template                              */
/*                                                                 */
/* Derived from the Adobe After Effects SDK "Skeleton" sample.    */
/* The Adobe SDK headers and support utilities remain under the    */
/* Adobe license and are NOT redistributed in this repository.     */
/*                                                                 */
/*******************************************************************/

#include "TemplateEffect.h"

/*  PF_Cmd_ABOUT — text shown by the "About" / effect info dialog. */
static PF_Err About(PF_InData* in_data, PF_OutData* out_data, PF_ParamDef* params[], PF_LayerDef* output)
{
    AEGP_SuiteHandler suites(in_data->pica_basicP);

    suites.ANSICallbacksSuite1()->sprintf(
        out_data->return_msg, "%s v%d.%d\r%s", STR(StrID_Name), MAJOR_VERSION, MINOR_VERSION, STR(StrID_Description));

    return PF_Err_NONE;
}

/*  PF_Cmd_GLOBAL_SETUP — called once per AE session, before any rendering.
 *
 *  NOTE: whatever you declare in out_flags / out_flags2 here MUST agree with
 *  AE_Effect_Global_OutFlags / AE_Effect_Global_OutFlags_2 in the PiPL
 *  resource. AE uses the PiPL for host compatibility decisions, so a mismatch
 *  produces confusing behaviour rather than an obvious error.
 */
static PF_Err GlobalSetup(PF_InData* in_data, PF_OutData* out_data, PF_ParamDef* params[], PF_LayerDef* output)
{
    out_data->my_version = PF_VERSION(MAJOR_VERSION, MINOR_VERSION, BUG_VERSION, STAGE_VERSION, BUILD_VERSION);

    /* 16bpc support. 32bpc float additionally requires
     * PF_OutFlag2_SUPPORTS_SMART_RENDER | PF_OutFlag2_FLOAT_COLOR_AWARE plus
     * the PF_Cmd_SMART_* call sequence — see docs/reference/upgrading-to-smartfx.md. */
    out_data->out_flags  = PF_OutFlag_DEEP_COLOR_AWARE;
    out_data->out_flags2 = PF_OutFlag2_NONE;

    return PF_Err_NONE;
}

/*  PF_Cmd_PARAMS_SETUP — describes the effect's parameter list. Runs once.
 *
 *  Always AEFX_CLR_STRUCT() before registering a parameter; leaving stale bytes
 *  in PF_ParamDef is the classic source of intermittent parameter bugs.
 */
static PF_Err ParamsSetup(PF_InData* in_data, PF_OutData* out_data, PF_ParamDef* params[], PF_LayerDef* output)
{
    PF_Err      err  = PF_Err_NONE;
    PF_ParamDef def;

    AEFX_CLR_STRUCT(def);

    PF_ADD_FLOAT_SLIDERX(
        STR(StrID_Gain_Param_Name),
        TEMPLATE_GAIN_MIN,
        TEMPLATE_GAIN_MAX,
        TEMPLATE_GAIN_MIN,
        TEMPLATE_GAIN_MAX,
        TEMPLATE_GAIN_DFLT,
        PF_Precision_HUNDREDTHS,
        0,
        0,
        GAIN_DISK_ID);

    AEFX_CLR_STRUCT(def);

    PF_ADD_COLOR(STR(StrID_Color_Param_Name), PF_HALF_CHAN8, PF_MAX_CHAN8, PF_MAX_CHAN8, COLOR_DISK_ID);

    out_data->num_params = TEMPLATE_NUM_PARAMS;

    return err;
}

/*  16bpc pixel callback.
 *
 *  Invoked once per pixel inside the AE-supplied iteration suite. `inP` and
 *  `outP` may alias, so never assume you can read `outP` before writing it.
 */
static PF_Err MySimpleGainFunc16(void* refcon, A_long xL, A_long yL, PF_Pixel16* inP, PF_Pixel16* outP)
{
    GainInfo* giP    = static_cast<GainInfo*>(refcon);
    PF_FpLong tempF  = 0;

    if (giP)
    {
        tempF = giP->gainF * PF_MAX_CHAN16 / 100.0;
        if (tempF > PF_MAX_CHAN16)
        {
            tempF = PF_MAX_CHAN16;
        }

        outP->alpha = inP->alpha;
        outP->red   = MIN(inP->red + static_cast<A_u_char>(tempF), PF_MAX_CHAN16);
        outP->green = MIN(inP->green + static_cast<A_u_char>(tempF), PF_MAX_CHAN16);
        outP->blue  = MIN(inP->blue + static_cast<A_u_char>(tempF), PF_MAX_CHAN16);
    }

    return PF_Err_NONE;
}

/*  8bpc pixel callback. */
static PF_Err MySimpleGainFunc8(void* refcon, A_long xL, A_long yL, PF_Pixel8* inP, PF_Pixel8* outP)
{
    GainInfo* giP    = static_cast<GainInfo*>(refcon);
    PF_FpLong tempF  = 0;

    if (giP)
    {
        tempF = giP->gainF * PF_MAX_CHAN8 / 100.0;
        if (tempF > PF_MAX_CHAN8)
        {
            tempF = PF_MAX_CHAN8;
        }

        outP->alpha = inP->alpha;
        outP->red   = MIN(inP->red + static_cast<A_u_char>(tempF), PF_MAX_CHAN8);
        outP->green = MIN(inP->green + static_cast<A_u_char>(tempF), PF_MAX_CHAN8);
        outP->blue  = MIN(inP->blue + static_cast<A_u_char>(tempF), PF_MAX_CHAN8);
    }

    return PF_Err_NONE;
}

/*  PF_Cmd_RENDER — called once per frame for 8bpc and 16bpc paths.
 *
 *  Replace the body of this function with the real per-pixel work.
 */
static PF_Err Render(PF_InData* in_data, PF_OutData* out_data, PF_ParamDef* params[], PF_LayerDef* output)
{
    PF_Err       err    = PF_Err_NONE;
    AEGP_SuiteHandler suites(in_data->pica_basicP);

    GainInfo giP;
    AEFX_CLR_STRUCT(giP);

    A_long linesL = output->extent_hint.bottom - output->extent_hint.top;

    giP.gainF = params[TEMPLATE_GAIN]->u.fs_d.value;

    if (PF_WORLD_IS_DEEP(output))
    {
        ERR(suites.Iterate16Suite2()->iterate(
            in_data,
            0,                              // progress base
            linesL,                         // progress final
            &params[TEMPLATE_INPUT]->u.ld, // src
            NULL,                           // area - NULL for every pixel
            &giP,                           // refcon - your per-render state
            MySimpleGainFunc16,             // pixel callback
            output));
    }
    else
    {
        ERR(suites.Iterate8Suite2()->iterate(
            in_data,
            0,                              // progress base
            linesL,                         // progress final
            &params[TEMPLATE_INPUT]->u.ld, // src
            NULL,                           // area - NULL for every pixel
            &giP,                           // refcon - your per-render state
            MySimpleGainFunc8,              // pixel callback
            output));
    }

    return err;
}

/*  Entry point invoked by AE during plug-in registration. */
extern "C" DllExport PF_Err PluginDataEntryFunction2(
    PF_PluginDataPtr    inPtr,
    PF_PluginDataCB2    inPluginDataCallBackPtr,
    SPBasicSuite*       inSPBasicSuitePtr,
    const char*         inHostName,
    const char*         inHostVersion)
{
    PF_Err result = PF_Err_INVALID_CALLBACK;

    result = PF_REGISTER_EFFECT_EXT2(
        inPtr,
        inPluginDataCallBackPtr,
        "Template Effect",   // display name
        "RBPL TemplateEffect", // match name - must be unique and permanent
        "RBPL Template",     // category
        AE_RESERVED_INFO,
        "EffectMain",
        "https://example.invalid/"); // support URL, shown in the Effects Manager

    return result;
}

PF_Err EffectMain(
    PF_Cmd       cmd,
    PF_InData*   in_data,
    PF_OutData*  out_data,
    PF_ParamDef* params[],
    PF_LayerDef* output,
    void*        extra)
{
    PF_Err err = PF_Err_NONE;

    /*  On arm64 a C++ exception escaping an extern "C" frame calls terminate()
     *  rather than being undefined behaviour. Keep this guard. */
    try
    {
        switch (cmd)
        {
            case PF_Cmd_ABOUT:

                err = About(in_data, out_data, params, output);
                break;

            case PF_Cmd_GLOBAL_SETUP:

                err = GlobalSetup(in_data, out_data, params, output);
                break;

            case PF_Cmd_PARAMS_SETUP:

                err = ParamsSetup(in_data, out_data, params, output);
                break;

            case PF_Cmd_RENDER:

                err = Render(in_data, out_data, params, output);
                break;

            default:

                break;
        }
    }
    catch (PF_Err& thrown_err)
    {
        err = thrown_err;
    }

    return err;
}