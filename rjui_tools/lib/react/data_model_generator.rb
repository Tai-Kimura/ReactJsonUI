# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'set'
require_relative '../core/config_manager'
require_relative '../core/type_converter'
require_relative 'style_loader'

module RjuiTools
  module React
    class DataModelGenerator
      def initialize
        @config = Core::ConfigManager.load_config
        @source_path = @config['source_path'] || Dir.pwd
        @layouts_dir = File.join(@source_path, @config['layouts_directory'] || 'Layouts')
        @data_dir = File.join(@source_path, @config['data_directory'] || 'src/generated/data')
        @styles_dir = File.join(@source_path, @config['styles_directory'] || 'Styles')
        @use_typescript = @config['typescript'] != false
      end

      def update_data_models
        # Process all JSON files in Layouts directory
        json_files = Dir.glob(File.join(@layouts_dir, '**/*.json')).reject do |file|
          # Skip Resources folder and Styles folder
          file.include?(File.join(@layouts_dir, 'Resources')) ||
            file.include?(File.join(@layouts_dir, 'Styles'))
        end

        json_files.each do |json_file|
          process_json_file(json_file)
        end
      end

      private

      def process_json_file(json_file)
        json_content = File.read(json_file, encoding: 'UTF-8')
        json_data = JSON.parse(json_content)

        # Expand styles before extracting data and actions
        expanded_data = StyleLoader.load_and_merge(json_data, @styles_dir)

        # Extract data properties from expanded JSON
        data_properties = extract_data_properties(expanded_data)

        # Extract onclick actions from expanded JSON
        onclick_actions = extract_onclick_actions(expanded_data)

        # Get the view name from file path
        base_name = File.basename(json_file, '.json')

        # Update the Data model file
        update_data_file(base_name, data_properties, onclick_actions)
      end

      def extract_onclick_actions(json_data, actions = Set.new)
        if json_data.is_a?(Hash)
          # Check for onclick attribute (selector format)
          if json_data['onclick'] && json_data['onclick'].is_a?(String)
            actions.add(json_data['onclick'])
          end

          # Process children
          child = json_data['child'] || json_data['children']
          if child
            if child.is_a?(Array)
              child.each do |c|
                extract_onclick_actions(c, actions)
              end
            else
              extract_onclick_actions(child, actions)
            end
          end
        elsif json_data.is_a?(Array)
          json_data.each do |item|
            extract_onclick_actions(item, actions)
          end
        end

        actions.to_a
      end

      def extract_data_properties(json_data, properties = [])
        if json_data.is_a?(Hash)
          # Check for data section (data-only element)
          if json_data['data'] && json_data['data'].is_a?(Array)
            # Only extract from data-only elements (no type, just data key)
            if json_data.keys == ['data'] || (json_data.keys - ['data', 'type']).empty?
              json_data['data'].each do |data_item|
                if data_item.is_a?(Hash)
                  # Normalize type using TypeConverter (mode: react)
                  normalized = Core::TypeConverter.normalize_data_property(data_item, 'react')
                  properties << normalized
                end
              end
            end
          end

          # Process children
          child = json_data['child'] || json_data['children']
          if child
            if child.is_a?(Array)
              child.each do |c|
                extract_data_properties(c, properties)
              end
            else
              extract_data_properties(child, properties)
            end
          end
        elsif json_data.is_a?(Array)
          json_data.each do |item|
            extract_data_properties(item, properties)
          end
        end

        properties
      end

      def update_data_file(base_name, data_properties, onclick_actions = [])
        # Convert base_name to PascalCase
        view_name = to_pascal_case(base_name)

        # Determine file extension
        extension = @use_typescript ? '.ts' : '.js'
        data_file_path = File.join(@data_dir, "#{view_name}Data#{extension}")

        # Create directory if needed
        FileUtils.mkdir_p(@data_dir)

        # Generate new content
        content = generate_data_content(view_name, data_properties, onclick_actions)

        # Write the updated content
        File.write(data_file_path, content)
        puts "  Updated Data model: #{data_file_path}"
      end

      def generate_data_content(view_name, data_properties, onclick_actions = [])
        if @use_typescript
          generate_typescript_content(view_name, data_properties, onclick_actions)
        else
          generate_javascript_content(view_name, data_properties, onclick_actions)
        end
      end

      def generate_typescript_content(view_name, data_properties, onclick_actions = [])
        content = <<~TS
          // Generated by ReactJsonUI - Do not edit directly

          export interface #{view_name}Data {
        TS

        if data_properties.empty? && onclick_actions.empty?
          content += "  // No data properties defined in JSON\n"
        else
          # Add each property with correct type
          data_properties.each do |prop|
            name = prop['name']
            ts_type = prop['tsType'] || Core::TypeConverter.to_typescript_type(prop['class'])
            default_value = prop['defaultValue']

            # Properties are optional by default
            if default_value.nil?
              content += "  #{name}?: #{ts_type};\n"
            else
              content += "  #{name}: #{ts_type};\n"
            end
          end

          # Add onclick actions as function properties
          onclick_actions.each do |action|
            content += "  #{action}?: () => void;\n"
          end
        end

        content += "}\n\n"

        # Generate default data object
        content += "export const create#{view_name}Data = (): #{view_name}Data => ({\n"

        data_properties.each do |prop|
          name = prop['name']
          ts_type = prop['tsType'] || Core::TypeConverter.to_typescript_type(prop['class'])
          default_value = prop['defaultValue']

          formatted_value = format_default_value(default_value, ts_type, prop['class'])
          content += "  #{name}: #{formatted_value},\n"
        end

        onclick_actions.each do |action|
          content += "  #{action}: undefined,\n"
        end

        content += "});\n"

        content
      end

      def generate_javascript_content(view_name, data_properties, onclick_actions = [])
        content = <<~JS
          // Generated by ReactJsonUI - Do not edit directly

          /**
           * @typedef {Object} #{view_name}Data
        JS

        data_properties.each do |prop|
          name = prop['name']
          ts_type = prop['tsType'] || Core::TypeConverter.to_typescript_type(prop['class'])
          content += " * @property {#{ts_type}} [#{name}]\n"
        end

        onclick_actions.each do |action|
          content += " * @property {Function} [#{action}]\n"
        end

        content += " */\n\n"

        # Generate default data object
        content += "export const create#{view_name}Data = () => ({\n"

        data_properties.each do |prop|
          name = prop['name']
          ts_type = prop['tsType'] || Core::TypeConverter.to_typescript_type(prop['class'])
          default_value = prop['defaultValue']

          formatted_value = format_default_value(default_value, ts_type, prop['class'])
          content += "  #{name}: #{formatted_value},\n"
        end

        onclick_actions.each do |action|
          content += "  #{action}: undefined,\n"
        end

        content += "});\n"

        content
      end

      def format_default_value(value, ts_type, json_class = nil)
        return 'undefined' if value.nil?

        case ts_type
        when 'string'
          value.is_a?(String) ? "\"#{value}\"" : "\"#{value}\""
        when 'number'
          value.to_s
        when 'boolean'
          value.to_s.downcase
        else
          # For arrays and objects
          if value.is_a?(Array)
            '[]'
          elsif value.is_a?(Hash)
            '{}'
          else
            value.to_s
          end
        end
      end

      def to_pascal_case(str)
        # Handle various naming patterns
        snake = str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                   .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                   .downcase
        snake.split(/[_\-]/).map(&:capitalize).join
      end
    end
  end
end
