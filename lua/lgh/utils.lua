local M = {}

--- Clean the filename from leading slashes
-- @filename Filename to clean
function clean_filename(filename)
	if string.sub(filename, 1, 1) == '/' then
		filename = string.sub(filename, 2)
	end
	return filename
end

--- Get the backup path
-- @filename Filename to clean
function M.get_backup_path(opts, dirname, filename)
  local backupdir = M.get_backup_dir(opts, dirname)
  local backuppath = backupdir .. '/' .. clean_filename(filename)
	return backuppath
end

--- Get the backup base directory
-- @filename Filename to clean
function M.get_backup_dir(opts, dirname, _)
  local backupdir = opts.basedir .. '/' .. vim.fn.hostname()
	if dirname ~= nil then
		backupdir = backupdir .. '/' .. clean_filename(dirname)
	end
	return backupdir
end

--- Get the full fledged relative path for the file
-- @filename Filename to clean
function M.relative_path(opts, dirname, filename)
  local backupdir = vim.fn.hostname()
	if dirname ~= nil then
		backupdir = backupdir .. '/' .. clean_filename(dirname)
	end
  local backuppath = backupdir .. '/' .. clean_filename(filename)
	return backuppath
end
return M
