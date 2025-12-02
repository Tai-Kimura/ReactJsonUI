# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class GradientViewConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          style_attr = build_gradient_style
          children = convert_children(indent)
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          event_attrs = build_event_attrs

          jsx = if children.empty?
            "#{indent_str(indent)}<div#{id_attr} className=\"#{class_name}\"#{style_attr}#{event_attrs} />"
          else
            <<~JSX.chomp
              #{indent_str(indent)}<div#{id_attr} className="#{class_name}"#{style_attr}#{event_attrs}>
              #{children}
              #{indent_str(indent)}</div>
            JSX
          end

          wrap_with_visibility(jsx, indent)
        end

        protected

        def build_gradient_style
          gradient_css = build_gradient_css
          return '' unless gradient_css

          existing_style = build_style_attr
          if existing_style.empty?
            " style={{ background: '#{gradient_css}' }}"
          else
            existing_style.sub(/\}\}$/, ", background: '#{gradient_css}' }}")
          end
        end

        def build_gradient_css
          colors = json['gradient']
          return nil unless colors.is_a?(Array) && colors.length >= 2

          direction = get_gradient_direction
          locations = json['locations']

          color_stops = if locations.is_a?(Array) && locations.length == colors.length
            colors.each_with_index.map do |color, i|
              "#{color} #{(locations[i] * 100).to_i}%"
            end.join(', ')
          else
            colors.join(', ')
          end

          "linear-gradient(#{direction}, #{color_stops})"
        end

        def get_gradient_direction
          # Check for startPoint/endPoint first
          if json['startPoint'] && json['endPoint']
            start_x, start_y = json['startPoint']
            end_x, end_y = json['endPoint']

            # Calculate angle from points
            angle = Math.atan2(end_y - start_y, end_x - start_x) * (180 / Math::PI) + 90
            return "#{angle.round}deg"
          end

          # Fall back to gradientDirection
          direction = (json['gradientDirection'] || 'Vertical').downcase
          case direction
          when 'horizontal'
            'to right'
          when 'oblique'
            '45deg'
          else # vertical
            'to bottom'
          end
        end

        def build_class_name
          classes = [super]

          # Default flex column for View with children
          if json['child'].is_a?(Array) && !json['orientation']
            classes.unshift('flex flex-col')
          end

          # Cursor pointer for clickable items
          classes << 'cursor-pointer' if json['onClick'] || json['onclick']

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_event_attrs
          attrs = []
          attrs << build_onclick_attr
          attrs.compact.join('')
        end
      end
    end
  end
end
