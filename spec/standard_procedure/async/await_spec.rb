RSpec.describe StandardProcedure::Async::Actor do
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
end
