# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class IndicatorConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''

          # Loading spinner using CSS animation
          <<~JSX.chomp
            #{indent_str(indent)}<div#{id_attr} className="#{class_name}">
            #{indent_str(indent + 2)}<div className="#{build_spinner_class}" />
            #{indent_str(indent)}</div>
          JSX
        end

        protected

        def build_class_name
          classes = [super]

          classes << 'inline-flex items-center justify-center'

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_spinner_class
          classes = []

          # Size
          size = json['size'] || 'medium'
          case size.to_s.downcase
          when 'small'
            classes << 'w-4 h-4'
          when 'large'
            classes << 'w-8 h-8'
          else # medium
            classes << 'w-6 h-6'
          end

          # Spinner animation
          classes << 'animate-spin'
          classes << 'rounded-full'
          classes << 'border-2'
          classes << 'border-transparent'

          # Color
          color = json['color'] || json['tintColor'] || '#3B82F6'
          if color.start_with?('#')
            classes << "border-t-[#{color}]"
          else
            classes << "border-t-#{color}"
          end

          classes.join(' ')
        end
      end
    end
  end
end
