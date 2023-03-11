local Popup = require('nui.popup')
local event = require('nui.utils.autocmd').event

local uv = vim.loop
local nvim_dir = vim.fn.stdpath('config')
local branch = config.core.branch or 'main'

extensions.updater.update = function()
  local git_available = vim.fn.executable('git')
  if not git_available then
    utils.logger.error('Couldn\'t find git!')
  end

  local content = {
    name = ui.icons.branch .. ' Updater',
    title = 'Updating...',
    error = false,
    description = {},
    pull_done = false,
  }

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = config.ui.border,
    },
    padding = {
      top = 2,
      bottom = 2,
      left = 2,
      right = 2,
    },
    buf_options = {
      modifiable = true,
      readonly = false,
    },
  })

  popup:mount()

  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  vim.opt_local.buflisted = false
  vim.opt_local.number = false
  vim.opt_local.list = false
  vim.opt_local.relativenumber = false
  vim.opt_local.wrap = false
  vim.opt_local.cul = false

  local oxygen_updater = vim.api.nvim_create_namespace('@oxygen.updater')

  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, { content.name })
  vim.api.nvim_buf_set_lines(popup.bufnr, 1, -1, false, { content.title })
  vim.api.nvim_buf_add_highlight(popup.bufnr, oxygen_updater, '@oxygen.updater.name', 1, 1, -1)
  vim.api.nvim_buf_add_highlight(popup.bufnr, oxygen_updater, '@oxygen.updater.title', 1, 2, -1)

  local handle
  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  local git_fetch_err = false
  local git_output = {}

  local head_hash = vim.fn.systemlist('git -C ' .. nvim_dir .. ' rev-parse HEAD')

  local on_exit = function()
    uv.read_stop(stdout)
    uv.close(stdout)
    uv.close(handle)

    vim.schedule(function()
      if git_fetch_err then
        content['title'] = 'Error while pulling the commits'
        content['error'] = true
        content['description'] = { git_output }
      else
        if git_output[1] == 'Already up to date.' or #git_output == 0 then
          content['title'] = git_output[1]
        else
          content['title'] = 'Successfully updated!'
          content['description'] = vim.fn.systemlist(
            'git -C ' .. nvim_dir .. ' log --format="format:%h: %s" ' .. head_hash[1] .. '..origin/' .. branch
          )
        end
      end

      vim.api.nvim_buf_set_lines(popup.bufnr, 1, 1, false, { content.title })
      vim.api.nvim_buf_add_highlight(popup.bufnr, oxygen_updater, '@oxygen.updater.title', 1, 2, -1)

      for i = 1, #content.description do
        vim.api.nvim_buf_set_lines(popup.bufnr, 2 + i, 1, false, { content.description[i] })
        vim.api.nvim_buf_add_highlight(popup.bufnr, oxygen_updater, '@oxygen.updater.description', 1, 2 + i, -1)
      end
    end)
  end

  handle = uv.spawn('git', {
    args = { 'pull', '--ff-only' },
    cwd = nvim_dir,
    stdio = { nil, stdout, stderr },
  }, on_exit)

  uv.read_start(stdout, function(_, data)
    if data then
      git_output[#git_output + 1] = data:gsub('\n', '')
    end
  end)

  uv.read_start(stderr, function(_, data)
    if data then
      git_fetch_err = true
      git_output[#git_output + 1] = data:gsub('\n', '')
    end
  end)
end
