return {
  {
    '3rd/image.nvim',
    -- Uses the ImageMagick CLI (processor = 'magick_cli'), so no luarocks needed.
    build = false,
    lazy = false,
    opts = {
      backend = 'kitty', -- Noctty (Ghostty-based) supports the kitty graphics protocol
      processor = 'magick_cli', -- use ImageMagick CLI (you have `convert`/`magick`)
      integrations = {
        markdown = {
          enabled = true,
          only_render_image_at_cursor = false,
          filetypes = { 'markdown', 'vimwiki' },
        },
      },
      max_width = nil,
      max_height = nil,
      max_width_window_percentage = nil,
      max_height_window_percentage = 100,
      window_overlap_clear_enabled = true,
      -- Render standalone image files opened directly in a buffer.
      hijack_file_patterns = {
        '*.png',
        '*.jpg',
        '*.jpeg',
        '*.gif',
        '*.webp',
        '*.avif',
        '*.svg',
      },
    },
    config = function(_, opts)
      -- In WSL the terminal is a Windows program and can't read files from the
      -- Linux filesystem, so send image data inline instead of as a file path.
      if vim.fn.has 'wsl' == 1 then
        -- image.nvim requires this module with slashes; a dotted path would load a separate copy.
        local medium = require('image/backends/kitty/codes').control.transmit_medium
        medium.file = medium.direct
      end
      require('image').setup(opts)
    end,
  },
}
