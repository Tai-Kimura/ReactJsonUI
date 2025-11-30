# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'optparse'
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

          type = @args.shift

          case type
          when 'view', 'v'
            name = @args.shift
            unless name
              Core::Logger.error("Name is required for '#{type}'")
              return
            end
            generate_view(name)
          when 'component', 'c'
            name = @args.shift
            unless name
              Core::Logger.error("Name is required for '#{type}'")
              return
            end
            generate_component(name)
          when 'converter', 'conv'
            generate_converter
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

        def generate_converter
          options = parse_converter_options
          name = @args.shift

          unless name
            Core::Logger.error("Name is required for 'converter'")
            Core::Logger.info("Usage: rjui g converter <Name> [--attributes key:type,...]")
            return
          end

          require_relative '../../react/generators/converter_generator'
          generator = React::Generators::ConverterGenerator.new(name, options, @config)
          generator.generate
        end

        def parse_converter_options
          options = {
            attributes: {}
          }

          OptionParser.new do |opts|
            opts.on('--attributes ATTRS', 'Add attributes (comma-separated key:type pairs)') do |attrs|
              attrs.split(',').each do |attr|
                key, type = attr.strip.split(':', 2)
                if key && type
                  options[:attributes][key] = type
                else
                  Core::Logger.error("Invalid attribute format: #{attr}. Use key:type")
                  exit 1
                end
              end
            end
          end.parse!(@args)

          options
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
            Usage: rjui generate <type> <name> [options]

            Types:
              view, v           Generate a view layout
              component, c      Generate a component layout
              converter, conv   Generate a custom converter

            Options for converter:
              --attributes      Comma-separated key:type pairs (e.g., file:String,language:String)

            Examples:
              rjui g view HomeView
              rjui g component UserCard
              rjui g converter CodeBlock --attributes file:String,language:String
          HELP
        end
      end
    end
  end
end
