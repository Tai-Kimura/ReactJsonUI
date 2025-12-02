# frozen_string_literal: true

require_relative 'converters/base_converter'
require_relative 'converters/view_converter'
require_relative 'converters/label_converter'
require_relative 'converters/button_converter'
require_relative 'converters/image_converter'
require_relative 'converters/text_field_converter'
require_relative 'converters/text_view_converter'
require_relative 'converters/scroll_view_converter'
require_relative 'converters/collection_converter'
require_relative 'converters/toggle_converter'
require_relative 'converters/slider_converter'
require_relative 'converters/segment_converter'
require_relative 'converters/radio_converter'
require_relative 'converters/progress_converter'
require_relative 'converters/indicator_converter'
require_relative 'converters/select_box_converter'
require_relative 'converters/include_converter'
require_relative 'tailwind_mapper'
require_relative 'helpers/string_manager_helper'

module RjuiTools
  module React
    class ReactGenerator
      include Helpers::StringManagerHelper

      CONVERTERS = {
        'View' => Converters::ViewConverter,
        'SafeAreaView' => Converters::ViewConverter,
        'Label' => Converters::LabelConverter,
        'Text' => Converters::LabelConverter,
        'Button' => Converters::ButtonConverter,
        'Image' => Converters::ImageConverter,
        'CircleImage' => Converters::ImageConverter,
        'NetworkImage' => Converters::ImageConverter,
        'TextField' => Converters::TextFieldConverter,
        'TextView' => Converters::TextViewConverter,
        'Scroll' => Converters::ScrollViewConverter,
        'ScrollView' => Converters::ScrollViewConverter,
        'Collection' => Converters::CollectionConverter,
        'Table' => Converters::CollectionConverter,
        'Switch' => Converters::ToggleConverter,
        'Toggle' => Converters::ToggleConverter,
        'Check' => Converters::ToggleConverter,
        'Checkbox' => Converters::ToggleConverter,
        'Slider' => Converters::SliderConverter,
        'Segment' => Converters::SegmentConverter,
        'Radio' => Converters::RadioConverter,
        'Progress' => Converters::ProgressConverter,
        'Indicator' => Converters::IndicatorConverter,
        'SelectBox' => Converters::SelectBoxConverter,
        'Include' => Converters::IncludeConverter
      }.freeze

      def initialize(config)
        @config = config
        @use_tailwind = config['use_tailwind'] != false
        @extension_converters = load_extension_converters
        # Store extension converters in config so child converters can access them
        @config['_extension_converters'] = @extension_converters
      end

      # Load custom converters from extensions directory
      def load_extension_converters
        converters = {}

        # Check for extensions directory
        extensions_dir = find_extensions_dir
        return converters unless extensions_dir && File.directory?(extensions_dir)

        # Load converter mappings if exists
        mappings_file = File.join(extensions_dir, 'converter_mappings.rb')
        return converters unless File.exist?(mappings_file)

        # Load the mappings
        require mappings_file

        # Get the mappings hash
        if defined?(Converters::Extensions::CONVERTER_MAPPINGS)
          Converters::Extensions::CONVERTER_MAPPINGS.each do |type, class_name|
            # Load the converter file
            snake_case = type.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                            .downcase
            converter_file = File.join(extensions_dir, "#{snake_case}_converter.rb")

            if File.exist?(converter_file)
              require converter_file
              converter_class = Converters::Extensions.const_get(class_name)
              converters[type] = converter_class
            end
          end
        end

        converters
      rescue => e
        Core::Logger.warn("Failed to load extension converters: #{e.message}") if defined?(Core::Logger)
        {}
      end

      def find_extensions_dir
        # Check multiple possible locations
        candidates = [
          File.join(Dir.pwd, 'rjui_tools', 'lib', 'react', 'converters', 'extensions'),
          File.join(File.dirname(__FILE__), 'converters', 'extensions')
        ]

        candidates.find { |dir| File.directory?(dir) }
      end

      def generate(component_name, json)
        jsx_content = convert_component(json)

        generate_component_file(component_name, jsx_content, json)
      end

      private

      def convert_component(json, indent = 2)
        # Check if this is an include component
        if json['include']
          converter = Converters::IncludeConverter.new(json, @config)
          return converter.convert(indent)
        end

        type = json['type'] || 'View'

        # First check extension converters, then built-in converters
        converter_class = @extension_converters[type] || CONVERTERS[type] || Converters::ViewConverter

        converter = converter_class.new(json, @config)
        converter.convert(indent)
      end

      def generate_component_file(name, jsx_content, json)
        state_vars = extract_state_variables(json)
        included_components = extract_included_components(json)
        extension_components = extract_extension_components(json)
        uses_string_manager = uses_string_manager?(json)
        uses_link = uses_link?(json)

        # Props come from 'data' attribute - can be at root level or as first child element
        data = extract_data_from_json(json)
        props = extract_data_props(data)

        # Determine if we need useState or "use client"
        needs_state = !state_vars.empty?
        uses_extensions = !extension_components.empty?
        needs_client = needs_state || uses_string_manager || uses_extensions
        use_client = needs_client ? "\"use client\";\n\n" : ''

        # Build React import
        react_hooks = []
        react_hooks << 'useState' if needs_state
        react_import = react_hooks.empty? ? "import React from 'react';" : "import React, { #{react_hooks.join(', ')} } from 'react';"

        # Generate Next.js Link import if needed
        link_import = uses_link ? "\nimport Link from 'next/link';" : ''

        # Generate StringManager import if needed
        string_manager_import = uses_string_manager ? "\nimport { StringManager } from '@/generated/StringManager';" : ''

        # Generate imports for extension components
        extension_imports = extension_components.map do |comp_name|
          "import { #{comp_name} } from '@/components/extensions/#{comp_name}';"
        end.join("\n")
        extension_imports = "\n#{extension_imports}" unless extension_imports.empty?

        # Generate imports for included components
        component_imports = included_components.map do |comp_name|
          "import #{comp_name} from './#{comp_name}';"
        end.join("\n")
        component_imports = "\n#{component_imports}" unless component_imports.empty?

        # Generate state declarations
        state_declarations = state_vars.map do |var|
          "  const [#{var[:name]}, set#{capitalize_first(var[:name])}] = useState(#{var[:default]});"
        end.join("\n")
        state_declarations = "\n#{state_declarations}\n" unless state_declarations.empty?

        # Generate props signature
        props_sig = generate_props_signature(props)

        <<~JSX
          #{use_client}// Generated by ReactJsonUI - Do not edit directly
          #{react_import}#{link_import}#{string_manager_import}#{extension_imports}#{component_imports}

          #{generate_props_interface(name, props) if @config['typescript']}
          export const #{name} = (#{props_sig}) => {#{state_declarations}
            return (
          #{jsx_content}
            );
          };

          export default #{name};
        JSX
      end

      def capitalize_first(str)
        str[0].upcase + str[1..]
      end

      def extract_state_variables(json, vars = [])
        # Check for Segment/Radio that need state
        type = json['type']

        if type == 'Segment'
          id = json['id'] || 'segment'
          selected = json['selectedIndex'] || json['selectedTabIndex']
          unless selected.is_a?(String) && selected.start_with?('@{')
            vars << { name: 'selectedIndex', default: selected || 0 }
          end
        elsif type == 'Radio'
          id = json['id'] || 'radio'
          selected = json['selectedValue']
          unless selected.is_a?(String) && selected.start_with?('@{')
            vars << { name: 'selectedValue', default: '""' }
          end
        end

        # Recurse into children
        json['child']&.each do |child|
          extract_state_variables(child, vars) if child.is_a?(Hash)
        end

        vars.uniq { |v| v[:name] }
      end

      def generate_props_signature(props)
        return '' if props.empty?

        "{ #{props.join(', ')} }"
      end

      def generate_props_interface(name, props)
        return '' if props.empty?

        <<~TS
          interface #{name}Props {
            #{props.map { |p| "#{p}?: any;" }.join("\n  ")}
          }
        TS
      end

      def extract_included_components(json, components = [])
        # Check if this node has an include
        if json['include']
          include_path = json['include']
          base_name = include_path.split('/').last
          component_name = base_name.split('_').map(&:capitalize).join
          components << component_name
        end

        # Check for Collection headerClasses/cellClasses/footerClasses
        %w[headerClasses cellClasses footerClasses].each do |key|
          json[key]&.each do |class_ref|
            class_name = class_ref.is_a?(Hash) ? class_ref['className'] : class_ref
            next unless class_name.is_a?(String)
            base_name = class_name.split('/').last
            # If already PascalCase (starts with uppercase and no underscores), use as-is
            component_name = if base_name.match?(/^[A-Z]/) && !base_name.include?('_')
                               base_name
                             else
                               base_name.split('_').map(&:capitalize).join
                             end
            components << component_name
          end
        end

        # Recurse into children
        json['child']&.each do |child|
          extract_included_components(child, components) if child.is_a?(Hash)
        end

        components.uniq
      end

      def extract_extension_components(json, components = [])
        type = json['type']

        # Check if this type is an extension component
        if type && @extension_converters.key?(type)
          components << type
        end

        # Recurse into children
        json['child']&.each do |child|
          extract_extension_components(child, components) if child.is_a?(Hash)
        end

        components.uniq
      end

      def uses_string_manager?(json)
        # Check text attributes for snake_case string keys
        %w[text hint placeholder label title].each do |attr|
          return true if json[attr] && string_key?(json[attr])
        end

        # Recurse into children
        json['child']&.each do |child|
          return true if child.is_a?(Hash) && uses_string_manager?(child)
        end

        false
      end

      def uses_link?(json)
        # Check if this element has href attribute
        return true if json['href']

        # Recurse into children
        json['child']&.each do |child|
          return true if child.is_a?(Hash) && uses_link?(child)
        end

        false
      end

      # Extract data from JSON - search for data-only elements in children (recursively)
      # A data-only element is { "data": [...] } with only the data key
      def extract_data_from_json(json)
        return [] unless json['child'].is_a?(Array)

        json['child'].each do |child|
          next unless child.is_a?(Hash)
          # Check if this child has only 'data' key (data-only element)
          if child.keys == ['data'] && child['data'].is_a?(Array)
            return child['data']
          end
          # Recurse into children
          result = extract_data_from_json(child)
          return result unless result.empty?
        end

        []
      end

      # Check if a child element is a data-only element (should not be rendered)
      def data_only_element?(child)
        return false unless child.is_a?(Hash)
        child.keys == ['data'] && child['data'].is_a?(Array)
      end

      # Extract props from 'data' attribute
      # Format: [{"class": "String", "name": "title"}, {"class": "ViewModel", "name": "viewModel"}]
      def extract_data_props(data)
        return [] unless data.is_a?(Array)

        data.filter_map do |item|
          item['name'] if item.is_a?(Hash) && item['name']
        end
      end

    end
  end
end
