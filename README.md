
# JC's Hammerspoon for Development

Just to share, cherry-pick what you need. 

Related Repos: 
- [jc-zed-config](https://github.com/jeremychone/jc-zed-config), Theme, snippets, shortcuts, and more
- [jc-zed-tasks](https://github.com/jeremychone/jc-zed-tasks), Save clipboard to image, HTML to MD
- [jc-tmux-config](https://github.com/jeremychone/jc-tmux-config)
- [jc-alacritty-config](https://github.com/jeremychone/jc-alacritty-config)
- **[jc-hammer (this one)](https://github.com/jeremychone/jc-hammer)**, `jc.spoon` for [Hammerspoon](https://www.hammerspoon.org/), Open/Close Zed projects and position term

_tune as you see fit_

Smart Zed picker chooser that creates new windows only if not already open. 

1 project == 1 window

`cmd + ctrl + shift + o`

![zed picker](https://github.com/user-attachments/assets/8a2cc9ea-977e-42d1-8d63-6cd18db0c4fa)

- Blue opened folders are already-open Zed windows projects. Selecting them brings the Zed window into focus.
- White closed folders are recent Zed projects that are not currently open. Selecting one creates a new Zed window for that project.

Modifiers: 

- `shift` click will keep the chooser open after performing the action and refresh the list
- `option` click will close the project (it will do nothing if the project is not open)

> Note 1: I made this to solve a Zed regression [#54657](https://github.com/zed-industries/zed/issues/54657) that caused Open Recent Project to reopen a new window instead of reusing an already opened window. This issue has a nice [PR #56479](https://github.com/zed-industries/zed/pull/56479) but it is unclear if/when it will be merged

> Note 2: For recent projects, this script reads the Zed recent projects database (`/Library/Application Support/Zed/db/...`).

**IMPORTANT** Make it your own. This `jc.spoon` will evolve with some personal productivity scripts and might change behavior. So, make your own spoon so that you can test/cherry-pick what you need from this one.

## Install

### 1) Install the amazing HammerSpoon

See [HammerSpoon.org](https://www.hammerspoon.org/)

### 2) Set up the jc.spoon

In `~/.hammerspoon/init.lua` add

```lua
hs.loadSpoon("jc")
```

Here is my main init.lua

```lua
---@diagnostic disable: undefined-global

require("hs.ipc") -- To enable command line (not related to jc.spoon)

hs.loadSpoon("jc")
```

> NOTE:
> It is recommended to customize this spoon to your needs. You can then keep it manually in sync.
> Make sure it works as-is, and then copy it to create your own spoon.
> Do not forget to change the spoon name in `jc.spoon/init.lua` at the end of the file.

Restart Hammerspoon or press Reload in the Console

## Usage

`Cmd + Ctrl + Shift + O` triggers the picker (see screenshot above).


---

[This repo](https://github.com/jeremychone/jc-hammer)