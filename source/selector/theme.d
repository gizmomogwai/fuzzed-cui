/// Theme and accent selection, independent of CUI so it can be unit tested.
module selector.theme;

import std.algorithm : canFind;
import std.exception : enforce;
import std.format : format;
import std.math : pow;
import std.string : join;

struct Rgb
{
    ubyte red;
    ubyte green;
    ubyte blue;
}

enum ThemeName
{
    standard,
    zenburn,
}

/// Accent names of CUI's built-in themes, in the order of `cui_accent`.
immutable string[] standardAccents = [
    "neutral", "violet", "blue", "green", "amber", "orange", "coral", "rose"
];

immutable string[] zenburnAccents = [
    "yellow", "cyan", "green", "orange", "red", "magenta", "blue"
];

struct ZenburnPalette
{
    Rgb background;
    Rgb surface;
    Rgb surfaceRaised;
    Rgb surfaceMuted;
    Rgb foreground;
    Rgb secondary;
    Rgb muted;
    Rgb success;
    Rgb warning;
    Rgb danger;
    Rgb info;
    /// Series colors: blue, orange, green, magenta, yellow, cyan.
    Rgb[6] series;
}

immutable ZenburnPalette zenburn = ZenburnPalette(Rgb(0x3f, 0x3f, 0x3f),
        Rgb(0x4f, 0x4f, 0x4f), Rgb(0x5f, 0x5f, 0x5f), Rgb(0x6f, 0x6f, 0x6f),
        Rgb(0xdc, 0xdc, 0xcc), Rgb(0xc3, 0xc3, 0xb3), Rgb(0xa3, 0xa3, 0x93),
        Rgb(0x7f, 0x9f, 0x7f), Rgb(0xdf, 0xaf, 0x8f), Rgb(0xcc, 0x93, 0x93),
        Rgb(0x8c, 0xd0, 0xd3), [
            Rgb(0x94, 0xbf, 0xf3), Rgb(0xdf, 0xaf, 0x8f), Rgb(0x7f, 0x9f,
                0x7f), Rgb(0xdc, 0x8c, 0xc3), Rgb(0xf0, 0xdf, 0xaf),
            Rgb(0x8c, 0xd0, 0xd3)
]);

ThemeName parseTheme(string name)
{
    switch (name)
    {
    case "default":
        return ThemeName.standard;
    case "zenburn":
        return ThemeName.zenburn;
    default:
        throw new Exception(format!"Unknown theme '%s' (expected default or zenburn)"(name));
    }
}

/// Defaults to violet for the default theme and yellow for zenburn when `name` is empty.
string resolveAccent(ThemeName theme, string name)
{
    auto accents = theme == ThemeName.zenburn ? zenburnAccents : standardAccents;
    if (name.length == 0)
    {
        return accents[theme == ThemeName.zenburn ? 0 : 1];
    }
    enforce(accents.canFind(name),
            format!"Unknown accent '%s' for this theme (expected one of: %s)"(name,
                accents.join(", ")));
    return name;
}

/// Index into CUI's `cui_accent` for the default theme.
int standardAccentIndex(string name)
{
    foreach (index, candidate; standardAccents)
    {
        if (candidate == name)
        {
            return cast(int) index;
        }
    }
    throw new Exception(format!"Unknown accent '%s'"(name));
}

Rgb zenburnAccent(string name)
{
    switch (name)
    {
    case "yellow":
        return Rgb(0xf0, 0xdf, 0xaf);
    case "cyan":
        return Rgb(0x8c, 0xd0, 0xd3);
    case "green":
        return Rgb(0x7f, 0x9f, 0x7f);
    case "orange":
        return Rgb(0xdf, 0xaf, 0x8f);
    case "red":
        return Rgb(0xcc, 0x93, 0x93);
    case "magenta":
        return Rgb(0xdc, 0x8c, 0xc3);
    case "blue":
        return Rgb(0x94, 0xbf, 0xf3);
    default:
        throw new Exception(format!"Unknown zenburn accent '%s'"(name));
    }
}

private double linearized(ubyte channel)
{
    const value = channel / 255.0;
    return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
}

/// WCAG contrast ratio between two colors.
double contrastRatio(Rgb first, Rgb second)
{
    double luminance(Rgb color)
    {
        return 0.2126 * linearized(color.red) + 0.7152 * linearized(
                color.green) + 0.0722 * linearized(color.blue);
    }

    const a = luminance(first);
    const b = luminance(second);
    return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
}

/// Linear mix: `amount` 0 gives `from`, 1 gives `to`.
Rgb mix(Rgb from, Rgb to, double amount)
{
    ubyte channel(ubyte a, ubyte b)
    {
        return cast(ubyte)(a + (b - a) * amount + 0.5);
    }

    return Rgb(channel(from.red, to.red), channel(from.green, to.green),
            channel(from.blue, to.blue));
}
