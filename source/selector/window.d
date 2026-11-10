module selector.window;

import core.stdc.string : strlen;
import cui_c;
import cui_util : CUI_FILL, tokenColor, CuiToken;
import selector.model : Navigation, Selector;
import selector.theme : mix, Rgb, standardAccentIndex, ThemeName, zenburn, zenburnAccent;
import std.algorithm : max, min;
import std.format : format;
import std.range : empty;
import std.string : toStringz;
import std.uni : graphemeStride;

private enum rowHeight = 34.0f;
private enum queryCapacity = 256;

/// Runs the selector in a CUI window until a line is chosen or the window is closed.
final class SelectorWindow
{
    private cui_app* app;
    private Selector selector;
    private char[queryCapacity] queryBuffer;
    private float scrollTop = 0;
    private bool highlightChanged = true;

    this(Selector selector, string title, bool hidden = false,
            ThemeName theme = ThemeName.standard, string accent = "violet")
    {
        this.selector = selector;
        cui_app_desc description;
        description.title = title.toStringz;
        description.width = 760;
        description.height = 560;
        description.hidden = hidden;
        description.borderless = true;
        description.theme = CUI_THEME_DARK;
        description.accent = cast(cui_accent) standardAccentIndex(theme == ThemeName.standard
                ? accent : "neutral");
        app = cui_app_create(&description);
        if (app is null)
        {
            throw new Exception("Could not create the CUI window");
        }
        if (theme == ThemeName.zenburn)
        {
            applyZenburn(cui_theme_get(cui_app_ui(app)), zenburnAccent(accent));
        }
    }

    /// Overwrites the colors of CUI's dark theme; the selector never switches theme at runtime.
    private static void applyZenburn(cui_theme* theme, Rgb accent)
    {
        static cui_color color(Rgb value, ubyte alpha = 255)
        {
            return cui_color(value.red, value.green, value.blue, alpha);
        }

        auto colors = theme.colors.ptr;
        colors[CUI_TOKEN_BACKGROUND] = color(zenburn.background);
        colors[CUI_TOKEN_SURFACE] = color(zenburn.surface);
        colors[CUI_TOKEN_SURFACE_RAISED] = color(zenburn.surfaceRaised);
        colors[CUI_TOKEN_SURFACE_MUTED] = color(zenburn.surfaceMuted);
        colors[CUI_TOKEN_FOREGROUND] = color(zenburn.foreground);
        colors[CUI_TOKEN_TEXT_SECONDARY] = color(zenburn.secondary);
        colors[CUI_TOKEN_TEXT_MUTED] = color(zenburn.muted);
        colors[CUI_TOKEN_BORDER] = color(mix(zenburn.surface, zenburn.foreground, 0.18));
        colors[CUI_TOKEN_BORDER_SUBTLE] = color(mix(zenburn.surface, zenburn.foreground, 0.08));
        colors[CUI_TOKEN_BORDER_STRONG] = color(mix(zenburn.surface, zenburn.foreground, 0.4));
        colors[CUI_TOKEN_ACCENT] = color(accent);
        colors[CUI_TOKEN_ACCENT_STRONG] = color(mix(accent, zenburn.foreground, 0.35));
        colors[CUI_TOKEN_ACCENT_SUBTLE] = color(accent, 0x30);
        colors[CUI_TOKEN_ACCENT_FOREGROUND] = color(zenburn.background);
        colors[CUI_TOKEN_SUCCESS] = color(zenburn.success);
        colors[CUI_TOKEN_WARNING] = color(zenburn.warning);
        colors[CUI_TOKEN_DANGER] = color(zenburn.danger);
        colors[CUI_TOKEN_INFO] = color(zenburn.info);
        colors[CUI_TOKEN_CONTROL_ON] = color(accent);
        colors[CUI_TOKEN_CONTROL_GLYPH] = color(zenburn.background);
        colors[CUI_TOKEN_CONTROL_TRACK] = color(zenburn.surfaceMuted);
        colors[CUI_TOKEN_CONTROL_TRACK_HOVER] = color(mix(zenburn.surfaceMuted,
                zenburn.foreground, 0.12));
        colors[CUI_TOKEN_CONTROL_THUMB] = color(zenburn.foreground);
        colors[CUI_TOKEN_CONTROL_THUMB_ON] = color(zenburn.background);
        colors[CUI_TOKEN_HOVER] = color(zenburn.foreground, 13);
        colors[CUI_TOKEN_ACTIVE] = color(zenburn.foreground, 19);
        colors[CUI_TOKEN_FOCUS_RING] = color(mix(accent, zenburn.background, 0.35));
        foreach (index, series; zenburn.series)
        {
            colors[CUI_TOKEN_SERIES_1 + index] = color(series);
        }
        theme.tone_sky = color(zenburn.series[0]);
        theme.tone_amber = color(zenburn.series[1]);
        theme.tone_green = color(zenburn.series[2]);
        theme.tone_orchid = color(zenburn.series[3]);
        theme.tone_violet = color(zenburn.series[3]);
        theme.tone_rose = color(zenburn.danger);
        theme.tone_teal = color(zenburn.series[5]);
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

        cui_box outer;
        outer.pad = 16;
        outer.pad_top = 16;
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
        resultList(ui);
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

    private void resultList(cui_ctx* ui)
    {
        if (selector.count == 0)
        {
            cui_muted(ui, "No matches");
            return;
        }
        cui_box wrapper;
        wrapper.id = "list";
        wrapper.width = CUI_FILL;
        wrapper.height = CUI_FILL;
        wrapper.dir = CUI_STACK;
        auto wrapperId = cui_box_begin(ui, &wrapper);
        auto listBounds = cui_get_rect(ui, wrapperId);
        if (listBounds.h > 0)
        {
            // Bounds are from the previous frame; the model keeps its default until then.
            selector.pageSize = cast(int)(listBounds.h / rowHeight) - 1;
        }
        int first, last;
        cui_virtual_list_begin(ui, "rows", selector.count, rowHeight, CUI_FILL, &first, &last);
        bool scrollKnown;
        foreach (index; first .. last)
        {
            auto rowBounds = resultRow(ui, index);
            if (!scrollKnown && listBounds.h > 0 && rowBounds.h > 0)
            {
                // Row `index` sits at index * rowHeight minus the scroll offset, as of the previous frame.
                scrollTop = index * rowHeight - (rowBounds.y - listBounds.y);
                scrollKnown = true;
            }
        }
        cui_virtual_list_end(ui);
        if (highlightChanged && listBounds.h > 0)
        {
            highlightChanged = !scrollToHighlighted(ui, listBounds.h);
        }
        scrollbar(ui, listBounds);
        cui_box_end(ui);
    }

    /// A thin scrollbar that stays visible, unlike CUI's overlay bar that fades out.
    private void scrollbar(cui_ctx* ui, cui_rect bounds)
    {
        auto contentHeight = selector.count * rowHeight;
        if (bounds.h <= 0 || contentHeight <= bounds.h)
        {
            return;
        }
        enum width = 6.0f;
        auto thumbHeight = max(28.0f, bounds.h * bounds.h / contentHeight);
        auto travel = bounds.h - thumbHeight - 4;
        auto ratio = max(0.0f, min(1.0f, scrollTop / (contentHeight - bounds.h)));
        auto x = bounds.x + bounds.w - width - 2;
        auto foreground = cui_color_of(ui, tokenColor(CuiToken.foreground));
        cui_draw_rect(ui, cui_rect(x, bounds.y + 2, width, bounds.h - 4),
                cui_corners(3, 3, 3, 3), cui_alpha(foreground, 0.08f));
        cui_draw_rect(ui, cui_rect(x, bounds.y + 2 + ratio * travel, width,
                thumbHeight), cui_corners(3, 3, 3, 3), cui_alpha(foreground, 0.35f));
    }

    /// Scrolls the highlighted row into view; true once it is fully visible.
    private bool scrollToHighlighted(cui_ctx* ui, float listHeight)
    {
        auto rowTop = selector.highlighted * rowHeight;
        auto rowBottom = rowTop + rowHeight;
        if (rowTop < scrollTop)
        {
            cui_scroll_to(ui, "rows", rowTop);
        }
        else if (rowBottom > scrollTop + listHeight)
        {
            cui_scroll_to(ui, "rows", rowBottom - listHeight);
        }
        else
        {
            return true;
        }
        return false;
    }

    private cui_rect resultRow(cui_ctx* ui, int index)
    {
        cui_box row;
        row.id = format("row%d", index).toStringz;
        row.dir = CUI_ROW;
        row.width = CUI_FILL;
        row.pad_x = 10;
        row.pad_right = 18;
        row.radius = 8;
        row.align_ = CUI_ALIGN_CENTER;
        if (index == selector.highlighted)
        {
            row.bg = tokenColor(CuiToken.accentSubtle);
        }
        auto rowId = cui_box_begin(ui, &row);
        auto rowBounds = cui_get_rect(ui, rowId);
        highlightedText(ui, selector.row(index), selector.matchedPositions(index));
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
        return rowBounds;
    }

    /// Draws `text` as one text node, coloring the graphemes at `matchedPositions` with the accent.
    private void highlightedText(cui_ctx* ui, string text, const(ulong)[] matchedPositions)
    {
        cui_highlight_range[] ranges;
        size_t offset;
        size_t position;
        size_t matchIndex;
        while (offset < text.length && matchIndex < matchedPositions.length)
        {
            const next = offset + graphemeStride(text, offset);
            if (matchedPositions[matchIndex] == position)
            {
                ++matchIndex;
                if (!ranges.empty && ranges[$ - 1].end == offset)
                {
                    ranges[$ - 1].end = cast(int) next;
                }
                else
                {
                    ranges ~= cui_highlight_range(cast(int) offset, cast(int) next);
                }
            }
            offset = next;
            ++position;
        }
        cui_highlight_text_opts options;
        options.color = tokenColor(CuiToken.foreground);
        options.highlight = tokenColor(CuiToken.accent);
        cui_highlight_text_ex(ui, text.toStringz, ranges.ptr, cast(int) ranges.length, &options);
    }
}
