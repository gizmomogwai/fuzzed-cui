module selector.model_test;

import selector.model;
import unit_threaded.assertions;

@("subsequence matching ignores case and reports offsets")
unittest
{
    auto match = fuzzyMatch("Banana", "an", 0);
    match.shouldNotBeNull;
    match.matchedOffsets.shouldEqual([1, 2]);
    fuzzyMatch("banana", "xz", 0).shouldBeNull;
}

@("ranks contiguous and boundary matches first")
unittest
{
    auto selector = new Selector(["a---b", "ab", "xaxb"]);
    selector.filter("ab");
    selector.row(0).shouldEqual("ab");
    selector.count.shouldEqual(3);
}

@("empty query keeps input order")
unittest
{
    auto selector = new Selector(["c", "a", "b"]);
    selector.row(0).shouldEqual("c");
    selector.row(2).shouldEqual("b");
}

@("navigation is clamped and accept selects the highlighted row")
unittest
{
    auto selector = new Selector(["alpha", "beta", "gamma"]);
    selector.pageSize = 2;
    selector.navigate(Navigation.up);
    selector.highlighted.shouldEqual(0);
    selector.navigate(Navigation.pageDown);
    selector.navigate(Navigation.pageDown);
    selector.highlighted.shouldEqual(2);
    selector.accept;
    selector.chosen.shouldBeTrue;
    selector.selection.shouldEqual("gamma");
}

@("cancel clears the query before closing")
unittest
{
    auto selector = new Selector(["alpha"]);
    selector.filter("al");
    selector.cancel;
    selector.query.shouldEqual("");
    selector.closed.shouldBeFalse;
    selector.cancel;
    selector.closed.shouldBeTrue;
    selector.chosen.shouldBeFalse;
}

@("accept with no matches does nothing")
unittest
{
    auto selector = new Selector(["alpha"]);
    selector.filter("zzz");
    selector.accept;
    selector.closed.shouldBeFalse;
}

@("contiguous substring outranks scattered subsequence")
unittest
{
    auto selector = new Selector([
        "source/selector", "dub.selections.json", "s-e-l"
    ]);
    selector.filter("sel");
    selector.row(2).shouldEqual("s-e-l");
}
