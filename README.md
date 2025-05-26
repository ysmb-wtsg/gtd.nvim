# gtd.nvim

> Simple, modern task management for Neovim — inspired by the "Getting Things Done" philosophy.

`gtd.nvim` is a minimal and keyboard-centric task manager for Neovim.  
It helps you quickly capture, review, and organize tasks using a modern UI powered by [nui.nvim](https://github.com/MunifTanjim/nui.nvim).

https://github.com/user-attachments/assets/2e4c6ef3-69bd-4b89-b7cb-81e7042e47e8

## ✨ Features

- 📥 **INBOX / DONE** workflow
- 🗂️ Task **categories**
- 📅 **Due date** management
- 📝 **Multi-line memos** (markdown-compatible)
- ⌨️ Pure keyboard control
- 📦 Lightweight & dependency-free (except `nui.nvim`)

## 📦 Installation

Requires [nui.nvim](https://github.com/MunifTanjim/nui.nvim)

### Using lazy.nvim

```lua
{
	"ysmb-wtsg/gtd.nvim",
	dependencies = { "MunifTanjim/nui.nvim" },
	config = function()
		require("gtd").setup()
	end,
}
```

## 🚀 Usage

Open the task manager:

```
:GtdOpen
```

### Default Keybindings

| Key       | Description                         |
| --------- | ----------------------------------- |
| `a`       | Add a new task (INBOX only)         |
| `dd`      | Delete selected task (INBOX only)   |
| `<CR>`    | Toggle done/undone                  |
| `Tab`     | Switch between INBOX / DONE view    |
| `q`       | Close the UI                        |
| `j / k`   | Move between tasks                  |
| `<Space>` | Select task for reorder             |
| `i`       | Show task details                   |
| `e`       | Edit selected detail in info modal  |
| `R`       | Clear all DONE tasks (with confirm) |
| `g?`      | Show help                           |

### Task Properties

- **Title**
- **Category**
- **Due date**
- **Memo** (markdown-supported)

## 📁 Storage

Tasks are stored as JSON in:

```
~/.local/share/nvim/gtd-nvim.json
```

(Uses `vim.fn.stdpath("data")` internally.)

## 🧠 Philosophy

This plugin draws inspiration from the **GTD (Getting Things Done)** methodology.
It encourages:

- Quick capture (INBOX)
- Focused review (task details)
- Clear action (DONE)

But it stays out of your way — no unnecessary complexity.

## 📄 License

MIT

---

Made with 💡 by ysmb-wtsg
