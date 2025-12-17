# frozen_string_literal: true

require 'json'

module RjuiTools
  module Core
    # Converts JSON primitive types to TypeScript types
    # This ensures cross-platform compatibility with SwiftJsonUI and KotlinJsonUI
    class TypeConverter
      # Language key for this platform
      LANGUAGE = 'react'

      # Available modes for this platform
      MODES = %w[react].freeze

      # JSON type -> TypeScript type mapping
      TYPE_MAPPING = {
        # Standard types (cross-platform)
        'String' => 'string',
        'string' => 'string',
        'Int' => 'number',
        'int' => 'number',
        'Integer' => 'number',
        'integer' => 'number',
        'Double' => 'number',
        'double' => 'number',
        'Float' => 'number',
        'float' => 'number',
        'Number' => 'number',
        'number' => 'number',
        'Bool' => 'boolean',
        'bool' => 'boolean',
        'Boolean' => 'boolean',
        'boolean' => 'boolean',
        # iOS-specific types mapped to TypeScript equivalents
        'CGFloat' => 'number',
        # Array types
        'Array' => 'any[]',
        'array' => 'any[]',
        # Object types
        'Object' => 'Record<string, any>',
        'object' => 'Record<string, any>',
        'Hash' => 'Record<string, any>',
        'hash' => 'Record<string, any>',
        # Function types (cross-platform: Swift uses () -> Void, Kotlin uses () -> Unit)
        '() -> Void' => '() => void',
        '(() -> Void)?' => '(() => void) | undefined',
        '() -> Unit' => '() => void',
        '(() -> Unit)?' => '(() => void) | undefined',
        '(Int) -> Void' => '(index: number) => void',
        '((Int) -> Void)?' => '((index: number) => void) | undefined',
        '(Int) -> Unit' => '(index: number) => void',
        '((Int) -> Unit)?' => '((index: number) => void) | undefined'
      }.freeze

      # Default values for each TypeScript type
      DEFAULT_VALUES = {
        'string' => '""',
        'number' => '0',
        'boolean' => 'false',
        'any[]' => '[]',
        'Record<string, any>' => '{}'
      }.freeze

      class << self
        # Extract platform-specific value from a potentially nested hash
        # Supports three formats:
        # 1. Simple value: "String" -> "String"
        # 2. Language only: { "swift": "Int", "react": "number" } -> "number"
        # 3. Language + mode: { "react": { "react": "string" } } -> "string"
        #
        # @param value [Object] the value (String, Hash, or other)
        # @param mode [String] the mode (react)
        # @return [Object] the extracted value for this platform/mode
        def extract_platform_value(value, mode = nil)
          return value unless value.is_a?(Hash)

          # Try to get language-specific value
          lang_value = value[LANGUAGE]
          return value unless lang_value # No language key found, return original hash

          # If language value is a hash, try to get mode-specific value
          if lang_value.is_a?(Hash) && mode
            mode_value = lang_value[mode]
            return mode_value if mode_value

            # Fallback: try first available mode
            MODES.each do |m|
              return lang_value[m] if lang_value[m]
            end

            # No mode found, return the hash as-is (might be a custom structure)
            lang_value
          else
            # Language value is not a hash, return it directly
            lang_value
          end
        end

        # Convert JSON type to TypeScript type
        # @param json_type [String] the type specified in JSON
        # @return [String] the corresponding TypeScript type
        def to_typescript_type(json_type)
          return 'any' if json_type.nil? || json_type.to_s.empty?

          type_str = json_type.to_s

          # Check for Array(ElementType) syntax -> ElementType[]
          if (match = type_str.match(/^Array\((.+)\)$/))
            element_type = to_typescript_type(match[1].strip)
            return "#{element_type}[]"
          end

          # Check for Dictionary(KeyType,ValueType) syntax -> Record<KeyType, ValueType>
          if (match = type_str.match(/^Dictionary\((.+),\s*(.+)\)$/))
            key_type = to_typescript_type(match[1].strip)
            value_type = to_typescript_type(match[2].strip)
            return "Record<#{key_type}, #{value_type}>"
          end

          # Return mapped type, or original type as-is if not found
          TYPE_MAPPING[type_str] || type_str
        end

        # Check if the type is a primitive type
        # @param json_type [String] the type to check
        # @return [Boolean] true if it's a primitive type
        def primitive?(json_type)
          return false if json_type.nil? || json_type.to_s.empty?

          TYPE_MAPPING.key?(json_type.to_s)
        end

        # Get default value for a TypeScript type
        # @param ts_type [String] the TypeScript type
        # @return [String] the default value as TypeScript code
        def default_value(ts_type)
          DEFAULT_VALUES[ts_type] || 'undefined'
        end

        # Format a value for TypeScript code based on type
        # @param value [Object] the value to format
        # @param ts_type [String] the TypeScript type
        # @return [String] the formatted value as TypeScript code
        def format_value(value, ts_type)
          return 'undefined' if value.nil?

          case ts_type
          when 'string'
            format_string_value(value)
          when 'number'
            value.to_f.to_s
          when 'boolean'
            value.to_s.downcase
          when 'any[]'
            value.is_a?(Array) ? value.to_json : '[]'
          when 'Record<string, any>'
            value.is_a?(Hash) ? value.to_json : '{}'
          else
            value.to_s
          end
        end

        # Convert data property from JSON format to normalized format
        # @param data_prop [Hash] the data property from JSON
        # @param mode [String] the mode (react)
        # @return [Hash] normalized data property with TypeScript type
        def normalize_data_property(data_prop, mode = nil)
          return data_prop unless data_prop.is_a?(Hash)

          normalized = data_prop.dup

          # Extract platform-specific class
          if normalized['class']
            raw_class = extract_platform_value(normalized['class'], mode)
            normalized['tsType'] = to_typescript_type(raw_class)
          end

          # Extract platform-specific defaultValue
          if normalized['defaultValue']
            normalized['defaultValue'] = extract_platform_value(normalized['defaultValue'], mode)
          end

          normalized
        end

        # Convert array of data properties
        # @param data_props [Array<Hash>] array of data properties
        # @param mode [String] the mode (react)
        # @return [Array<Hash>] normalized data properties
        def normalize_data_properties(data_props, mode = nil)
          return [] unless data_props.is_a?(Array)

          data_props.map { |prop| normalize_data_property(prop, mode) }
        end

        private

        def format_string_value(value)
          str = value.to_s
          # Handle already quoted strings
          if str.start_with?('"') && str.end_with?('"')
            str
          elsif str.start_with?("'") && str.end_with?("'")
            # Convert single quotes to double quotes
            inner = str[1..-2]
            "\"#{escape_string(inner)}\""
          else
            "\"#{escape_string(str)}\""
          end
        end

        def escape_string(str)
          str.gsub('\\', '\\\\').gsub('"', '\\"')
        end
      end
    end
  end
end
