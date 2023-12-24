# frozen_string_literal: true

require "concurrent/array"
require "concurrent/mvar"
require "concurrent/immutable_struct"
require_relative "promises"

module StandardProcedure::Async
  module Actor
    def self.included base
      base.class_eval do
        extend ClassMethods

        def initialize *args
          super
          @_promises = StandardProcedure::Async::Promises.new
          @_messages = Concurrent::Array.new
        end
      end
    end

    module ClassMethods
      def async name, &implementation
        name = name.to_sym
        implementation_name = :"_#{name}"

        define_method name do |*args, **params, &block|
          _add_message_to_queue(implementation_name, *args, **params, &block)
        end

        define_method implementation_name do |*args, **params, &block|
          implementation.call(*args, **params, &block)
        end
      end
    end

    private

    attr_reader :_messages

    def _add_message_to_queue name, *args, **params, &block
      message = Message.new(self, name, args, params, block, Concurrent::MVar.new)
      _messages << message
      _perform_messages if _messages.count == 1
      message
    end

    def _perform_messages
      @_promises.future do
        while (message = _messages.shift)
          message.call
        end
      end
    end

    # nodoc:
    class Message < Concurrent::ImmutableStruct.new(:target, :name, :args, :params, :block, :result)
      def value(timeout: 30)
        result.take(timeout)
      end
      alias_method :get, :value
      alias_method :await, :value

      def then &block
        block&.call value
      end

      def call
        result.put target.send(name, *args, **params, &block)
      end
    end
  end
end
