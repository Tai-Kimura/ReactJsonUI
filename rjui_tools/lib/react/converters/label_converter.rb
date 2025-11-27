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

          "#{indent_str(indent)}<span#{id_attr} className=\"#{class_name}\"#{style_attr}>#{text}</span>"
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

          classes.compact.reject(&:empty?).join(' ')
        end
      end
    end
  end
end
