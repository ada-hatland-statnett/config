return {
  {
    '3rd/image.nvim',
    -- image.nvim needs magick_rock (luarocks) or the magick CLI to decode
    -- images. rocks.nvim/lazy can install the rock automatically.
    build = false,
    dependencies = {
      {
        'vhyrro/luarocks.nvim',
        priority = 1001, -- load before image.nvim
        opts = {
          rocks = { 'magick' },
        },
      },
    },
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
