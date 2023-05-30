# Standard::Procedure::Async

## The Actor model

The [Actor Model](https://en.wikipedia.org/wiki/Actor_model) is widely regarded as one of the safest ways to write thread-safe code.  Each "actor" maintains a single internal thread and as messages are received by the actor (via method calls), the thread responds to those messages sequentially.  This means that no matter which thread sends a message to the actor, the actor's internal behaviour is always thread-safe.  

The actual implementation does not use a thread-per-object as that could get very costly.  Instead, each actor maintains a queue of incoming messages and then uses a [Future](https://ruby-concurrency.github.io/concurrent-ruby/master/Concurrent/Promises.html) to actually perform those messages.  The future uses a thread which is allocated from Concurrent Ruby's internal thread pool, freeing up resources when the system is quiet and increasing the number of workers when the system is busy.  

## Why does this gem exist?

Two reasons.  

Concurrent-ruby has a simple implementation of this model, using the [Async](https://ruby-concurrency.github.io/concurrent-ruby/master/Concurrent/Async.html) mixin.  However, Concurrent::Async uses [IVar](https://ruby-concurrency.github.io/concurrent-ruby/master/Concurrent/IVar.html)s which are now deprecated.  

In addition, while concurrent-ruby is an excellent library, it does not work well with Ruby on Rails.  The [Rails Executor](https://guides.rubyonrails.org/threading_and_code_execution.html) ensures that any threads interact safely with the framework.  But concurrent-ruby knows nothing about the executor.

Finally, using the actor model is infectious.  If you mark a public method as asynchronous, in order to be safe, you have to mark them all as asynchronous.  Concurrent::Async's syntax relies on the caller using `@my_object.async.my_method` which means that it is easy to forget and miss an asynchronous call.  Which in turn will result in inconsistent behaviour and hard to trace bugs.  

So [Standard::Procedure::Async::Actor](https://github.com/standard-procedure/async/blob/main/lib/standard/procedure/async/actor.rb) replaces the IVars with a mix of Futures and MVars.  The MVar is used to transfer the return values of any methods back to the calling thread and the Future is used to do the work in a separate thread.  

In addition, if you are in a Ruby on Rails project, Standard::Procedure::Async uses [Luiz Kowalski](https://github.com/luizkowalski)'s [concurrent_rails](https://github.com/luizkowalski/concurrent_rails) gem.  This is a layer above concurrent-ruby's Futures that ensure any future code is run within the Rails Executor.  

Finally, instead of relying on the caller to call `async` on asynchronous methods, we define the asynchronous methods on the class itself with the `async` definition.  The caller simply uses `@my_object.my_method` and it will always be run safely in an alternate thread.  There is also an implementation of `await`, making it easy to resolve the results of your method calls.  

## Adding `async` and `await` capabilities to ruby objects

Instead of defining methods on your class with ruby's `def` keyword, include the [Standard::Procedure::Async::Actor](https://github.com/standard-procedure/async/blob/main/lib/standard/procedure/async/actor.rb) module and use the `async` class method.  

When you call an asynchronous method, it immediately returns an internal message object.  If you don't care about the return value from the method, you can discard this object immediately.  But if you do need the return value, you can call `value` on this message object - and your thread will then wait until the return value is ready.  Alternatively, you can use `await`, effectively turning your asynchronous method into a synchronous one.  

An added bonus (or negative, depending upon your point of view) is that this syntax is very similar to Javascript's async/await pairing, which similarly marks out asychronous function calls and waits until any Promises are ready to return their values.  

Example usage:
```ruby
class MyObject 
  include Standard::Procedure::Async::Actor 

  def initialize name 
    @name = name 
    @status = :idle
  end

  async :report_status do 
    @status
  end

  async :greet do 
    "Hello #{@name}".freeze
  end

  async :rename do |new_name|
    @name = new_name.freeze
  end 

  async :do_some_long_running_task do 
    @status = :in_progress
    do_part_two_of_the_long_running_task
    @status 
  end

  private 

  async :do_part_two_of_the_long_running_task do 
    sleep 10 
    _rename "John"
    @status = :done
  end
end

@my_object = MyObject.new "George"

puts await { @my_object.greet } # => "Hello George"
await { @my_object.rename "Ringo" }
puts await { @my_object.greet } # => "Hello Ringo"
@my_object.rename "Paul" # Note: we didn't use await here - we'll talk about that later
puts await { @my_object.greet } # => "Hello Paul"

@initial_status = @my_object.do_some_long_running_task 
puts @initial_status # => a internal message object
puts @initial_status.value # => :in_progress
sleep 11
@final_status = await { @my_object.report_status }
puts @final_status # => :done
puts await { @my_object.greet } # => Hello John
```

### Defining asynchronous methods

When defining `MyObject`, we use `async` instead of `def` for each method.  For example, we use `async :greet` instead of `def greet`.  This creates two methods - `greet` and `_greet`.  `_greet` is the actual implementation of the method and `greet` is the asynchronous wrapper around it.  

### Awaiting the results from those methods

The asynchronous wrapper always returns an object containing a [Concurrent::MVar](https://ruby-concurrency.github.io/concurrent-ruby/master/Concurrent/MVar.html) which is empty until the actor has completed its work.  

If you need the return value from the method, there are two ways to access it.  

You can call `value` on the returned object, or you can use the `await` method (which is just a fancy wrapper around `value`).  In both cases the calling thread will block until the value is returned.  In the example above, you can see what happens if you use neither of these methods - `puts @initial_status` returns the internal message object itself, not any meaningful information.  The next line then calls `@initial_status.value` to wait until the return value is generated.  

### The sequence of asynchronous calls

In the example above there is the following code:

```ruby
@my_object.rename "Paul"
puts await { @my_object.greet } # => "Hello Paul"
```
The call to `rename` is asynchronous, so you may expect that sometimes the following call to `greet` would return "Hello Paul" and other times it would return "Hello Ringo" (the previous value) - depending on the timing of the two calls.  

However, it will _always_ return "Hello Paul".  

This is because internally, the actor queues all method calls.  So even if the call to `rename` takes a long time to complete, the subsequent call to `greet` will not start until `rename` has finished.  

Another example of the same behaviour is in `do_some_long_running_task`:

```ruby
  async :do_some_long_running_task do 
    @status = :in_progress
    do_part_two_of_the_long_running_task
    @status 
  end
```

When `@my_object.do_some_long_running_task` is called, the message `do_some_long_running_task` is added to the queue.  

When the queue starts processing that message, `_do_some_long_running_task` (the implementation of the method) changes the status to :in_progress, then adds `do_part_two_of_the_long_running_task` to the message queue.  This second message will _not_ start processing immediately as it is behind the unfinished `do_some_long_running_task`.  `_do_some_long_running_task` returns the value of status (which is still :in_progress) and completes, which allows the next message on the queue to start.  And that next message is probably `do_part_two_of_the_long_running_task` - but it might not be, as other threads may have got there first.  

### The rules of using actors

- If you make a public method asynchronous, you need to make _all_ public methods asynchronous.  You cannot mix and match asynchronous and synchronous usage. The simplest way to comply is to make all your public methods as `async` and your protected and private methods as synchronous.  If you have to call an async method on `self` use the internal implementation (which starts with `_`).
- Never make internal instance variables directly accessible without an asynchronous method call.  Do not use `attr_reader` or `attr_accessor` -  these will bypass the internal queue and you may get inconsistent results from the actor.  For the same reason, never update internal variables outside of an asynchronous call.  
- When an object is calling its own internal methods, never use `await` or `value` as this will cause your actor to block indefinitely.  If you don't care about the return value or if it does not matter when the method starts and finishes, call the asynchronous method.  If you need the return value or need to be sure that the method runs immediately then use the internal implementation - `_rename` instead of `rename`.
- Avoid class variables.  These are effectively global variables that are accessible without any locking around them, so you could get inconsistent results.  If you must have class variables, intialize them on startup and if they are mutable, use concurrent-ruby's thread-safe objects.  

## Making Rails work with Concurrent-Ruby

[Concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby) is amazing, providing an extensive suite of tools to make multi-threaded programming as safe as it can possibly be in ruby (which isn't perfect, as ruby's dynamic semantics make it impossible to be completely safe).  

However, concurrent-ruby doesn't play well with [Ruby on Rails](https://rubyonrails.org).  Rails is a big complex framework that auto-loads code and has lots of data stored in class variables (which are effectively globals that can be written to and read from any thread at any time).  Therefore it includes the [Rails Executor](https://guides.rubyonrails.org/threading_and_code_execution.html) which ensures that the framework is aware when other threads may be touching Rails code.  

This gem checks to see if `Rails` is defined, and if so, it attempts to load [Luiz Kowalski](https://github.com/luizkowalski)'s [concurrent_rails](https://github.com/luizkowalski/concurrent_rails) gem.  This provides a wrapper around concurrent-ruby's [Promises](https://ruby-concurrency.github.io/concurrent-ruby/master/Concurrent/Promises.html) factory that ensures the Rails Executor is loaded before the threaded code is run.  This gem then uses the concurrent-rails Future instead of concurrent-ruby's Future, so it can be sure that your code is both thread-safe and rails-safe.  

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'standard-procedure-async'
```

If you are using Ruby on Rails, you must also add in the `concurrent_rails` gem, or this gem will raise an error when you try to use it.

```ruby
gem 'concurrent_rails'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install standard-procedure-async

## Development

Coming soon
## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/standard-procedure-async.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
