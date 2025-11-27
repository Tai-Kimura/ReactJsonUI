# frozen_string_literal: true

require 'json'

module RjuiTools
  module Core
    class ConfigManager
      CONFIG_FILE = 'rjui.config.json'

      DEFAULT_CONFIG = {
        'layouts_directory' => 'src/Layouts',
        'generated_directory' => 'src/generated',
        'components_directory' => 'src/generated/components',
        'styles_directory' => 'src/Styles',
        'strings_directory' => 'src/Strings',
        'languages' => ['en', 'ja'],
        'default_language' => 'en',
        'use_tailwind' => true,
        'typescript' => false
      }.freeze

      class << self
        def load_config
          if File.exist?(CONFIG_FILE)
            JSON.parse(File.read(CONFIG_FILE))
          else
            DEFAULT_CONFIG.dup
          end
        end

        def save_config(config)
          File.write(CONFIG_FILE, JSON.pretty_generate(config))
        end

        def create_default_config
          save_config(DEFAULT_CONFIG)
          DEFAULT_CONFIG.dup
        end
      end
    end
  end
end
