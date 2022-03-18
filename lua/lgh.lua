local cmds = require "lgh.commands"
local utils = require "lgh.utils"

local M = {}

M.config = {
	basedir = vim.fn.stdpath('data') .. '/githistory/',
	git_cmd = 'git',
	verbose = true,
	fix_ownership = true,
	diff = true,
	new_window = 'vnew'
}

local function log(...)
	if M.config.verbose then
		print(...)
	end
end

local function ensure_directory(dir)
	if vim.fn.isdirectory(dir) ~= 1 then
		vim.fn.mkdir(dir)
	end
end

-- public
local function run_command(cmd, on_exit, on_stdout)
	log('running command: ', cmd)
	local jobid = vim.fn.jobstart(
		cmd,
		{
			stdout_buffered = true,
			cwd = M.config.basedir,
			on_exit = on_exit,
			on_stdout = on_stdout,
			on_stderr = on_stdout,
			detach = (on_stdout == nil)
		}
	)
end

local function check_git_dir()
	log('cheching lgh backup directory')
	run_command(cmds.build_git_command(M.config, 'rev-parse', '--is-inside-work-tree'), function(_, data, _)
		if data ~= 0 then
			log('directory not initialized, doing so')
			run_command(cmds.build_git_command(M.config, 'init', '.'), function(_, data, _)
				if data ~= 0 then
					print('Could not initialize lgh.nvim backup directory')
				end
				run_command(cmds.build_git_command(M.config, 'config', '--local', 'user.email', 'local-history-git@noemail.com'))
				run_command(cmds.build_git_command(M.config, 'config', '--local', 'user.name', 'local-history-git'))
				run_command(cmds.build_git_command(M.config, 'commit', '--allow-empty', '-m', 'initial commit (empty)'))
			end
			)
		end
	end
	)
end

local function open_backup(dirname, filename, ft, selected, opts)
	local ago, date, commit
	local status, err = pcall (function()
		ago, date, commit = string.match(selected[1], '.*/([^/]*)\t(.+)\t([0-9a-f]+)$')
	end)
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

	function() vim.cmd(table.concat(steps, '\n'))end
end

local function show_history(dirname, filename)
	local backuppath = utils.get_backup_path(M.config, dirname, filename)
	local relpath = utils.relative_path(M.config, dirname, filename)
	local ft = vim.bo.filetype

	require('fzf-lua').git_files({
		cmd = 'git log --format="%ar%x09%ad%x09%h" -- ' .. relpath,
		cwd = M.config.basedir,
		prompt = "Saved History >>> ",
		previewer = false,
		preview = '"git show {3}:' .. relpath .. '"',
		fzf_opts = {
			['--delimiter']   = "'\t'",
		},
		actions = {
			["default"]= function(selected, opts) open_backup(dirname, filename, ft, selected, opts) end,
		} } )
end

M.show_history = show_history

local function setup(opts)
	local globals = vim.tbl_deep_extend("keep", opts, M.config)
	globals.basedir = vim.fn.resolve(globals.basedir)
	if string.sub(globals.basedir, -1) ~= '/' then
		globals.basedir = globals.basedir .. '/'
	end
	ensure_directory(globals.basedir)
	check_git_dir()
	log('setting up lgh.nvim', vim.inspect(globals))
	M.config = globals

	vim.cmd [[

		augroup lgh.nvim
				autocmd!
				autocmd BufWritePost * lua require('lgh').backup_file(vim.fn.expand("%:p:h"), vim.fn.expand("%:t"))
		augroup END

		com! LGHFix lua require('lgh').fix_dangling()
		com! LGHistory lua require('lgh').show_history(vim.fn.expand("%:p:h"), vim.fn.expand("%:t"))
	]]

end
M.setup = setup

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
	run_command(cmds.shell_cmd(unpack(commands)))
end
M.backup_file = backup_file

local function fix_dangling()
	local commands = {}
	local backupdir = vim.fn.fnameescape(utils.get_backup_dir(M.config))
	table.insert(commands, cmds.build_git_command(M.config, 'add',  backupdir))
	table.insert(commands, cmds.build_git_command(M.config, 'commit',  '-m', '"Backup danlging files ' .. backupdir .. '"'))
	run_command(cmds.shell_cmd(unpack(commands)))
end
M.fix_dangling = fix_dangling

return M
