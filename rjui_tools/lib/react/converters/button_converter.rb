# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class ButtonConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          text = convert_binding(json['text'] || '')
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          on_click = build_on_click

          # If href is specified, wrap with Next.js Link
          if json['href']
            href = json['href']
            "#{indent_str(indent)}<Link href=\"#{href}\"><button#{id_attr} className=\"#{class_name}\"#{on_click}>#{text}</button></Link>"
          else
            "#{indent_str(indent)}<button#{id_attr} className=\"#{class_name}\"#{on_click}>#{text}</button>"
          end
        end

        protected

        def build_class_name
          classes = [super]

          # Default button styles
          classes << 'cursor-pointer'
          classes << 'transition-colors'

          # Hover state
          if json['tapBackground']
            hover_color = TailwindMapper.map_color(json['tapBackground'], 'hover:bg')
            classes << hover_color
          else
            classes << 'hover:opacity-80'
          end

          # Disabled state
          classes << 'disabled:opacity-50 disabled:cursor-not-allowed'

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_on_click
          build_onclick_attr
        end
      end
    end
  end
end
