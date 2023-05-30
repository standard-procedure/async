# frozen_string_literal: true

require_relative "async/version"
require_relative "async/error"
require_relative "async/promises"
require_relative "async/actor"
require_relative "async/await"
module Standard
  module Procedure
    module Async
      def self.promises
        @promises ||= Promises.new
      end
    end
  end
end
