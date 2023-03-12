local Split = require('nui.split')
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
    name = ' ' .. ui.icons.branch .. ' Updater',
    title = ' ' .. ui.icons.empty_dot .. '  Updating',
    error = false,
    description = {},
  }

  local split = Split({
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

  split:mount()

  split:on(event.BufLeave, function()
    split:unmount()
  end)

  vim.opt_local.buflisted = false
  vim.opt_local.number = false
  vim.opt_local.list = false
  vim.opt_local.relativenumber = false
  vim.opt_local.wrap = false
  vim.opt_local.cul = false

  local oxygen_updater = vim.api.nvim_create_namespace('OxygenUpdater')

  vim.api.nvim_buf_set_lines(split.bufnr, 0, -1, false, { '' })

  vim.api.nvim_buf_set_lines(split.bufnr, 1, -1, false, { ' ' .. content.name .. ' ' })
  vim.api.nvim_buf_add_highlight(split.bufnr, oxygen_updater, 'OxygenUpdaterName', 1, 1, -1)

  vim.api.nvim_buf_set_lines(split.bufnr, 2, -1, false, { '' })

  vim.api.nvim_buf_set_lines(split.bufnr, 3, -1, false, { ' ' .. content.title .. ' ' })
  vim.api.nvim_buf_add_highlight(
    split.bufnr,
    oxygen_updater,
    content.error and 'OxygenUpdaterTitleError' or 'OxygenUpdaterTitle',
    3,
    5,
    -1
  )
  vim.api.nvim_buf_add_highlight(
    split.bufnr,
    oxygen_updater,
    content.error and 'OxygenUpdaterTitleIconError' or 'OxygenUpdaterTitleIcon',
    3,
    1,
    4
  )

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
        content['title'] = ' ' .. ui.icons.error .. '  ' .. 'Error while pulling the commits'
        content['error'] = true
        content['description'] = { git_output }
      else
        if git_output[1] == 'Already up to date.' or #git_output == 0 then
          content['title'] = ' ' .. ui.icons.empty .. '  ' .. git_output[1]
        else
          content['title'] = ' ' .. ui.icons.tick .. '  ' .. 'Successfully updated!'
          content['description'] = vim.fn.systemlist(
            'git -C ' .. nvim_dir .. ' log --format="format:%h: %s" ' .. head_hash[1] .. '..origin/' .. branch
          )
        end
      end

      vim.api.nvim_buf_set_lines(split.bufnr, 3, -1, false, { ' ' .. content.title .. ' ' })
      vim.api.nvim_buf_add_highlight(
        split.bufnr,
        oxygen_updater,
        content.error and 'OxygenUpdaterTitleError' or 'OxygenUpdaterTitle',
        3,
        5,
        -1
      )
      vim.api.nvim_buf_add_highlight(
        split.bufnr,
        oxygen_updater,
        content.error and 'OxygenUpdaterTitleIconError' or 'OxygenUpdaterTitleIcon',
        3,
        1,
        4
      )

      if content.description and #content.description > 0 and not vim.tbl_isempty(content.description) then
        vim.api.nvim_buf_set_lines(split.bufnr, 4, -1, false, { '' })

        for i = 1, #content.description do
          content.description[i] = string.gsub(content.description[i], ':', '')

          local hash = string.sub(content.description[i], 1, 8)
          local desc = string.sub(content.description[i], 8, -1)

          content.description[i] = hash .. desc
        end

        local get_longest_string_lenght = function(tbl)
          local new_tbl = vim.deepcopy(tbl)

          table.sort(new_tbl, function(a, b)
            return #a < #b
          end)

          local longest = new_tbl[#new_tbl]
          return #longest
        end

        local str = ''
        for _ = -4, get_longest_string_lenght(content.description) do
          str = ' ' .. str
        end

        vim.api.nvim_buf_set_lines(split.bufnr, 5, -1, false, { ' ' .. str .. ' ' })
        vim.api.nvim_buf_add_highlight(
          split.bufnr,
          oxygen_updater,
          content.error and 'OxygenUpdaterDescriptionError' or 'OxygenUpdaterDescription',
          5,
          1,
          -1
        )

        for i = 1, #content.description do
          vim.api.nvim_buf_set_lines(
            split.bufnr,
            5 + i,
            -1,
            false,
            { '   ' .. content.error and ui.icons.warning or ui.icons.warning .. ' ' .. content.description[i] .. '  ' }
          )

          if content.error then
            vim.api.nvim_buf_add_highlight(split.bufnr, oxygen_updater, 'OxygenUpdaterDescriptionError', 5 + i, 1, -1)
          else
            vim.api.nvim_buf_add_highlight(split.bufnr, oxygen_updater, 'OxygenUpdaterDescription', 5 + i, 14, -1)
            vim.api.nvim_buf_add_highlight(split.bufnr, oxygen_updater, 'OxygenUpdaterDescription', 5 + i, 1, 3)
            vim.api.nvim_buf_add_highlight(split.bufnr, oxygen_updater, 'OxygenUpdaterDescriptionHash', 5 + i, 2, 14)
          end
        end
        vim.api.nvim_buf_set_lines(split.bufnr, 5 + #content.description + 1, -1, false, { ' ' .. str .. ' ' })
        vim.api.nvim_buf_add_highlight(
          split.bufnr,
          oxygen_updater,
          content.error and 'OxygenUpdaterDescriptionError' or 'OxygenUpdaterDescription',
          5 + #content.description + 1,
          1,
          -1
        )
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
end
