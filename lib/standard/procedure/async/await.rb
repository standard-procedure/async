module Kernel
  def await &block
    block.call.value
  end
end
