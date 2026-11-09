/// Hides the native macOS title bar of a CUI window through the Objective-C runtime.
module selector.macos;

version (OSX)
{
    private extern (C) nothrow @nogc
    {
        void* objc_msgSend(void* receiver, void* selector);
        void* sel_registerName(const(char)* name);
    }

    private enum NSWindowStyleMaskFullSizeContentView = 1UL << 15;
    private enum NSWindowTitleHidden = 1L;

    private alias SendReturningUlong = extern (C) ulong function(void*, void*) nothrow @nogc;
    private alias SendBool = extern (C) void function(void*, void*, bool) nothrow @nogc;
    private alias SendUlong = extern (C) void function(void*, void*, ulong) nothrow @nogc;
    private alias SendLong = extern (C) void function(void*, void*, long) nothrow @nogc;
    private alias SendPointerFromUlong = extern (C) void* function(void*, void*, ulong) nothrow @nogc;

    /// Removes the title text, the title bar background and the close, minimize and zoom buttons.
    /// The window stays resizable and draggable by its background.
    void hideTitleBar(void* window)
    {
        auto selector(const(char)* name)
        {
            return sel_registerName(name);
        }

        auto styleMask = (cast(SendReturningUlong)&objc_msgSend)(window, selector("styleMask"));
        (cast(SendUlong)&objc_msgSend)(window, selector("setStyleMask:"),
                styleMask | NSWindowStyleMaskFullSizeContentView);
        (cast(SendBool)&objc_msgSend)(window, selector("setTitlebarAppearsTransparent:"), true);
        (cast(SendLong)&objc_msgSend)(window, selector("setTitleVisibility:"), NSWindowTitleHidden);
        (cast(SendBool)&objc_msgSend)(window, selector("setMovableByWindowBackground:"), true);
        // Close, miniaturize and zoom.
        foreach (button; 0 .. 3)
        {
            auto view = (cast(SendPointerFromUlong)&objc_msgSend)(window,
                    selector("standardWindowButton:"), button);
            if (view !is null)
            {
                (cast(SendBool)&objc_msgSend)(view, selector("setHidden:"), true);
            }
        }
    }

    /// Space above the content that the transparent title bar still reserves for dragging.
    enum titleBarInset = 28.0f;
}
else
{
    void hideTitleBar(void* window)
    {
    }

    enum titleBarInset = 0.0f;
}
