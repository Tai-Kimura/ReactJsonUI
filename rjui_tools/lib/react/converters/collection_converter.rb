# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class CollectionConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''

          content = generate_collection_content(indent + 2)

          <<~JSX.chomp
            #{indent_str(indent)}<div#{id_attr} className="#{class_name}">
            #{content}
            #{indent_str(indent)}</div>
          JSX
        end

        protected

        def build_class_name
          classes = [super]

          columns = json['columnCount'] || json['columns'] || 1
          layout = json['layout'] || 'vertical'
          is_horizontal = layout == 'horizontal'

          if is_horizontal
            # Horizontal scroll collection
            classes << 'overflow-x-auto'
            classes << 'flex flex-row'
            classes << "gap-#{TailwindMapper::PADDING_MAP[json['itemSpacing']] || '2'}" if json['itemSpacing']
          elsif columns == 1
            # List style (single column)
            classes << 'flex flex-col'
            classes << "gap-#{TailwindMapper::PADDING_MAP[json['itemSpacing']] || '2'}" if json['itemSpacing']
          else
            # Grid layout
            classes << 'grid'
            classes << "grid-cols-#{columns}"
            classes << "gap-#{TailwindMapper::PADDING_MAP[json['itemSpacing']] || '2'}" if json['itemSpacing']
          end

          classes.compact.reject(&:empty?).join(' ')
        end

        private

        def generate_collection_content(indent)
          sections = json['sections'] || []
          items_binding = extract_binding_property(json['items'])

          content_lines = []

          if sections.any?
            # Section-based rendering
            sections.each_with_index do |section, section_index|
              content_lines << generate_section_content(section, section_index, items_binding, indent)
            end
          else
            # Legacy cellClasses-based rendering
            content_lines << generate_legacy_content(indent)
          end

          content_lines.join("\n")
        end

        def generate_section_content(section, section_index, items_binding, indent)
          lines = []

          header_view = extract_view_name(section['header'])
          cell_view = extract_view_name(section['cell'])
          footer_view = extract_view_name(section['footer'])

          # Header
          if header_view
            lines << "#{indent_str(indent)}<#{header_view} />"
          end

          # Cells with map
          if cell_view && items_binding
            lines << "#{indent_str(indent)}{#{items_binding}?.sections?.[#{section_index}]?.cells?.data?.map((cellData, cellIndex) => ("
            lines << "#{indent_str(indent + 2)}<#{cell_view} key={cellIndex} data={cellData} />"
            lines << "#{indent_str(indent)}))}"
          elsif cell_view
            # Placeholder for static content
            lines << "#{indent_str(indent)}{/* Cells for section #{section_index} */}"
            lines << "#{indent_str(indent)}<#{cell_view} />"
          end

          # Footer
          if footer_view
            lines << "#{indent_str(indent)}<#{footer_view} />"
          end

          lines.join("\n")
        end

        def generate_legacy_content(indent)
          lines = []

          cell_classes = json['cellClasses'] || []
          header_classes = json['headerClasses'] || []
          footer_classes = json['footerClasses'] || []

          cell_view = extract_view_name(cell_classes.first) if cell_classes.any?
          header_view = extract_view_name(header_classes.first) if header_classes.any?
          footer_view = extract_view_name(footer_classes.first) if footer_classes.any?

          # Header
          if header_view
            lines << "#{indent_str(indent)}<#{header_view} />"
          end

          # Cells placeholder
          if cell_view
            items_binding = extract_binding_property(json['items'])
            if items_binding
              lines << "#{indent_str(indent)}{#{items_binding}?.map((item, index) => ("
              lines << "#{indent_str(indent + 2)}<#{cell_view} key={index} data={item} />"
              lines << "#{indent_str(indent)}))}"
            else
              lines << "#{indent_str(indent)}{/* Add items prop to render cells */}"
              lines << "#{indent_str(indent)}<#{cell_view} />"
            end
          else
            lines << "#{indent_str(indent)}{/* No cellClasses specified */}"
          end

          # Footer
          if footer_view
            lines << "#{indent_str(indent)}<#{footer_view} />"
          end

          lines.join("\n")
        end

        def extract_view_name(class_info)
          return nil unless class_info

          class_name = if class_info.is_a?(Hash)
                         class_info['className']
                       elsif class_info.is_a?(String)
                         class_info
                       end

          return nil unless class_name

          # Handle path-based component references like "components/attribute_row"
          if class_name.include?('/')
            # Extract the last part of the path and convert to PascalCase
            base_name = class_name.split('/').last
            return to_pascal_case(base_name)
          end

          # If already PascalCase React component name (starts with uppercase, no underscores),
          # use as-is without appending 'View'
          if class_name.match?(/^[A-Z]/) && !class_name.include?('_') &&
             !class_name.end_with?('Cell') && !class_name.end_with?('CollectionViewCell')
            return class_name
          end

          # Convert UIKit cell class name to React component name
          # InformationListCollectionViewCell -> InformationListView
          # SomeCell -> SomeCellView
          if class_name.end_with?('CollectionViewCell')
            class_name.sub(/CollectionViewCell$/, 'View')
          elsif class_name.end_with?('cell')
            class_name.sub(/cell$/, 'Cell') + 'View'
          elsif class_name.end_with?('Cell')
            class_name + 'View'
          elsif !class_name.end_with?('View')
            class_name + 'View'
          else
            class_name
          end
        end

        def to_pascal_case(string)
          string.split('_').map(&:capitalize).join
        end

        def extract_binding_property(items_property)
          return nil unless items_property

          if items_property.start_with?('@{') && items_property.end_with?('}')
            items_property[2...-1]
          else
            nil
          end
        end
      end
    end
  end
end
