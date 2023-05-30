# frozen_string_literal: true

require_relative "async/version"
require_relative "async/error"
require_relative "async/promises"

module Standard
  module Procedure
    module Async
      extend Promises
    end
  end
end
