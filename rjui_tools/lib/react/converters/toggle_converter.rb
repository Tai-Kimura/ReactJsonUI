# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class ToggleConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          text = json['text'] || json['label'] || ''

          # Get state binding
          checked_attr = build_checked_attr
          on_change = build_on_change

          if text.empty?
            # Toggle only (no label)
            <<~JSX.chomp
              #{indent_str(indent)}<input#{id_attr} type="checkbox" className="#{class_name}"#{checked_attr}#{on_change} />
            JSX
          else
            # Toggle with label
            <<~JSX.chomp
              #{indent_str(indent)}<label#{id_attr} className="#{class_name}">
              #{indent_str(indent + 2)}<input type="checkbox"#{checked_attr}#{on_change} />
              #{indent_str(indent + 2)}<span>#{convert_binding(text)}</span>
              #{indent_str(indent)}</label>
            JSX
          end
        end

        protected

        def build_class_name
          classes = [super]

          classes << 'flex items-center gap-2' if json['text'] || json['label']
          classes << 'cursor-pointer'

          # Disabled state
          classes << 'opacity-50 cursor-not-allowed' if json['enabled'] == false

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_checked_attr
          is_on = json['isOn'] || json['checked']

          if is_on && is_binding?(is_on)
            prop = extract_binding_property(is_on)
            " checked={#{prop}}"
          elsif is_on
            ' defaultChecked'
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
            " onChange={#{handler}}"
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
