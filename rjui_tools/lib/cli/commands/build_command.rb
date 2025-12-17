# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative '../../core/config_manager'
require_relative '../../core/logger'
require_relative '../../core/attribute_validator'
require_relative '../../core/binding_validator'
require_relative '../../react/react_generator'
require_relative '../../react/data_model_generator'

module RjuiTools
  module CLI
    module Commands
      class BuildCommand
        def initialize(args)
          @args = args
          @config = Core::ConfigManager.load_config
          @validator = Core::AttributeValidator.new(:react)
          @binding_validator = Core::BindingValidator.new
          @all_warnings = []
          @binding_warnings = []
        end

        def execute
          Core::Logger.info('Building React components from JSON layouts...')

          layouts_dir = @config['layouts_directory']

          unless Dir.exist?(layouts_dir)
            Core::Logger.error("Layouts directory not found: #{layouts_dir}")
            Core::Logger.info('Run "rjui init" first')
            exit 1
          end

          # Update StringManager from Strings directory
          update_string_manager

          # Update Data models from JSON data sections
          update_data_models

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

              # Validate JSON attributes
              validate_component(json_content, json_file)

              # Validate binding expressions for business logic
              validate_bindings(json_content, json_file)

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

          # Print all collected warnings at the end
          print_validation_summary
          print_binding_warnings

          Core::Logger.success('Build completed!')
        end

        private

        def to_pascal_case(string)
          string.split(/[-_]/).map(&:capitalize).join
        end

        # Validate component and its children recursively
        # @param component [Hash] The component to validate
        # @param file_path [String] The file path for error messages
        # @param parent_orientation [String] The parent's orientation ('horizontal' or 'vertical')
        def validate_component(component, file_path, parent_orientation = nil)
          return unless component.is_a?(Hash)

          # Skip style-only entries and data declarations
          return if component.key?('style') && component.keys.size == 1
          return if component.key?('data') && !component.key?('type')

          if component['type']
            warnings = @validator.validate(component, nil, parent_orientation)
            warnings.each do |warning|
              @all_warnings << { file: file_path, message: warning }
            end
          end

          # Get this component's orientation for children validation
          current_orientation = component['orientation']

          # Validate children recursively
          if component['child']
            children = component['child'].is_a?(Array) ? component['child'] : [component['child']]
            children.each { |child| validate_component(child, file_path, current_orientation) }
          end
        end

        # Print validation summary at the end of build
        def print_validation_summary
          return if @all_warnings.empty?

          puts
          Core::Logger.warn("Validation warnings found: #{@all_warnings.size}")
          puts

          # Group warnings by file
          grouped = @all_warnings.group_by { |w| w[:file] }
          grouped.each do |file, warnings|
            puts "\e[33m  #{file}:\e[0m"
            warnings.each do |w|
              puts "\e[33m    ⚠️  #{w[:message]}\e[0m"
            end
          end
          puts
        end

        # Validate binding expressions for business logic
        def validate_bindings(json_content, file_path)
          file_name = File.basename(file_path)
          warnings = @binding_validator.validate(json_content, file_name)
          warnings.each do |warning|
            @binding_warnings << warning
          end
        end

        # Print binding warnings at the end of build
        def print_binding_warnings
          return if @binding_warnings.empty?

          puts
          Core::Logger.warn("Binding warnings found: #{@binding_warnings.size}")
          puts "  Business logic detected in bindings. Move this logic to ViewModel."
          puts

          @binding_warnings.each do |warning|
            puts "\e[33m  ⚠️  #{warning}\e[0m"
          end
          puts
        end

        def update_data_models
          Core::Logger.info('Generating Data models...')
          data_generator = React::DataModelGenerator.new
          data_generator.update_data_models
        rescue StandardError => e
          Core::Logger.error("Error generating data models: #{e.message}")
        end

        def update_string_manager
          strings_dir = @config['strings_directory'] || 'src/Strings'
          generated_dir = @config['generated_directory'] || 'src/generated'
          string_manager_path = File.join(generated_dir, 'StringManager.js')

          return unless Dir.exist?(strings_dir)

          languages = @config['languages'] || ['en', 'ja']
          default_language = @config['default_language'] || 'en'

          # Read all string files
          strings_data = {}
          languages.each do |lang|
            lang_file = File.join(strings_dir, "#{lang}.json")
            if File.exist?(lang_file)
              strings_data[lang] = JSON.parse(File.read(lang_file, encoding: 'UTF-8'))
            else
              strings_data[lang] = {}
            end
          end

          # Generate StringManager content
          strings_json = JSON.pretty_generate(strings_data)

          content = <<~JS
            "use client";

            // Generated by ReactJsonUI - StringManager
            // Manages multi-language string resources

            const strings = #{strings_json};

            // Convert snake_case keys to camelCase for property access
            function createCamelCaseProxy(obj) {
              const camelCaseMap = {};
              for (const key in obj) {
                const camelKey = key.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
                camelCaseMap[camelKey] = obj[key];
                camelCaseMap[key] = obj[key]; // Also keep snake_case access
              }
              return camelCaseMap;
            }

            class StringManagerClass {
              constructor() {
                this._currentLanguage = '#{default_language}';
                this._cache = {};
              }

              get currentLanguage() {
                const lang = this._currentLanguage;
                if (!this._cache[lang]) {
                  this._cache[lang] = createCamelCaseProxy(strings[lang] || strings['#{default_language}']);
                }
                return this._cache[lang];
              }

              get language() {
                return this._currentLanguage;
              }

              setLanguage(lang) {
                if (strings[lang]) {
                  this._currentLanguage = lang;
                  this._cache = {}; // Clear cache on language change
                } else {
                  console.warn(`Language '${lang}' not found. Available: ${Object.keys(strings).join(', ')}`);
                }
              }

              get availableLanguages() {
                return Object.keys(strings);
              }

              getString(key) {
                return this.currentLanguage[key] || key;
              }
            }

            export const StringManager = new StringManagerClass();
            export default StringManager;
          JS

          FileUtils.mkdir_p(generated_dir)
          File.write(string_manager_path, content)
          Core::Logger.success("Updated: #{string_manager_path}")
        end
      end
    end
  end
end
