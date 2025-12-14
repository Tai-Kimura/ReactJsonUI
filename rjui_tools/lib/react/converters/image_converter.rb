# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class ImageConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          style_attr = build_style_attr
          src = build_src
          alt = json['alt'] || json['accessibilityLabel'] || ''
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          onclick_attr = build_onclick_attr
          testid_attr = build_testid_attr
          tag_attr = build_tag_attr

          # Build src attribute
          src_attr = if src.include?('{')
                       " src={#{src.gsub(/[{}]/, '')}}"
                     else
                       " src=\"#{src}\""
                     end

          "#{indent_str(indent)}<img#{id_attr} className=\"#{class_name}\"#{style_attr}#{src_attr} alt=\"#{alt}\"#{onclick_attr}#{testid_attr}#{tag_attr} />"
        end

        protected

        def build_src
          # Priority: srcName > src > url > defaultImage
          if json['srcName']
            # srcName is typically a local asset name, may need path prefix
            "/images/#{json['srcName']}"
          elsif json['src']
            convert_binding(json['src'])
          elsif json['url']
            convert_binding(json['url'])
          elsif json['defaultImage']
            "/images/#{json['defaultImage']}"
          else
            '/images/placeholder.png'
          end
        end

        def build_class_name
          classes = [super]

          # Content mode
          case json['contentMode']&.downcase
          when 'aspectfit', 'aspect_fit'
            classes << 'object-contain'
          when 'aspectfill', 'aspect_fill'
            classes << 'object-cover'
          when 'center'
            classes << 'object-none object-center'
          when 'scaletofill', 'scale_to_fill'
            classes << 'object-fill'
          else
            classes << 'object-cover'
          end

          # CircleImage type
          if json['type'] == 'CircleImage'
            classes << 'rounded-full'
          end

          # Clickable cursor
          if json['canTap'] || json['onclick'] || json['onClick']
            classes << 'cursor-pointer'
          end

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_style_attr
          super

          # Corner radius (for non-circle images)
          if json['cornerRadius'] && json['type'] != 'CircleImage'
            @dynamic_styles['borderRadius'] = "'#{json['cornerRadius']}px'"
          end

          return '' if @dynamic_styles.nil? || @dynamic_styles.empty?

          style_pairs = @dynamic_styles.map do |key, value|
            clean_value = value.gsub(/^\{|\}$/, '')
            "#{key}: #{clean_value}"
          end

          " style={{ #{style_pairs.join(', ')} }}"
        end

        def build_onclick_attr
          return '' unless json['canTap'] || json['onclick'] || json['onClick']

          onclick = json['onclick'] || json['onClick']
          return '' unless onclick

          if onclick.end_with?(':')
            method_name = onclick.chomp(':')
            " onClick={() => #{method_name}(this)}"
          else
            " onClick={#{onclick}}"
          end
        end
      end
    end
  end
end
