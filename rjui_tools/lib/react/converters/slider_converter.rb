# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class SliderConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''

          min_value = json['minimumValue'] || 0
          max_value = json['maximumValue'] || 100

          # Handle range array format: [min, max]
          if json['range'].is_a?(Array) && json['range'].length == 2
            min_value = json['range'][0]
            max_value = json['range'][1]
          end

          value_attr = build_value_attr
          on_change = build_on_change
          disabled = json['enabled'] == false ? ' disabled' : ''

          # Accent color via style
          style_attr = build_style_attr

          <<~JSX.chomp
            #{indent_str(indent)}<input#{id_attr} type="range" className="#{class_name}" min={#{min_value}} max={#{max_value}}#{value_attr}#{on_change}#{disabled}#{style_attr} />
          JSX
        end

        protected

        def build_class_name
          classes = [super]

          classes << 'w-full'
          classes << 'cursor-pointer'

          # Disabled state
          classes << 'opacity-50 cursor-not-allowed' if json['enabled'] == false

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_value_attr
          value = json['value']

          if value && is_binding?(value)
            prop = extract_binding_property(value)
            " value={#{prop}}"
          elsif value
            " defaultValue={#{value}}"
          else
            ''
          end
        end

        def build_on_change
          handler = json['onValueChanged'] || json['onChange']
          return '' unless handler

          if handler.start_with?('@{')
            " onChange={#{handler.gsub(/@\{|\}/, '')}}"
          else
            " onChange={(e) => #{handler}(e.target.value)}"
          end
        end

        def build_style_attr
          tint_color = json['tintColor']
          return '' unless tint_color

          " style={{ accentColor: '#{tint_color}' }}"
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
