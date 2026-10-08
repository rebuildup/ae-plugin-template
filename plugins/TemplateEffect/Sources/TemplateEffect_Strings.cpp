/*******************************************************************/
/*                                                                 */
/* After Effects C++ Plugin Template                              */
/*                                                                 */
/*******************************************************************/

#include "TemplateEffect.h"

typedef struct
{
    A_u_long index;
    A_char   str[256];
} TableString;

TableString g_strs[StrID_NUMTYPES] = {
    StrID_NONE,
    "",
    StrID_Name,
    "Template Effect",
    StrID_Description,
    "Starting point for a new After Effects effect.\rReplace the pixel routines in TemplateEffect.cpp with your own.",
    StrID_Gain_Param_Name,
    "Gain",
    StrID_Color_Param_Name,
    "Color",
};

char* GetStringPtr(int strNum)
{
    return g_strs[strNum].str;
}