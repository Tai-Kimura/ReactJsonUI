# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../lib/core/resources/color_manager'
require_relative '../../../lib/core/logger'

RSpec.describe RjuiTools::Core::Resources::ColorManager do
  let(:temp_dir) { Dir.mktmpdir('color_manager_test') }
  let(:source_path) { temp_dir }
  let(:resources_dir) { File.join(temp_dir, 'Resources') }
  let(:config) { { 'generated_directory' => 'src/generated' } }
  let(:manager) { described_class.new(config, source_path, resources_dir) }

  before do
    FileUtils.mkdir_p(resources_dir)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe '#initialize' do
    it 'creates instance with config, source_path, and resources_dir' do
      expect(manager).to be_a(described_class)
    end

    it 'loads existing colors.json if present' do
      colors_file = File.join(resources_dir, 'colors.json')
      File.write(colors_file, '{"primary": "#FF0000"}')

      new_manager = described_class.new(config, source_path, resources_dir)
      expect(new_manager).to be_a(described_class)
    end

    it 'handles invalid colors.json gracefully' do
      colors_file = File.join(resources_dir, 'colors.json')
      File.write(colors_file, 'invalid json')

      expect { described_class.new(config, source_path, resources_dir) }.not_to raise_error
    end

    it 'loads existing defined_colors.json if present' do
      defined_colors_file = File.join(resources_dir, 'defined_colors.json')
      File.write(defined_colors_file, '{"myColor": null}')

      new_manager = described_class.new(config, source_path, resources_dir)
      expect(new_manager).to be_a(described_class)
    end
  end

  describe '#process_colors' do
    let(:json_file) { File.join(temp_dir, 'test.json') }

    before do
      FileUtils.mkdir_p(File.join(source_path, 'src', 'generated'))
    end

    context 'with no processed files' do
      it 'returns early without processing' do
        expect { manager.process_colors([], 0, 0, config) }.not_to output.to_stdout
      end
    end

    context 'with json files containing hex colors' do
      before do
        File.write(json_file, JSON.pretty_generate({
          'type' => 'View',
          'background' => '#FF0000'
        }))
      end

      it 'extracts and replaces hex colors' do
        manager.process_colors([json_file], 1, 0, config)

        # Check that colors.json was created
        colors_file = File.join(resources_dir, 'colors.json')
        expect(File.exist?(colors_file)).to be true
      end

      it 'updates json file with color key' do
        manager.process_colors([json_file], 1, 0, config)

        content = JSON.parse(File.read(json_file))
        # The hex color should be replaced with a key
        expect(content['background']).not_to eq('#FF0000')
      end
    end

    context 'with json files containing undefined color keys' do
      before do
        File.write(json_file, JSON.pretty_generate({
          'type' => 'View',
          'background' => 'my_custom_color'
        }))
      end

      it 'adds undefined colors to defined_colors.json' do
        manager.process_colors([json_file], 1, 0, config)

        defined_colors_file = File.join(resources_dir, 'defined_colors.json')
        expect(File.exist?(defined_colors_file)).to be true
      end
    end

    context 'with binding expressions' do
      before do
        File.write(json_file, JSON.pretty_generate({
          'type' => 'View',
          'background' => '@{viewModel.backgroundColor}'
        }))
      end

      it 'skips binding expressions' do
        manager.process_colors([json_file], 1, 0, config)

        content = JSON.parse(File.read(json_file))
        expect(content['background']).to eq('@{viewModel.backgroundColor}')
      end
    end
  end

  describe '#apply_to_color_assets' do
    it 'saves pending colors' do
      manager.apply_to_color_assets
      # Should not raise error
    end
  end

  describe 'private methods' do
    describe '#is_color_property?' do
      it 'returns true for background' do
        expect(manager.send(:is_color_property?, 'background')).to be true
      end

      it 'returns true for fontColor' do
        expect(manager.send(:is_color_property?, 'fontColor')).to be true
      end

      it 'returns true for textColor' do
        expect(manager.send(:is_color_property?, 'textColor')).to be true
      end

      it 'returns true for borderColor' do
        expect(manager.send(:is_color_property?, 'borderColor')).to be true
      end

      it 'returns true for tintColor' do
        expect(manager.send(:is_color_property?, 'tintColor')).to be true
      end

      it 'returns false for non-color properties' do
        expect(manager.send(:is_color_property?, 'type')).to be false
      end
    end

    describe '#is_hex_color?' do
      it 'returns true for 6-digit hex with hash' do
        expect(manager.send(:is_hex_color?, '#FF0000')).to be true
      end

      it 'returns true for 6-digit hex without hash' do
        expect(manager.send(:is_hex_color?, 'FF0000')).to be true
      end

      it 'returns true for 3-digit hex' do
        expect(manager.send(:is_hex_color?, '#F00')).to be true
      end

      it 'returns true for 8-digit hex (with alpha)' do
        expect(manager.send(:is_hex_color?, '#FF0000FF')).to be true
      end

      it 'returns false for non-hex strings' do
        expect(manager.send(:is_hex_color?, 'red')).to be false
      end

      it 'returns false for non-string values' do
        expect(manager.send(:is_hex_color?, 123)).to be false
      end
    end

    describe '#normalize_hex_color' do
      it 'adds hash if missing' do
        expect(manager.send(:normalize_hex_color, 'FF0000')).to eq('#FF0000')
      end

      it 'converts to uppercase' do
        expect(manager.send(:normalize_hex_color, '#ff0000')).to eq('#FF0000')
      end

      it 'expands 3-digit to 6-digit' do
        expect(manager.send(:normalize_hex_color, '#F00')).to eq('#FF0000')
      end

      it 'keeps 8-digit hex as is' do
        expect(manager.send(:normalize_hex_color, '#FF0000AA')).to eq('#FF0000AA')
      end
    end

    describe '#parse_hex_to_rgb' do
      it 'parses 6-digit hex' do
        expect(manager.send(:parse_hex_to_rgb, '#FF0000')).to eq([255, 0, 0])
      end

      it 'parses 3-digit hex' do
        expect(manager.send(:parse_hex_to_rgb, '#F00')).to eq([255, 0, 0])
      end

      it 'parses 8-digit hex (ignoring alpha)' do
        expect(manager.send(:parse_hex_to_rgb, '#FF0000AA')).to eq([255, 0, 0])
      end

      it 'returns nil for invalid length hex' do
        expect(manager.send(:parse_hex_to_rgb, '#FF00')).to be_nil
      end
    end

    describe '#generate_color_key' do
      it 'generates key for red colors' do
        key = manager.send(:generate_color_key, '#FF0000')
        expect(key).to include('red')
      end

      it 'generates key for green colors' do
        key = manager.send(:generate_color_key, '#00FF00')
        expect(key).to include('green')
      end

      it 'generates key for blue colors' do
        key = manager.send(:generate_color_key, '#0000FF')
        expect(key).to include('blue')
      end

      it 'generates key for white' do
        key = manager.send(:generate_color_key, '#FFFFFF')
        expect(key).to eq('white')
      end

      it 'generates key for black' do
        key = manager.send(:generate_color_key, '#000000')
        expect(key).to eq('black')
      end

      it 'generates key for gray' do
        key = manager.send(:generate_color_key, '#808080')
        expect(key).to include('gray')
      end
    end

    describe '#snake_to_camel' do
      it 'converts snake_case to camelCase' do
        expect(manager.send(:snake_to_camel, 'primary_blue')).to eq('primaryBlue')
      end

      it 'handles single word' do
        expect(manager.send(:snake_to_camel, 'primary')).to eq('primary')
      end

      it 'handles numbers' do
        expect(manager.send(:snake_to_camel, 'white_2')).to eq('white2')
      end
    end

    describe '#replace_colors_recursive' do
      context 'with nested hash' do
        let(:json_file) { File.join(temp_dir, 'nested.json') }

        before do
          File.write(json_file, JSON.pretty_generate({
            'type' => 'View',
            'child' => [
              { 'type' => 'Label', 'fontColor' => '#FF0000' }
            ]
          }))
        end

        it 'processes nested color properties' do
          content = JSON.parse(File.read(json_file))
          manager.send(:replace_colors_recursive, content)
          expect(content['child'][0]['fontColor']).not_to eq('#FF0000')
        end
      end

      context 'with array' do
        it 'processes items in arrays' do
          data = [
            { 'background' => '#00FF00' },
            { 'background' => '#0000FF' }
          ]
          manager.send(:replace_colors_recursive, data)
          expect(data[0]['background']).not_to eq('#00FF00')
          expect(data[1]['background']).not_to eq('#0000FF')
        end
      end
    end

    describe '#generate_color_manager_js' do
      before do
        FileUtils.mkdir_p(File.join(source_path, 'src', 'generated'))
        # Add some colors to test
        colors_file = File.join(resources_dir, 'colors.json')
        File.write(colors_file, '{"primary": "#FF0000", "secondary": "#00FF00"}')
      end

      it 'generates ColorManager.js file' do
        new_manager = described_class.new(config, source_path, resources_dir)
        new_manager.send(:generate_color_manager_js)

        output_file = File.join(source_path, 'src', 'generated', 'ColorManager.js')
        expect(File.exist?(output_file)).to be true
      end

      it 'includes color definitions in generated file' do
        new_manager = described_class.new(config, source_path, resources_dir)
        new_manager.send(:generate_color_manager_js)

        output_file = File.join(source_path, 'src', 'generated', 'ColorManager.js')
        content = File.read(output_file)
        expect(content).to include('primary')
        expect(content).to include('secondary')
        expect(content).to include('#FF0000')
        expect(content).to include('#00FF00')
      end

      it 'generates color() method with binding expression handling' do
        new_manager = described_class.new(config, source_path, resources_dir)
        new_manager.send(:generate_color_manager_js)

        output_file = File.join(source_path, 'src', 'generated', 'ColorManager.js')
        content = File.read(output_file)
        expect(content).to include('color(key)')
        expect(content).to include('startsWith("@{") && key.endsWith("}")')
        expect(content).to include('return undefined')
      end

      it 'generates camelCase property accessors' do
        # Test with snake_case color name
        colors_file = File.join(resources_dir, 'colors.json')
        File.write(colors_file, '{"primary_blue": "#0000FF"}')

        new_manager = described_class.new(config, source_path, resources_dir)
        new_manager.send(:generate_color_manager_js)

        output_file = File.join(source_path, 'src', 'generated', 'ColorManager.js')
        content = File.read(output_file)
        expect(content).to include('get primaryBlue()')
      end
    end
  end

  describe 'integration tests' do
    context 'with multiple color formats in one file' do
      let(:json_file) { File.join(temp_dir, 'multi.json') }

      before do
        FileUtils.mkdir_p(File.join(source_path, 'src', 'generated'))
        File.write(json_file, JSON.pretty_generate({
          'type' => 'View',
          'background' => '#FF0000',
          'child' => [
            {
              'type' => 'Label',
              'fontColor' => '@{vm.textColor}',
              'text' => 'Test'
            },
            {
              'type' => 'Button',
              'background' => 'custom_color',
              'text' => 'Click'
            }
          ]
        }))
      end

      it 'handles hex colors, bindings, and custom keys correctly' do
        manager.process_colors([json_file], 1, 0, config)

        content = JSON.parse(File.read(json_file))

        # Hex color should be replaced with key
        expect(content['background']).not_to eq('#FF0000')
        expect(content['background']).to be_a(String)

        # Binding should remain unchanged
        expect(content['child'][0]['fontColor']).to eq('@{vm.textColor}')

        # Custom color key should remain unchanged
        expect(content['child'][1]['background']).to eq('custom_color')

        # colors.json should have the hex color
        colors_file = File.join(resources_dir, 'colors.json')
        colors_data = JSON.parse(File.read(colors_file))
        expect(colors_data.values).to include('#FF0000')

        # defined_colors.json should have the custom key
        defined_colors_file = File.join(resources_dir, 'defined_colors.json')
        defined_colors_data = JSON.parse(File.read(defined_colors_file))
        expect(defined_colors_data.keys).to include('custom_color')
      end
    end
  end
end
