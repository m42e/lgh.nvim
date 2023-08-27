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
-- @dirname the directory of the file
-- @filename Filename to backup
function M.get_backup_path(opts, dirname, filename)
  local backupdir = M.get_backup_dir(opts, dirname)
  local backuppath = backupdir .. '/' .. clean_filename(filename)
	return backuppath
end

--- Get the backup base directory
-- @dirname the directory of the file
-- @filename Filename to clean
function M.get_backup_dir(opts, dirname, filename)
  local backupdir = M.get_backup_basedir(opts, dirname, filename)
  if dirname ~= nil then
    backupdir = backupdir .. '/' .. clean_filename(dirname)
  end
  return backupdir
end

--- Get the basedir of the backup
-- @dirname the directory of the file
-- @filename Filename
function M.get_backup_basedir(opts, dirname, filename)
  if type(opts.basedir) == "function" then
    return opts.basedir(opts, dirname, filename)
  end
  local backupdir = opts.basedir .. '/' .. vim.fn.hostname()
  return backupdir
end

--- Split a filepath into the directory and the filename, may not be perfect, but anyhow
-- @filepath the filepath to split
function M.split_path(opts, filepath)
  local lastpart = filepath:match('[^/]+$')
  return filepath:sub(1, #filepath - #lastpart-1), lastpart
end

--- Get the full fledged relative path for the file
-- @dirname the directory of the file
-- @filename Filename to clean
function M.relative_path(opts, dirname, filename)
  local backupdir = vim.fn.hostname()
	if dirname ~= nil then
		backupdir = backupdir .. '/' .. clean_filename(dirname)
	end
  local backuppath = backupdir .. '/' .. clean_filename(filename)
	return backuppath
end

--- Dump an object
-- @o object to dump
function M.dump(o, depth)
   depth = depth or 2
   if type(o) == 'table' then
      local s = string.rep(" ", depth) .. '{\n'
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s.. string.rep(" ", depth) .. '['..k..'] = '
         s = s .. M.dump(v, depth+2) .. ',\n'
      end
      return s .. '}\n'
   else
      return tostring(o)
   end
end

return M



