# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative '../../core/config_manager'
require_relative '../../core/logger'

module RjuiTools
  module CLI
    module Commands
      class GenerateCommand
        def initialize(args)
          @args = args
          @config = Core::ConfigManager.load_config
        end

        def execute
          if @args.empty?
            show_help
            return
          end

          type = @args[0]
          name = @args[1]

          unless name
            Core::Logger.error("Name is required for '#{type}'")
            return
          end

          case type
          when 'view', 'v'
            generate_view(name)
          when 'component', 'c'
            generate_component(name)
          else
            Core::Logger.error("Unknown generator type: #{type}")
            show_help
          end
        end

        private

        def generate_view(name)
          view_name = to_pascal_case(name)
          json_name = to_snake_case(name)

          layouts_dir = @config['layouts_directory']
          json_path = File.join(layouts_dir, "#{json_name}.json")

          if File.exist?(json_path)
            Core::Logger.warn("Layout already exists: #{json_path}")
            return
          end

          FileUtils.mkdir_p(layouts_dir)

          layout = {
            'type' => 'View',
            'id' => "#{json_name}_container",
            'className' => 'flex flex-col p-4',
            'child' => [
              {
                'type' => 'Label',
                'id' => "#{json_name}_title",
                'text' => view_name,
                'fontSize' => 24,
                'fontColor' => '#000000'
              }
            ]
          }

          File.write(json_path, JSON.pretty_generate(layout))
          Core::Logger.success("Created layout: #{json_path}")
          Core::Logger.info('Run "rjui build" to generate the React component')
        end

        def generate_component(name)
          # For custom reusable components
          generate_view(name)
        end

        def to_pascal_case(string)
          string.split(/[-_\/]/).map(&:capitalize).join
        end

        def to_snake_case(string)
          string
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
            .gsub(/\//, '_')
        end

        def show_help
          puts <<~HELP
            Usage: rjui generate <type> <name>

            Types:
              view, v        Generate a view layout
              component, c   Generate a component layout

            Examples:
              rjui g view HomeView
              rjui g component UserCard
          HELP
        end
      end
    end
  end
end
