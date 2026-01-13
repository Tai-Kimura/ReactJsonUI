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
        # Ensure data directory exists
        FileUtils.mkdir_p(@data_dir)

        # Generate CollectionDataSource if not exists
        generate_collection_data_source

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

        # Extract TextField bindings for onChange handlers
        text_field_bindings = extract_text_field_bindings(expanded_data)

        # Get the view name from file path
        base_name = File.basename(json_file, '.json')

        # Update the Data model file
        update_data_file(base_name, data_properties, onclick_actions, text_field_bindings)
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

      # Extract TextField text bindings for auto-generating onChange handlers
      # e.g., TextField with text: "@{email}" -> "email"
      def extract_text_field_bindings(json_data, bindings = Set.new)
        if json_data.is_a?(Hash)
          # Check for TextField type with text binding
          if json_data['type'] == 'TextField' && json_data['text']
            text_value = json_data['text']
            # Check if it's a binding (@{propertyName})
            if text_value.is_a?(String) && text_value.start_with?('@{') && text_value.end_with?('}')
              # Skip if custom onChange is already defined
              unless json_data['onTextChange'] || json_data['onChange']
                property_name = text_value[2...-1]
                bindings.add(property_name)
              end
            end
          end

          # Process children
          child = json_data['child'] || json_data['children']
          if child
            if child.is_a?(Array)
              child.each do |c|
                extract_text_field_bindings(c, bindings)
              end
            else
              extract_text_field_bindings(child, bindings)
            end
          end
        elsif json_data.is_a?(Array)
          json_data.each do |item|
            extract_text_field_bindings(item, bindings)
          end
        end

        bindings.to_a
      end

      def extract_data_properties(json_data, properties = [], is_root = true)
        if json_data.is_a?(Hash)
          # Check for data section
          if json_data['data'] && json_data['data'].is_a?(Array)
            # Extract from root element OR data-only elements (no type, just data key)
            should_extract = is_root || json_data.keys == ['data'] || (json_data.keys - ['data', 'type']).empty?
            if should_extract
              json_data['data'].each do |data_item|
                if data_item.is_a?(Hash)
                  # Normalize type using TypeConverter (mode: react)
                  normalized = Core::TypeConverter.normalize_data_property(data_item, 'react')
                  properties << normalized
                end
              end
            end
          end

          # Check for TabView tabs - generate data properties for each tab's view
          if json_data['type'] == 'TabView' && json_data['tabs'].is_a?(Array)
            # Add setSelectedTabIndex function for tab switching
            properties << {
              'name' => 'setSelectedTabIndex',
              'class' => 'Function',
              'tsType' => '(index: number) => void',
              'defaultValue' => nil
            }

            json_data['tabs'].each do |tab|
              if tab['view']
                # Convert view name to camelCase + Data (e.g., home -> homeData, whisky_card -> whiskyCardData)
                view_name = tab['view']
                data_prop_name = view_name.split('_').each_with_index.map { |part, i| i == 0 ? part.downcase : part.capitalize }.join + 'Data'
                pascal_name = view_name.split('_').map(&:capitalize).join
                properties << {
                  'name' => data_prop_name,
                  'class' => 'Object',
                  'tsType' => "#{pascal_name}Data",
                  'defaultValue' => nil
                }
              end
            end
          end

          # Process children
          child = json_data['child'] || json_data['children']
          if child
            if child.is_a?(Array)
              child.each do |c|
                extract_data_properties(c, properties, false)
              end
            else
              extract_data_properties(child, properties, false)
            end
          end
        elsif json_data.is_a?(Array)
          json_data.each do |item|
            extract_data_properties(item, properties, false)
          end
        end

        properties
      end

      def update_data_file(base_name, data_properties, onclick_actions = [], text_field_bindings = [])
        # Convert base_name to PascalCase
        view_name = to_pascal_case(base_name)

        # Determine file extension
        extension = @use_typescript ? '.ts' : '.js'
        data_file_path = File.join(@data_dir, "#{view_name}Data#{extension}")

        # Create directory if needed
        FileUtils.mkdir_p(@data_dir)

        # Generate new content
        content = generate_data_content(view_name, data_properties, onclick_actions, text_field_bindings)

        # Write the updated content
        File.write(data_file_path, content)
        puts "  Updated Data model: #{data_file_path}"
      end

      def generate_data_content(view_name, data_properties, onclick_actions = [], text_field_bindings = [])
        if @use_typescript
          generate_typescript_content(view_name, data_properties, onclick_actions, text_field_bindings)
        else
          generate_javascript_content(view_name, data_properties, onclick_actions, text_field_bindings)
        end
      end

      def generate_typescript_content(view_name, data_properties, onclick_actions = [], text_field_bindings = [])
        # Check if we need to import CollectionDataSource
        needs_collection_import = data_properties.any? { |p| p['tsType']&.include?('CollectionDataSource') || p['class'] == 'CollectionDataSource' }

        # Check for other Data type imports (e.g., HomeData, SearchData)
        data_type_imports = data_properties
          .map { |p| p['tsType'] }
          .compact
          .select { |t| t.match?(/^[A-Z][a-zA-Z]+Data$/) && t != "#{view_name}Data" }
          .uniq

        imports = "// Generated by ReactJsonUI - Do not edit directly\n"
        imports += "\nimport { CollectionDataSource } from './CollectionDataSource';\n" if needs_collection_import
        data_type_imports.each do |data_type|
          imports += "import type { #{data_type} } from './#{data_type}';\n"
        end
        imports += "\n"

        content = <<~TS
          #{imports}export interface #{view_name}Data {
        TS

        if data_properties.empty? && onclick_actions.empty? && text_field_bindings.empty?
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

          # Add onChange handlers for TextField bindings
          text_field_bindings.each do |binding|
            handler_name = "on#{capitalize_first(binding)}Change"
            content += "  #{handler_name}?: (value: string) => void;\n"
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

        # Add onChange handlers with undefined default
        text_field_bindings.each do |binding|
          handler_name = "on#{capitalize_first(binding)}Change"
          content += "  #{handler_name}: undefined,\n"
        end

        content += "});\n"

        content
      end

      def capitalize_first(str)
        return str if str.nil? || str.empty?
        str[0].upcase + str[1..]
      end

      def generate_javascript_content(view_name, data_properties, onclick_actions = [], text_field_bindings = [])
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
          content += " * @property {(() => void) | undefined} [#{action}]\n"
        end

        # Add onChange handlers for TextField bindings
        text_field_bindings.each do |binding|
          handler_name = "on#{capitalize_first(binding)}Change"
          content += " * @property {((value: string) => void) | undefined} [#{handler_name}]\n"
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

        # Add onChange handlers with undefined default
        text_field_bindings.each do |binding|
          handler_name = "on#{capitalize_first(binding)}Change"
          content += "  #{handler_name}: undefined,\n"
        end

        content += "});\n"

        content
      end

      def format_default_value(value, ts_type, json_class = nil)
        return 'undefined' if value.nil?

        case ts_type
        when 'string'
          # Handle '' as empty string (common shorthand)
          if value == "''"
            '""'
          elsif value.is_a?(String) && (value.start_with?('"') || value.start_with?("'"))
            # Already quoted (e.g., from TypeConverter for Color/Image types)
            value
          else
            value.is_a?(String) ? "\"#{value}\"" : "\"#{value}\""
          end
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

      def generate_collection_data_source
        extension = @use_typescript ? '.ts' : '.js'
        file_path = File.join(@data_dir, "CollectionDataSource#{extension}")

        # Skip if file already exists
        return if File.exist?(file_path)

        content = if @use_typescript
                    generate_collection_data_source_typescript
                  else
                    generate_collection_data_source_javascript
                  end

        File.write(file_path, content)
        puts "  Generated: #{file_path}"
      end

      def generate_collection_data_source_typescript
        <<~TS
          // Generated by ReactJsonUI - Do not edit directly

          /**
           * Section data for collection views
           */
          export interface CollectionDataSection<T = Record<string, unknown>> {
            /** Header data */
            header?: Record<string, unknown>;
            /** Cell data array */
            cells?: {
              data: T[];
            };
            /** Footer data */
            footer?: Record<string, unknown>;
          }

          /**
           * Collection data source configuration
           */
          export class CollectionDataSource<T = Record<string, unknown>> {
            sections: CollectionDataSection<T>[];

            constructor(sections: CollectionDataSection<T>[] = []) {
              this.sections = sections;
            }

            /** Add a new section */
            addSection(section: CollectionDataSection<T>): void {
              this.sections.push(section);
            }

            /** Create and add a new empty section */
            createSection(): CollectionDataSection<T> {
              const section: CollectionDataSection<T> = {};
              this.sections.push(section);
              return section;
            }

            /** Set cells for a section */
            setCells(sectionIndex: number, data: T[]): void {
              if (this.sections[sectionIndex]) {
                this.sections[sectionIndex].cells = { data };
              }
            }

            /** Get all cell data from all sections */
            getAllCells(): T[] {
              return this.sections.flatMap(section => section.cells?.data || []);
            }
          }

          /** Create a new CollectionDataSource instance */
          export const createCollectionDataSource = <T = Record<string, unknown>>(
            sections: CollectionDataSection<T>[] = []
          ): CollectionDataSource<T> => {
            return new CollectionDataSource<T>(sections);
          };
        TS
      end

      def generate_collection_data_source_javascript
        <<~JS
          // Generated by ReactJsonUI - Do not edit directly

          /**
           * @typedef {Object} CollectionDataSection
           * @property {Object} [header] - Header data
           * @property {{ data: Array }} [cells] - Cell data array
           * @property {Object} [footer] - Footer data
           */

          /**
           * Collection data source configuration
           */
          export class CollectionDataSource {
            /**
             * @param {CollectionDataSection[]} sections
             */
            constructor(sections = []) {
              this.sections = sections;
            }

            /**
             * Add a new section
             * @param {CollectionDataSection} section
             */
            addSection(section) {
              this.sections.push(section);
            }

            /**
             * Create and add a new empty section
             * @returns {CollectionDataSection}
             */
            createSection() {
              const section = {};
              this.sections.push(section);
              return section;
            }

            /**
             * Set cells for a section
             * @param {number} sectionIndex
             * @param {Array} data
             */
            setCells(sectionIndex, data) {
              if (this.sections[sectionIndex]) {
                this.sections[sectionIndex].cells = { data };
              }
            }

            /**
             * Get all cell data from all sections
             * @returns {Array}
             */
            getAllCells() {
              return this.sections.flatMap(section => section.cells?.data || []);
            }
          }

          /**
           * Create a new CollectionDataSource instance
           * @param {CollectionDataSection[]} sections
           * @returns {CollectionDataSource}
           */
          export const createCollectionDataSource = (sections = []) => {
            return new CollectionDataSource(sections);
          };
        JS
      end
    end
  end
end
