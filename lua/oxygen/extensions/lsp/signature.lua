local M = {}

M.is_trigger_char = function(chars)
  local current_line = vim.api.nvim_get_current_line()
  local position = vim.api.nvim_win_get_cursor(0)[2]

  current_line = current_line:gsub('%s+$', '')

  for _, char in ipairs(chars) do
    if current_line:sub(position, position) == char then
      return true
    end
  end
end

M.setup = function(client, bufnr)
  local group = require('oxygen.core.utils').create_augroup('LspSignature', { clear = false })
  vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })

  local trigger_chars = client
      and client.server_capabilities
      and client.server_capabilities.signatureHelpProvider
      and client.server_capabilities.signatureHelpProvider.triggerCharacters

  if not trigger_chars then
    return
  end

  vim.api.nvim_create_autocmd('TextChangedI', {
    group = group,
    buffer = bufnr,
    callback = function()
      if M.is_trigger_char(trigger_chars) then
        vim.lsp.buf.signature_help()
      end
    end,
  })
end

return M
