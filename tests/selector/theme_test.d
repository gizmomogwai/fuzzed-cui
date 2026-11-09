module selector.theme_test;

import selector.theme;
import std.algorithm : all;
import std.exception : assertThrown;
import unit_threaded.assertions;

@("theme names")
unittest
{
    parseTheme("default").shouldEqual(ThemeName.standard);
    parseTheme("zenburn").shouldEqual(ThemeName.zenburn);
    assertThrown(parseTheme("solarized"));
}

@("accents default per theme and are validated against the theme")
unittest
{
    resolveAccent(ThemeName.standard, "").shouldEqual("violet");
    resolveAccent(ThemeName.zenburn, "").shouldEqual("yellow");
    resolveAccent(ThemeName.standard, "rose").shouldEqual("rose");
    resolveAccent(ThemeName.zenburn, "cyan").shouldEqual("cyan");
    assertThrown(resolveAccent(ThemeName.standard, "yellow"));
    assertThrown(resolveAccent(ThemeName.zenburn, "violet"));
}

@("every accent name maps to a color or index")
unittest
{
    foreach (name; zenburnAccents)
    {
        zenburnAccent(name);
    }
    foreach (index, name; standardAccents)
    {
        standardAccentIndex(name).shouldEqual(cast(int) index);
    }
}

@("zenburn text is legible on its surfaces")
unittest
{
    foreach (surface; [
            zenburn.background, zenburn.surface, zenburn.surfaceRaised
        ])
    {
        (contrastRatio(zenburn.foreground, surface) >= 4.5).shouldBeTrue;
        (contrastRatio(zenburn.secondary, surface) >= 3.0).shouldBeTrue;
    }
    (contrastRatio(zenburn.foreground, zenburn.background) >= 6.0).shouldBeTrue;
}

@("zenburn accents stand out from the background")
unittest
{
    zenburnAccents.all!(name => contrastRatio(zenburnAccent(name),
            zenburn.background) >= 3.0).shouldBeTrue;
}

@("contrast of identical colors is one")
unittest
{
    contrastRatio(zenburn.background, zenburn.background).shouldEqual(1.0);
}
