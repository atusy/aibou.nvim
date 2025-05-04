# aibou.nvim

:construction: **WIP** :construction:

aibou.nvim is an AI-powered pair programming partner.
It captures code changes as you edit, and makes feedback on the fly.

NOTE: aibou (相棒) means "partner" in Japanese.

```lua
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
    end,
}
```

## Demo

<div><video controls src="https://github.com/user-attachments/assets/cfbd7ff8-051b-4815-85a0-027ad64bcbd4" muted="false"></video></div>

## Customization

```lua
require("aibou.codecompanion").start({
  -- changing system and initial user prompts
  system_prompt = "You are a helpful assistant.",
  user_prompt = "#buffer\nBe a navigator of pair programming. I will send diff of the buffer",
  -- configuring codecompanion chat
  codecompanion = {
    chat_args = {
      adapter = "openai",
    }
  }
})
```
