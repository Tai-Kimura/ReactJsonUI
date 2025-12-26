# frozen_string_literal: true

require_relative '../../spec_helper'
require 'react/converters/tab_view_converter'

RSpec.describe RjuiTools::React::Converters::TabViewConverter do
  let(:default_config) { { 'use_tailwind' => true } }

  def create_converter(json_data, config = nil)
    described_class.new(json_data, config || default_config)
  end

  describe '#convert' do
    context 'basic TabView' do
      it 'generates tab navigation with tabs array' do
        converter = create_converter({
          'type' => 'TabView',
          'tabs' => [
            { 'title' => 'Home', 'icon' => 'house', 'view' => 'home' },
            { 'title' => 'Profile', 'icon' => 'person', 'view' => 'profile' }
          ]
        })
        result = converter.convert
        expect(result).to include('<div')
        expect(result).to include('<nav')
        expect(result).to include('<button')
        expect(result).to include('Home')
        expect(result).to include('Profile')
      end

      it 'generates view references' do
        converter = create_converter({
          'type' => 'TabView',
          'tabs' => [
            { 'title' => 'Home', 'icon' => 'house', 'view' => 'home' }
          ]
        })
        result = converter.convert
        expect(result).to include('<HomeView />')
      end
    end

    context 'with selectedIndex binding' do
      it 'uses binding for selection state' do
        converter = create_converter({
          'type' => 'TabView',
          'selectedIndex' => '@{currentTab}',
          'tabs' => [
            { 'title' => 'Tab 1', 'icon' => 'circle' },
            { 'title' => 'Tab 2', 'icon' => 'circle' }
          ]
        })
        result = converter.convert
        expect(result).to include('data.currentTab === 0')
        expect(result).to include('data.currentTab === 1')
      end
    end

    context 'with onTabChange handler' do
      it 'uses handler for onClick' do
        converter = create_converter({
          'type' => 'TabView',
          'onTabChange' => '@{handleTabChange}',
          'tabs' => [
            { 'title' => 'Tab', 'icon' => 'circle' }
          ]
        })
        result = converter.convert
        expect(result).to include('onClick={() => data.handleTabChange(0)}')
      end
    end

    context 'with tintColor' do
      it 'applies tint color to selected tab' do
        converter = create_converter({
          'type' => 'TabView',
          'tintColor' => 'blue-600',
          'tabs' => [
            { 'title' => 'Tab', 'icon' => 'circle' }
          ]
        })
        result = converter.convert
        expect(result).to include('text-blue-600')
      end
    end

    context 'with unselectedColor' do
      it 'applies unselected color' do
        converter = create_converter({
          'type' => 'TabView',
          'unselectedColor' => 'gray-400',
          'tabs' => [
            { 'title' => 'Tab', 'icon' => 'circle' }
          ]
        })
        result = converter.convert
        expect(result).to include('text-gray-400')
      end
    end

    context 'with tabBarBackground' do
      it 'applies background color to nav' do
        converter = create_converter({
          'type' => 'TabView',
          'tabBarBackground' => 'white',
          'tabs' => [
            { 'title' => 'Tab', 'icon' => 'circle' }
          ]
        })
        result = converter.convert
        expect(result).to include('bg-white')
      end
    end

    context 'with showLabels=false' do
      it 'hides tab labels' do
        converter = create_converter({
          'type' => 'TabView',
          'showLabels' => false,
          'tabs' => [
            { 'title' => 'Tab', 'icon' => 'circle' }
          ]
        })
        result = converter.convert
        expect(result).not_to include('<span')
      end
    end

    context 'with badge' do
      it 'renders numeric badge' do
        converter = create_converter({
          'type' => 'TabView',
          'tabs' => [
            { 'title' => 'Notifications', 'icon' => 'bell', 'badge' => 5 }
          ]
        })
        result = converter.convert
        expect(result).to include('bg-red-500')
        expect(result).to include('5')
      end

      it 'renders badge with binding' do
        converter = create_converter({
          'type' => 'TabView',
          'tabs' => [
            { 'title' => 'Cart', 'icon' => 'cart', 'badge' => '@{cartCount}' }
          ]
        })
        result = converter.convert
        expect(result).to include('data.cartCount')
      end
    end

    context 'with snake_case view names' do
      it 'converts to PascalCase' do
        converter = create_converter({
          'type' => 'TabView',
          'tabs' => [
            { 'title' => 'Home', 'icon' => 'house', 'view' => 'home_screen' }
          ]
        })
        result = converter.convert
        expect(result).to include('<HomeScreenView />')
      end
    end

    context 'with default values' do
      it 'generates default content when no view specified' do
        converter = create_converter({
          'type' => 'TabView',
          'tabs' => [
            { 'title' => 'Settings', 'icon' => 'gear' }
          ]
        })
        result = converter.convert
        expect(result).to include('Settings content')
      end

      it 'generates default title when not provided' do
        converter = create_converter({
          'type' => 'TabView',
          'tabs' => [
            { 'icon' => 'circle' },
            { 'icon' => 'circle' }
          ]
        })
        result = converter.convert
        expect(result).to include('Tab 1')
        expect(result).to include('Tab 2')
      end
    end

    context 'with visibility binding' do
      it 'wraps with conditional rendering' do
        converter = create_converter({
          'type' => 'TabView',
          'visibility' => '@{showTabs}',
          'tabs' => [
            { 'title' => 'Tab', 'icon' => 'circle' }
          ]
        })
        result = converter.convert
        expect(result).to include('{data.showTabs &&')
      end
    end

    context 'with testId' do
      it 'generates data-testid attribute' do
        converter = create_converter({
          'type' => 'TabView',
          'testId' => 'main-tabs',
          'tabs' => [
            { 'title' => 'Tab', 'icon' => 'circle' }
          ]
        })
        result = converter.convert
        expect(result).to include('data-testid="main-tabs"')
      end
    end

    context 'icon mapping' do
      it 'maps SF Symbol icons to Lucide icons' do
        converter = create_converter({
          'type' => 'TabView',
          'tabs' => [
            { 'title' => 'Home', 'icon' => 'house' },
            { 'title' => 'User', 'icon' => 'person' },
            { 'title' => 'Settings', 'icon' => 'gearshape' }
          ]
        })
        result = converter.convert
        expect(result).to include('<Home')
        expect(result).to include('<User')
        expect(result).to include('<Settings')
      end
    end

    context 'with empty tabs array' do
      it 'generates empty navigation' do
        converter = create_converter({
          'type' => 'TabView',
          'tabs' => []
        })
        result = converter.convert
        expect(result).to include('<nav')
        expect(result).not_to include('<button')
      end
    end
  end

  describe '#map_to_lucide_icon' do
    it 'maps house to Home' do
      converter = create_converter({ 'type' => 'TabView', 'tabs' => [] })
      result = converter.send(:map_to_lucide_icon, 'house')
      expect(result).to eq('Home')
    end

    it 'maps person to User' do
      converter = create_converter({ 'type' => 'TabView', 'tabs' => [] })
      result = converter.send(:map_to_lucide_icon, 'person')
      expect(result).to eq('User')
    end

    it 'maps gearshape to Settings' do
      converter = create_converter({ 'type' => 'TabView', 'tabs' => [] })
      result = converter.send(:map_to_lucide_icon, 'gearshape')
      expect(result).to eq('Settings')
    end
  end
end
