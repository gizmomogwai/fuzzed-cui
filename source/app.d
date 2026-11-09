import core.sys.posix.unistd : isatty;
import selector.model : Navigation, Selector;
import selector.window : SelectorWindow;
import std.array : array;
import std.exception : enforce;
import std.file : write;
import std.format : format;
import std.getopt : getopt;
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

int main(string[] arguments)
{
    string initialQuery;
    string screenshotPath;
    bool demo;
    int highlightSteps;
    try
    {
        arguments.getopt("down", "Move the highlight down this many rows first (for screenshots)",
                &highlightSteps, "demo",
                "Use built-in sample lines instead of stdin", &demo, "query",
                "Initial filter text", &initialQuery, "screenshot",
                "Render headlessly to this PPM file and exit", &screenshotPath);
        auto lines = demo || isatty(0) ? sampleLines : stdin.byLineCopy.array;
        enforce(lines.length != 0, "No input lines");
        auto selector = new Selector(lines);
        auto window = new SelectorWindow(selector, "cui-selector", screenshotPath.length != 0);
        window.setQuery(initialQuery);
        foreach (_; 0 .. highlightSteps)
        {
            selector.navigate(Navigation.down);
        }
        if (screenshotPath.length != 0)
        {
            int width, height;
            auto pixels = window.screenshot(5, width, height);
            writePpm(screenshotPath, pixels, width, height);
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
