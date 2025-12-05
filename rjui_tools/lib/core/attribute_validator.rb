#!/usr/bin/env ruby

require 'json'

module RjuiTools
  module Core
    # Validates JSON component attributes against defined schemas
    # Used by React converters to ensure JSON layout correctness
    class AttributeValidator
      attr_reader :definitions, :warnings
      attr_accessor :mode

      # Valid modes
      MODES = [:react, :all].freeze

      def initialize(mode = :all)
        @definitions = load_definitions
        @warnings = []
        @mode = mode
      end

      # Validate a component and return warnings
      # @param component [Hash] The component to validate
      # @param component_type [String] The type of component (e.g., "Label", "TextField")
      # @return [Array<String>] Array of warning messages
      def validate(component, component_type = nil)
        @warnings = []
        type = component_type || component['type']

        return @warnings unless type

        # Get valid attributes for this component type
        valid_attrs = get_valid_attributes(type)

        # Check each attribute in the component
        component.each do |key, value|
          next if key == 'type' || key == 'child' || key == 'children'

          if valid_attrs.key?(key)
            attr_def = valid_attrs[key]
            # Check mode compatibility first
            if mode_compatible?(attr_def)
              # Validate attribute value
              validate_attribute(key, value, attr_def, type)
            else
              # Attribute not supported in current mode
              add_mode_warning(key, attr_def, type)
            end
          else
            # Unknown attribute
            add_warning("Unknown attribute '#{key}' for component type '#{type}'")
          end
        end

        # Check for required attributes
        valid_attrs.each do |attr_name, attr_def|
          if attr_def['required'] && !component.key?(attr_name)
            add_warning("Required attribute '#{attr_name}' is missing for component type '#{type}'")
          end
        end

        @warnings
      end

      # Print all warnings to console
      def print_warnings
        @warnings.each do |warning|
          puts "\e[33m\u26a0\ufe0f  [RJUI Warning] #{warning}\e[0m"
        end
      end

      # Check if there are any warnings
      def has_warnings?
        !@warnings.empty?
      end

      private

      def load_definitions
        # Load base definitions
        definitions_path = File.join(File.dirname(__FILE__), 'attribute_definitions.json')
        base_definitions = if File.exist?(definitions_path)
          JSON.parse(File.read(definitions_path))
        else
          puts "\e[31m[RJUI Error] attribute_definitions.json not found at #{definitions_path}\e[0m"
          {}
        end

        # Load and merge extension definitions
        extension_definitions = load_extension_definitions
        merge_definitions(base_definitions, extension_definitions)
      end

      # Load extension attribute definitions from extensions directory
      # @return [Hash] Hash of component types to their attribute definitions
      def load_extension_definitions
        extensions = {}
        extensions_dir = find_extensions_definitions_dir

        return extensions unless extensions_dir && Dir.exist?(extensions_dir)

        # Find all JSON files in the extensions/attribute_definitions directory
        Dir.glob(File.join(extensions_dir, '*.json')).each do |file_path|
          begin
            content = JSON.parse(File.read(file_path))
            # Merge this extension file's definitions
            content.each do |component_type, attributes|
              extensions[component_type] ||= {}
              extensions[component_type].merge!(attributes)
            end
          rescue JSON::ParserError => e
            puts "\e[33m[RJUI Warning] Failed to parse extension definition: #{file_path}\e[0m"
            puts "\e[33m  Error: #{e.message}\e[0m"
          rescue => e
            puts "\e[33m[RJUI Warning] Error loading extension definition: #{file_path}\e[0m"
            puts "\e[33m  Error: #{e.message}\e[0m"
          end
        end

        extensions
      end

      # Find the extensions attribute_definitions directory
      # @return [String, nil] Path to the directory or nil if not found
      def find_extensions_definitions_dir
        # Try project root (rjui_tools at root)
        root_path = File.join(Dir.pwd, 'rjui_tools', 'lib', 'react', 'converters', 'extensions', 'attribute_definitions')
        return root_path if Dir.exist?(root_path)

        # Try lib directory (rjui_tools within lib)
        lib_path = File.join(Dir.pwd, 'lib', 'react', 'converters', 'extensions', 'attribute_definitions')
        return lib_path if Dir.exist?(lib_path)

        # Try relative to this file (for development)
        relative_path = File.join(File.dirname(__FILE__), '..', 'react', 'converters', 'extensions', 'attribute_definitions')
        return File.expand_path(relative_path) if Dir.exist?(File.expand_path(relative_path))

        nil
      end

      # Merge extension definitions into base definitions
      # @param base [Hash] Base attribute definitions
      # @param extensions [Hash] Extension attribute definitions
      # @return [Hash] Merged definitions
      def merge_definitions(base, extensions)
        result = base.dup

        extensions.each do |component_type, attributes|
          result[component_type] ||= {}
          result[component_type].merge!(attributes)
        end

        result
      end

      # Get valid attributes for a component type (common + type-specific)
      def get_valid_attributes(type)
        attrs = {}

        # Add common attributes
        attrs.merge!(@definitions['common'] || {})

        # Map component type to definition key
        def_key = map_type_to_definition(type)

        # Add type-specific attributes
        if @definitions[def_key]
          attrs.merge!(@definitions[def_key])
        end

        attrs
      end

      # Map JSON type to definition key
      def map_type_to_definition(type)
        case type
        when 'Label', 'Text'
          'Label'
        when 'TextField', 'EditText', 'Input'
          'TextField'
        when 'TextView', 'MultiLineEditText', 'Textarea'
          'TextView'
        when 'Button'
          'Button'
        when 'Image', 'ImageView', 'Img'
          'Image'
        when 'NetworkImage', 'NetworkImageView', 'CircleImage', 'CircleImageView', 'AsyncImage'
          'NetworkImage'
        when 'SelectBox', 'Spinner', 'DatePicker', 'Select', 'Picker'
          'SelectBox'
        when 'Toggle', 'Switch'
          'Toggle'
        when 'Segment', 'SegmentedControl', 'TabGroup'
          'Segment'
        when 'Slider', 'SeekBar', 'Range'
          'Slider'
        when 'Progress', 'ProgressBar'
          'Progress'
        when 'View', 'LinearLayout', 'RelativeLayout', 'FrameLayout', 'HStack', 'VStack', 'ZStack', 'Div', 'Box'
          'View'
        when 'ScrollView'
          'ScrollView'
        when 'Collection', 'CollectionView', 'RecyclerView', 'Table', 'TableView', 'List', 'Grid'
          'Collection'
        when 'Radio', 'RadioButton'
          'Radio'
        when 'CheckBox', 'Checkbox'
          'CheckBox'
        when 'Indicator', 'Spinner', 'Loading'
          'Indicator'
        when 'GradientView', 'Gradient'
          'GradientView'
        when 'Blur', 'BlurView'
          'Blur'
        when 'IconLabel'
          'IconLabel'
        when 'Web', 'WebView', 'Iframe'
          'Web'
        when 'SafeAreaView'
          'SafeAreaView'
        else
          type
        end
      end

      # Validate a single attribute value
      def validate_attribute(name, value, definition, component_type, path = nil)
        return unless definition

        current_path = path ? "#{path}.#{name}" : name

        # Check type
        expected_types = Array(definition['type'])
        actual_type = get_value_type(value)

        unless type_matches?(actual_type, expected_types, value)
          add_warning("Attribute '#{current_path}' in '#{component_type}' expects #{expected_types.join(' or ')}, got #{actual_type}")
          return # Don't validate nested properties if type is wrong
        end

        # Check enum values
        if definition['enum'] && !definition['enum'].include?(value)
          add_warning("Attribute '#{current_path}' in '#{component_type}' has invalid value '#{value}'. Valid values: #{definition['enum'].join(', ')}")
        end

        # Check min/max for numbers
        if actual_type == 'number'
          if definition['min'] && value < definition['min']
            add_warning("Attribute '#{current_path}' in '#{component_type}' value #{value} is less than minimum #{definition['min']}")
          end
          if definition['max'] && value > definition['max']
            add_warning("Attribute '#{current_path}' in '#{component_type}' value #{value} is greater than maximum #{definition['max']}")
          end
        end

        # Validate nested object properties
        if actual_type == 'object' && definition['properties']
          validate_nested_object(value, definition['properties'], component_type, current_path)
        end

        # Validate array items
        if actual_type == 'array' && definition['items']
          validate_array_items(value, definition['items'], component_type, current_path)
        end
      end

      # Validate nested object properties
      def validate_nested_object(obj, properties, component_type, path)
        return unless obj.is_a?(Hash)

        obj.each do |key, value|
          if properties.key?(key)
            validate_attribute(key, value, properties[key], component_type, path)
          else
            add_warning("Unknown property '#{path}.#{key}' in '#{component_type}'")
          end
        end
      end

      # Validate array items
      def validate_array_items(arr, item_def, component_type, path)
        return unless arr.is_a?(Array)

        arr.each_with_index do |item, index|
          item_path = "#{path}[#{index}]"

          if item_def['type'] == 'object' && item_def['properties']
            if item.is_a?(Hash)
              validate_nested_object(item, item_def['properties'], component_type, item_path)
            else
              add_warning("#{item_path} in '#{component_type}' expects object, got #{get_value_type(item)}")
            end
          else
            # Simple type validation for array items
            expected_types = Array(item_def['type'])
            actual_type = get_value_type(item)
            unless type_matches?(actual_type, expected_types, item)
              add_warning("#{item_path} in '#{component_type}' expects #{expected_types.join(' or ')}, got #{actual_type}")
            end
          end
        end
      end

      def get_value_type(value)
        case value
        when String
          'string'
        when Integer, Float
          'number'
        when TrueClass, FalseClass
          'boolean'
        when Array
          'array'
        when Hash
          'object'
        when NilClass
          'null'
        else
          'unknown'
        end
      end

      def type_matches?(actual, expected_types, value)
        expected_types.any? do |expected|
          case expected
          when 'string'
            actual == 'string'
          when 'number'
            actual == 'number'
          when 'boolean'
            actual == 'boolean'
          when 'array'
            actual == 'array'
          when 'object'
            actual == 'object'
          when 'binding'
            # binding型は @{propertyName} 形式の文字列である必要がある
            actual == 'string' && value.is_a?(String) && value.start_with?('@{') && value.end_with?('}')
          when 'any'
            true
          else
            # For union types or special cases
            actual == expected
          end
        end
      end

      def add_warning(message)
        @warnings << message unless @warnings.include?(message)
      end

      # Check if attribute is compatible with current mode
      def mode_compatible?(attr_def)
        return true if @mode == :all
        return true unless attr_def['mode']

        attr_modes = Array(attr_def['mode'])
        attr_modes.include?(@mode.to_s) || attr_modes.include?('all')
      end

      # Add warning for mode-incompatible attribute
      def add_mode_warning(attr_name, attr_def, component_type)
        attr_modes = Array(attr_def['mode'])
        mode_str = attr_modes.map { |m| m.capitalize }.join('/')
        current_mode_str = @mode.to_s.capitalize

        add_warning("Attribute '#{attr_name}' in '#{component_type}' is only supported in #{mode_str} mode (current: #{current_mode_str})")
      end
    end
  end
end
