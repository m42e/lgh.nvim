local utils = require('lgh.utils')
local M = {}

--- Makes a command executed in the shell
-- Automatically concats commands and executes them in a shell
-- @args The commands
function M.shell_cmd(...)
	return vim.opt.shell:get() .. ' ' .. vim.opt.shellcmdflag:get() .. ' ' .. vim.fn.shellescape(M.multiple_commands(...))
end

--- Concats multiple command line commands.
-- Per default it executes one after another (using ;). You can change that
-- by adding a '&&' or '||' as concatenation element
-- @args The commands
function M.multiple_commands(...)
	local commands = {...}
	local tbl = {}

	local add_semicolon = false
	for k, c in pairs(commands) do
		local entry
		if type(c) == "string" then
			entry = c
		else
			entry = table.concat(c, ' ')
		end
		if add_semicolon and string.find('&& ||', entry) == nil then
			table.insert(tbl, ';')
		end
		table.insert(tbl, entry)
		add_semicolon = (string.find('&& ||', entry) == nil)
	end
	return '(' .. table.concat(tbl, ' ') .. ')'
end

--- Build a git command with the base directory
-- @opts The options for lgh.nvim
-- @args The command arguments
function M.build_git_command(opts, ...)
	local command = {
		opts.git_cmd,
		'--work-tree',
		opts.basedir,
		'--git-dir',
		opts.basedir .. '.git',
	}
	local args={...}
	for _, v in pairs(args) do
		table.insert(command,v)
	end
	return command
end

--- Get the whole commit chain (add and commit if changed)
-- @opts The options for lgh.nvim
-- @dirname The directory name of the file to be commited
-- @filename The filename name of the file to be commited
function M.get_commit_command(opts, dirname, filename)
	local backuppath = utils.get_backup_path(opts, dirname, filename)
	return M.multiple_commands(
		M.build_git_command(opts, 'add', backuppath),
		'&&',
		M.build_git_command(opts, 'diff-index', '--quiet', 'HEAD', '--', backuppath),
		'||',
		M.build_git_command(opts, 'commit', '-m', '"Backup ' .. dirname .. '/'.. filename .. '"', backuppath)
	)
end

--- Get the command to fix the file ownership
-- @opts The options for lgh.nvim
-- @dirname The directory name of the file to be commited
-- @_ Ignored parameter to keep the signatures equal
function M.get_owner_fix_command(opts, dirname, _)
	local backupdir = vim.fn.fnameescape(utils.get_backup_dir(opts, dirname))
	local realuser = vim.env.SUDO_USER
	if realuser == nil then
		realuser = vim.env.USER
	end
  if realuser == nil then
    local pipe = io.popen('whoami')
    realuser = pipe:read("*a")
  end
  return {'chown', '-R', realuser, backupdir}
end
--- Get the command to copy the file to backup into the right directory
-- @opts The options for lgh.nvim
-- @dirname The directory name of the file to be commited
-- @filename The filename name of the file to be commited
function M.get_copy_command(opts, dirname, filename)
	local backuppath = utils.get_backup_path(opts, dirname, filename)
	return {'cp', vim.fn.fnameescape(vim.fn.resolve(vim.fn.expand("%:p"))), vim.fn.fnameescape(backuppath) }
end

--- Get command for creating dir for the backup
-- @opts The options for lgh.nvim
-- @dirname The directory name of the file to be commited
-- @filename The filename name of the file to be commited
function M.make_backup_dir(opts, dirname, filename)
	local backuppath = utils.get_backup_dir(opts, dirname, filename)
	return {'mkdir', '-p', backuppath}
end

--- Wrap function to be called with real user in sudo mode
-- @command The command table to wrap
function M.wrap_in_sudo(command)
  if type(command) == 'table' then
    table.insert(command, 1, vim.env.SUDO_USER)
    table.insert(command, 1, '-u')
    table.insert(command, 1, 'sudo')
  else
    command = 'sudo -u ' .. vim.env.SUDO_USER .. ' ' .. command
  end
  return command
end

--- Get command for the initialization of the backup directory
-- @opts The options for lgh.nvim
-- @dirname The directory name of the file to be commited
-- @filename The filename name of the file to be commited
function M.initialization(opts, dirname, filename)
	local backuppath = utils.get_backup_path(opts, dirname, filename)
	return M.multiple_commands(
		M.make_backup_dir(opts, dirname, filename),
		'&&',
		M.build_git_command(opts, 'rev-parse', '--is-inside-work-tree'),
		'||',
		M.multiple_commands(
			M.build_git_command(opts, 'init', '.'),
			M.build_git_command(opts, 'config', '--local', 'user.email', 'local-history-git@noemail.com'),
			M.build_git_command(opts, 'config', '--local', 'user.name', 'local-history-git'),
			M.build_git_command(opts, 'commit', '--allow-empty', '-m', '"initial commit empty"')
		)
	)
end

return M
