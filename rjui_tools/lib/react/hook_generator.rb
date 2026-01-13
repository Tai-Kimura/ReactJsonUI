# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'set'
require_relative '../core/config_manager'
require_relative 'style_loader'

module RjuiTools
  module React
    class HookGenerator
      def initialize
        @config = Core::ConfigManager.load_config
        @source_path = @config['source_path'] || Dir.pwd
        @layouts_dir = File.join(@source_path, @config['layouts_directory'] || 'Layouts')
        @hooks_dir = File.join(@source_path, @config['hooks_directory'] || 'src/generated/hooks')
        @generated_viewmodels_dir = File.join(@source_path, @config['generated_viewmodels_directory'] || 'src/generated/viewmodels')
        @viewmodels_dir = File.join(@source_path, @config['viewmodels_directory'] || 'src/viewmodels')
        @data_dir = File.join(@source_path, @config['data_directory'] || 'src/generated/data')
        @styles_dir = File.join(@source_path, @config['styles_directory'] || 'Styles')
        @use_typescript = @config['typescript'] != false
      end

      def generate_hooks
        # Ensure hooks directory exists
        FileUtils.mkdir_p(@hooks_dir)

        # Find all ViewModel files (in src/viewmodels/)
        viewmodel_files = Dir.glob(File.join(@viewmodels_dir, "*ViewModel.{ts,js}"))

        viewmodel_files.each do |vm_file|
          process_viewmodel(vm_file)
        end
      end

      private

      def process_viewmodel(vm_file)
        base_name = File.basename(vm_file, '.*').sub(/ViewModel$/, '')
        vm_extension = File.extname(vm_file)  # .ts or .js
        is_typescript = vm_extension == '.ts'

        # Find corresponding JSON layout
        json_file = find_json_file(base_name)
        return unless json_file

        # Extract TextField bindings from JSON
        json_content = File.read(json_file, encoding: 'UTF-8')
        json_data = JSON.parse(json_content)
        expanded_data = StyleLoader.load_and_merge(json_data, @styles_dir)
        text_field_bindings = extract_text_field_bindings(expanded_data)

        # Generate hook file (match ViewModel extension)
        generate_hook_file(base_name, text_field_bindings, is_typescript)
      end

      def find_json_file(base_name)
        # Convert PascalCase to snake_case for file search
        snake_name = to_snake_case(base_name)

        # Search in layouts directory
        patterns = [
          File.join(@layouts_dir, "**/*.json")
        ]

        patterns.each do |pattern|
          Dir.glob(pattern).each do |file|
            file_base = File.basename(file, '.json')
            if file_base.downcase == snake_name.downcase ||
               file_base.downcase == base_name.downcase
              return file
            end
          end
        end
        nil
      end

      def extract_text_field_bindings(json_data, bindings = Set.new)
        if json_data.is_a?(Hash)
          if json_data['type'] == 'TextField' && json_data['text']
            text_value = json_data['text']
            if text_value.is_a?(String) && text_value.start_with?('@{') && text_value.end_with?('}')
              unless json_data['onTextChange'] || json_data['onChange']
                property_name = text_value[2...-1]
                bindings.add(property_name)
              end
            end
          end

          child = json_data['child'] || json_data['children']
          if child
            if child.is_a?(Array)
              child.each { |c| extract_text_field_bindings(c, bindings) }
            else
              extract_text_field_bindings(child, bindings)
            end
          end
        elsif json_data.is_a?(Array)
          json_data.each { |item| extract_text_field_bindings(item, bindings) }
        end

        bindings.to_a
      end

      def generate_hook_file(base_name, text_field_bindings, is_typescript)
        view_name = to_pascal_case(base_name)
        extension = is_typescript ? '.ts' : '.js'
        hook_file_path = File.join(@hooks_dir, "use#{view_name}ViewModel#{extension}")

        content = if is_typescript
                    generate_typescript_hook(view_name, text_field_bindings)
                  else
                    generate_javascript_hook(view_name, text_field_bindings)
                  end

        File.write(hook_file_path, content)
        puts "  Generated hook: #{hook_file_path}"
      end

      def generate_typescript_hook(view_name, text_field_bindings)
        data_type = "#{view_name}Data"
        vm_type = "#{view_name}ViewModel"

        # Generate onChange handlers
        on_change_defaults = text_field_bindings.map do |binding|
          handler_name = "on#{capitalize_first(binding)}Change"
          "    #{handler_name}: data.#{handler_name} ?? ((value: string) => setData(prev => ({ ...prev, #{binding}: value }))),"
        end.join("\n")

        <<~TS
          "use client";

          import { useRef, useState } from "react";
          import { AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";
          import { #{data_type}, create#{data_type} } from "@/generated/data/#{data_type}";
          import { #{vm_type} } from "@/viewmodels/#{vm_type}";

          export function use#{view_name}ViewModel(router: AppRouterInstance) {
            const [data, setData] = useState<#{data_type}>(create#{data_type}());
            const dataRef = useRef(data);
            dataRef.current = data;

            const viewModelRef = useRef<#{vm_type} | null>(null);
            if (!viewModelRef.current) {
              viewModelRef.current = new #{vm_type}(
                router,
                () => dataRef.current,
                setData
              );
            }

          #{on_change_defaults.empty? ? '  const dataWithDefaults = data;' : "  // デフォルトのonChangeハンドラ（ViewModelで未定義の場合のみ適用）\n  const dataWithDefaults: #{data_type} = {\n    ...data,\n#{on_change_defaults}\n  };"}

            return { data: dataWithDefaults, viewModel: viewModelRef.current };
          }
        TS
      end

      def generate_javascript_hook(view_name, text_field_bindings)
        data_type = "#{view_name}Data"
        vm_type = "#{view_name}ViewModel"

        # Generate onChange handlers
        on_change_defaults = text_field_bindings.map do |binding|
          handler_name = "on#{capitalize_first(binding)}Change"
          "    #{handler_name}: data.#{handler_name} ?? ((value) => setData(prev => ({ ...prev, #{binding}: value }))),"
        end.join("\n")

        <<~JS
          "use client";

          import { useRef, useState } from "react";
          import { create#{data_type} } from "@/generated/data/#{data_type}";
          import { #{vm_type} } from "@/viewmodels/#{vm_type}";

          /**
           * Hook for #{view_name} page with ViewModel
           * @param {import("next/dist/shared/lib/app-router-context.shared-runtime").AppRouterInstance} router
           */
          export function use#{view_name}ViewModel(router) {
            const [data, setData] = useState(create#{data_type}());
            const dataRef = useRef(data);
            dataRef.current = data;

            const viewModelRef = useRef(null);
            if (!viewModelRef.current) {
              viewModelRef.current = new #{vm_type}(
                router,
                () => dataRef.current,
                setData
              );
            }

          #{on_change_defaults.empty? ? '  const dataWithDefaults = data;' : "  // デフォルトのonChangeハンドラ（ViewModelで未定義の場合のみ適用）\n  const dataWithDefaults = {\n    ...data,\n#{on_change_defaults}\n  };"}

            return { data: dataWithDefaults, viewModel: viewModelRef.current };
          }
        JS
      end

      def capitalize_first(str)
        return str if str.nil? || str.empty?
        str[0].upcase + str[1..]
      end

      def to_pascal_case(str)
        snake = str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                   .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                   .downcase
        snake.split(/[_\-]/).map(&:capitalize).join
      end

      def to_snake_case(str)
        str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .downcase
      end
    end
  end
end
