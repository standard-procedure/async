RSpec.describe StandardProcedure::Async::Actor do
  it "defines an asynchronous method and a hidden implementation method on a class" do
    klass = Class.new do
      include StandardProcedure::Async::Actor

      async :do_something do
        :the_result
      end
    end

    expect(klass.new).to respond_to :do_something
    expect(klass.new).to respond_to :_do_something
    expect(klass.new._do_something).to eq :the_result
  end

  it "performs the asynchronous method in a background thread" do
    lock = Concurrent::MVar.new
    current_thread = Thread.current.to_s

    klass = Struct.new(:lock) do
      include StandardProcedure::Async::Actor

      async :do_something do
        # wait till the main thread tells us to go
        value = lock.take
        sleep 0.1
        lock.put Thread.current.to_s
        value
      end
    end

    result = klass.new(lock).do_something
    # do_something is now waiting for us to tell it to go
    lock.put current_thread
    # wait for do_something to finish
    value = result.value
    # value should be the current thread ID that we passed to lock.put
    expect(value).to eq current_thread
    # other_thread should be the thread ID that do_something placed into the lock
    other_thread = lock.take
    # test that do_something actually ran in a different thread
    expect(other_thread).not_to eq current_thread
  end

  it "adds multiple messages to a queue and performs them in order" do
    values = Concurrent::Array.new

    klass = Struct.new(:values) do
      include StandardProcedure::Async::Actor

      async :do_something do |number|
        sleep(0.3) if number % 2 == 0
        values << number
        :done
      end
    end
    instance = klass.new
    # Because do_something sleeps for a random amount of time,
    # it will theoretically fill up the values array in a random order.
    # However as the actor queues all the method calls
    # and performs them in order, the values array should be in order.
    results = (1..10).map { |number| instance.do_something(number) }
    # wait for all the messages to finish
    results.each(&:value)
    expect(values).to eq (1..10).to_a
  end

  it "times out when attempting to retrieve a result from a method that has not finished" do
    klass = Class.new do
      include StandardProcedure::Async::Actor

      async :wait_for_ages do
        sleep 10 # this will never finish
        "You will never see this"
      end
    end

    result = klass.new.wait_for_ages
    expect(result.value(timeout: 0.1)).to eq Concurrent::MVar::TIMEOUT
  end
end
