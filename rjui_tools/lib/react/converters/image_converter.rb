# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class ImageConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          src = convert_binding(json['src'] || json['url'] || '')
          alt = json['alt'] || ''
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''

          if src.include?('{')
            "#{indent_str(indent)}<img#{id_attr} className=\"#{class_name}\" src={#{src.gsub(/[{}]/, '')}} alt=\"#{alt}\" />"
          else
            "#{indent_str(indent)}<img#{id_attr} className=\"#{class_name}\" src=\"#{src}\" alt=\"#{alt}\" />"
          end
        end

        protected

        def build_class_name
          classes = [super]

          # Content mode
          case json['contentMode']&.downcase
          when 'aspectfit'
            classes << 'object-contain'
          when 'aspectfill'
            classes << 'object-cover'
          when 'center'
            classes << 'object-none'
          else
            classes << 'object-cover'
          end

          classes.compact.reject(&:empty?).join(' ')
        end
      end
    end
  end
end
