# frozen_string_literal: true

require_relative "rails_not_loaded_error"
require "concurrent/promises"

module Standard::Procedure::Async
  class Promises
    def initialize
      @promises = rails_is_loaded? ? ConcurrentRails::Promises : Concurrent::Promises
    end

    attr_reader :promises

    def future &block
      @promises.future(&block)
    end

    private

    def rails_is_loaded?
      return false if !defined?(Rails::Railtie)
      raise RailsNotLoadedError if !defined?(ConcurrentRails) || !defined?(Rails::Railtie)
      true
    end
  end
end
