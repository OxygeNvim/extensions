_G.extensions = {
  updater = {},
}

extensions.setup = function()
  base46.load_highlight('extensions')

  for _, module in pairs({ 'updater' }) do
    require('oxygen.extensions.' .. module)
  end
end

return extensions
