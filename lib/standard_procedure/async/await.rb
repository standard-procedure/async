module Kernel
  def await &block
    block.call.value.tap do |result|
      raise result if result.is_a? Exception
    end
  end
end
