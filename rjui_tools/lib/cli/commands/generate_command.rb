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
        def initialize(args, original_args = nil)
          @args = args
          @original_args = original_args || args.dup
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
          # Handle nested paths like "learn/components/View"
          path_parts = name.split('/')
          base_name = path_parts.last
          dir_parts = path_parts[0...-1]

          view_name = to_pascal_case(base_name)
          json_name = to_snake_case(base_name)

          # Convert directory parts to kebab-case
          kebab_dir_parts = dir_parts.map { |part| to_kebab_case(part) }
          kebab_path = (kebab_dir_parts + [to_kebab_case(base_name)]).join('/')

          layouts_dir = @config['layouts_directory']
          # Build nested path for JSON file
          json_dir = File.join(layouts_dir, "pages", *kebab_dir_parts)
          json_path = File.join(json_dir, "#{json_name}.json")

          if File.exist?(json_path)
            Core::Logger.warn("Layout already exists: #{json_path}")
            return
          end

          FileUtils.mkdir_p(json_dir)

          layout = {
            'type' => 'View',
            'id' => "#{json_name}_page",
            'width' => 'matchParent',
            'orientation' => 'vertical',
            'child' => [
              { 'data' => [{ 'class' => "#{view_name}ViewModel", 'name' => 'viewModel' }] },
              {
                'type' => 'View',
                'id' => "#{json_name}_content",
                'width' => 'matchParent',
                'padding' => [48, 24],
                'orientation' => 'vertical',
                'background' => '#FFFFFF',
                'child' => [
                  {
                    'type' => 'Label',
                    'text' => view_name,
                    'fontSize' => 32,
                    'fontWeight' => 'bold',
                    'fontColor' => '#23272F'
                  }
                ]
              }
            ]
          }

          File.write(json_path, JSON.pretty_generate(layout))
          Core::Logger.success("Created layout: #{json_path}")

          # Generate page.tsx
          generate_page_file(view_name, kebab_path)

          # Generate ViewModel
          generate_viewmodel_file(view_name)

          Core::Logger.info('Run "rjui build" to generate the React component')
        end

        def generate_component(name)
          view_name = to_pascal_case(name)
          json_name = to_snake_case(name)

          layouts_dir = @config['layouts_directory']
          json_path = File.join(layouts_dir, "components", "#{json_name}.json")

          if File.exist?(json_path)
            Core::Logger.warn("Layout already exists: #{json_path}")
            return
          end

          FileUtils.mkdir_p(File.dirname(json_path))

          layout = {
            'type' => 'View',
            'id' => "#{json_name}_container",
            'orientation' => 'vertical',
            'child' => [
              {
                'type' => 'Label',
                'text' => view_name,
                'fontSize' => 16,
                'fontColor' => '#000000'
              }
            ]
          }

          File.write(json_path, JSON.pretty_generate(layout))
          Core::Logger.success("Created component layout: #{json_path}")
          Core::Logger.info('Run "rjui build" to generate the React component')
        end

        def generate_page_file(view_name, kebab_path)
          # kebab_path can be nested like "learn/components/view"
          path_parts = kebab_path.split('/')
          page_dir = File.join('src', 'app', *path_parts)
          page_path = File.join(page_dir, 'page.tsx')

          if File.exist?(page_path)
            Core::Logger.warn("Page already exists: #{page_path}")
            return
          end

          FileUtils.mkdir_p(page_dir)

          page_content = <<~TSX
            "use client";

            import { useRouter } from "next/navigation";
            import { useMemo, useState } from "react";
            import Header from "@/generated/components/Header";
            import #{view_name} from "@/generated/components/#{view_name}";
            import { HeaderViewModel } from "@/viewmodels/HeaderViewModel";
            import { #{view_name}ViewModel } from "@/viewmodels/#{view_name}ViewModel";

            export default function #{view_name}Page() {
              const router = useRouter();
              const [currentTab, setCurrentTab] = useState(0);
              const headerViewModel = useMemo(() => new HeaderViewModel(router), [router]);
              const viewModel = useMemo(
                () => new #{view_name}ViewModel(router, currentTab, setCurrentTab),
                [router, currentTab]
              );

              return (
                <>
                  <Header viewModel={headerViewModel} />
                  <#{view_name} viewModel={viewModel} />
                </>
              );
            }
          TSX

          File.write(page_path, page_content)
          Core::Logger.success("Created page: #{page_path}")
        end

        def generate_viewmodel_file(view_name)
          viewmodel_dir = File.join('src', 'viewmodels')
          viewmodel_path = File.join(viewmodel_dir, "#{view_name}ViewModel.ts")

          if File.exist?(viewmodel_path)
            Core::Logger.warn("ViewModel already exists: #{viewmodel_path}")
            return
          end

          FileUtils.mkdir_p(viewmodel_dir)

          viewmodel_content = <<~TS
            import { AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";

            export class #{view_name}ViewModel {
              private router: AppRouterInstance;
              private _currentTab: number;
              private _setCurrentTab: (tab: number) => void;

              constructor(
                router: AppRouterInstance,
                currentTab: number,
                setCurrentTab: (tab: number) => void
              ) {
                this.router = router;
                this._currentTab = currentTab;
                this._setCurrentTab = setCurrentTab;
              }

              get currentTab(): number {
                return this._currentTab;
              }

              onTabChange = (index: number) => {
                this._setCurrentTab(index);
              };
            }
          TS

          File.write(viewmodel_path, viewmodel_content)
          Core::Logger.success("Created ViewModel: #{viewmodel_path}")
        end

        def generate_converter
          options = parse_converter_options
          name = @args.shift

          unless name
            Core::Logger.error("Name is required for 'converter'")
            Core::Logger.info("Usage: rjui g converter <Name> [--attributes key:type,...]")
            return
          end

          # Build command line string for comment (skip the type argument like 'converter')
          remaining_args = @original_args[1..] || []
          command_line = "rjui g converter #{remaining_args.join(' ')}"

          require_relative '../../react/generators/converter_generator'
          generator = React::Generators::ConverterGenerator.new(name, options, @config, command_line)
          generator.generate
        end

        def parse_converter_options
          options = {
            attributes: {},
            is_container: nil  # nil means auto-detect based on children
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

            opts.on('--container', 'Force component to be a container (handles children)') do
              options[:is_container] = true
            end

            opts.on('--no-container', 'Force component to not be a container (ignores children)') do
              options[:is_container] = false
            end
          end.parse!(@args)

          options
        end

        def to_pascal_case(string)
          # If already PascalCase (no separators), return as-is
          return string if string !~ /[-_\/]/ && string =~ /^[A-Z]/

          # Otherwise, split and capitalize each part
          string.split(/[-_\/]/).map { |part| part.sub(/^./, &:upcase) }.join
        end

        def to_snake_case(string)
          string
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
            .gsub(/\//, '_')
        end

        def to_kebab_case(string)
          string
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1-\2')
            .gsub(/([a-z\d])([A-Z])/, '\1-\2')
            .downcase
            .gsub(/[_\/]/, '-')
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
              --container       Force component to be a container (handles children)
              --no-container    Force component to not be a container (ignores children)

            Examples:
              rjui g view HomeView
              rjui g component UserCard
              rjui g converter CodeBlock --attributes file:String,language:String
              rjui g converter Card --container
              rjui g converter Badge --no-container
          HELP
        end
      end
    end
  end
end
