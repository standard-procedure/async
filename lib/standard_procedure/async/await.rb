module Kernel
  def await &block
    block.call.value
  end
  
  def wait_for timeout = 30, &block 
    puts "WAITING"
    timeout = timeout * 10 
    counter = 0
    while !block.call do 
      puts "...waiting"
      sleep 0.1 
      counter += 1 
      raise "Timeout" if counter >= timeout 
    end
  end
end
