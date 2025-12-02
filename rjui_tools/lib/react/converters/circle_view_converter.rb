# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class CircleViewConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          style_attr = build_circle_style
          children = convert_children(indent)
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          onclick_attr = build_onclick_attr

          jsx = if children.empty?
            "#{indent_str(indent)}<div#{id_attr} className=\"#{class_name}\"#{style_attr}#{onclick_attr} />"
          else
            <<~JSX.chomp
              #{indent_str(indent)}<div#{id_attr} className="#{class_name}"#{style_attr}#{onclick_attr}>
              #{children}
              #{indent_str(indent)}</div>
            JSX
          end

          wrap_with_visibility(jsx, indent)
        end

        protected

        def build_class_name
          classes = [super]

          # Make it circular
          classes << 'rounded-full'

          # Cursor pointer for clickable items
          classes << 'cursor-pointer' if json['onClick'] || json['onclick']

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_circle_style
          style_parts = []

          # Fill color (takes precedence over background for circle)
          fill_color = json['fillColor'] || json['background']
          style_parts << "backgroundColor: '#{fill_color}'" if fill_color

          # Border/Stroke
          stroke_color = json['strokeColor'] || json['borderColor']
          stroke_width = json['strokeWidth'] || json['borderWidth']

          if stroke_color || stroke_width
            stroke_width ||= 1
            stroke_color ||= '#000000'
            style_parts << "border: '#{stroke_width}px solid #{stroke_color}'"
          end

          return build_style_attr if style_parts.empty?

          existing_style = build_style_attr
          if existing_style.empty?
            " style={{ #{style_parts.join(', ')} }}"
          else
            existing_style.sub(/\}\}$/, ", #{style_parts.join(', ')} }}")
          end
        end
      end
    end
  end
end
