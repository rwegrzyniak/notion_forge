# frozen_string_literal: true

require "spec_helper"

RSpec.describe NotionForge do
  it "has a version number" do
    expect(NotionForge::VERSION).not_to be_nil
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(NotionForge.configuration).to be_a(NotionForge::Configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      expect { |b| NotionForge.configure(&b) }.to yield_with_args(NotionForge.configuration)
    end

    it "allows setting configuration values" do
      NotionForge.configure do |config|
        config.token = "test_token"
        config.verbose = true
      end

      expect(NotionForge.configuration.token).to eq("test_token")
      expect(NotionForge.configuration.verbose).to be(true)
    end
  end

  describe ".reset!" do
    it "resets configuration to defaults" do
      NotionForge.configure do |config|
        config.token = "test_token"
        config.verbose = true
      end

      NotionForge.reset!

      expect(NotionForge.configuration.token).to be_nil
      expect(NotionForge.configuration.verbose).to be(false)
    end
  end

  describe ".log" do
    let(:output) { StringIO.new }

    before do
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
    end

    context "when verbose is enabled" do
      before { NotionForge.configuration.verbose = true }

      it "outputs info messages with emoji" do
        NotionForge.log(:info, "Test message")
        expect(output.string).to include("ℹ️ Test message")
      end

      it "outputs success messages with emoji" do
        NotionForge.log(:success, "Success message")
        expect(output.string).to include("✅ Success message")
      end

      it "outputs error messages with emoji" do
        NotionForge.log(:error, "Error message")
        expect(output.string).to include("❌ Error message")
      end
    end

    context "when verbose is disabled" do
      before { NotionForge.configuration.verbose = false }

      it "does not output messages" do
        NotionForge.log(:info, "Test message")
        expect(output.string).to be_empty
      end
    end
  end
end
