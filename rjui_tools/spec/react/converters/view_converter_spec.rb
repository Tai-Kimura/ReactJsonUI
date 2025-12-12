# frozen_string_literal: true

require_relative '../../spec_helper'
require 'react/converters/view_converter'

RSpec.describe RjuiTools::React::Converters::ViewConverter do
  def create_converter(json_data)
    described_class.new(json_data)
  end

  describe '#build_container_classes' do
    context 'with spacing' do
      it 'adds gap class for spacing' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'horizontal',
          'spacing' => 16,
          'child' => [
            { 'type' => 'Label', 'text' => 'A' }
          ]
        })
        classes = converter.send(:build_container_classes)
        expect(classes).to include('gap-16')
      end

      it 'maps spacing to Tailwind gap values' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'vertical',
          'spacing' => 8,
          'child' => []
        })
        classes = converter.send(:build_container_classes)
        expect(classes).to include('gap-8')
      end
    end

    context 'with distribution' do
      it 'adds justify-between for fill distribution' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'horizontal',
          'distribution' => 'fill',
          'child' => []
        })
        classes = converter.send(:build_container_classes)
        expect(classes).to include('justify-between')
      end

      it 'adds justify-evenly for fillEqually distribution' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'horizontal',
          'distribution' => 'fillEqually',
          'child' => []
        })
        classes = converter.send(:build_container_classes)
        expect(classes).to include('justify-evenly')
      end

      it 'adds justify-around for equalSpacing distribution' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'vertical',
          'distribution' => 'equalSpacing',
          'child' => []
        })
        classes = converter.send(:build_container_classes)
        expect(classes).to include('justify-around')
      end

      it 'adds justify-evenly for equalCentering distribution' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'horizontal',
          'distribution' => 'equalCentering',
          'child' => []
        })
        classes = converter.send(:build_container_classes)
        expect(classes).to include('justify-evenly')
      end
    end

    context 'with spacing and distribution combined' do
      it 'applies both spacing and distribution classes' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'horizontal',
          'spacing' => 12,
          'distribution' => 'equalSpacing',
          'child' => []
        })
        classes = converter.send(:build_container_classes)
        expect(classes).to include('gap-12')
        expect(classes).to include('justify-around')
      end
    end
  end
end
