# neovim Local Git History - in lua

## What this plugin does

This plugin saves the file worked on in a git repository every time you save.
Its a rewrite of https://github.com/m42e/vim-lgh in lua. So this runs only with neovim and https://github.com/ibhagwan/fzf-lua

## Why? Don't you know undo?

Yes, I do know undo, and yes I know persistent undo, too. But there are times, when you replace a file on disk, either by yourself or a git checkout or reset,
or your evil twin deleted a file. And here undo does not help.

## How to use it?

Install it, feel saver. If you want to see the history of a file type

```
:LGHistory
```

And then you get an fzf window with all the dates when the file has been stored.

## To-dos

Well, basically the same as for the old one, but it still covers the basics.

- Search for files where you don't have the exact filename
- Allowing diff mode
- Handling of more edge use cases.
- Handling `:q` in diffmode like fugitive does

## Installation

[fzf-lua](https://github.com/ibhagwan/fzf-lua) is required.

With packer:

```
use { 'm42e/lgh.nvim',
        requires = {
            "nvim-telescope/telescope.nvim",
        },
    }
```

## Options

You can configure it by callling the setup function with the following options, the given value represents the default:

```
require('lgh').setup({
  basedir = vim.fn.stdpath('data') .. '/githistory/',
  git_cmd = 'git',
  verbose = false,
  fix_ownership = true,
  diff = true,
  new_window = 'vnew'
  })

```

- **basedir**: The location where the history should be saved. Will be created if not existing. You can provide a **function**(options, dirname, filename) instead. This will be called and is expected to return the basepath for the backup the file.
- **git_cmd**: The git command used
- **verbose**: If true, it will bug you with useless information :D
- **fix_ownership**: In case you are using you nvim with `su` or `sudo` it will try to restore the original user as file owner, disabling this may cause issues with file permission in the backup folder, so make sure you know what you are doing. Additionally when running in different user mode, the git command will be executed as original user.
- **diff**: Show history as diff. Else it will only load the history in a new buffer, without starting diff
- **new_window**: How the new window for the history should be created. Like: `vnew`, `new` and options if you like.
- **show_diff_preview**: In preview of previous versions show diff instead of whole file

## Inspirations

- [vim-historic](https://github.com/serby/vim-historic) Which also handles a local history in git. But uses some shell script and I try to avoid that. To at least have a possibility that it may work on Windows
- [vim-localhistory](https://github.com/mg979/vim-localhistory) I saw he is using fzf for handling the history files. I really liked the idea, because I thought about how to make vim-historic better but thinking of that I was afraid. vim-localhistory gave me the hint into the right direction.


