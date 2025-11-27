# frozen_string_literal: true

module RjuiTools
  module React
    module Helpers
      module StringManagerHelper
        # Check if the text is a snake_case string key (e.g., "welcome_message", "button_submit")
        def string_key?(text)
          return false unless text.is_a?(String)
          return false if text.empty?

          # Remove quotes if present
          text_without_quotes = text.gsub(/^["']|["']$/, '')

          # Skip if it's a binding expression (@{...})
          return false if text_without_quotes.match?(/^@\{.*\}$/)

          # Skip if it contains spaces (regular text)
          return false if text_without_quotes.include?(' ')

          # Check if it's snake_case (lowercase letters, numbers, underscores only)
          text_without_quotes.match?(/^[a-z][a-z0-9]*(_[a-z0-9]+)*$/)
        end

        # Convert snake_case string key to StringManager.currentLanguage.key
        def convert_string_key(text)
          return text unless string_key?(text)

          # Remove quotes if present
          text_without_quotes = text.gsub(/^["']|["']$/, '')

          # Convert to camelCase for JavaScript property access
          camel_case_key = to_camel_case(text_without_quotes)

          "{StringManager.currentLanguage.#{camel_case_key}}"
        end

        # Get text with StringManager resolution
        def get_text_with_string_manager(text_content)
          return text_content unless text_content.is_a?(String)

          # Remove quotes if present
          text_without_quotes = text_content.gsub(/^["']|["']$/, '')

          # Check if it's a binding (starts with @{)
          return text_content if text_without_quotes.match?(/^@\{.*\}$/)

          # Check if it's a snake_case key
          if string_key?(text_without_quotes)
            convert_string_key(text_without_quotes)
          else
            text_content
          end
        end

        private

        # Convert snake_case to camelCase
        def to_camel_case(snake_str)
          parts = snake_str.split('_')
          parts.first + parts[1..].map(&:capitalize).join
        end
      end
    end
  end
end
