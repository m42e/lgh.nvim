local cmds = require "lgh.commands"
local utils = require "lgh.utils"

local M = {}

M.config = {
  -- Base directory to save file history
  basedir = vim.fn.stdpath('data') .. '/githistory/',
  -- git command to use, coudl be command or full path
  git_cmd = 'git',
  -- log a lot of things, you might not want to hear about
  verbose = false,
  -- fix ownership of files. highly recommended, especially if you tend to use sudo
  fix_ownership = true,
  -- if a uncommitted files is found, just add and commit it
  fix_dangling = false,
  -- open history file in diff mode
  diff = true,
  -- command to open history file with, something like vnew, tabnew, ect.
  new_window = 'vnew',
  -- should the preview display the differences to the current file?
  show_diff_preview = true,
  -- do not backup the following paths (pattern matching)
  disabled_paths = {},
  -- do not backup the following files (pattern matching)
  disabled_filenames = {},
}

M.last_error = {}
M.last_command = {}

--- Logging if enabled
-- @args things to log
local function log(...)
  if M.config.verbose then
    print(...)
  end
end

local function ensure_directory(dir)
  if vim.fn.isdirectory(dir) ~= 1 then
    log('creating directory')
    vim.fn.mkdir(dir)
  end
end


-- public
--- Run a command in the base directory and return the job id
-- @cmd The command to run
-- @on_exit Function to be called if the command completes
-- @on_stdout Function to receive output
local function run_command(cmd, on_exit, on_stdout, on_stderr)
  M.last_command = cmd
  ensure_directory(M.config.basedir)
  local function on_exit_wrapper(jobid, exit_code, event)
    log(event,'[', jobid, ']: ', exit_code)
    if on_exit ~= nil then
      on_exit(jobid, exit_code, event)
    end
  end
  local function on_stdout_wrapper(jobid, data, event)
    log(event,'[', jobid, ']: ', table.concat(data, '\n'))
    if on_stdout ~= nil then
      on_stdout(jobid, data, event)
    end
  end
  local function on_stderr_wrapper(jobid, data, event)
    log(event,'[', jobid, ']: ', table.concat(data, '\n'))
    M.handle_stderr(jobid, data, event)
    if on_stderr ~= nil then
      on_stderr(jobid, data, event)
    end
  end
  log('running command: ', cmd)
  local jobid = vim.fn.jobstart(
  cmd,
  {
    stdout_buffered = true,
    cwd = M.config.basedir,
    on_exit = on_exit_wrapper,
    on_stdout = on_stdout_wrapper,
    on_stderr = on_stderr_wrapper,
    detach = false -- (on_stdout == nil and on_stderr == nil),
  }
  )
  log('command [', jobid, ']: ', cmd)
  return jobid
end

--- Opent the backup for a file
-- @dirname Dirname of the file to show backup for
-- @filename Filename of the file to show backup for
-- @ft Filetype of the original file (for highlighting)
-- @selected Selected entry of history, to extract commit
local function open_backup(dirname, filename, ft, selected, noshowdiff)
  local ago, date, commit
  if selected == nil then
    return
  end
  ago = selected.reltime
  date = selected.date
  commit = selected.hash

  if commit == nil then return end

  local relpath = utils.relative_path(M.config, dirname, filename)
  local steps = {}

  if M.config.diff and not noshowdiff then
    table.insert(steps, "diffthis")
  end


  table.insert(steps, M.config.new_window ..' | r! ' .. table.concat(cmds.build_git_command(M.config, 'show', commit..':'..relpath), ' '))
  table.insert(steps,  'normal! 1Gdd')
  table.insert(steps,  "setlocal bt=nofile bh=wipe nobl noswf ro ft=" .. ft .. " | file ".. filename .. " [" .. date .. "(".. ago .. ")]")

  if M.config.diff then
    table.insert(steps, "diffthis")
  end

  local commands = table.concat(steps, '\n')

  log('Run in vim:\n' .. commands)
  vim.cmd(commands)
end

--- Show all available backup files (for this host)
local function find_in_history()
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local backuppath = utils.get_backup_basedir(M.config, nil, nil)
  local function run_selection(prompt_bufnr, map)
    actions.select_default:replace(function()
      actions.close(prompt_bufnr)
      local selection = action_state.get_selected_entry()
      dirname, path = utils.split_path(M.config, selection[1])
      M.show_history(dirname, path, true)
    end)
    return true
  end
  local opts = {
    attach_mappings = run_selection,
    cwd = backuppath
  }
  require('telescope.builtin').find_files(opts)
end
M.find_in_history = find_in_history

--- Show the history of the current file
-- @dirname Dirname of the file to show backups
-- @filename Filename of the file to show backups
local function show_history(dirname, filename, nodiff)
  local relpath = utils.relative_path(M.config, dirname, filename)
  local noshowdiff = nodiff or false

  local status, pickers = pcall(require, "telescope.pickers")
  local finders = require "telescope.finders"
  local previewers = require "telescope.previewers"
  local entry_display = require "telescope.pickers.entry_display"
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local from_entry = require "telescope.from_entry"

  local cmd = {'git', 'log', '--format=%ar%x09%ai%x09%h', '--', relpath}

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 24 },
      { remaining = true },
    },
  }

  local make_display = function(entry)
    return displayer {
      { entry.reltime, "TelescopeResultsIdentifier" },
      entry.date,
    }
  end

  local opts = {
    cwd = M.config.basedir,
    delimiter = '\t',
    entry_maker = function(entry)
      local v = {}
      for k in string.gmatch(entry, "([^\t]+)") do
        table.insert(v, k)
      end
      return {
        value = v[3],
        reltime = v[1],
        date = v[2],
        hash = v[3],
        display = make_display,
        ordinal = v[1]
      }
    end
  }
  local finder = finders.new_oneshot_job( cmd, opts )

  local putils = require "telescope.previewers.utils"
  local conf = require("telescope.config").values
  local diff_preview = previewers.new_buffer_previewer {
    title = "Git File Diff Preview",
    get_buffer_by_name = function(_, entry)
      return entry.value
    end,

    define_preview = function(self, entry)
      if entry.status and (entry.status == "??" or entry.status == "A ") then
        local p = from_entry.path(entry, true)
        if p == nil or p == "" then
          return
        end
        conf.buffer_previewer_maker(p, self.state.bufnr, {
          bufname = self.state.bufname,
          winid = self.state.winid,
        })
      else
        local cmd = ''
        if M.config.show_diff_preview and vim.fn.filereadable(dirname .. '/' .. filename) ~= 0 then
          cmd = {vim.opt.shell:get(), '-c', cmds.multiple_commands(
            cmds.build_git_command(M.config, 'show', entry.hash .. ':' .. relpath),
            '|',
            {'diff', '--unified', '--color=never', dirname .. '/' .. filename, '-' },
            '|',
            {'tail', '-n+5'}
            )
          }
          vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "diff")
        else
          cmd = cmds.build_git_command(M.config, 'show', entry.hash .. ':' .. relpath )
          local ft = putils.filetype_detect(relpath)
          if ft then
            vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", ft)
          end

        end
        putils.job_maker(cmd, self.state.bufnr, {
          value = entry.value,
          bufname = self.state.bufname,
          cwd = opts.cwd,
          callback = function(bufnr)
            if vim.api.nvim_buf_is_valid(bufnr) then
              putils.regex_highlighter(bufnr, "diff")
            end
          end,
        })
      end
    end,
  }


  pickers.new(opts, {
    prompt_title = "History of " .. filename .. " in " .. dirname,
    finder = finder,
    sorter = conf.generic_sorter(opts),
    previewer = diff_preview,
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        open_backup(dirname, filename, ft, selection, noshowdiff)
      end)
      return true
    end,
  }):find()
end
M.show_history = show_history

--- Setup function for lgh.nvim
-- @opts Options for lgh.nvim
local function setup(opts)
  local globals = vim.tbl_deep_extend("keep", opts, M.config)
  globals.basedir = vim.fn.resolve(globals.basedir)
  if string.sub(globals.basedir, -1) ~= '/' then
    globals.basedir = globals.basedir .. '/'
  end
  M.config = globals
end
M.setup = setup

local function handle_stderr(channel, data, name)
  for _,v in ipairs(data) do
    table.insert(M.last_error, v)
  end
end
M.handle_stderr = handle_stderr

local function handle_exit(channel, exitcode, name)
  if exitcode ~= 0 then
    print("An error occured while running ", M.last_command, vim.inspect(M.last_error))
    for _,v in ipairs(M.last_error) do
      print(v)
    end
  end
end
M.handle_exit = handle_exit

local function is_superuser_active()
  local is_superuser_mode = false
  local effectiveuserid = vim.fn.system("whoami")
  effectiveuserid = effectiveuserid:gsub("%s+", "")
  local user = vim.env.SUDO_USER
  if user == nil then
    user = vim.env.USER
  end
  if user ~= effectiveuserid then
    is_superuser_mode = true
  end
  return is_superuser_mode
end
M.is_superuser_active = is_superuser_active

local function ignore_file(dirname, filename)
  for _, dpattern in ipairs(M.config.disabled_paths) do
    if string.match(dirname, dpattern, 1) ~= nil then
      return true
    end
  end
  for _, fpattern in ipairs(M.config.disabled_filenames) do
    if string.match(filename, fpattern, 1) ~= nil then
      return true
    end
  end
  return false
end
M.ignore_file = ignore_file

--- Backup a file
-- @dirname Directory of the file
-- @filename Filename of the file
local function backup_file(dirname, filename)
  local commands = {}
  if M.ignore_file(dirname, filename) then
    return
  end

  local is_superuser_mode = M.is_superuser_active()
  commit_command = cmds.get_commit_command(M.config, dirname, filename)
  if is_superuser_mode then
    commit_command = cmds.wrap_in_sudo(commit_command)
  end
  table.insert(commands, commit_command)
  if is_superuser_mode then
    if M.config.fix_ownership then
      log('trying to fix ownership, registering callback')
      table.insert(commands, 1, cmds.get_owner_fix_command(M.config, dirname, filename))
    else
      print('current user seems not to be the uid neovim is running at, file will not be backed up')
      return
    end
  end
  if M.config.fix_dangling then
    local backupdir = vim.fn.fnameescape(utils.get_backup_dir(M.config))
    table.insert(commands, cmds.build_git_command(M.config, 'add',  backupdir))
    table.insert(commands, '&&')
    table.insert(commands, cmds.build_git_command(M.config, 'commit',  '-m', '"Backup danlging files ' .. backupdir .. '"'))
  end
  table.insert(commands, "exit 0")
  table.insert(commands, 1, cmds.get_copy_command(M.config, dirname, filename))
  table.insert(commands, 1, cmds.initialization(M.config, dirname, filename))

  run_command(cmds.shell_cmd(unpack(commands)), M.handle_exit, nil, M.handle_stderr)
end
M.backup_file = backup_file

--- Fix dangling commits
-- In case some file has been copied but not commited
local function fix_dangling()
  local commands = {}
  local backupdir = vim.fn.fnameescape(utils.get_backup_dir(M.config))
  table.insert(commands, cmds.build_git_command(M.config, 'add',  backupdir))
  table.insert(commands, cmds.build_git_command(M.config, 'commit',  '-m', '"Backup danlging files ' .. backupdir .. '"'))
  run_command(cmds.shell_cmd(unpack(commands)), M.handle_exit, nil, M.handle_stderr)
end
M.fix_dangling = fix_dangling

return M
