require 'spec_helper'

RSpec.describe TangoOrm do
  let(:file_path) { 'spec/fixtures/database.yml' }
  let(:env) { 'test' }
  let(:db_config) do
    { :dbname => "bank_account_test", :host=> "localhost", :port => 5432}
  end

  around do |example|
    # config is a class instance variable, so it persists between specs
    described_class.instance_variable_set(:@config, nil)
    example.run
    described_class.instance_variable_set(:@config, nil)
  end

  it "has a version number" do
    expect(TangoOrm::VERSION).not_to be nil
  end

  describe ".config" do
    before do
      expect(TangoOrm::Config).to receive(:load).with(nil, nil).
        and_return(db_config)
    end

    it "calls Config.load with file_path and env set to nil" do
      described_class.config
    end

    it "fetches the db config using the default file_path and env" do
      config = described_class.config
      expect(config).to eq db_config
    end

    it "sets TangoOrm config variable" do
      config = described_class.config
      expect(TangoOrm.config).to eq config
    end
  end

  describe ".configure" do
    context "when file_path and env arguments are given" do
      let(:file_path) { 'spec/fixtures/db.yml' }
      let(:db_config) do
        { :dbname => "hello_test", :host=> "localhost", :port => 5432}
      end

      before do
        expect(TangoOrm::Config).to receive(:load).with(file_path, env).
          and_return(db_config)
      end

      it "calls Config.load with correct file_path and env" do
        described_class.configure(file_path, env)
      end

      it "fetches the db config using the given file_path and env" do
        config = described_class.configure(file_path, env)
        expect(config).to eq db_config
      end

      it "sets TangoOrm config variable" do
        config = described_class.configure(file_path, env)
        expect(TangoOrm.config).to eq config
      end
    end

    context "when the given file_path is incorrect" do
      let(:file_path) { 'spec/fixtures/fake_db.yml' }

      it "raises an error" do
        expect { described_class.configure(file_path, env) }.
          to raise_error(TangoOrm::ConfigError)
      end
    end

    context "when the given config file is incorrectly formatted" do
      let(:file_path) { 'spec/fixtures/incorrect_config.yml' }

      it "raises an error" do
        expect { described_class.configure(file_path, env) }.
          to raise_error(TangoOrm::ConfigError)
      end
    end
  end
end
