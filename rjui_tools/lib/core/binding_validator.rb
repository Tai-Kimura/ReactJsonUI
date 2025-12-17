#!/usr/bin/env ruby

require 'json'

module RjuiTools
  module Core
    # Validates binding expressions in JSON layouts
    # Warns when bindings contain business logic that should be in ViewModel
    # Also validates that binding variables are defined in data declarations
    class BindingValidator
      attr_reader :warnings

      # Patterns that indicate business logic in bindings
      # Note: Order matters - more specific patterns should come before general ones
      BUSINESS_LOGIC_PATTERNS = [
        # Ternary operator (condition ? value : value) - most common violation
        {
          pattern: /\?.*:/,
          message: "ternary operator (? :) - compute value in ViewModel (e.g., showContent: currentTab === 0)"
        },
        # Comparison operators (===, ==, !==, !=, <, >, <=, >=)
        {
          pattern: /===|==|!==|!=|<=|>=|<|>/,
          message: "comparison operator - move comparison to ViewModel"
        },
        # viewModel. prefix in binding - should use direct property name
        {
          pattern: /viewModel\./,
          message: "viewModel. prefix - use direct property name (e.g., @{propertyName} instead of @{viewModel.propertyName})"
        },
        # Increment/decrement operators (must be before arithmetic)
        {
          pattern: /\+\+|--/,
          message: "increment/decrement - update value in ViewModel"
        },
        # Arithmetic operators (but allow simple negation, and exclude ++ --)
        {
          pattern: /(?<!\+)\+(?!\+)|(?<!-)\/|(?<![a-zA-Z_])\*|(?<![a-zA-Z_])%/,
          message: "arithmetic operator - compute value in ViewModel"
        },
        # Logical operators
        {
          pattern: /&&|\|\|/,
          message: "logical operator (&&, ||) - move logic to ViewModel"
        },
        # Nil coalescing
        {
          pattern: /\?\?/,
          message: "nil coalescing (??) - handle nil in ViewModel"
        },
        # Function calls with arguments (standalone or chained)
        {
          pattern: /\w+\([^)]+\)/,
          message: "function call with arguments - move to ViewModel"
        },
        # String interpolation (JavaScript template literals)
        {
          pattern: /`[^`]*\$\{/,
          message: "string interpolation - compose string in ViewModel"
        },
        # Array subscript with complex expression
        {
          pattern: /\[[^\]]*[+\-*\/<>=]/,
          message: "complex array subscript - simplify in ViewModel"
        },
        # Spread operator
        {
          pattern: /\.\.\./,
          message: "spread operator - handle in ViewModel"
        }
      ].freeze

      # Allowed simple patterns that look like logic but are acceptable
      ALLOWED_PATTERNS = [
        # Simple property access (no dot notation - direct property name only)
        /^@\{[a-zA-Z_][a-zA-Z0-9_]*\}$/,
        # Simple negation for boolean
        /^@\{![a-zA-Z_][a-zA-Z0-9_]*\}$/,
        # Simple array access with constant index
        /^@\{[a-zA-Z_][a-zA-Z0-9_]*\[\d+\]\}$/,
        # Action bindings (callbacks) - onXxx pattern
        /^@\{on[A-Z][a-zA-Z0-9_]*\}$/,
        # data. prefix for accessing data properties (e.g., @{data.name} in Collection cells)
        /^@\{data\.[a-zA-Z_][a-zA-Z0-9_.]*\}$/
      ].freeze

      def initialize
        @warnings = []
        @data_properties = Set.new
        @has_data_definitions = false
      end

      # Validate all bindings in a JSON component tree
      # @param json_data [Hash] The root component
      # @param file_name [String] The file name for error messages
      # @return [Array<String>] Array of warning messages
      def validate(json_data, file_name = nil)
        @warnings = []
        @current_file = file_name
        @data_properties = Set.new
        @has_data_definitions = false

        # First pass: collect all data property names
        collect_data_properties(json_data)

        # Second pass: validate bindings
        validate_component(json_data)
        @warnings
      end

      # Check a single binding expression
      # @param binding_expr [String] The binding expression (without @{ })
      # @param attribute_name [String] The attribute name
      # @param component_type [String] The component type
      # @return [Array<String>] Array of warning messages
      def check_binding(binding_expr, attribute_name, component_type)
        warnings = []

        # Check if it's allowed simple pattern
        full_binding = "@{#{binding_expr}}"
        return warnings if allowed_pattern?(full_binding)

        # Check for business logic patterns
        BUSINESS_LOGIC_PATTERNS.each do |rule|
          if binding_expr.match?(rule[:pattern])
            context = @current_file ? "[#{@current_file}] " : ""
            warnings << "#{context}Binding '@{#{binding_expr}}' in '#{component_type}.#{attribute_name}' contains #{rule[:message]}"
          end
        end

        warnings
      end

      # Check if there are any warnings
      def has_warnings?
        !@warnings.empty?
      end

      # Print all warnings to stdout
      def print_warnings
        @warnings.each do |warning|
          puts "\e[33m[RJUI Binding Warning]\e[0m #{warning}"
        end
      end

      private

      # Collect all data property names from the component tree
      def collect_data_properties(component)
        return unless component.is_a?(Hash)

        # Check for data declarations
        if component['data'].is_a?(Array)
          component['data'].each do |data_item|
            next unless data_item.is_a?(Hash)
            # Skip ViewModel class declarations (class ends with 'ViewModel')
            next if data_item['class'].to_s.end_with?('ViewModel')
            # Add property name to the set
            if data_item['name']
              @data_properties << data_item['name']
              @has_data_definitions = true
            end
          end
        end

        # Recurse into children
        children = component['child'] || component['children'] || []
        children = [children] unless children.is_a?(Array)
        children.each do |child|
          next unless child.is_a?(Hash)
          # Check if child is a data-only object (no 'type' key, has 'data' key)
          if child['data'] && !child['type']
            collect_data_from_array(child['data'])
          else
            collect_data_properties(child)
          end
        end

        # Recurse into sections
        if component['sections'].is_a?(Array)
          component['sections'].each do |section|
            next unless section.is_a?(Hash)
            ['header', 'footer', 'cell'].each do |key|
              collect_data_properties(section[key]) if section[key].is_a?(Hash)
            end
          end
        end
      end

      # Helper to collect data from a data array
      def collect_data_from_array(data_array)
        return unless data_array.is_a?(Array)

        data_array.each do |data_item|
          next unless data_item.is_a?(Hash)
          # Skip ViewModel class declarations (class ends with 'ViewModel')
          next if data_item['class'].to_s.end_with?('ViewModel')
          # Add property name to the set
          if data_item['name']
            @data_properties << data_item['name']
            @has_data_definitions = true
          end
        end
      end

      def validate_component(component, parent_type = nil)
        return unless component.is_a?(Hash)

        component_type = component['type'] || parent_type || 'Unknown'

        # Check each attribute for bindings
        component.each do |key, value|
          next if key == 'type' || key == 'child' || key == 'children' || key == 'sections'
          next if key == 'data' || key == 'generatedBy' || key == 'include' || key == 'style'

          check_value_for_bindings(value, key, component_type)
        end

        # Validate children
        children = component['child'] || component['children'] || []
        children = [children] unless children.is_a?(Array)
        children.each { |child| validate_component(child, component_type) if child.is_a?(Hash) }

        # Validate sections (Collection/Table)
        if component['sections'].is_a?(Array)
          component['sections'].each do |section|
            next unless section.is_a?(Hash)
            ['header', 'footer', 'cell'].each do |key|
              validate_component(section[key], component_type) if section[key].is_a?(Hash)
            end
          end
        end
      end

      def check_value_for_bindings(value, attribute_name, component_type)
        case value
        when String
          if value.start_with?('@{') && value.end_with?('}')
            binding_expr = value[2..-2] # Remove @{ and }
            binding_warnings = check_binding(binding_expr, attribute_name, component_type)
            @warnings.concat(binding_warnings)

            # Check if binding variables are defined in data (only for components with data definitions)
            # Pages/components without data definitions get bindings from ViewModel props
            check_undefined_variables(binding_expr, attribute_name, component_type) if @has_data_definitions
          end
        when Hash
          value.each do |k, v|
            check_value_for_bindings(v, "#{attribute_name}.#{k}", component_type)
          end
        when Array
          value.each_with_index do |item, index|
            check_value_for_bindings(item, "#{attribute_name}[#{index}]", component_type)
          end
        end
      end

      # Check if variables in binding expression are defined in data
      def check_undefined_variables(binding_expr, attribute_name, component_type)
        # Skip data. prefix bindings (Collection cell bindings)
        return if binding_expr.start_with?('data.')

        # Extract variable names from the binding expression
        variables = extract_variables(binding_expr)

        variables.each do |var|
          unless @data_properties.include?(var)
            context = @current_file ? "[#{@current_file}] " : ""
            @warnings << "#{context}Binding variable '#{var}' in '#{component_type}.#{attribute_name}' is not defined in data. Add: { \"class\": \"#{infer_type(var, attribute_name)}\", \"name\": \"#{var}\" }"
          end
        end
      end

      # Extract variable names from binding expression
      def extract_variables(binding_expr)
        variables = Set.new

        # Remove string literals to avoid false positives
        expr = binding_expr.gsub(/'[^']*'/, '').gsub(/"[^"]*"/, '')

        # Match variable names (identifiers that are not keywords or literals)
        # Skip: numbers, true, false, null, undefined, visible, gone
        keywords = %w[true false null undefined visible gone]

        expr.scan(/\b([a-zA-Z_][a-zA-Z0-9_]*)\b/).flatten.each do |match|
          next if keywords.include?(match)
          next if match =~ /^\d/ # Skip if starts with digit
          variables << match
        end

        variables.to_a
      end

      # Infer type from variable name and attribute context
      # Returns cross-platform type format (works with Swift, Kotlin, React)
      def infer_type(var_name, attribute_name)
        # onClick, onXxx -> (() -> Void)? (cross-platform callback type)
        return '(() -> Void)?' if var_name.start_with?('on') && var_name[2]&.match?(/[A-Z]/)

        # xxxItems, xxxOptions, xxxList -> Array
        return 'Array' if var_name.end_with?('Items', 'Options', 'List', 'Args', 'Subcommands')

        # isXxx, hasXxx, canXxx, shouldXxx -> Bool
        return 'Bool' if var_name.start_with?('is', 'has', 'can', 'should')

        # xxxVisibility -> String
        return 'String' if var_name.end_with?('Visibility')

        # xxxIndex, xxxCount, xxxTab -> Int
        return 'Int' if var_name.end_with?('Index', 'Count', 'Tab')

        # Based on attribute name
        case attribute_name
        when 'onClick', 'onValueChanged', 'onValueChange', 'onTap'
          '(() -> Void)?'
        when 'items', 'sections'
          'Array'
        when 'visibility', 'text', 'fontColor', 'background'
          'String'
        when 'selectedIndex', 'width', 'height'
          'Int'
        when 'hidden', 'enabled', 'disabled'
          'Bool'
        else
          'any'
        end
      end

      def allowed_pattern?(binding)
        ALLOWED_PATTERNS.any? { |pattern| binding.match?(pattern) }
      end
    end
  end
end
