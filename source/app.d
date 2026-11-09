import argparse.api.cli : CLI;
import argparse.config : Config;
import argparse : Description, NamedArgument;
import core.sys.posix.unistd : isatty;
import selector.model : Navigation, Selector;
import selector.theme : parseTheme, resolveAccent;
import selector.window : SelectorWindow;
import std.array : array;
import std.exception : enforce;
import std.file : write;
import std.format : format;
import std.stdio : stderr, stdin, stdout;

private string[] sampleLines()
{
    return [
        "source/app.d", "source/selector/model.d", "source/selector/window.d",
        "source/cuic.d", "tests/runner.d", "tests/selector/model_test.d",
        "flake.nix", "flake.lock", "dub.sdl", "dub.selections.json", "readme.org",
        "LICENSE", ".gitignore", ".envrc", "out/main/cui-selector/cui-selector",
        "out/tests/cui-selector/cui-selector-tests",
    ];
}

private void writePpm(string path, const(ubyte)[] rgba, int width, int height)
{
    auto data = cast(ubyte[]) format("P6\n%d %d\n255\n", width, height);
    foreach (pixel; 0 .. width * height)
    {
        data ~= rgba[pixel * 4 .. pixel * 4 + 3];
    }
    write(path, data);
}

struct Options
{
    @(NamedArgument.Description("Use built-in sample lines instead of stdin"))
    bool demo;
    @(NamedArgument.Description("Initial filter text"))
    string query;
    @(NamedArgument.Description("Move the highlight down this many rows first (for screenshots)"))
    int down;
    @(NamedArgument.Description("Render headlessly to this PPM file and exit"))
    string screenshot;
    @(NamedArgument.Description("Color theme: default or zenburn"))
    string theme = "default";
    @(NamedArgument.Description("Accent color. default: neutral, violet, blue, green, amber, orange, coral, rose; "
            ~ "zenburn: yellow, cyan, green, orange, red, magenta, blue"))
    string accent;
}

int run(Options options)
{
    try
    {
        auto theme = parseTheme(options.theme);
        auto accent = resolveAccent(theme, options.accent);
        auto lines = options.demo || isatty(0) ? sampleLines : stdin.byLineCopy.array;
        enforce(lines.length != 0, "No input lines");
        auto selector = new Selector(lines);
        auto window = new SelectorWindow(selector, "cui-selector",
                options.screenshot.length != 0, theme, accent);
        window.setQuery(options.query);
        foreach (_; 0 .. options.down)
        {
            selector.navigate(Navigation.down);
        }
        if (options.screenshot.length != 0)
        {
            int width, height;
            auto pixels = window.screenshot(5, width, height);
            writePpm(options.screenshot, pixels, width, height);
            return 0;
        }
        window.run;
        if (!selector.chosen)
        {
            return 1;
        }
        stdout.writeln(selector.selection);
        return 0;
    }
    catch (Exception failure)
    {
        stderr.writeln("cui-selector: ", failure.msg);
        return 2;
    }
}

mixin CLI!(Options).main!(run);
