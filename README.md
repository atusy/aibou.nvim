# aibou.nvim

aibou.nvim is AI-powered pair programming partner.
It captures code changes as you edit and makes feedback on the fly.

```lua
-- example setup with lazy.nvim
{
    {
        "atusy/aibou.nvim",
        dependencies = { "olimorris/codecompanion.nvim" },
        config = function(
            vim.keymap.set("n", "<leader>ai", function()
                require("aibou.codecompanion").start()
            end, { desc = "Start aibou" })
        )
    },
}
```

