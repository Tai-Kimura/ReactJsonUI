# frozen_string_literal: true

require 'fileutils'
require_relative '../../core/config_manager'
require_relative '../../core/logger'

module RjuiTools
  module CLI
    module Commands
      class InitCommand
        def initialize(args)
          @args = args
        end

        def execute
          Core::Logger.info('Initializing ReactJsonUI...')

          # Create config file
          if File.exist?(Core::ConfigManager::CONFIG_FILE)
            Core::Logger.warn('Config file already exists, skipping...')
          else
            Core::ConfigManager.create_default_config
            Core::Logger.success("Created #{Core::ConfigManager::CONFIG_FILE}")
          end

          config = Core::ConfigManager.load_config

          # Create directories
          directories = [
            config['layouts_directory'],
            config['generated_directory'],
            config['components_directory'],
            config['styles_directory']
          ]

          directories.each do |dir|
            if Dir.exist?(dir)
              Core::Logger.warn("Directory already exists: #{dir}")
            else
              FileUtils.mkdir_p(dir)
              Core::Logger.success("Created directory: #{dir}")
            end
          end

          # Create sample layout
          sample_layout_path = File.join(config['layouts_directory'], 'sample.json')
          unless File.exist?(sample_layout_path)
            create_sample_layout(sample_layout_path)
            Core::Logger.success("Created sample layout: #{sample_layout_path}")
          end

          Core::Logger.success('ReactJsonUI initialized successfully!')
          Core::Logger.info('Run "rjui build" to generate React components')
        end

        private

        def create_sample_layout(path)
          sample = {
            'type' => 'View',
            'id' => 'sample_container',
            'className' => 'p-4',
            'child' => [
              {
                'type' => 'Label',
                'id' => 'title',
                'text' => 'Hello ReactJsonUI!',
                'fontSize' => 24,
                'fontColor' => '#000000'
              },
              {
                'type' => 'Button',
                'id' => 'action_button',
                'text' => 'Click Me',
                'onClick' => 'handleClick',
                'background' => '#007AFF',
                'fontColor' => '#FFFFFF',
                'cornerRadius' => 8,
                'padding' => [12, 24]
              }
            ]
          }

          File.write(path, JSON.pretty_generate(sample))
        end
      end
    end
  end
end
