#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2022 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'

describe Setting, type: :model do
  before do
    described_class.clear_cache
  end

  after do
    described_class.destroy_all
  end

  describe "OpenProject's default settings" do
    it 'has OpenProject as application title' do
      expect(described_class.app_title).to eq 'OpenProject'
    end

    it 'allows users to register themselves' do
      expect(described_class).to be_self_registration
    end

    it 'allows anonymous users to access public information' do
      expect(described_class).not_to be_login_required
    end
  end

  # checks whether settings can be set and are persisted in the database
  describe 'changing a setting' do
    context "for a setting that doesn't exist in the database" do
      before do
        described_class.host_name = 'some name'
      end

      after do
        described_class.find_by(name: 'host_name').destroy
      end

      it 'sets the setting' do
        expect(described_class.host_name).to eq 'some name'
      end

      context 'when overwritten' do
        let!(:setting_definition) do
          Settings::Definition[:host_name].tap do |setting|
            allow(setting)
              .to receive(:writable?)
                    .and_return false
          end
        end

        it 'takes the setting from the definition' do
          expect(described_class.host_name)
            .to eql setting_definition.value
        end
      end

      it 'stores the setting' do
        expect(described_class.find_by(name: 'host_name').value).to eq 'some name'
      end
    end

    context 'for a setting that already exist in the database' do
      before do
        described_class.host_name = 'some name'
        described_class.host_name = 'some other name'
      end

      after do
        described_class.find_by(name: 'host_name').destroy
      end

      it 'sets the setting' do
        expect(described_class.host_name).to eq 'some other name'
      end

      it 'stores the setting' do
        expect(described_class.find_by(name: 'host_name').value).to eq 'some other name'
      end
    end
  end

  describe '.[setting]' do
    it 'fetches the value' do
      expect(described_class.app_title)
        .to eql('OpenProject')
    end

    context 'when value is blank but not nil' do
      it 'is read correctly for array' do
        expect(Settings::Definition['apiv3_cors_origins'].format).to eq(:array) # safeguard
        expect(described_class['apiv3_cors_origins']).to eq([])
      end

      it 'is read correctly for hash' do
        expect(Settings::Definition['fog'].format).to eq(:hash) # safeguard
        expect(described_class['fog']).to eq({})
      end
    end

    context 'when value was seeded as empty string in database', :settings_reset do
      let(:setting_name) { "my_setting" }

      subject { described_class[setting_name] }

      before do
        Settings::Definition.add(
          setting_name,
          value: nil,
          format: setting_format
        )
        described_class.create!(name: setting_name, value: '')
      end

      %i[array boolean date datetime hash symbol].each do |setting_format|
        context "for a #{setting_format} setting" do
          let(:setting_format) { setting_format }

          it { is_expected.to be_nil }
        end
      end

      context 'for a string setting' do
        let(:setting_format) { :string }

        it { is_expected.to eq('') }
      end
    end
  end

  describe '.[setting]?' do
    it 'fetches the value' do
      expect(described_class.smtp_enable_starttls_auto?)
        .to be false
    end

    it 'works for non boolean settings as well (deprecated)' do
      expect(described_class.app_title?)
        .to be true
    end
  end

  describe '.[setting]=' do
    it 'sets the value' do
      described_class.app_title = 'New title'

      expect(described_class.app_title)
        .to eql('New title')
    end

    it 'raises an error for a non writable setting' do
      expect { described_class.smtp_openssl_verify_mode = 'none' }
        .to raise_error NoMethodError
    end
  end

  describe '.[setting]_writable?' do
    before do
      allow(Settings::Definition[:host_name])
        .to receive(:writable?)
              .and_return writable
    end

    context 'when definition states it to be writable' do
      let(:writable) { true }

      it 'is writable' do
        expect(described_class)
          .to be_host_name_writable
      end
    end

    context 'when definition states it to be non writable' do
      let(:writable) { false }

      it 'is non writable' do
        expect(described_class)
          .not_to be_host_name_writable
      end
    end
  end

  describe ".installation_uuid" do
    after do
      described_class.find_by(name: "installation_uuid")&.destroy
    end

    it "returns unknown if the settings table isn't available yet" do
      allow(Setting)
        .to receive(:settings_table_exists_yet?)
        .and_return(false)
      expect(described_class.installation_uuid).to eq("unknown")
    end

    context "with settings table ready" do
      it "resets the value if blank" do
        described_class.create!(name: "installation_uuid", value: "")
        expect(described_class.installation_uuid).not_to be_blank
      end

      it "returns the existing value if any" do
        # can't use with_settings since described_class.installation_uuid has a custom implementation
        allow(Setting).to receive(:installation_uuid).and_return "abcd1234"

        expect(described_class.installation_uuid).to eq("abcd1234")
      end

      context "with no existing value" do
        context "in test environment" do
          before do
            expect(Rails.env).to receive(:test?).and_return(true)
          end

          it "returns 'test' as the UUID" do
            expect(described_class.installation_uuid).to eq("test")
          end
        end

        it "returns a random UUID" do
          expect(Rails.env).to receive(:test?).and_return(false)
          installation_uuid = described_class.installation_uuid
          expect(installation_uuid).not_to eq("test")
          expect(installation_uuid.size).to eq(36)
          expect(described_class.installation_uuid).to eq(installation_uuid)
        end
      end
    end
  end

  # Check that when reading certain setting values that they get overwritten if needed.
  describe "filter saved settings" do
    describe "with EE token", with_ee: [:conditional_highlighting] do
      it "returns the value for 'work_package_list_default_highlighting_mode' without changing it" do
        expect(described_class.work_package_list_default_highlighting_mode).to eq("inline")
      end
    end

    describe "without EE" do
      it "return 'none' as 'work_package_list_default_highlighting_mode'" do
        expect(described_class.work_package_list_default_highlighting_mode).to eq("none")
      end
    end
  end

  # tests the serialization feature to store complex data types like arrays in settings
  describe 'serialized array settings' do
    before do
      described_class.default_projects_modules = ['some_input']
    end

    it 'serializes arrays' do
      expect(described_class.default_projects_modules).to eq ['some_input']
      expect(described_class.find_by(name: 'default_projects_modules').value).to eq ['some_input']
    end
  end

  # tests the serialization feature to store complex data types like arrays in settings
  describe 'serialized hash settings' do
    before do
      setting = described_class.create!(name: 'repository_checkout_data')
      setting.update_columns(
        value: {
          git: { enabled: 0 },
          subversion: { enabled: 0 }
        }.to_yaml
      )
    end

    it 'deserializes hashes stored with symbol keys as string keys' do
      expected_value = {
        "git" => { "enabled" => 0 },
        "subversion" => { "enabled" => 0 }
      }

      expect(described_class.repository_checkout_data).to eq(expected_value)
      expect(described_class.find_by(name: 'repository_checkout_data').value).to eq(expected_value)
    end
  end

  describe 'caching' do
    let(:cache_key) { described_class.send :cache_key }

    before do
      RequestStore.clear!
      Rails.cache.clear
    end

    after do
      RequestStore.clear!
      Rails.cache.clear
    end

    context 'when cache is empty' do
      it 'requests the settings once from database' do
        expect(Setting).to receive(:pluck).with(:name, :value)
          .once
          .and_call_original

        expect(Rails.cache).to receive(:fetch).once.and_call_original
        expect(RequestStore).to receive(:fetch).exactly(3).times.and_call_original

        # Settings are empty by default
        expect(RequestStore.read(:cached_settings)).to be_nil
        expect(Rails.cache.read(cache_key)).to be_nil

        # Falls back to default values, but hitting cache
        value = described_class.app_title
        expect(described_class.app_title).to eq 'OpenProject'
        expect(value).to eq(described_class.app_title)

        # Settings are empty by default
        expect(RequestStore.read(:cached_settings)).to eq({})
        expect(Rails.cache.read(cache_key)).to eq({})
      end

      it 'clears the cache when writing a setting' do
        expect(described_class.app_title).to eq 'OpenProject'
        expect(RequestStore.read(:cached_settings)).to eq({})

        new_title = 'OpenProject with changed title'
        described_class.app_title = new_title
        expect(RequestStore.read(:cached_settings)).to be_nil
        expect(Rails.cache.read(cache_key)).to be_nil

        expect(described_class.app_title).to eq(new_title)
        expect(described_class.count).to eq(1)
        expect(RequestStore.read(:cached_settings)).to eq('app_title' => new_title)
      end
    end

    context 'when cache is not empty' do
      let(:cached_hash) do
        { 'available_languages' => "---\n- en\n- de\n" }
      end

      before do
        Rails.cache.write(cache_key, cached_hash)
      end

      it 'returns the value from the deeper cache' do
        expect(RequestStore.read(:cached_settings)).to be_nil
        expect(described_class.available_languages).to eq(%w(en de))

        expect(RequestStore.read(:cached_settings)).to eq(cached_hash)
      end

      it 'expires the cache when writing a setting' do
        described_class.available_languages = %w(en)
        expect(RequestStore.read(:cached_settings)).to be_nil

        # Creates a new cache key
        new_cache_key = described_class.send(:cache_key)
        new_hash = { 'available_languages' => "---\n- en\n" }
        expect(new_cache_key).not_to be eq(cache_key)

        # No caching is done until first read
        expect(RequestStore.read(:cached_settings)).to be_nil
        expect(Rails.cache.read(cache_key)).to be_nil
        expect(Rails.cache.read(new_cache_key)).to be_nil

        expect(described_class.available_languages).to eq(%w(en))
        expect(Rails.cache.read(new_cache_key)).to eq(new_hash)
        expect(RequestStore.read(:cached_settings)).to eq(new_hash)
      end
    end
  end

  # tests stuff regarding settings callbacks
  describe 'callbacks' do
    # collects data for the dummy callback
    let(:collector) { [] }

    # a dummy callback that collects data
    let(:callback)  { lambda { |args| collector << args[:value] } }

    # registers the dummy callback
    before do
      described_class.register_callback(:default_projects_modules, &callback)
    end

    it 'calls a callback when a setting is set' do
      described_class.default_projects_modules = [:some_value]
      expect(collector).not_to be_empty
    end

    it 'calls no callback on invalid setting' do
      allow_any_instance_of(Setting).to receive(:valid?).and_return(false)
      described_class.default_projects_modules = 'invalid'
      expect(collector).to be_empty
    end

    it 'calls multiple callbacks when a setting is set' do
      described_class.register_callback(:default_projects_modules, &callback)
      described_class.default_projects_modules = [:some_value]
      expect(collector.size).to eq 2
    end

    it 'calls callbacks every time a setting is set' do
      described_class.default_projects_modules = [:some_value]
      described_class.default_projects_modules = [:some_value]
      expect(collector.size).to eq 2
    end

    it 'calls only the callbacks belonging to the changed setting' do
      described_class.register_callback(:host_name, &callback)
      described_class.default_projects_modules = [:some_value]
      expect(collector.size).to eq 1
    end

    it 'attaches to the right setting by passing a string' do
      described_class.register_callback('app_title', &callback)
      described_class.app_title = 'some title'
      expect(collector).not_to be_empty
    end

    it 'passes the new setting value to the callback' do
      described_class.default_projects_modules = [:some_value]
      expect(collector).to include [:some_value]
    end

    it 'optionally passes the old setting value to the callback as the second argument' do
      described_class.host_name = 'some name' # set old value
      cb = lambda { |args| collector << args[:old_value] }
      described_class.register_callback(:host_name, &cb)
      described_class.host_name = 'some other name'
      expect(collector).to include 'some name'
    end
  end
end
