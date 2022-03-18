local M = {}

function clean_filename(filename)
	if string.sub(filename, 1, 1) == '/' then
		filename = string.sub(filename, 2)
	end
	return filename
end
function M.ensure_directory(dir)
	if vim.fn.isdirectory(dir) ~= 1 then
		vim.fn.mkdir(dir, 'p')
	end
end

function M.get_backup_path(opts, dirname, filename)
  local backupdir = M.get_backup_dir(opts, dirname)
  local backuppath = backupdir .. '/' .. clean_filename(filename)
	return backuppath
end

function M.get_backup_dir(opts, dirname, _)
  local backupdir = opts.basedir .. '/' .. vim.fn.hostname()
	if dirname ~= nil then
		backupdir = backupdir .. '/' .. clean_filename(dirname)
	end
	M.ensure_directory(backupdir)
	return backupdir
end

function M.relative_path(opts, dirname, filename)
  local backupdir = vim.fn.hostname()
	if dirname ~= nil then
		backupdir = backupdir .. '/' .. clean_filename(dirname)
	end
  local backuppath = backupdir .. '/' .. clean_filename(filename)
	return backuppath
end
return M
