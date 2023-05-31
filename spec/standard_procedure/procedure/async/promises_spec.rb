RSpec.describe StandardProcedure::Async::Promises do
  context "when Rails is not loaded" do
    it "uses concurrent-ruby's Promises" do
      expect(StandardProcedure::Async::Promises.new.promises).to eq Concurrent::Promises
    end
  end

  context "when Rails is loaded" do
    before do
      require "active_support"
      require "rails/railtie"
    end

    it "raises an error if concurrent-rails is not loaded" do
      expect { StandardProcedure::Async::Promises.new.promises }.to raise_error StandardProcedure::Async::RailsNotLoadedError
    end

    it "uses concurrent-rails's Promises" do
      require "concurrent_rails"
      expect(StandardProcedure::Async::Promises.new.promises).to eq ConcurrentRails::Promises
    end
  end
end
