# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class SwitchConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          text = json['text'] || json['label'] || ''

          checked_attr = build_checked_attr
          on_change = build_on_change
          tint_color = json['tintColor'] || json['onTintColor'] || '#34C759'

          # iOS-style toggle switch using pure CSS
          switch_html = build_switch_element(checked_attr, on_change, tint_color)

          if text.empty?
            "#{indent_str(indent)}<div#{id_attr} className=\"#{class_name}\">#{switch_html}</div>"
          else
            <<~JSX.chomp
              #{indent_str(indent)}<label#{id_attr} className="#{class_name} flex items-center gap-3 cursor-pointer">
              #{indent_str(indent + 2)}#{switch_html}
              #{indent_str(indent + 2)}<span>#{convert_binding(text)}</span>
              #{indent_str(indent)}</label>
            JSX
          end
        end

        protected

        def build_class_name
          classes = [super]
          classes << 'inline-flex'
          classes << 'opacity-50 cursor-not-allowed' if json['enabled'] == false
          classes.compact.reject(&:empty?).join(' ')
        end

        def build_switch_element(checked_attr, on_change, tint_color)
          # Create iOS-style toggle with hidden checkbox and styled span
          <<~HTML.gsub("\n", '').gsub(/\s+/, ' ').strip
            <span className="relative inline-block w-[51px] h-[31px]">
              <input type="checkbox" className="sr-only peer"#{checked_attr}#{on_change} />
              <span className="absolute inset-0 bg-gray-200 rounded-full transition-colors duration-200 peer-checked:bg-[#{tint_color}]" />
              <span className="absolute left-[2px] top-[2px] w-[27px] h-[27px] bg-white rounded-full shadow transition-transform duration-200 peer-checked:translate-x-[20px]" />
            </span>
          HTML
        end

        def build_checked_attr
          is_on = json['isOn'] || json['checked'] || json['value']

          if is_on && is_binding?(is_on)
            prop = extract_binding_property(is_on)
            " checked={#{prop}}"
          elsif is_on == true
            ' defaultChecked'
          else
            ''
          end
        end

        def build_on_change
          handler = json['onValueChanged'] || json['onChange'] || json['valueChange']
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
