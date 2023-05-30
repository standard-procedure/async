RSpec.describe Standard::Procedure::Async::Promises do
  context "when Rails is not loaded" do
    it "uses concurrent-ruby's Promises" do
      expect(Standard::Procedure::Async::Promises.new.promises).to eq Concurrent::Promises
    end
  end

  context "when Rails is loaded" do
    before do
      require "active_support"
      require "rails/railtie"
    end

    it "raises an error if concurrent-rails is not loaded" do
      expect { Standard::Procedure::Async::Promises.new.promises }.to raise_error Standard::Procedure::Async::RailsNotLoadedError
    end

    it "uses concurrent-rails's Promises" do
      require "concurrent_rails"
      expect(Standard::Procedure::Async::Promises.new.promises).to eq ConcurrentRails::Promises
    end
  end
end
