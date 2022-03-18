local utils = require('lgh.utils')
local M = {}


function M.shell_cmd(...)
	return vim.opt.shell:get() .. ' ' .. vim.opt.shellcmdflag:get() .. ' ' .. vim.fn.shellescape(M.multiple_commands(...))
end

function M.multiple_commands(...)
	local commands = {...}
	local tbl = {}

	local add_semicolon = false
	for _, c in pairs(commands) do
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
	return table.concat(tbl, ' ')
end

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

function M.get_owner_fix_command(opts, dirname, _)
	local backupdir = vim.fn.fnameescape(utils.get_backup_dir(opts, dirname))
	local realuser = vim.env.SUDO_USER
	if realuser == nil then
		realuser = vim.env.USER
	end
	return {'chown', '-R',  realuser, backupdir}
end

function M.get_copy_command(opts, dirname, filename)
	local backuppath = utils.get_backup_path(opts, dirname, filename)
	return {'cp', vim.fn.fnameescape(vim.fn.resolve(vim.fn.expand("%:p"))), vim.fn.fnameescape(backuppath) }
end

return M
