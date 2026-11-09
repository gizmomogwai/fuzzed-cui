module selector.model;

import std.algorithm : max, min, sort;
import std.range : empty;
import std.uni : toLower;
import std.utf : decode, stride;

/// A line that matches the query, with the byte offsets of the matched characters.
struct Match
{
    size_t lineIndex;
    long score;
    size_t[] matchedOffsets;
}

enum Navigation
{
    up,
    down,
    pageUp,
    pageDown,
    first,
    last,
}

/// Case-insensitive subsequence match; null when `query` is not a subsequence of `line`.
/// Tries every start position and keeps the best-scoring greedy match.
Match* fuzzyMatch(string line, string query, size_t lineIndex)
{
    if (query.empty)
    {
        return new Match(lineIndex, 0, []);
    }
    Match* best;
    size_t start;
    while (start < line.length)
    {
        auto candidate = greedyMatch(line, start, query, lineIndex);
        if (candidate is null)
        {
            break;
        }
        if (best is null || candidate.score > best.score)
        {
            best = candidate;
        }
        start += stride(line, start);
    }
    return best;
}

private Match* greedyMatch(string line, size_t start, string query, size_t lineIndex)
{
    auto match = new Match(lineIndex, 0, []);
    size_t queryOffset;
    size_t lineOffset = start;
    bool previousMatched;
    bool previousSeparator = start == 0;
    if (start != 0)
    {
        auto previous = line[0 .. start];
        auto last = previous[$ - 1];
        previousSeparator = last == ' ' || last == '/' || last == '_' || last == '-' || last == '.';
    }
    while (queryOffset < query.length && lineOffset < line.length)
    {
        auto lineStart = lineOffset;
        auto lineCharacter = line.decode(lineOffset);
        auto queryEnd = queryOffset;
        auto queryCharacter = query.decode(queryEnd);
        auto separator = lineCharacter == ' ' || lineCharacter == '/'
            || lineCharacter == '_' || lineCharacter == '-' || lineCharacter == '.';
        if (lineCharacter.toLower == queryCharacter.toLower)
        {
            match.matchedOffsets ~= lineStart;
            match.score += 10;
            if (previousMatched)
            {
                match.score += 15;
            }
            if (previousSeparator)
            {
                match.score += 8;
            }
            queryOffset = queryEnd;
            previousMatched = true;
        }
        else
        {
            previousMatched = false;
        }
        previousSeparator = separator;
    }
    if (queryOffset < query.length)
    {
        return null;
    }
    // Shorter lines and earlier matches rank higher.
    match.score -= cast(long) line.length / 4;
    if (!match.matchedOffsets.empty)
    {
        match.score -= cast(long) match.matchedOffsets[0] / 2;
    }
    return match;
}

/// UI-independent selector state: the filtered list, the highlighted row and the outcome.
final class Selector
{
    private string[] lines;
    private Match[] matches_;
    private string query_;
    private int highlighted_;
    private int pageSize_ = 10;
    string selection;
    bool chosen;
    bool closed;

    this(string[] lines)
    {
        this.lines = lines;
        filter("");
    }

    string query() const
    {
        return query_;
    }

    int highlighted() const
    {
        return highlighted_;
    }

    int count() const
    {
        return cast(int) matches_.length;
    }

    int totalCount() const
    {
        return cast(int) lines.length;
    }

    string row(int index) const
    {
        return lines[matches_[index].lineIndex];
    }

    const(size_t)[] matchedOffsets(int index) const
    {
        return matches_[index].matchedOffsets;
    }

    void pageSize(int rows)
    {
        pageSize_ = max(1, rows);
    }

    void filter(string newQuery)
    {
        query_ = newQuery;
        matches_ = [];
        foreach (index, line; lines)
        {
            if (auto match = fuzzyMatch(line, newQuery, index))
            {
                matches_ ~= *match;
            }
        }
        if (!newQuery.empty)
        {
            matches_.sort!((left, right) => left.score > right.score
                    || (left.score == right.score && left.lineIndex < right.lineIndex));
        }
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
        if (!query_.empty)
        {
            filter("");
            return;
        }
        closed = true;
    }
}
