require 'test_helper'

class ResqueUnitTest < Test::Unit::TestCase

  def setup
    # should probably happen automatically, but I haven't thought of a
    # good way to hook setup() yet.
    Resque.reset!
  end

  context "A task that schedules a resque job implementing self.queue" do
    setup { Resque.enqueue(MediumPriorityJob) }
    should "pass the assert_queued(job) assertion" do
      assert_queued(MediumPriorityJob)
      assert_equal 1, Resque.queue(MediumPriorityJob.queue).length
    end
  end

  context "A task that schedules a resque job" do
    setup do 
      @returned = Resque.enqueue(LowPriorityJob)
    end

    should 'return a value that evaluates to true' do
      assert @returned
    end

    should "pass the assert_queued(job) assertion" do 
      assert_queued(LowPriorityJob)
    end

    should "fail the assert_not_queued(job) assertion" do 
      assert_raise Test::Unit::AssertionFailedError do 
        assert_not_queued(LowPriorityJob)
      end
    end

    should "should be size 1" do
      assert_equal 1, Resque.size(:low)
    end

    context ", when Resque.run! is called," do 
      setup do 
        assert !LowPriorityJob.run?, "The job should not have been run yet"
        Resque.run!
      end
      
      teardown do 
        LowPriorityJob.run = false
      end

      should "run the job" do 
        assert LowPriorityJob.run?, "The job should have run"
      end

      should "clear the job from the queue" do
        assert_not_queued(LowPriorityJob)
      end
    end

    # assert number of jobs?
  end

  context "A task that schedules a resque job with hooks" do
    setup do 
      Resque.enable_hooks!
      JobWithHooks.clear_markers
      Resque.enqueue(JobWithHooks)
    end

    teardown do
      Resque.disable_hooks!
    end

    should "have run the after_enqueue hook" do 
      assert_queued(JobWithHooks)
      assert(JobWithHooks.markers[:after_enqueue], 'no after_queue marker set')
    end

    should "run the before and after hooks during a run" do 
      Resque.run!
      assert(JobWithHooks.markers[:before], 'no before marker set')
      assert(JobWithHooks.markers[:around], 'no around marker set')
      assert(JobWithHooks.markers[:after], 'no after marker set')
      assert(!JobWithHooks.markers[:failed], 'failed marker set, and it should not')
    end

    should "run the before and failed hooks during a run" do
      JobWithHooks.make_it_fail do
        assert_raise(RuntimeError) do
          Resque.run!
          assert(JobWithHooks.markers[:before], 'no before marker set')
          assert(JobWithHooks.markers[:around], 'no around marker set')
          assert(!JobWithHooks.markers[:after], 'after marker set, and it should not')
          assert(JobWithHooks.markers[:failed], 'no failed marker set')
        end
      end
    end

    should "not call perform if the around hook raised Resque::Job::DontPerform" do
      JobWithHooks.make_it_dont_perform do
        Resque.run!
        assert(JobWithHooks.markers[:before], 'no before marker set')
        assert(JobWithHooks.markers[:around], 'no around marker set')
        assert(!JobWithHooks.markers[:after], 'after marker set, and it should not')
        assert(!JobWithHooks.markers[:failed], 'failed marker set, and it should not')
      end
    end

  end

  context "Block assertions" do
    should "pass the assert_queued(job) assertion when queued in block" do
      assert_queues(HighPriorityJob) do
        Resque.enqueue(HighPriorityJob)
      end
    end

    should "pass the assert_queued(job) assertion when queued and not in block" do
      Resque.enqueue(HighPriorityJob)
      assert_queues(HighPriorityJob) do
        Resque.enqueue(HighPriorityJob)
      end
    end

    should "fail the assert_queued(job) assertion when not queued in block" do
      Resque.enqueue(LowPriorityJob)
      assert_raise Test::Unit::AssertionFailedError do
        assert_queues(LowPriorityJob) do
          # Nothing.
        end
      end
    end

    should "pass the assert_not_queued(job) assertion when not queued in block" do
      Resque.enqueue(LowPriorityJob)
      assert_not_queued(LowPriorityJob) do
        # Nothing.
      end
    end

    should "fail the assert_not_queued(job) assertion when not queued in block" do
      assert_raise Test::Unit::AssertionFailedError do
        assert_not_queued(LowPriorityJob) do
          Resque.enqueue(LowPriorityJob)
        end
      end
    end

    should "fail the assert_not_queued(job) assertion when queued and not in block" do
      assert_raise Test::Unit::AssertionFailedError do
        Resque.enqueue(LowPriorityJob)
        assert_not_queued(LowPriorityJob) do
          Resque.enqueue(LowPriorityJob)
        end
      end
    end

    should "pass the assert_nothing_queued assertion when nothing queued in block" do
      Resque.enqueue(LowPriorityJob)
      assert_nothing_queued do
        # Nothing.
      end
    end

    should "fail the assert_nothing_queued assertion when queued in block" do
      assert_raise Test::Unit::AssertionFailedError do
        assert_nothing_queued do
          Resque.enqueue(LowPriorityJob)
        end
      end
    end
  end

  context "An empty queue" do
    should "pass the assert_not_queued(job) assertion" do 
      assert_not_queued(LowPriorityJob)
    end

    should "fail the assert_queued(job) assertion" do
      assert_raise Test::Unit::AssertionFailedError do 
        assert_queued(LowPriorityJob)
      end
    end

    should "be size 0 when empty" do
      assert_equal 0, Resque.size(:low)
    end
  end
  
  context "A task that schedules a resque job with arguments" do 
    setup do 
      Resque.enqueue(JobWithArguments, 1, :test, {:symbol => :symbol})
    end
    
    should "pass the assert_queued(job, *args) assertion if the args match and sees enqueued symbols as strings" do
      assert_queued(JobWithArguments, [1, "test", {"symbol"=>"symbol"}])
    end
    
    should "pass the assert_queued(job, *args) assertion if the args match using symbols" do
      assert_queued(JobWithArguments, [1, :test, {:symbol => :symbol}])
    end

    should "pass the assert_queued(job) assertion with no args passed" do
      assert_queued(JobWithArguments)
    end

    should "fail the assert_queued(job) assertion if the args don't match" do 
      assert_raise Test::Unit::AssertionFailedError do 
        assert_queued(JobWithArguments, [2, "test"])
      end
    end

    should "pass the assert_not_queued(job) assertion if the args don't match" do
      assert_not_queued(JobWithArguments, [2, "test"])
    end

    should "fail the assert_not_queued(job) assertion if the args match" do
      assert_raise Test::Unit::AssertionFailedError do 
        assert_not_queued(JobWithArguments, [1, "test", {"symbol"=>"symbol"}])
      end
    end
  end

  context "A job that schedules a new resque job" do
    setup do 
      Resque.enqueue(JobThatCreatesANewJob)
    end

    should "pass the assert_queued(job) assertion" do 
      assert_queued(JobThatCreatesANewJob)
    end

    should "fail the assert_not_queued(job) assertion" do 
      assert_raise Test::Unit::AssertionFailedError do 
        assert_not_queued(JobThatCreatesANewJob)
      end
    end

    should "pass the assert_not_queued(LowPriorityJob) assertion" do
      assert_not_queued(LowPriorityJob)
    end

    context ", when Resque.run! is called," do 
      setup do 
        Resque.run!
      end

      should "clear the job from the queue" do
        assert_not_queued(JobThatCreatesANewJob)
      end

      should "add a LowPriorityJob" do
        assert_queued(LowPriorityJob)
      end
    end

    context ", when Resque.full_run!" do
      setup do
        assert !LowPriorityJob.run?, "The job should not have been run yet, did you call 'LowPriorityJob.run = false' in teardowns of other tests?"
        Resque.full_run!
      end

      teardown do 
        LowPriorityJob.run = false
      end

      should "clear the jobs from the queue" do
        assert_not_queued(JobThatCreatesANewJob)
        assert_not_queued(LowPriorityJob)
      end

      should "run the new resque jobs" do
        assert LowPriorityJob.run?, "LowPriorityJob should have been run"
      end
    end
  end

  context "A task in a different queue" do
    setup do
      Resque.enqueue(LowPriorityJob)
      Resque.enqueue(HighPriorityJob)
    end

    should "add a LowPriorityJob" do
      assert_queued(LowPriorityJob)
    end

    should "add a HighPriorityJob" do
      assert_queued(HighPriorityJob)
    end

    context ", when Resque.run_for! is called," do 
      should "run only tasks in the high priority queue" do
        Resque.run_for!(Resque.queue_for(HighPriorityJob))
  
        assert_queued(LowPriorityJob)
        assert_not_queued(HighPriorityJob)
      end
    end
  end

  context "An assertion message" do
    context "of assert_queued" do
      should "include job class and queue content" do
        begin
          assert_not_queued(LowPriorityJob)
        rescue Test::Unit::AssertionFailedError => error
          assert_equal "LowPriorityJob should have been queued in low: [].", error.message
        end
      end
      
      should "include job arguments if provided" do
        begin
          assert_not_queued(JobWithArguments, [1, "test"])
        rescue Test::Unit::AssertionFailedError => error
          assert_equal "JobWithArguments with [1, \"test\"] should have been queued in medium: [].", error.message
        end
      end
    end

    context "of assert_not_queued" do
      should "include job class and queue content" do
        begin
          Resque.enqueue(LowPriorityJob)
          assert_not_queued(LowPriorityJob)
        rescue Test::Unit::AssertionFailedError => error
            assert_equal "LowPriorityJob should not have been queued in low.", error.message
        end
      end
      
      should "include job arguments if provided" do
        begin
          Resque.enqueue(JobWithArguments, 1, "test")
          assert_not_queued(JobWithArguments, [1, "test"])
        rescue Test::Unit::AssertionFailedError => error
          assert_equal "JobWithArguments with [1, \"test\"] should not have been queued in medium.", error.message
        end
      end
    end

    context "of assert_nothing_queued" do
      should "include diff" do
        begin
          Resque.reset!
          assert_nothing_queued do
            Resque.enqueue(LowPriorityJob)
          end
        rescue Test::Unit::AssertionFailedError => error
          assert_equal "No jobs should have been queued.\n<0> expected but was\n<1>.", error.message
        end
      end
    end
  end

  context "A job that does not specify a queue" do
    should "receive Resque::NoQueueError" do
      assert_raise(Resque::NoQueueError) do
        Resque.enqueue(JobThatDoesNotSpecifyAQueue)
      end
    end
  end
  
  context "A job inserted through Resque::Job.create" do
    should "be added to queue" do
      Resque::Job.create(:critical, 'MyJob')
      assert_queued MyJob    
    end
  end

end

class MyJob
  @queue = :critical 
end