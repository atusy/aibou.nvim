# aibou.nvim

aibou.nvim is an AI-powered pair programming partner.
It captures code changes as you edit, and makes feedback on the fly.

NOTE: aibou (相棒) means "partner" in Japanese.

``` lua
-- example setup with lazy.nvim
{
    "atusy/aibou.nvim",
    dependencies = {
        "olimorris/codecompanion.nvim",
    },
    config = function()
        vim.keymap.set("n", "<leader>ai", function()
            require("aibou.codecompanion").start()
        end, { desc = "Start aibou" })
    end
}
```
