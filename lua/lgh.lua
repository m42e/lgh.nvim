local cmds = require "lgh.commands"
local utils = require "lgh.utils"

local M = {}

M.config = {
	basedir = vim.fn.stdpath('data') .. '/githistory/',
	git_cmd = 'git',
	verbose = false,
	fix_ownership = true,
	diff = true,
	new_window = 'vnew'
}

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
local function run_command(cmd, on_exit, on_stdout)
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
	local jobid = vim.fn.jobstart(
		cmd,
		{
			stdout_buffered = true,
			cwd = M.config.basedir,
			on_exit = on_exit_wrapper,
			on_stdout = on_stdout_wrapper,
			on_stderr = on_stdout_wrapper,
      detach = (on_stdout == nil)
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
local function open_backup(dirname, filename, ft, selected)
	local ago, date, commit
	local status, err = pcall (function()
		ago, date, commit = string.match(selected[1], '(.*)\t(.+)\t([0-9a-f]+)$')
	end)

	if commit == nil then return end

	local relpath = utils.relative_path(M.config, dirname, filename)
	local steps = {}

	if M.config.diff then
		table.insert(steps, "diffthis")
	end

	table.insert(steps, M.config.new_window ..' | r! ' .. table.concat(cmds.build_git_command(M.config, 'show', commit..':'..relpath), ' '))
	table.insert(steps,  'normal! 1Gdd')
	table.insert(steps,  "setlocal bt=nofile bh=wipe nobl noswf ro ft=" .. ft .. " | file ".. filename .. " [" .. date .. "(".. ago .. ")]")

	if M.config.diff then
		table.insert(steps, "diffthis")
	end

	vim.cmd(table.concat(steps, '\n'))
end

--- Show the history of the current file
-- @dirname Dirname of the file to show backups
-- @filename Filename of the file to show backups
local function show_history(dirname, filename)
	local backuppath = utils.get_backup_path(M.config, dirname, filename)
	local relpath = utils.relative_path(M.config, dirname, filename)
	local ft = vim.bo.filetype

	local opts = {
		cmd = 'git log --format="%ar%x09%ad%x09%h" -- ' .. relpath,
		cwd = M.config.basedir,
		prompt = "Saved History >>> ",
		previewer = false,
		preview = vim.fn.shellescape('git show {3}:' .. relpath ),
		fzf_opts = {
			['--delimiter']   = "'\t'",
			['--no-multi'] = ''
		},
		actions = {
			["default"]= nil
		} }


	require('fzf-lua.core').fzf_wrap(opts,
		table.concat(cmds.build_git_command(M.config, 'log', '--format="%ar%x09%ad%x09%h"', '--', relpath), ' '),
		function(selected) open_backup(dirname, filename, ft, selected) end
	)()

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

--- Backup a file
-- @dirname Directory of the file
-- @filename Filename of the file
local function backup_file(dirname, filename)
	local commands = {}
	table.insert(commands, cmds.get_commit_command(M.config, dirname, filename))
  vim.fn.system("[[ \"${SUDO_USER:-$USER}\" == `whoami` ]]")
	if vim.v.shellerror ~= 0 then
		if M.config.fix_ownership then
			log('trying to fix ownership, registering callback')
			table.insert(commands, 1, cmds.get_owner_fix_command(M.config, dirname, filename))
		else
			print('current user seems not to be the uid neovim is running at, file will not be backed up')
			return
		end
	end
	table.insert(commands, 1, cmds.get_copy_command(M.config, dirname, filename))
	table.insert(commands, 1, cmds.initialization(M.config, dirname, filename))
	run_command(cmds.shell_cmd(unpack(commands)))
end
M.backup_file = backup_file

--- Fix dangling commits
-- In case some file has been copied but not commited
local function fix_dangling()
	local commands = {}
	local backupdir = vim.fn.fnameescape(utils.get_backup_dir(M.config))
	table.insert(commands, cmds.build_git_command(M.config, 'add',  backupdir))
	table.insert(commands, cmds.build_git_command(M.config, 'commit',  '-m', '"Backup danlging files ' .. backupdir .. '"'))
	run_command(cmds.shell_cmd(unpack(commands)))
end
M.fix_dangling = fix_dangling

return M
