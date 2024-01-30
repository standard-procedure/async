RSpec.describe "StandardProcedure::Async::Await" do
  it "waits until the asynchronous method has completed before returning the result" do
    klass = Class.new do
      include StandardProcedure::Async::Actor

      async :do_something do
        sleep 0.2
        :the_result
      end
    end

    expect(await { klass.new.do_something }).to eq :the_result
  end

  it "raises an exception if the asynchronous method raises an exception" do
    klass = Class.new do
      include StandardProcedure::Async::Actor

      async :do_something do
        raise "Failure"
      end
    end

    expect { await { klass.new.do_something } }.to raise_error "Failure"
  end
end
