# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class LabelConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          style_attr = build_style_attr
          text = convert_binding(json['text'] || '')
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          onclick_attr = build_onclick_attr

          "#{indent_str(indent)}<span#{id_attr} className=\"#{class_name}\"#{style_attr}#{onclick_attr}>#{text}</span>"
        end

        protected

        def build_class_name
          classes = [super]

          # Line clamp for multiple lines
          if json['lines'] && json['lines'] > 1
            classes << "line-clamp-#{json['lines']}"
          elsif json['lines'] == 1
            classes << 'truncate'
          end

          # Font weight
          classes << 'font-bold' if json['fontWeight'] == 'bold'

          # Cursor pointer for clickable items
          classes << 'cursor-pointer' if json['onClick']

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_onclick_attr
          return '' unless json['onClick']

          onclick = json['onClick']
          " onClick={#{onclick}}"
        end
      end
    end
  end
end
