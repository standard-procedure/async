RSpec.describe Standard::Procedure::Async::Actor do
  it "defines an asynchronous method and a hidden implementation method on a class" do
    klass = Class.new do
      include Standard::Procedure::Async::Actor

      async_def :do_something do
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
      include Standard::Procedure::Async::Actor

      async_def :do_something do
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
    klass = Class.new do
      include Standard::Procedure::Async::Actor

      async_def :do_something do |number|
        sleep rand(0.1)
        number
      end
    end
    instance = klass.new
    # the implementation of do_something sleeps for a random amount of time
    # so even though we add all the messages to the queue at once
    # and ask for the values in reverse order
    # we still expect the sequence to hold
    results = (1..10).map { |number| instance.do_something(number) }
    values_in_reverse = results.length.downto(1).map { |i| results[i - 1].value }
    expect(values_in_reverse).to eq (1..10).to_a.reverse
  end
end
