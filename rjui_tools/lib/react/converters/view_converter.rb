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
          onclick_attr = build_onclick_attr
          visibility_binding = build_visibility_binding

          jsx = if children.empty?
            "#{indent_str(indent)}<div#{id_attr} className=\"#{class_name}\"#{style_attr}#{onclick_attr} />"
          else
            <<~JSX.chomp
              #{indent_str(indent)}<div#{id_attr} className="#{class_name}"#{style_attr}#{onclick_attr}>
              #{children}
              #{indent_str(indent)}</div>
            JSX
          end

          # Wrap with visibility condition if binding exists
          if visibility_binding
            <<~JSX.chomp
              #{indent_str(indent)}{#{visibility_binding} && (
              #{jsx}
              #{indent_str(indent)})}
            JSX
          else
            jsx
          end
        end

        # Extract visibility binding property if exists
        # For visibility, we need to check if the result is 'visible' (not 'gone')
        def build_visibility_binding
          visibility = json['visibility']
          return nil unless visibility && has_binding?(visibility)

          # Extract the binding expression
          binding_expr = visibility.gsub(/@\{|\}/, '')

          # If expression contains ternary with 'gone'/'visible', convert to boolean condition
          # e.g., "data.isLast ? 'gone' : 'visible'" becomes "!data.isLast"
          if binding_expr =~ /^(.+?)\s*\?\s*'gone'\s*:\s*'visible'$/
            "!#{$1.strip}"
          elsif binding_expr =~ /^(.+?)\s*\?\s*'visible'\s*:\s*'gone'$/
            $1.strip
          else
            # Assume expression directly evaluates to 'visible' or 'gone'
            "(#{binding_expr}) !== 'gone'"
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

          # Cursor pointer for clickable items
          classes << 'cursor-pointer' if json['onClick']

          classes.compact.reject(&:empty?).join(' ')
        end
      end
    end
  end
end
