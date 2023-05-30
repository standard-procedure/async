# frozen_string_literal: true

require_relative "rails_not_loaded_error"
require "concurrent/promises"

module Standard::Procedure::Async
  module Promises
    def self.promises
      rails_is_loaded? ? ConcurrentRails::Promises : Concurrent::Promises
    end

    def self.future &block
      promises.future(&block)
    end

    def self.rails_is_loaded?
      return false if !defined?(Rails::Railtie)
      raise RailsNotLoadedError if !defined?(ConcurrentRails) || !defined?(Rails::Railtie)
      true
    end
    private_class_method :rails_is_loaded?
  end
end
