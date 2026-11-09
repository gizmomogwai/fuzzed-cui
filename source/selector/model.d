module selector.model;

import fuzzed.model : Model;
import std.algorithm : max, min;
import std.range : empty;

enum Navigation
{
    up,
    down,
    pageUp,
    pageDown,
    first,
    last,
}

/// UI-independent selector state: the filtered list, the highlighted row and the outcome.
final class Selector
{
    private Model model;
    private int highlighted_;
    private int pageSize_ = 10;
    string selection;
    bool chosen;
    bool closed;

    this(string[] lines)
    {
        model = new Model;
        model.setData(lines);
    }

    string query() const
    {
        return model.pattern;
    }

    int highlighted() const
    {
        return highlighted_;
    }

    int count() const
    {
        return cast(int) model.matches.length;
    }

    int totalCount() const
    {
        return cast(int) model.all.length;
    }

    string row(int index) const
    {
        return model.matches[index].value;
    }

    /// Grapheme positions of the row that match the query.
    const(ulong)[] matchedPositions(int index) const
    {
        return model.matches[index].positions;
    }

    void pageSize(int rows)
    {
        pageSize_ = max(1, rows);
    }

    void filter(string newQuery)
    {
        model.update(newQuery);
        highlighted_ = 0;
    }

    void navigate(Navigation direction)
    {
        if (count == 0)
        {
            return;
        }
        final switch (direction)
        {
        case Navigation.down:
            highlighted_ = min(count - 1, highlighted_ + 1);
            break;
        case Navigation.up:
            highlighted_ = max(0, highlighted_ - 1);
            break;
        case Navigation.pageDown:
            highlighted_ = min(count - 1, highlighted_ + pageSize_);
            break;
        case Navigation.pageUp:
            highlighted_ = max(0, highlighted_ - pageSize_);
            break;
        case Navigation.first:
            highlighted_ = 0;
            break;
        case Navigation.last:
            highlighted_ = count - 1;
            break;
        }
    }

    void highlight(int index)
    {
        if (index >= 0 && index < count)
        {
            highlighted_ = index;
        }
    }

    void accept()
    {
        if (highlighted_ < 0 || highlighted_ >= count)
        {
            return;
        }
        selection = row(highlighted_);
        chosen = true;
        closed = true;
    }

    /// Clears a non-empty query first; otherwise closes without a selection.
    void cancel()
    {
        if (!query.empty)
        {
            filter("");
            return;
        }
        closed = true;
    }
}
