# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class ViewConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          style_attr = build_style_attr
          children = convert_children(indent)
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''

          if children.empty?
            "#{indent_str(indent)}<div#{id_attr} className=\"#{class_name}\"#{style_attr} />"
          else
            <<~JSX.chomp
              #{indent_str(indent)}<div#{id_attr} className="#{class_name}"#{style_attr}>
              #{children}
              #{indent_str(indent)}</div>
            JSX
          end
        end

        protected

        def build_class_name
          classes = [super]

          # Default flex column for View with children
          if json['child'].is_a?(Array) && !json['orientation']
            classes.unshift('flex flex-col')
          end

          # Center alignment
          classes << 'items-center' if json['centerHorizontal']
          classes << 'justify-center' if json['centerVertical']
          classes << 'items-center justify-center' if json['centerInParent']

          # Gap/Spacing
          if json['spacing']
            spacing = TailwindMapper::PADDING_MAP[json['spacing']] || json['spacing']
            classes << "gap-#{spacing}"
          end

          classes.compact.reject(&:empty?).join(' ')
        end
      end
    end
  end
end
