# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class TextFieldConverter < BaseConverter
        def convert(indent = 2)
          apply_defaults
          class_name = build_class_name
          style_attr = build_style_attr
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''

          attrs = build_attributes
          on_change = build_on_change

          "#{indent_str(indent)}<input#{id_attr} className=\"#{class_name}\"#{style_attr}#{attrs}#{on_change} />"
        end

        protected

        def apply_defaults
          # Apply textField defaults if not explicitly set
          text_field_defaults = defaults('textField')
          return if text_field_defaults.empty?

          @json = json.dup
          @json['fontColor'] ||= text_field_defaults['fontColor']
          @json['padding'] ||= text_field_defaults['padding']
          @json['background'] ||= text_field_defaults['background']
          @json['cornerRadius'] ||= text_field_defaults['cornerRadius']
        end

        def build_class_name
          classes = [super]

          # Default input styles
          classes << 'border'
          classes << 'outline-none'
          classes << 'focus:ring-2 focus:ring-blue-500'

          # Border style
          case json['borderStyle']&.downcase
          when 'roundedrect'
            classes << 'rounded-md'
          when 'line'
            classes << 'border-b border-t-0 border-l-0 border-r-0'
          end

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_attributes
          attrs = []

          # Type
          input_type = case json['input']&.downcase
                       when 'email'
                         'email'
                       when 'password'
                         'password'
                       when 'number', 'decimal'
                         'number'
                       else
                         'text'
                       end
          attrs << " type=\"#{input_type}\""

          # Placeholder
          attrs << " placeholder=\"#{json['hint']}\"" if json['hint']

          # Value binding
          if json['text']
            value = convert_binding(json['text'])
            if value.include?('{')
              attrs << " value={#{value.gsub(/[{}]/, '')}}"
            else
              attrs << " defaultValue=\"#{value}\""
            end
          end

          # Secure (password)
          attrs << ' type="password"' if json['secure']

          attrs.join
        end

        def build_on_change
          handler = json['onTextChange'] || json['onChange']
          return '' unless handler

          if handler.start_with?('@{')
            " onChange={#{handler.gsub(/@\{|\}/, '')}}"
          else
            " onChange={#{handler}}"
          end
        end
      end
    end
  end
end
