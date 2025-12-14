# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class ScrollViewConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          style_attr = build_style_attr
          children = convert_children(indent)
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          testid_attr = build_testid_attr
          tag_attr = build_tag_attr

          if children.empty?
            "#{indent_str(indent)}<div#{id_attr} className=\"#{class_name}\"#{style_attr}#{testid_attr}#{tag_attr} />"
          else
            <<~JSX.chomp
              #{indent_str(indent)}<div#{id_attr} className="#{class_name}"#{style_attr}#{testid_attr}#{tag_attr}>
              #{children}
              #{indent_str(indent)}</div>
            JSX
          end
        end

        protected

        def build_class_name
          classes = [super]

          # Scroll direction
          orientation = json['orientation']
          horizontal_scroll = json['horizontalScroll']

          if horizontal_scroll || orientation == 'horizontal'
            classes << 'overflow-x-auto'
            classes << 'flex flex-row' unless json['orientation']
          else
            classes << 'overflow-y-auto'
            classes << 'flex flex-col' unless json['orientation']
          end

          # Hide scrollbar options
          if json['showsHorizontalScrollIndicator'] == false
            classes << 'scrollbar-hide'
          end
          if json['showsVerticalScrollIndicator'] == false
            classes << 'scrollbar-hide'
          end

          # Scroll snap (paging)
          if json['paging']
            if horizontal_scroll || orientation == 'horizontal'
              classes << 'snap-x snap-mandatory'
            else
              classes << 'snap-y snap-mandatory'
            end
          end

          # Scroll enabled
          if json['scrollEnabled'] == false
            classes << 'overflow-hidden'
            classes.reject! { |c| c.start_with?('overflow-x-auto', 'overflow-y-auto') }
          end

          # Bounces (overscroll behavior)
          if json['bounces'] == false
            classes << 'overscroll-none'
          end

          # Content inset adjustment behavior
          if json['contentInsetAdjustmentBehavior'] == 'never'
            classes << 'scroll-p-0'
          end

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_style_attr
          super

          # Content inset
          if json['contentInset']
            inset = json['contentInset']
            if inset.is_a?(Array)
              case inset.length
              when 1
                @dynamic_styles['padding'] = "'#{inset[0]}px'"
              when 2
                @dynamic_styles['padding'] = "'#{inset[0]}px #{inset[1]}px'"
              when 4
                @dynamic_styles['padding'] = "'#{inset[0]}px #{inset[1]}px #{inset[2]}px #{inset[3]}px'"
              end
            elsif inset.is_a?(Hash)
              top = inset['top'] || 0
              right = inset['right'] || 0
              bottom = inset['bottom'] || 0
              left = inset['left'] || 0
              @dynamic_styles['padding'] = "'#{top}px #{right}px #{bottom}px #{left}px'"
            else
              @dynamic_styles['padding'] = "'#{inset}px'"
            end
          end

          # Max zoom (for zoomable content)
          if json['maxZoom']
            @dynamic_styles['touchAction'] = "'pan-x pan-y pinch-zoom'"
          end

          return '' if @dynamic_styles.nil? || @dynamic_styles.empty?

          style_pairs = @dynamic_styles.map do |key, value|
            clean_value = value.gsub(/^\{|\}$/, '')
            "#{key}: #{clean_value}"
          end

          " style={{ #{style_pairs.join(', ')} }}"
        end
      end
    end
  end
end
