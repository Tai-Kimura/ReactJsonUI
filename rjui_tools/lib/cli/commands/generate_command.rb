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
            options = parse_view_options
            name = @args.shift
            unless name
              Core::Logger.error("Name is required for '#{type}'")
              return
            end
            generate_view(name, options)
          when 'component', 'c'
            options = parse_view_options
            name = @args.shift
            unless name
              Core::Logger.error("Name is required for '#{type}'")
              return
            end
            generate_component(name, options)
          when 'converter', 'conv'
            generate_converter
          else
            Core::Logger.error("Unknown generator type: #{type}")
            show_help
          end
        end

        private

        def generate_view(name, options = {})
          with_viewmodel = options[:with_viewmodel]

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

          # Build layout based on --with-viewmodel option
          if with_viewmodel
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
          else
            layout = {
              'type' => 'View',
              'id' => "#{json_name}_page",
              'width' => 'matchParent',
              'orientation' => 'vertical',
              'child' => [
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
          end

          File.write(json_path, JSON.pretty_generate(layout))
          Core::Logger.success("Created layout: #{json_path}")

          # Generate page.tsx
          generate_page_file(view_name, kebab_path, with_viewmodel)

          # Generate ViewModel only if --with-viewmodel is specified
          if with_viewmodel
            generate_viewmodel_file(view_name)
          end

          Core::Logger.info('Run "rjui build" to generate the React component')
        end

        def generate_component(name, options = {})
          with_viewmodel = options[:with_viewmodel]

          view_name = to_pascal_case(name)
          json_name = to_snake_case(name)

          layouts_dir = @config['layouts_directory']
          json_path = File.join(layouts_dir, "components", "#{json_name}.json")

          if File.exist?(json_path)
            Core::Logger.warn("Layout already exists: #{json_path}")
            return
          end

          FileUtils.mkdir_p(File.dirname(json_path))

          # Build layout based on --with-viewmodel option
          if with_viewmodel
            layout = {
              'type' => 'View',
              'id' => "#{json_name}_container",
              'orientation' => 'vertical',
              'child' => [
                { 'data' => [{ 'class' => "#{view_name}ViewModel", 'name' => 'viewModel' }] },
                {
                  'type' => 'Label',
                  'text' => view_name,
                  'fontSize' => 16,
                  'fontColor' => '#000000'
                }
              ]
            }
          else
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
          end

          File.write(json_path, JSON.pretty_generate(layout))
          Core::Logger.success("Created component layout: #{json_path}")

          # Generate ViewModel if --with-viewmodel is specified
          if with_viewmodel
            generate_component_viewmodel_file(view_name)
          end

          Core::Logger.info('Run "rjui build" to generate the React component')
        end

        def generate_page_file(view_name, kebab_path, with_viewmodel = false)
          # kebab_path can be nested like "learn/components/view"
          path_parts = kebab_path.split('/')
          page_dir = File.join('src', 'app', *path_parts)
          page_path = File.join(page_dir, 'page.tsx')

          if File.exist?(page_path)
            Core::Logger.warn("Page already exists: #{page_path}")
            return
          end

          FileUtils.mkdir_p(page_dir)

          if with_viewmodel
            page_content = <<~TSX
              "use client";

              import { useRouter } from "next/navigation";
              import { useMemo, useState } from "react";
              import Header from "@/generated/components/Header";
              import #{view_name} from "@/generated/components/#{view_name}";
              import { HeaderViewModel } from "@/viewmodels/HeaderViewModel";
              import { #{view_name}ViewModel } from "@/viewmodels/#{view_name}ViewModel";
              import { #{view_name}Data, create#{view_name}Data } from "@/generated/data/#{view_name}Data";

              export default function #{view_name}Page() {
                const router = useRouter();
                const [data, setData] = useState<#{view_name}Data>(create#{view_name}Data());
                const headerViewModel = useMemo(() => new HeaderViewModel(router), [router]);
                const viewModel = useMemo(
                  () => new #{view_name}ViewModel(router, data, setData),
                  [router, data]
                );

                return (
                  <>
                    <Header viewModel={headerViewModel} />
                    <#{view_name} viewModel={viewModel} />
                  </>
                );
              }
            TSX
          else
            page_content = <<~TSX
              "use client";

              import { useRouter } from "next/navigation";
              import { useMemo, useState } from "react";
              import Header from "@/generated/components/Header";
              import #{view_name} from "@/generated/components/#{view_name}";
              import { HeaderViewModel } from "@/viewmodels/HeaderViewModel";
              import { #{view_name}Data, create#{view_name}Data } from "@/generated/data/#{view_name}Data";

              export default function #{view_name}Page() {
                const router = useRouter();
                const [data, setData] = useState<#{view_name}Data>(create#{view_name}Data());
                const headerViewModel = useMemo(() => new HeaderViewModel(router), [router]);

                // Create a simple viewModel with just data
                const viewModel = useMemo(() => ({ data }), [data]);

                return (
                  <>
                    <Header viewModel={headerViewModel} />
                    <#{view_name} viewModel={viewModel} />
                  </>
                );
              }
            TSX
          end

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
            import { #{view_name}Data } from "@/generated/data/#{view_name}Data";

            export class #{view_name}ViewModel {
              private router: AppRouterInstance;
              data: #{view_name}Data;
              private _setData: (data: #{view_name}Data) => void;

              constructor(
                router: AppRouterInstance,
                data: #{view_name}Data,
                setData: (data: #{view_name}Data) => void
              ) {
                this.router = router;
                this.data = data;
                this._setData = setData;
              }

              // Update data and trigger re-render
              updateData = (updates: Partial<#{view_name}Data>) => {
                this._setData({ ...this.data, ...updates });
              };
            }
          TS

          File.write(viewmodel_path, viewmodel_content)
          Core::Logger.success("Created ViewModel: #{viewmodel_path}")
        end

        def generate_component_viewmodel_file(view_name)
          viewmodel_dir = File.join('src', 'viewmodels')
          viewmodel_path = File.join(viewmodel_dir, "#{view_name}ViewModel.ts")

          if File.exist?(viewmodel_path)
            Core::Logger.warn("ViewModel already exists: #{viewmodel_path}")
            return
          end

          FileUtils.mkdir_p(viewmodel_dir)

          viewmodel_content = <<~TS
            import { #{view_name}Data } from "@/generated/data/#{view_name}Data";

            export class #{view_name}ViewModel {
              data: #{view_name}Data;
              private _setData: (data: #{view_name}Data) => void;

              constructor(
                data: #{view_name}Data,
                setData: (data: #{view_name}Data) => void
              ) {
                this.data = data;
                this._setData = setData;
              }

              // Update data and trigger re-render
              updateData = (updates: Partial<#{view_name}Data>) => {
                this._setData({ ...this.data, ...updates });
              };
            }
          TS

          File.write(viewmodel_path, viewmodel_content)
          Core::Logger.success("Created ViewModel: #{viewmodel_path}")
        end

        def parse_view_options
          options = {
            with_viewmodel: false
          }

          OptionParser.new do |opts|
            opts.on('--with-viewmodel', 'Generate ViewModel along with view/component') do
              options[:with_viewmodel] = true
            end
          end.parse!(@args)

          options
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

            Options for view/component:
              --with-viewmodel  Generate ViewModel along with the view/component

            Options for converter:
              --attributes      Comma-separated key:type pairs (e.g., file:String,language:String)
              --container       Force component to be a container (handles children)
              --no-container    Force component to not be a container (ignores children)

            Examples:
              rjui g view HomeView
              rjui g view HomeView --with-viewmodel
              rjui g component UserCard
              rjui g component UserCard --with-viewmodel
              rjui g converter CodeBlock --attributes file:String,language:String
              rjui g converter Card --container
              rjui g converter Badge --no-container
          HELP
        end
      end
    end
  end
end
