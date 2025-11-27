# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class ProgressConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''

          value_attr = build_value_attr
          max_attr = " max={#{json['maximumValue'] || 100}}"

          # Tint color via style
          style_attr = build_style_attr

          <<~JSX.chomp
            #{indent_str(indent)}<progress#{id_attr} className="#{class_name}"#{value_attr}#{max_attr}#{style_attr} />
          JSX
        end

        protected

        def build_class_name
          classes = [super]

          classes << 'w-full'
          classes << 'h-2'
          classes << 'rounded-full'
          classes << 'appearance-none'

          # Custom progress bar styling
          classes << '[&::-webkit-progress-bar]:rounded-full'
          classes << '[&::-webkit-progress-bar]:bg-gray-200'
          classes << '[&::-webkit-progress-value]:rounded-full'

          # Progress color
          tint_color = json['tintColor'] || json['progressTintColor']
          if tint_color
            classes << "[&::-webkit-progress-value]:bg-[#{tint_color}]"
            classes << "[&::-moz-progress-bar]:bg-[#{tint_color}]"
          else
            classes << '[&::-webkit-progress-value]:bg-blue-500'
            classes << '[&::-moz-progress-bar]:bg-blue-500'
          end

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_value_attr
          value = json['value'] || json['progress'] || 0

          if is_binding?(value)
            prop = extract_binding_property(value)
            " value={#{prop}}"
          else
            " value={#{value}}"
          end
        end

        def build_style_attr
          # Additional styling not supported by Tailwind classes
          ''
        end

        def is_binding?(value)
          value.is_a?(String) && value.start_with?('@{') && value.end_with?('}')
        end

        def extract_binding_property(value)
          return nil unless is_binding?(value)

          value[2...-1]
        end
      end
    end
  end
end
