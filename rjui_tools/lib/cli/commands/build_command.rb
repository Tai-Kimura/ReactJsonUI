# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative '../../core/config_manager'
require_relative '../../core/logger'
require_relative '../../react/react_generator'

module RjuiTools
  module CLI
    module Commands
      class BuildCommand
        def initialize(args)
          @args = args
          @config = Core::ConfigManager.load_config
        end

        def execute
          Core::Logger.info('Building React components from JSON layouts...')

          layouts_dir = @config['layouts_directory']

          unless Dir.exist?(layouts_dir)
            Core::Logger.error("Layouts directory not found: #{layouts_dir}")
            Core::Logger.info('Run "rjui init" first')
            exit 1
          end

          json_files = Dir.glob(File.join(layouts_dir, '**', '*.json'))

          if json_files.empty?
            Core::Logger.warn('No JSON layout files found')
            return
          end

          generator = React::ReactGenerator.new(@config)

          json_files.each do |json_file|
            Core::Logger.info("Processing: #{json_file}")

            begin
              json_content = JSON.parse(File.read(json_file, encoding: 'UTF-8'))
              component_name = File.basename(json_file, '.json')
              component_name = to_pascal_case(component_name)

              output = generator.generate(component_name, json_content)

              output_path = File.join(
                @config['components_directory'],
                "#{component_name}.jsx"
              )

              FileUtils.mkdir_p(File.dirname(output_path))
              File.write(output_path, output)

              Core::Logger.success("Generated: #{output_path}")
            rescue JSON::ParserError => e
              Core::Logger.error("Invalid JSON in #{json_file}: #{e.message}")
            rescue StandardError => e
              Core::Logger.error("Error processing #{json_file}: #{e.message}")
            end
          end

          Core::Logger.success('Build completed!')
        end

        private

        def to_pascal_case(string)
          string.split(/[-_]/).map(&:capitalize).join
        end
      end
    end
  end
end
