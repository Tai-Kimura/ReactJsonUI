# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class SelectBoxConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          items = json['items'] || []

          value_attr = build_value_attr
          on_change = build_on_change
          disabled = json['enabled'] == false ? ' disabled' : ''

          # Check if items is a binding expression
          if items.is_a?(String) && is_binding?(items)
            items_prop = extract_binding_property(items)
            hint = json['hint'] || json['placeholder']
            hint_option = hint ? "\n#{indent_str(indent + 2)}<option value=\"\" disabled>#{hint}</option>" : ''

            <<~JSX.chomp
              #{indent_str(indent)}<select#{id_attr} className="#{class_name}"#{value_attr}#{on_change}#{disabled}>#{hint_option}
              #{indent_str(indent + 2)}{#{items_prop}.map((item) => (
              #{indent_str(indent + 4)}<option key={item.value} value={item.value}>{item.text}</option>
              #{indent_str(indent + 2)}))}
              #{indent_str(indent)}</select>
            JSX
          else
            options_jsx = items.map do |item|
              if item.is_a?(Hash)
                value = item['value'] || item['id'] || item['text']
                label = item['text'] || item['label'] || value
                "#{indent_str(indent + 2)}<option value=\"#{value}\">#{label}</option>"
              else
                "#{indent_str(indent + 2)}<option value=\"#{item}\">#{item}</option>"
              end
            end.join("\n")

            # Add placeholder option if hint exists
            hint = json['hint'] || json['placeholder']
            if hint
              options_jsx = "#{indent_str(indent + 2)}<option value=\"\" disabled>#{hint}</option>\n#{options_jsx}"
            end

            <<~JSX.chomp
              #{indent_str(indent)}<select#{id_attr} className="#{class_name}"#{value_attr}#{on_change}#{disabled}>
              #{options_jsx}
              #{indent_str(indent)}</select>
            JSX
          end
        end

        protected

        def build_class_name
          classes = [super]

          # Default select styling
          classes << 'border'
          classes << 'rounded-md'
          classes << 'px-3 py-2'
          classes << 'bg-white'
          classes << 'cursor-pointer'
          classes << 'outline-none'
          classes << 'focus:ring-2 focus:ring-blue-500 focus:border-blue-500'

          # Disabled state
          classes << 'opacity-50 cursor-not-allowed' if json['enabled'] == false

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_value_attr
          value = json['selectedValue'] || json['value']

          if value && is_binding?(value)
            prop = extract_binding_property(value)
            " value={#{prop}}"
          elsif value
            " defaultValue=\"#{value}\""
          else
            ''
          end
        end

        def build_on_change
          handler = json['onValueChanged'] || json['onChange']
          return '' unless handler

          if handler.start_with?('@{')
            prop = handler.gsub(/@\{|\}/, '')
            " onChange={(e) => #{prop}(e.target.value)}"
          else
            " onChange={(e) => #{handler}(e.target.value)}"
          end
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
