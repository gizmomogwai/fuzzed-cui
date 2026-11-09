module selector.window;

import core.stdc.string : strlen;
import cui_c;
import cui_util : CUI_FILL, CUI_PX, tokenColor, CuiToken;
import selector.model : Navigation, Selector;
import std.algorithm : max, min;
import std.format : format;
import std.string : toStringz;
import std.utf : stride;

private enum rowHeight = 34.0f;
private enum listChromeHeight = 110.0f;
private enum queryCapacity = 256;

/// Runs the selector in a CUI window until a line is chosen or the window is closed.
final class SelectorWindow
{
    private cui_app* app;
    private Selector selector;
    private char[queryCapacity] queryBuffer;
    private bool highlightChanged = true;
    private int visibleFirst;
    private int visibleLast;

    this(Selector selector, string title, bool hidden = false)
    {
        this.selector = selector;
        cui_app_desc description;
        description.title = title.toStringz;
        description.width = 760;
        description.height = 560;
        description.hidden = hidden;
        description.theme = CUI_THEME_DARK;
        description.accent = CUI_ACCENT_VIOLET;
        app = cui_app_create(&description);
        if (app is null)
        {
            throw new Exception("Could not create the CUI window");
        }
    }

    ~this()
    {
        if (app !is null)
        {
            cui_app_destroy(app);
            app = null;
        }
    }

    void setQuery(string query)
    {
        auto length = min(query.length, queryCapacity - 1);
        queryBuffer[0 .. length] = query[0 .. length];
        queryBuffer[length] = '\0';
        selector.filter(query[0 .. length]);
    }

    void run()
    {
        while (!selector.closed && cui_app_frame(app))
        {
            frame(cui_app_ui(app));
        }
    }

    /// Renders `frames` frames headlessly and returns the last one as RGBA pixels.
    ubyte[] screenshot(int frames, out int width, out int height)
    {
        foreach (_; 0 .. frames)
        {
            if (!cui_app_frame(app))
            {
                break;
            }
            frame(cui_app_ui(app));
        }
        foreach (scale; [2, 1])
        {
            auto size = cui_app_size(app);
            width = cast(int)(size.x * scale);
            height = cast(int)(size.y * scale);
            auto pixels = new ubyte[width * height * 4];
            if (cui_app_screenshot(app, pixels.ptr, width, height))
            {
                return pixels;
            }
        }
        throw new Exception("Could not take a screenshot");
    }

    private void handleKeys(cui_ctx* ui)
    {
        void navigate(Navigation direction)
        {
            selector.navigate(direction);
            highlightChanged = true;
        }

        if (cui_key_pressed(ui, CUI_KEY_DOWN) || cui_shortcut(ui, CUI_MOD_CTRL, CUI_KEY_N))
        {
            navigate(Navigation.down);
        }
        if (cui_key_pressed(ui, CUI_KEY_UP) || cui_shortcut(ui, CUI_MOD_CTRL, CUI_KEY_P))
        {
            navigate(Navigation.up);
        }
        if (cui_key_pressed(ui, CUI_KEY_PAGE_DOWN))
        {
            navigate(Navigation.pageDown);
        }
        if (cui_key_pressed(ui, CUI_KEY_PAGE_UP))
        {
            navigate(Navigation.pageUp);
        }
        if (cui_key_pressed(ui, CUI_KEY_ENTER))
        {
            selector.accept;
        }
        if (cui_key_pressed(ui, CUI_KEY_ESCAPE))
        {
            selector.cancel;
            syncQueryBuffer;
            highlightChanged = true;
        }
    }

    private void syncQueryBuffer()
    {
        auto query = selector.query;
        queryBuffer[0 .. query.length] = query;
        queryBuffer[query.length] = '\0';
    }

    private void frame(cui_ctx* ui)
    {
        handleKeys(ui);
        auto viewport = cui_viewport_size(ui);
        auto listHeight = max(rowHeight, viewport.y - listChromeHeight);
        selector.pageSize = cast(int)(listHeight / rowHeight) - 1;

        cui_box outer;
        outer.pad = 16;
        outer.gap = 10;
        outer.width = CUI_FILL;
        outer.height = CUI_FILL;
        cui_column_begin(ui, &outer);
        scope (exit)
        {
            cui_box_end(ui);
        }

        searchField(ui);
        statusLine(ui);
        resultList(ui, listHeight);
    }

    private void searchField(cui_ctx* ui)
    {
        cui_input_opts options;
        options.placeholder = "Type to filter…";
        options.autofocus = true;
        options.clearable = true;
        options.width = CUI_FILL;
        auto flags = cui_search_ex(ui, "query", queryBuffer.ptr, queryBuffer.length, &options);
        if (flags & CUI_CHANGED)
        {
            selector.filter(queryBuffer[0 .. strlen(queryBuffer.ptr)].idup);
            highlightChanged = true;
        }
    }

    private void statusLine(cui_ctx* ui)
    {
        cui_box row;
        row.gap = 12;
        row.width = CUI_FILL;
        cui_row_begin(ui, &row);
        scope (exit)
        {
            cui_box_end(ui);
        }
        cui_muted(ui, format("%d / %d", selector.count, selector.totalCount).toStringz);
        cui_kbd(ui, "↑ ↓");
        cui_kbd(ui, "Enter");
        cui_kbd(ui, "Esc");
    }

    private void resultList(cui_ctx* ui, float listHeight)
    {
        if (selector.count == 0)
        {
            cui_muted(ui, "No matches");
            return;
        }
        if (highlightChanged)
        {
            scrollToHighlighted(ui, listHeight);
            highlightChanged = false;
        }
        int first, last;
        cui_virtual_list_begin(ui, "rows", selector.count, rowHeight,
                CUI_PX(listHeight), &first, &last);
        // CUI builds two extra rows on each side of what is visible.
        visibleFirst = first == 0 ? 0 : first + 2;
        visibleLast = max(visibleFirst, last - 2);
        foreach (index; first .. last)
        {
            resultRow(ui, index);
        }
        cui_virtual_list_end(ui);
    }

    private void scrollToHighlighted(cui_ctx* ui, float listHeight)
    {
        auto highlighted = selector.highlighted;
        if (highlighted < visibleFirst)
        {
            cui_scroll_to(ui, "rows", highlighted * rowHeight);
        }
        else if (highlighted >= visibleLast - 1)
        {
            cui_scroll_to(ui, "rows", (highlighted + 1) * rowHeight - listHeight);
        }
    }

    private void resultRow(cui_ctx* ui, int index)
    {
        cui_box row;
        row.dir = CUI_ROW;
        row.height = CUI_PX(rowHeight - 4);
        row.width = CUI_FILL;
        row.pad_x = 10;
        row.radius = 8;
        row.align_ = CUI_ALIGN_CENTER;
        if (index == selector.highlighted)
        {
            row.bg = tokenColor(CuiToken.accentSubtle);
        }
        cui_box_begin(ui, &row);
        highlightedText(ui, selector.row(index), selector.matchedOffsets(index));
        cui_box_end(ui);
        auto bounds = cui_last_rect(ui);
        auto mouse = cui_mouse_pos(ui);
        if (cui_mouse_clicked(ui, CUI_MOUSE_LEFT) && mouse.x >= bounds.x
                && mouse.x < bounds.x + bounds.w && mouse.y >= bounds.y
                && mouse.y < bounds.y + bounds.h)
        {
            selector.highlight(index);
            selector.accept;
        }
    }

    /// Draws `text` as runs, coloring the bytes at `matchedOffsets` with the accent.
    private void highlightedText(cui_ctx* ui, string text, const(size_t)[] matchedOffsets)
    {
        size_t runStart;
        size_t offset;
        size_t matchIndex;
        bool runMatched;
        while (offset < text.length)
        {
            auto matched = matchIndex < matchedOffsets.length && matchedOffsets[matchIndex] == offset;
            if (matched)
            {
                ++matchIndex;
            }
            if (offset != runStart && matched != runMatched)
            {
                textRun(ui, text[runStart .. offset], runMatched);
                runStart = offset;
            }
            runMatched = matched;
            offset += stride(text, offset);
        }
        if (runStart < text.length)
        {
            textRun(ui, text[runStart .. $], runMatched);
        }
    }

    private void textRun(cui_ctx* ui, string run, bool matched)
    {
        cui_text_opts options;
        options.nowrap = true;
        options.color = tokenColor(matched ? CuiToken.accent : CuiToken.foreground);
        cui_text_ex(ui, run.toStringz, &options);
    }
}
