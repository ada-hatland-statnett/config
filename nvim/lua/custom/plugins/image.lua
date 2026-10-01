return {
  {
    '3rd/image.nvim',
    -- Uses the ImageMagick CLI (processor = 'magick_cli'), so no luarocks needed.
    build = false,
    opts = {
      backend = 'kitty', -- WezTerm supports the kitty graphics protocol
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
  },
}
