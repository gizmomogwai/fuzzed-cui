/// Helpers for CUI macros that ImportC cannot translate (compound-literal macros).
module cui_util;

import cui_c : cui_color, cui_size, CUI_SIZE_FIXED, CUI_SIZE_GROW;

// Token ids that CUI encodes in colors, in the order of `cui_token` in cui.h.
enum CuiToken : ubyte
{
    foreground = 5,
    accent = 11,
    accentSubtle = 13,
}

enum CUI_FILL = cui_size(CUI_SIZE_GROW, 1);

cui_size CUI_PX(float value)
{
    return cui_size(CUI_SIZE_FIXED, value);
}

/// Semantic color that follows the theme, as `CUI_TOKEN_COLOR` in cui.h.
cui_color tokenColor(CuiToken token)
{
    return cui_color(token, 0xC5, 0x1D, 0);
}
