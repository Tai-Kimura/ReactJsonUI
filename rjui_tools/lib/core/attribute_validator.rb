#!/usr/bin/env ruby

require 'json'

module RjuiTools
  module Core
    # Validates JSON component attributes against defined schemas
    # Used by React converters to ensure JSON layout correctness
    class AttributeValidator
      attr_reader :definitions, :warnings, :infos
      attr_accessor :mode

      # Valid modes for this platform
      MODES = [:react, :all].freeze

      # Current platform identifier
      PLATFORM = 'react'.freeze

      # All supported platforms across JsonUI libraries
      ALL_PLATFORMS = ['swift', 'kotlin', 'react'].freeze

      def initialize(mode = :all)
        @definitions = load_definitions
        @warnings = []
        @infos = []
        @mode = mode
      end

      # Validate a component and return warnings
      # @param component [Hash] The component to validate
      # @param component_type [String] The type of component (e.g., "Label", "TextField")
      # @param parent_orientation [String] The parent's orientation ('horizontal' or 'vertical')
      # @return [Array<String>] Array of warning messages
      def validate(component, component_type = nil, parent_orientation = nil)
        @warnings = []
        @infos = []
        type = component_type || component['type']

        return @warnings unless type

        # Get valid attributes for this component type
        valid_attrs = get_valid_attributes(type)

        # Check each attribute in the component
        component.each do |key, value|
          next if key == 'type' || key == 'child' || key == 'children'

          if valid_attrs.key?(key)
            attr_def = valid_attrs[key]
            # Check platform compatibility first
            if platform_compatible?(attr_def)
              # Check mode compatibility
              if mode_compatible?(attr_def)
                # Validate attribute value
                validate_attribute(key, value, attr_def, type)
              else
                # Attribute not supported in current mode - log as info
                add_mode_info(key, attr_def, type)
              end
            else
              # Attribute for other platform - log as info
              add_platform_info(key, attr_def, type)
            end
          else
            # Unknown attribute
            add_warning("Unknown attribute '#{key}' for component type '#{type}'")
          end
        end

        # Check for required attributes (only for current platform)
        valid_attrs.each do |attr_name, attr_def|
          next unless platform_compatible?(attr_def)
          if attr_def['required'] && !component.key?(attr_name)
            # Skip width/height required check if weight is set and parent orientation allows it
            next if skip_dimension_required?(attr_name, component, parent_orientation)

            add_warning("Required attribute '#{attr_name}' is missing for component type '#{type}'")
          end
        end

        @warnings
      end

      # Print all warnings to console
      def print_warnings
        @warnings.each do |warning|
          puts "\e[33m⚠️  [RJUI Warning] #{warning}\e[0m"
        end
      end

      # Print all info messages to console
      def print_infos
        @infos.each do |info|
          puts "\e[36mℹ️  [RJUI Info] #{info}\e[0m"
        end
      end

      # Check if there are any warnings
      def has_warnings?
        !@warnings.empty?
      end

      # Check if there are any info messages
      def has_infos?
        !@infos.empty?
      end

      private

      def load_definitions
        definitions_path = File.join(File.dirname(__FILE__), 'attribute_definitions.json')
        base_definitions = if File.exist?(definitions_path)
          JSON.parse(File.read(definitions_path))
        else
          puts "\e[31m[RJUI Error] attribute_definitions.json not found at #{definitions_path}\e[0m"
          {}
        end

        # Load and merge extension attribute definitions
        extension_definitions = load_extension_definitions
        merge_definitions(base_definitions, extension_definitions)
      end

      # Load extension attribute definitions from the extensions directory
      def load_extension_definitions
        extension_defs = {}

        # Check for extension definitions in various locations
        extension_paths = [
          # Main ReactJsonUI structure (converters/extensions)
          File.join(Dir.pwd, 'rjui_tools', 'lib', 'react', 'converters', 'extensions', 'attribute_definitions'),
          # Project with rjui_tools at root
          File.join(Dir.pwd, 'lib', 'react', 'converters', 'extensions', 'attribute_definitions'),
          # Legacy path (components/extensions) for backwards compatibility
          File.join(Dir.pwd, 'rjui_tools', 'lib', 'react', 'components', 'extensions', 'attribute_definitions')
        ]

        extension_paths.each do |ext_dir|
          next unless File.directory?(ext_dir)

          Dir.glob(File.join(ext_dir, '*.json')).each do |file|
            begin
              component_defs = JSON.parse(File.read(file))
              extension_defs.merge!(component_defs)
            rescue JSON::ParserError => e
              puts "\e[33m[RJUI Warning] Failed to parse extension definition #{file}: #{e.message}\e[0m"
            end
          end
        end

        extension_defs
      end

      # Merge extension definitions into base definitions
      def merge_definitions(base, extensions)
        extensions.each do |key, value|
          if base.key?(key) && base[key].is_a?(Hash) && value.is_a?(Hash)
            # Merge attributes for existing component types
            base[key] = base[key].merge(value)
          else
            # Add new component type definitions
            base[key] = value
          end
        end
        base
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
        when 'Check'
          'Check'
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

        # Check for invalid binding syntax
        check_invalid_binding_syntax(value, current_path, component_type)

        # Check if value is a binding expression
        is_binding = value.is_a?(String) && value.include?('@{')

        # Skip validation for binding expressions
        return if is_binding

        # Check type
        expected_types = Array(definition['type'])
        actual_type = get_value_type(value)

        unless type_matches?(actual_type, expected_types, value, definition)
          add_warning("Attribute '#{current_path}' in '#{component_type}' expects #{format_expected_types(expected_types)}, got #{actual_type}")
          return # Don't validate nested properties if type is wrong
        end

        # Check enum values
        if definition['enum']
          validate_enum_value(value, definition['enum'], current_path, component_type)
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

      # Validate enum value (supports both single values and arrays)
      def validate_enum_value(value, enum_values, path, component_type)
        if value.is_a?(Array)
          # For array values, check each element
          invalid_values = value.reject { |v| enum_values.include?(v) }
          unless invalid_values.empty?
            add_warning("Attribute '#{path}' in '#{component_type}' has invalid value(s) '#{invalid_values.inspect}'. Valid values: #{enum_values.join(', ')}")
          end
        else
          # For single values
          unless enum_values.include?(value)
            add_warning("Attribute '#{path}' in '#{component_type}' has invalid value '#{value}'. Valid values: #{enum_values.join(', ')}")
          end
        end
      end

      # Format expected types for error messages
      def format_expected_types(expected_types)
        formatted = expected_types.map do |type|
          if type.is_a?(Hash) && type['enum']
            "enum(#{type['enum'].join(', ')})"
          else
            type
          end
        end
        formatted.join(' or ')
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
            unless type_matches?(actual_type, expected_types, item, item_def)
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

      def type_matches?(actual, expected_types, value, definition = nil)
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
            # binding type requires @{propertyName} format
            actual == 'string' && value.is_a?(String) && value.start_with?('@{') && value.end_with?('}')
          when 'any'
            true
          when Hash
            # Handle enum type definition: {"enum": [...]}
            if expected['enum']
              if actual == 'string'
                expected['enum'].include?(value)
              elsif actual == 'array'
                # For array values, check if all elements are in enum
                value.is_a?(Array) && value.all? { |v| expected['enum'].include?(v) }
              else
                false
              end
            else
              false
            end
          else
            # For union types or special cases
            actual == expected
          end
        end
      end

      def add_warning(message)
        @warnings << message unless @warnings.include?(message)
      end

      def add_info(message)
        @infos << message unless @infos.include?(message)
      end

      # Check for invalid binding syntax (starts with @{ but doesn't end with })
      def check_invalid_binding_syntax(value, path, component_type)
        return unless value.is_a?(String)
        return unless value.start_with?('@{')
        return if value.end_with?('}')

        add_warning("Attribute '#{path}' in '#{component_type}' has invalid binding syntax (starts with '@{' but doesn't end with '}')")
      end

      # Check if width/height required warning should be skipped
      # When weight is set, the dimension in the parent's orientation direction is not required
      # - parent orientation: horizontal -> width not required if weight is set
      # - parent orientation: vertical -> height not required if weight is set
      def skip_dimension_required?(attr_name, component, parent_orientation)
        return false unless component.key?('weight')
        return false unless %w[width height].include?(attr_name)

        case parent_orientation
        when 'horizontal'
          # In horizontal layout, weight determines width
          attr_name == 'width'
        when 'vertical'
          # In vertical layout, weight determines height
          attr_name == 'height'
        else
          # Default orientation is vertical, so height is determined by weight
          attr_name == 'height'
        end
      end

      # Check if attribute is compatible with current platform
      # Attributes with platform specified for other platforms are silently skipped
      def platform_compatible?(attr_def)
        return true unless attr_def['platform']

        attr_platforms = Array(attr_def['platform'])
        attr_platforms.include?(PLATFORM) || attr_platforms.include?('all')
      end

      # Check if attribute is compatible with current mode
      def mode_compatible?(attr_def)
        return true if @mode == :all
        return true unless attr_def['mode']

        attr_modes = Array(attr_def['mode'])
        attr_modes.include?(@mode.to_s) || attr_modes.include?('all')
      end

      # Add info for mode-incompatible attribute (not an error, just informational)
      def add_mode_info(attr_name, attr_def, component_type)
        attr_modes = Array(attr_def['mode'])
        mode_str = attr_modes.map { |m| m.capitalize }.join('/')
        current_mode_str = @mode.to_s.capitalize

        add_info("Attribute '#{attr_name}' in '#{component_type}' is for #{mode_str} mode (current: #{current_mode_str})")
      end

      # Add info for platform-specific attribute (not an error, just informational)
      def add_platform_info(attr_name, attr_def, component_type)
        attr_platforms = Array(attr_def['platform'])
        platform_str = attr_platforms.map { |p| p.capitalize }.join('/')

        add_info("Attribute '#{attr_name}' in '#{component_type}' is for #{platform_str} platform (current: #{PLATFORM.capitalize})")
      end
    end
  end
end
