# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class ScrollViewConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          children = convert_children(indent)
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''

          if children.empty?
            "#{indent_str(indent)}<div#{id_attr} className=\"#{class_name}\" />"
          else
            <<~JSX.chomp
              #{indent_str(indent)}<div#{id_attr} className="#{class_name}">
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
          if json['showsHorizontalScrollIndicator'] == false || json['showsVerticalScrollIndicator'] == false
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

          classes.compact.reject(&:empty?).join(' ')
        end
      end
    end
  end
end
