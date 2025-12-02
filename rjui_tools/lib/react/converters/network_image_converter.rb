# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class NetworkImageConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''

          src = build_src_attr
          alt = json['alt'] || json['accessibilityLabel'] || ''
          content_mode = build_content_mode_attr
          placeholder = json['placeholder'] ? " placeholder=\"#{json['placeholder']}\"" : ''
          error_image = json['errorImage'] ? " errorImage=\"#{json['errorImage']}\"" : ''

          # Build event handlers
          on_load = build_event_handler('onLoad')
          on_error = build_event_handler('onError')

          style_attr = build_style_attr

          <<~JSX.chomp
            #{indent_str(indent)}<NetworkImage#{id_attr} className="#{class_name}"#{src}#{content_mode}#{placeholder}#{error_image} alt="#{alt}"#{on_load}#{on_error}#{style_attr} />
          JSX
        end

        protected

        def build_class_name
          classes = [super]
          classes.compact.reject(&:empty?).join(' ')
        end

        def build_src_attr
          src = json['src'] || json['url'] || json['imageUrl']
          return '' unless src

          if has_binding?(src)
            " src={#{convert_binding(src).gsub(/^\{|\}$/, '')}}"
          else
            " src=\"#{src}\""
          end
        end

        def build_content_mode_attr
          content_mode = json['contentMode'] || json['scaleType']
          return '' unless content_mode

          # Map iOS/Android content mode names to CSS object-fit values
          mode_map = {
            'scaleAspectFill' => 'cover',
            'scaleAspectFit' => 'contain',
            'scaleToFill' => 'fill',
            'center' => 'none',
            'centerCrop' => 'cover',
            'fitCenter' => 'contain',
            'fitXY' => 'fill'
          }

          mapped_mode = mode_map[content_mode] || content_mode
          " contentMode=\"#{mapped_mode}\""
        end

        def build_event_handler(event_name)
          handler = json[event_name]
          return '' unless handler

          if handler.start_with?('@{')
            " #{event_name}={#{handler.gsub(/@\{|\}/, '')}}"
          else
            " #{event_name}={#{handler}}"
          end
        end
      end
    end
  end
end
