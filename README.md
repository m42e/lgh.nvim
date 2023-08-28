# neovim Local Git History - in lua

## What this plugin does

This plugin saves the file worked on in a git repository every time you save.
Its a rewrite of https://github.com/m42e/vim-lgh in lua. So this runs only with neovim and is depending on [telescope](https://github.com/nvim-telescope/telescope.nvim).

fzf-lua support has been removed

## Why? Don't you know undo?

Yes, I do know undo, and yes I know persistent undo, too. But there are times, when you replace a file on disk, either by yourself or a git checkout or reset,
or your evil twin deleted a file. And here undo does not help.

## How to use it?

Install it, feel saver. If you want to see the history of a file type

```
:LGHistory
```

And then you get a telescope window with all the dates when the file has been stored.


To search a file in the backup files type

```
:LGHFind
```

then select the file and the revision you wish to view.

## To-dos

Well, basically the same as for the old one, but it still covers the basics.

- Handling of more edge use cases.
- Handling `:q` in diffmode like fugitive does

## Requirements

- git
- an operating system offering a shell (I think this excludes Windows, if someone is eager to try, e.g. with PowerShell, and it works let me know)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "m42e/lgh.nvim",
  depencencies = {
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("lgh").setup({
      fix_dangling = true
    })
  end,
}
```

## Options

You can configure it by callling the setup function with the following options, the given value represents the default:

```lua
require('lgh').setup({
  basedir = vim.fn.stdpath('data') .. '/githistory/',
  git_cmd = 'git',
  verbose = false,
  fix_ownership = true,
  diff = true,
  new_window = 'vnew',
  show_diff_preview = true,
  disabled_paths = {},
  disabled_filenames = {},
  })

```

- **basedir**: The location where the history should be saved. Will be created if not existing. You can provide a **function**(options, dirname, filename) instead. This will be called and is expected to return the basepath for the backup the file. It should return the `basedir` in case dirname and filename are `nil`.
- **git_cmd**: The git command used
- **verbose**: If true, it will bug you with useless information :D
- **fix_ownership**: In case you are using you nvim with `su` or `sudo` it will try to restore the original user as file owner, disabling this may cause issues with file permission in the backup folder, so make sure you know what you are doing. Additionally when running in different user mode, the git command will be executed as original user.
- **diff**: Show history as diff. Else it will only load the history in a new buffer, without starting diff
- **new_window**: How the new window for the history should be created. Like: `vnew`, `new` and options if you like.
- **show_diff_preview**: In preview of previous versions show diff instead of whole file, this is only supported if telescope is used. If the file is currently not available on disk, it will fallback to displaying the stored revision.
- **disabled_paths**: This setting allows you to define __lua patterns__ which the path of the file will be checked against. If a match is found the file will not be backed up.
- **disabled_filenames**: This setting allows you to define __lua patterns__ which the filename of the file will be checked against. If a match is found the file will not be backed up. You can use this e.g. for files that contain sensitive information.

## Inspirations

- [vim-historic](https://github.com/serby/vim-historic) Which also handles a local history in git. But uses some shell script and I ~try to avoid that~ tried to avoid that. The commands ares till using the shell so Windows will not be supported but no extra shell script.
- [vim-localhistory](https://github.com/mg979/vim-localhistory) I saw he is using fzf for handling the history files. I really liked the idea, because I thought about how to make vim-historic better but thinking of that I was afraid. vim-localhistory gave me the hint into the right direction.


