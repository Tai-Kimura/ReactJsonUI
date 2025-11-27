# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class RadioConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          items = json['items'] || []
          text = json['text'] || ''
          group = json['group'] || extract_id || 'radioGroup'

          if items.any?
            # Radio group with multiple items
            generate_radio_group(indent, id_attr, class_name, items, group, text)
          else
            # Single radio button
            generate_single_radio(indent, id_attr, class_name, group, text)
          end
        end

        protected

        def build_class_name
          classes = [super]

          classes << 'flex flex-col gap-2' if (json['items'] || []).any?
          classes << 'cursor-pointer'

          # Disabled state
          classes << 'opacity-50 cursor-not-allowed' if json['enabled'] == false

          classes.compact.reject(&:empty?).join(' ')
        end

        private

        def generate_radio_group(indent, id_attr, class_name, items, group, label_text)
          selected_binding = build_selected_binding
          on_change = build_on_change

          items_jsx = items.map do |item|
            escaped_item = item.gsub('"', '&quot;')
            <<~JSX.chomp
              #{indent_str(indent + 2)}<label className="flex items-center gap-2 cursor-pointer">
              #{indent_str(indent + 4)}<input type="radio" name="#{group}" value="#{escaped_item}" checked={#{selected_binding} === "#{escaped_item}"} onChange={() => #{on_change}("#{escaped_item}")} />
              #{indent_str(indent + 4)}<span>#{item}</span>
              #{indent_str(indent + 2)}</label>
            JSX
          end.join("\n")

          label_jsx = if label_text && !label_text.empty?
                        "#{indent_str(indent + 2)}<span className=\"font-medium\">#{convert_binding(label_text)}</span>\n"
                      else
                        ''
                      end

          <<~JSX.chomp
            #{indent_str(indent)}<div#{id_attr} className="#{class_name}">
            #{label_jsx}#{items_jsx}
            #{indent_str(indent)}</div>
          JSX
        end

        def generate_single_radio(indent, id_attr, class_name, group, text)
          selected_binding = build_selected_binding
          on_change = build_on_change
          radio_value = extract_id || 'option'

          <<~JSX.chomp
            #{indent_str(indent)}<label#{id_attr} className="#{class_name} flex items-center gap-2">
            #{indent_str(indent + 2)}<input type="radio" name="#{group}" value="#{radio_value}" checked={#{selected_binding} === "#{radio_value}"} onChange={() => #{on_change}("#{radio_value}")} />
            #{indent_str(indent + 2)}<span>#{convert_binding(text)}</span>
            #{indent_str(indent)}</label>
          JSX
        end

        def build_selected_binding
          selected = json['selectedValue']

          if selected && is_binding?(selected)
            extract_binding_property(selected)
          else
            'selectedValue'
          end
        end

        def build_on_change
          handler = json['onValueChanged'] || json['onChange'] || json['onclick']

          if handler
            if handler.start_with?('@{')
              handler.gsub(/@\{|\}/, '')
            else
              handler
            end
          else
            binding = build_selected_binding
            "set#{binding[0].upcase}#{binding[1..]}"
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
