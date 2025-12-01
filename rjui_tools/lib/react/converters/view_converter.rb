# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class ViewConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          style_attr = build_style_attr_with_visibility
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

          # Wrap with visibility condition (for 'gone' type)
          wrap_with_visibility(jsx, indent)
        end

        protected

        # Build style attribute including visibility (for 'invisible' type)
        def build_style_attr_with_visibility
          visibility_style = build_visibility_style

          if visibility_style
            @dynamic_styles ||= {}
            # Add visibility opacity to dynamic styles
            existing_style = build_style_attr
            if existing_style.empty?
              " style={{ #{visibility_style} }}"
            else
              # Merge with existing styles
              existing_style.sub(/\}\}$/, ", #{visibility_style} }}")
            end
          else
            build_style_attr
          end
        end

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

          # Cursor pointer for clickable items
          classes << 'cursor-pointer' if json['onClick']

          classes.compact.reject(&:empty?).join(' ')
        end
      end
    end
  end
end
