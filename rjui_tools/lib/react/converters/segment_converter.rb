# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class SegmentConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          items = json['items'] || []

          selected_binding = build_selected_binding
          on_change = build_on_change

          items_jsx = items.each_with_index.map do |item, index|
            button_class = build_button_class(index)
            "#{indent_str(indent + 2)}<button key={#{index}} className={`#{button_class}`} onClick={() => #{on_change}(#{index})}>#{item}</button>"
          end.join("\n")

          <<~JSX.chomp
            #{indent_str(indent)}<div#{id_attr} className="#{class_name}">
            #{items_jsx}
            #{indent_str(indent)}</div>
          JSX
        end

        protected

        def build_class_name
          classes = [super]

          classes << 'w-full'
          classes << 'flex'
          classes << 'rounded-lg'
          classes << 'bg-gray-100'
          classes << 'p-1'

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_button_class(index)
          selected_index = json['selectedIndex'] || json['selectedTabIndex'] || 0

          # Build font size class
          font_size_class = if json['fontSize']
            TailwindMapper.map_font_size(json['fontSize'])
          else
            'text-sm'
          end

          # Build padding class
          padding_class = if json['height']
            "py-#{TailwindMapper::PADDING_MAP[json['height'] / 4] || (json['height'] / 4)}"
          else
            'py-2'
          end

          base_classes = "flex-1 px-4 #{padding_class} #{font_size_class} font-medium rounded-md transition-colors cursor-pointer"

          if is_binding?(selected_index)
            prop = extract_binding_property(selected_index)
            "#{base_classes} ${#{prop} === #{index} ? 'bg-white text-gray-900 shadow' : 'text-gray-500 hover:text-gray-700'}"
          else
            # Static selection - for generated code, we'll use a state variable
            "#{base_classes} ${selectedIndex === #{index} ? 'bg-white text-gray-900 shadow' : 'text-gray-500 hover:text-gray-700'}"
          end
        end

        def build_selected_binding
          selected = json['selectedIndex'] || json['selectedTabIndex']

          if selected && is_binding?(selected)
            extract_binding_property(selected)
          else
            'selectedIndex'
          end
        end

        def build_on_change
          handler = json['onValueChanged'] || json['onChange']

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
