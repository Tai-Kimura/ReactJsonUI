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
            config['styles_directory'],
            config['strings_directory']
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

          # Create language files
          create_language_files(config)

          # Create StringManager
          create_string_manager(config)

          # Create built-in components
          create_builtin_components(config)

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

        def create_language_files(config)
          strings_dir = config['strings_directory'] || 'src/Strings'
          languages = config['languages'] || ['en', 'ja']

          languages.each do |lang|
            lang_file = File.join(strings_dir, "#{lang}.json")
            next if File.exist?(lang_file)

            # Create sample strings for each language
            sample_strings = case lang
                             when 'en'
                               {
                                 'app_name' => 'My App',
                                 'welcome_message' => 'Welcome!',
                                 'button_submit' => 'Submit',
                                 'button_cancel' => 'Cancel'
                               }
                             when 'ja'
                               {
                                 'app_name' => 'マイアプリ',
                                 'welcome_message' => 'ようこそ！',
                                 'button_submit' => '送信',
                                 'button_cancel' => 'キャンセル'
                               }
                             else
                               {
                                 'app_name' => 'My App',
                                 'welcome_message' => 'Welcome!'
                               }
                             end

            File.write(lang_file, JSON.pretty_generate(sample_strings))
            Core::Logger.success("Created language file: #{lang_file}")
          end
        end

        def create_string_manager(config)
          generated_dir = config['generated_directory'] || 'src/generated'
          string_manager_path = File.join(generated_dir, 'StringManager.js')

          return if File.exist?(string_manager_path)

          languages = config['languages'] || ['en', 'ja']
          default_language = config['default_language'] || 'en'
          strings_dir = config['strings_directory'] || 'src/Strings'

          # Read string files and embed them directly
          strings_data = {}
          languages.each do |lang|
            lang_file = File.join(strings_dir, "#{lang}.json")
            if File.exist?(lang_file)
              strings_data[lang] = JSON.parse(File.read(lang_file, encoding: 'UTF-8'))
            else
              strings_data[lang] = {}
            end
          end

          # Generate embedded strings object
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

          File.write(string_manager_path, content)
          Core::Logger.success("Created StringManager: #{string_manager_path}")
        end

        def create_builtin_components(config)
          extensions_dir = config['extensions_directory'] || 'src/components/extensions'
          FileUtils.mkdir_p(extensions_dir)

          # Create NetworkImage component
          network_image_path = File.join(extensions_dir, 'NetworkImage.tsx')
          unless File.exist?(network_image_path)
            template_path = File.join(File.dirname(__FILE__), '../../react/templates/network_image.tsx')
            File.write(network_image_path, File.read(template_path))
            Core::Logger.success("Created built-in component: #{network_image_path}")
          end
        end
      end
    end
  end
end
